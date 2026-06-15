# Beacon — System Architecture

_The end-to-end architecture in one document: components, data flow, scale, security
tiers, exports, and integration pathways. Authoritative build state:
[`STATUS.md`](./STATUS.md); API contract: `backend/openapi.yaml`._

## Components

```
                ┌────────────────────────┐        ┌──────────────────────────┐
                │  Reporter mobile app   │        │  Analyst console (web)   │
                │  Kotlin Multiplatform  │        │  Next.js 16 + React 19   │
                │  Compose (Android/iOS) │        │  MapLibre · RBAC-gated   │
                │  Voyager+MVI+Koin      │        │  + /public heatmap page  │
                │  MapLibre · offline    │        │  (no login, coarsened)   │
                │  outbox · Plus Codes   │        └────────────┬─────────────┘
                └───────────┬────────────┘                     │ JWT (analyst)
                            │ X-Device-Id (anonymous)          │ none (public)
                            ▼                                  ▼
                ┌──────────────────────────────────────────────────────────┐
                │            Traefik edge (TLS / Let's Encrypt)            │
                └────────────────────────────┬─────────────────────────────┘
                                             ▼
                ┌──────────────────────────────────────────────────────────┐
                │   Go API (chi + pgx) — backend/internal                  │
                │   idempotent submit · crisis assignment (space+time +    │
                │   geographic containment) · versioning · RBAC · rate     │
                │   limits · public projection (~110 m) · form-schema ·    │
                │   exports · MVT tiles ·                                  │
                │   boundary loader (Natural Earth + geoBoundaries ADM1)   │
                └──────┬───────────────┬──────────────────┬────────────────┘
                       ▼               ▼                  ▼
            ┌────────────────┐ ┌───────────────┐ ┌──────────────────────┐
            │ PostgreSQL 16  │ │ Photo volume  │ │ LibreTranslate       │
            │ + PostGIS 3.4  │ │ beacon-photos │ │ (self-hosted MT,     │
            │ embedded goose │ │ (durable,     │ │ beacon-libretranslate│
            │ migrations     │ │ named volume) │ │ container)           │
            └────────────────┘ └───────────────┘ └──────────────────────┘
```

All three repos in this workspace: `backend/` (Go), `Mobile app/` (KMP), `dashboard/`
(Next.js). Live: `beacon-api.stepanok.com` / `beacon.stepanok.com` (+ `/public`) /
`beacon-help.stepanok.com`.

## Data flow (capture → action)

1. **Capture (offline-first)** — guided wizard in the app: in-app camera (EXIF GPS/time
   stripped on device), 3-level damage classification (minimal / partial / complete),
   infrastructure (+ optional
   `infraName`), location (GPS fix, tapped building footprint → stable `fp-` hash, or
   landmark-only), Plus Code computed on device. Capture form (incl. modular questions)
   comes from the server's **dynamic form-schema endpoint** with per-crisis require/hide
   overrides, cached for offline use.
2. **Outbox** — reports queue locally (`Mobile app/shared/.../data/outbox/`) and auto-flush
   on reconnect.
3. **Idempotent submit** — `POST /api/v1/reports` with client-generated id as PK
   (`ON CONFLICT` upsert) + `X-Device-Id` pseudonym; anti-abuse guards (per-device rate
   limits, near-dup 409) in `backend/internal/service/report_service.go`.
4. **Crisis assignment** — explicit crisis honored only if the point falls inside that
   crisis's spatial extent (**geographic containment**); otherwise assigned by space+time
   to the nearest covering active/proposed crisis, else **pending** (may seed an emergent
   crisis from ≥3 nearby pending reports). Emergent crises are proposed from report
   clusters and confirmed or dismissed by an analyst.
5. **Enrichment** — reverse-geocode to admin areas (`ST_Contains` over `admin_areas`;
   global auto-Area via `backend/internal/boundary/`); description auto-translated to
   English by LibreTranslate (original preserved).
6. **Version chain** — server computes `version` + `supersedesReportId` per building in a
   transaction; the building timeline is latest-wins, never client-asserted.
