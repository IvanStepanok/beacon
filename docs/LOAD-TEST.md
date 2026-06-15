# Beacon — Database scale, architecture & load test

_Evidence for the challenge requirement: "detail the structure, scale, and architecture
of your database" for up to **500k reports per crisis** and **hundreds of crises per year**._
_Run 2026-06-08 on PostgreSQL 16 + PostGIS 3.4. Raw `EXPLAIN ANALYZE` output:
[`load-test-explain.txt`](./load-test-explain.txt)._

**Read this first — what is deployed vs. what is benchmarked.** The **currently deployed
production schema is a flat (non-partitioned) `reports` table with the index set below**, and
it **meets the stated interactive targets at 525k rows (measured)** — the flat twin ran the
heaviest map query in 6.6 ms, and every other query uses the same crisis_id-leading indexes.
**`LIST` partitioning by `crisis_id` is NOT deployed**; it is the **benchmarked migration
path** (validated side-by-side in this test) for the multi-hundred-crisis scale, where its
payoff is operational (pruning, per-partition retention `DROP`, bounded maintenance), not
single-query speed. The migration recipe is at the end of this document.

## Method

A benchmark schema mirroring the production `reports` columns + indexes, seeded with
**525,000 synthetic reports**:
- **500,000** in one crisis (`crisis-big`) over ~200k buildings, spread across a 0.6° bbox;
- ~25,000 across two other crises (`crisis-b`, `crisis-c`).

Two tables, identical columns + indexes, to isolate the effect of partitioning:
- `reports_p` — **partitioned by `LIST (crisis_id)`** (one partition per crisis + a DEFAULT);
- `reports_np` — a flat (non-partitioned) table — **the same shape as the deployed
  production schema**.

Indexes (both): GIST `(geom)`, btree `(crisis_id, captured_at DESC)`, `(building_id, captured_at DESC)`, `(crisis_id, damage)` — the same crisis_id-leading indexes the live schema uses.

## Results — every interactive query is sub-30 ms on 500k rows

| Query (the real client request) | Plan | Time |
|---|---|---|
| **Q1** crisis-scoped map bbox count (~14k hits) | **pruned to 1 partition** (`reports_p_big`) → GIST bitmap scan | **22 ms** (flat: 6.6 ms) |
| **Q2** latest-per-building in crisis bbox (map pins) | pruned partition + GIST + window | **4.4 ms** |
| **Q3** damage breakdown for the crisis (stats, full 500k) | pruned partition + **parallel** seq scan (3 workers) | **30 ms** |
| **Q4** keyset pagination, page 1 (reports list) | index scan `(crisis_id, captured_at DESC)`, 1 partition | **0.08 ms** |
| **Q5** MVT tile bbox, **no crisis filter** ("near me", cross-partition) | `Append` over each partition's GIST index | **0.06 ms** |

**Storage:** a 500k-report crisis = **162 MB** (68 MB heap + 93 MB indexes).

## What this proves

1. **Partition pruning works** — a crisis-scoped query (Q1–Q4) reads **only that crisis's
   partition**, never the other crises' rows. The `EXPLAIN` shows a single `reports_p_big`
   node; the other partitions are pruned at plan time.
2. **The viewport + index design is the primary scaler.** Bbox / tile / list / latest-per-
   building queries finish in **sub-millisecond to single-digit ms** even at 500k, because
   they touch only the visible rectangle (GIST) or a keyset index range — never a full scan.
   Only the full-crisis stats aggregate reads all 500k, and that is **30 ms** (parallelised).
3. **Honest nuance — the flat table is what runs in production, and it is enough at this
   scale:** at 500k rows in one crisis, the **indexes alone** already deliver the latency —
   Q1 was actually **faster on the flat table** (6.6 ms vs 22 ms; planner/parent overhead,
   both far under the interactive threshold). Partitioning's payoff is **operational and
   grows with the number of crises** (next section), not single-query speed on one crisis —
   which is exactly why the deployed schema stays flat until crisis count demands it.

## Why partition by `crisis_id` (the migration path, at hundreds of crises/year)

- **Tenant isolation & pruning** — each crisis's data is physically separate; a query for one
  crisis can never be slowed by another's volume, and per-partition indexes stay
  crisis-sized instead of growing with the global total.
- **Retention by partition** — when a crisis closes and its retention window passes, `DROP`/
  `DETACH` the partition: instant, no giant `DELETE`, matching the data-retention SOP.
- **Parallelism** — Postgres scans partitions in parallel (`Parallel Append`), so cross-crisis
  analytics scale with cores.
- **Bounded maintenance** — `VACUUM`/`ANALYZE`/reindex run per partition.

**Topology:** `LIST (crisis_id)` with a partition auto-created when a crisis is declared
(analyst/emergent) + a `DEFAULT` partition for pending/unassigned reports. For lower
operational overhead, `HASH (crisis_id)` into a fixed partition count is the alternative —
pruning still applies for `WHERE crisis_id = $1`, at the cost of per-crisis `DROP`.

## Capacity projection

500k/crisis × ~200 crises/year ≈ **100M reports/year ≈ ~32 GB/year** — trivial for a single
PostgreSQL node; partition-per-crisis + retention keeps the *hot* working set to active
crises only. Beyond that: read replicas for the map/stats read path (the app is stateless
behind Traefik and already pools via pgxpool), MVT tiles behind a CDN (30 s cache, already
emitted), and the existing latest-per-building dedup to cap the rendered set.

## Production migration path (live flat table → partitioned)

To restate the summary at the top: the live `reports` table is **flat (not partitioned)
today** — both because the demo's ~60 rows make partitioning pure operational cost, and
because the flat schema is **measured to hold the stated targets at 525k rows**. The self-FK
`supersedes_report_id` + audit FKs would need composite-key rework before partitioning.
When sustained multi-hundred-crisis volume arrives, partitioning is validated here at 500k
and applied in production via:

1. `CREATE TABLE reports_new (LIKE reports INCLUDING ALL) PARTITION BY LIST (crisis_id)` with
   PK `(crisis_id, id)`; create one partition per active crisis + `DEFAULT`.
2. Re-point the self-FK (`supersedes_report_id`) and audit FKs to the composite key, or
   enforce those relationships in the service layer (they are already written transactionally).
3. `INSERT INTO reports_new SELECT * FROM reports;` then swap names in one transaction.
4. Auto-create a partition in the crisis-creation path (analyst / emergent).

This is a forward-only migration with no contract change — every API response is identical.
