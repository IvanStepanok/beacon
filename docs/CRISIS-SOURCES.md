# Beacon — Crisis sources & lifecycle

_How a "crisis" comes into being, where the data comes from, and how reports attach to it._
_Last updated 2026-06-08._

> **⚠️ Roadmap / design — NOT in the current build.**
> Most of this document (USGS / GDACS and other automated disaster-feed ingestion,
> the background poller, `POST /api/v1/feeds/refresh`, and feed-driven auto-creation of
> crises) describes a **planned design that is not implemented in the shipped build**.
> There is no feed ingestion in the current product.
>
> **What ships today as the live crisis source:** emergent crises proposed from
> clusters of community reports, plus analyst / manual crisis creation. The
> emergent → proposed → analyst confirm/dismiss lifecycle is real; the feed legs below
> are roadmap. Read the rest of this file as design intent, not current capability.

## What a crisis is

A **crisis** in Beacon is a **discrete event** (assessment unit): an earthquake, a
flood, a strike, not a permanent state. The challenge's scale numbers ("hundreds
of crises/year, up to 500k reports/crisis") describe events, not standing conditions.
A long-running situation (e.g. a country's complex emergency) is modeled as a
**Response** umbrella that many event-crises roll up to:

```
Response (umbrella, long-running)  →  Crisis / Event (the assessment unit)  →  Reports
   e.g. "Ukraine response"              e.g. "Strike on Odesa, 2026-06-08"        citizen submissions
```

Each crisis carries spatial extent (`center` + `radius_km`), a time window
(`started_at` … `ended_at`), a `status` (`active | proposed | closed | dismissed`),
a `source`, and a `glide` (the global disaster id used as the cross-source dedup key).

Reports are **decoupled** from crises: a citizen can report damage **anywhere, anytime**,
even before any crisis is declared. The server assigns a report to a crisis **by
space + time**. If nothing matches, the report is **pending** (`crisis_id = NULL`) and
may seed an emergent crisis (below).

## The three source legs (industry-standard hybrid)

Serious crisis systems never rely on one channel. Beacon combines three, deduplicated
against GLIDE and gated by analyst verification:

| Leg | Direction | Status in Beacon | Notes |
|---|---|---|---|
| **Authoritative open feeds** | top-down | 🔜 **Roadmap / not in current build (USGS, GDACS, more)** | event known from global monitoring the moment it's detected |
| **Analyst / agency declaration** | top-down | ✅ built | RAPIDA activation; seeded crises; analyst confirm of proposals |
| **Emergent from citizen reports** | bottom-up | ✅ built | fastest for localized/sudden events feeds miss or lag |

This matches RAPIDA's own model (`challenge.md`): within 72 h it "combines satellite
imagery, geospatial overlays, and remote analytics", i.e. the event is known from
feeds/satellite first, and our crowdsourced reports "complement … and validate
preliminary findings." `need.md` explicitly states integration with **satellite/GIS
systems will be preferred**.

## Roadmap — live feed ingestion (keyless, real-time)

> **Not in the current build.** This section describes a planned design, not a shipped
> capability. There is no feeds package, background poller, or `/feeds/refresh` route in
> the shipped product; crises are not created from external feeds today.

As designed, a background poller would run on startup and every `FEEDS_INTERVAL_MIN`
(default 30 min); analysts could also trigger it on demand via
`POST /api/v1/feeds/refresh`. Each connector would be best-effort and isolated: a feed
that is down or changes shape is logged and skipped.

| Source | Endpoint (no key) | Hazards | Mapping |
|---|---|---|---|
| **USGS** | `earthquake.usgs.gov/.../4.5_week.geojson` | earthquakes (+ tsunami flag) | precise epicenter; radius from magnitude; `feed:USGS` |
| **GDACS** (JRC + UN OCHA) | `gdacs.org/gdacsapi/.../geteventlist/MAP` | EQ · TC(→hurricane) · FL(flood) · WF(wildfire) · DR(drought) · VO(volcano) | bbox center; radius from bbox/alert level; carries **GLIDE**; Orange+Red only (Green = noise); `feed:GDACS` |

In the design, each feed event would upsert a crisis **idempotently by deterministic id**
(`usgs-<id>`, `gdacs-<TYPE>-<id>`), so re-polling refreshes rather than duplicates, and
**never clobbers** an analyst- or emergent-created crisis. After each upsert, pending
reports inside the new crisis's coverage+window would be swept into it
(`AssignPendingToCrisis`).

## Planned — additional sources (designed; need a key, registration, or licensing)

> Roadmap, like the rest of the feed legs — not in the current build.

The planned connector interface (`feeds.Connector`) is designed so each of these would
be a drop-in addition:

| Source | Hazards | Why not yet wired |
|---|---|---|
| **ReliefWeb (OCHA) v2** | declared disasters + **GLIDE** registry | requires an approved `appname` (free registration), trivial once granted; would enrich the GLIDE dedup layer |
| **NASA FIRMS** | active wildfire/thermal detections (satellite, near-real-time) | requires a free `MAP_KEY` |
| **Copernicus EMS** (+ GloFAS floods, EFFIS fires) | EU rapid-mapping activations | activation feeds less uniform; on the roadmap |
| **ACLED / UCDP** | armed-conflict & political-violence events | API key + registration; licensing restrictions; data politically sensitive, analyst-gated ingestion planned |
| **PDC DisasterAWARE** | multi-hazard | partner access |

## Dedup & merge strategy

_Items 1–3 below cover the roadmap feed legs and are **not in the current build**; only
item 4 (report-level dedup) ships today._

1. **Within a source** (roadmap): deterministic id ⇒ re-poll is an idempotent upsert.
2. **Across sources** (roadmap): **GLIDE** is the join key. When two feeds publish the
   same event (e.g. a USGS and a GDACS earthquake), they would coexist as linked crises;
   the planned merge collapses them on matching GLIDE, else on a space + time + nature
   fuzzy match, keeping the most authoritative.
3. **Emergent ↔ feed** (roadmap): when a feed publishes an event that an emergent
   (`proposed`) citizen cluster already represents, the authoritative feed crisis would
   win and the emergent proposal's reports be reassigned to it. (The emergent → proposed →
   analyst-confirm/dismiss lifecycle that backs this is already built.)
4. **Report-level dedup**: per-building versioning + capture-time proximity checks
   (already built) prevent duplicate reports for the same building.

## Config

**Roadmap (not in current build)** — these feed-ingestion env vars are part of the
planned design only; the shipped product has no feed poller and does not read them:

| Env | Default | Meaning |
|---|---|---|
| `FEEDS_ENABLED` | `true` | poll external disaster feeds |
| `FEEDS_INTERVAL_MIN` | `30` | minutes between ingest passes |

**Shipped** — emergent-cluster thresholds (in `store/crisis.go`): radius 2 km, window
24 h, min 3 reports — production-tunable.