7. **Verify** — analyst console: verify/flag (photo-gated — verifying a photo-less
   report needs an explicit `force` + note, both audited) via
   `PATCH /api/v1/reports/{id}/verification`.
8. **Out** — interop exports (below), the coarsened public heatmap (`/public`), MVT tiles
   (`GET /api/v1/tiles/reports/{z}/{x}/{y}`), and the print brief for offline handoff.

## Scale (measured — [`LOAD-TEST.md`](./LOAD-TEST.md))

- 525k synthetic reports, PostgreSQL 16 + PostGIS 3.4: every interactive query
  **sub-30 ms** (map bbox 6.6–22 ms, map pins 4.4 ms, keyset page 0.08 ms, full-crisis
  stats aggregate 30 ms). Storage: **162 MB per 500k-report crisis**.
- **Honest schema note:** the deployed `reports` table is **flat + indexed** (GIST geom,
  crisis_id-leading btrees) and meets the targets at 525k rows as measured.
  `LIST (crisis_id)` partitioning is the **benchmarked migration path** for
  multi-hundred-crisis scale (pruning, per-partition retention `DROP`) — validated
  side-by-side in the same test, not deployed.
- Projection: 500k/crisis × ~200 crises/yr ≈ 100M rows ≈ ~32 GB/yr — single-node
  territory; stateless API behind Traefik scales horizontally, MVT tiles are
  CDN-cacheable.

## Security tiers

- **Anonymous reporters** — no account; pseudonymous `X-Device-Id`
  ([`DATA-DICTIONARY.md`](./DATA-DICTIONARY.md) §6).
- **Public / low-trust reads** (anonymous + `external_viewer`) — **verified reports only**
  through the locked-down public projection: coordinates coarsened to ~110 m, submitter
  id / Plus Code / landmark / building id / free text stripped
  (`publicProjection`, `backend/internal/handler/handlers.go`); bulk export denied (403).
  The `/public` heatmap renders only this tier.
- **Analysts** — JWT + bcrypt, 5 roles, crisis-scoped, audit actor from token
  (`backend/internal/auth/`, migrations `00006`). Verification decisions audited.
- Honest gaps (encryption at rest, MFA, cert pinning, purge job, real IdP) are tracked as
  binding pre-deployment gates in [`STATUS.md`](./STATUS.md) and `SECURITY.md` — not
  claimed here.

## Export surface

`GET /api/v1/reports/export?format=geojson|csv|gpkg|kml|shapefile` (analyst-only, crisis-scoped;
schemas in [`DATA-DICTIONARY.md`](./DATA-DICTIONARY.md) §4): **GeoJSON** · **CSV with HXL
hashtag row** · **GeoPackage** (pure-Go OGC 1.3) · **KML** · **Shapefile**. All carry the 3-tier
`damage_classification` (`Minimal|Partial|Complete`) plus the raw grade. Modular columns
flatten as **three stable columns plus dynamic extras derived from the report data** —
a new modular section reaches exports automatically, without code changes. The on-device
reporter export (GeoJSON/CSV) is a **schema-aligned subset** of the same vocabulary (same
column names; the device file lacks the verification/admin columns and the HXL row).

## Integration pathway (roadmap — none of these are claimed as built)

- **UNDP GeoHub** — publish the verified layer as **PMTiles** for GeoHub upload; the
  backend already emits the same data as MVT tiles, so this is a packaging step.
- **RAPIDA** — ship our GeoPackage with zonal aggregates following RAPIDA's `stats.*`
  column convention so Beacon ground truth drops into the same QGIS/RAPIDA workflow that
  consumes satellite damage classes (see [`OPERATIONAL-MODEL.md`](./OPERATIONAL-MODEL.md)).
- **OCHA COD-AB P-codes** — implemented: on the first report in a country the backend
  lazily fetches that country's official COD-AB ADM1+ADM2 P-codes from HDX (`source='cod'`),
  which `ResolveAdmin` ranks above geoBoundaries. Export admin columns are `admin*_pcode`
  (HXL `#loc+admN+code`); where no COD is published for a country the value carries a `GB:`
  prefix marking it a geoBoundaries shapeID fallback, not an official P-code (see
  [`STATUS.md`](./STATUS.md) § Admin-boundary follow-ups).
