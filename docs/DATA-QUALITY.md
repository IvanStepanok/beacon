# Beacon — Data Quality & Verification Workflow

_How a crowd-sourced report becomes data an analyst can act on: the controls between
"someone tapped submit" and "this is on the verified map." Field semantics:
[`DATA-DICTIONARY.md`](./DATA-DICTIONARY.md); honest build state: [`STATUS.md`](./STATUS.md)._

## Verification — is it credible?

Every report carries a **verification** state (`pending|verified|flagged`). Verification is
an analyst-only mutation (`PATCH /reports/{id}/verification`), RBAC- and crisis-scoped, with
every decision audited server-side (`report_verification_audit` — actor from the JWT, never
a header).

## Controls at intake (server-side, before any human)

- **Photo-gate on verify** — verifying a report **without a photo** requires an explicit
  analyst `force` flag plus a written note; both land in the verification audit trail.
  Default path: no photo, no verify.
- **Geographic containment** — a report claiming a pinned crisis is accepted onto it only
  if its point falls inside that crisis's spatial extent; otherwise it goes through normal
  space+time assignment (or pending). Stops mis-pinned/cross-country attachments.
- **Near-duplicate guard** — any report **without a tapped footprint** from the same
  submitter within **25 m and 10 minutes** of their previous one is rejected with **409 +
  the existing report id** (`backend/internal/service/report_service.go`); only a real
  footprint re-report is exempt (it versions instead, see below). The app points the user
  at the original and surfaces the server rejection as a terminal **"Rejected"** sync
  state — no silent retries.
- **Rate limits** — per-device (5/min burst, 20/10 min sustained, DB-backed → 429) and
  per-IP (`backend/internal/api/router.go`).
- **Place sanitation** — generic reporter-side place stamps ("Your location", "unknown")
  carry no analyst value and are filtered out of analyst-facing locator labels; the label
  falls back place → Plus Code → coordinates → landmark (`dashboard/lib/format.ts`).

## Building identity — three explicitly distinguished location qualities

A `buildingId` exists **only** when the reporter tapped a real map footprint — it is never
fabricated from coordinates (`Mobile app/.../capture/CaptureFlowScreenModel.kt`). The
`buildingSource` field records how the identity was derived, so consumers never mistake
one location quality for another:

| Quality | How it's produced | Stability |
|---|---|---|
| **Footprint** (`buildingSource="footprint"`) | Reporter taps a map building footprint → stable `fp-` FNV-1a hash of the normalized ring (`Mobile app/.../map/BeaconMap.kt`) | Strong: re-reports of the same footprint always collide into one chain |
| **GPS pin only** | No footprint tapped → the report carries the pin + `gpsAccuracyMeters` and **no building identity** (`buildingId` null — a coordinate-derived id would defeat the near-dup guard) | Honest about precision; the 25 m / 10 min near-dup guard applies |
| **Landmark-unresolved** | No fix at all (indoors, jammed GPS) → free-text landmark only; `lat`/`lng` stored **NULL**, `locationResolved=false` — never `0,0` (migration `00012_location_unresolved.sql`) | Located by a human later; excluded from geometric exports (blank geometry) |

## Versioning — latest wins, server-authoritative

Re-reports of the same **footprint** `buildingId` are **not duplicates**: the server
computes `version` and `supersedesReportId` in a row-locked transaction, building a
per-building timeline (damage over time is real signal). Only footprint ids version
freely — any non-footprint re-report near the same spot inside the 25 m / 10 min window
is a **409** (near-duplicate guard above), not a new version. Maps and exports dedupe to
**latest-per-building**; "worst-of" comparisons rank by the 3-tier rollup (`minimal` <
`partial` < `complete`), never by raw grade strings.

## Public-tier protections

Quality control includes what low-trust callers *can't* see: anonymous and
`external_viewer` reads return **verified reports only**, coordinates coarsened to ~110 m,
with submitter id / Plus Code / landmark / building id / free text stripped, and bulk
export denied (`SECURITY.md`; `publicProjection` in
`backend/internal/handler/handlers.go`). Unverified photos are never served
unauthenticated. The `/public` heatmap page renders only this tier.

## Honest "not yet" list

- **ML/CV duplicate detection** (image similarity across submitters) — not built; today's
  dedup is spatial-temporal + building-identity based.
- **Reviewer assignment queues** (auto-routing pending reports to specific analysts,
  workload balancing) — not built; analysts work the pending list directly, there is no
  queueing or assignment engine.
- **Freshness SLA dashboards** (time-to-verify metrics, stale-report alerts) — `ageMin` is
  exposed per report; no SLA tracking UI exists.
- **AI damage-grade suggestion** remains an advisory stub — see the AI/CV section in
  [`STATUS.md`](./STATUS.md).
