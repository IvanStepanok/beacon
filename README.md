# Beacon — community ground truth for crisis damage mapping

Beacon is an open-source (Apache-2.0) system that lets affected communities report
building damage after a crisis from their phone: offline-first, anonymous, in all six
UN languages. Analysts then verify, triage, and export the result in the formats
humanitarian teams already use (GeoJSON, HXL-tagged CSV, GeoPackage, KML, Shapefile).
It is not another satellite product. It is the ground-level layer that complements UNDP
RAPIDA and satellite workflows, supplying the signal nadir imagery misses: low damage
grades, side- and ground-floor collapse, and the "possibly damaged" middle. Built for the
UNDP "Build the Future of Crisis Mapping" challenge.

## Components

| Component | Stack | Where |
|---|---|---|
| Reporter mobile app | Kotlin Multiplatform + Compose (Android + iOS), Voyager + MVI + Koin, MapLibre | [github.com/IvanStepanok/beacon-mobile](https://github.com/IvanStepanok/beacon-mobile) |
| Backend API | Go (chi + pgx) + PostgreSQL 16 / PostGIS, embedded migrations, LibreTranslate sidecar | [github.com/IvanStepanok/beacon-backend](https://github.com/IvanStepanok/beacon-backend) |
| Analyst console + public view | Next.js 16 + React 19 + Tailwind + MapLibre | [github.com/IvanStepanok/beacon-dashboard](https://github.com/IvanStepanok/beacon-dashboard) |

Docs live in [`docs/`](docs/). Start with [`docs/STATUS.md`](docs/STATUS.md), the honest
record of what is built and what is not, then
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md),
[`docs/DATA-QUALITY.md`](docs/DATA-QUALITY.md),
[`docs/INCENTIVES.md`](docs/INCENTIVES.md), and the governance pack
([`docs/governance/`](docs/governance/)).

## Live demo

| Service | URL |
|---|---|
| Analyst console | https://beacon.stepanok.com (demo login in [`docs/STATUS.md`](docs/STATUS.md)) |
| Public damage heatmap (no login, coarsened, verified-only) | https://beacon.stepanok.com/public |
| Backend API | https://beacon-api.stepanok.com |
| Help / how-it-works | https://beacon-help.stepanok.com |

All four links are live now; the `/public` heatmap needs no login.

## What it does

Everything below is implemented. See STATUS.md for the equally honest list of what isn't.

- Offline-first capture: in-app camera (EXIF stripped on the device), 3-level damage grade
  (minimal / partial / complete), building-footprint snap for a stable building identity,
  on-device Plus Codes, an outbox that survives dead networks, and downloadable map packs.
- Six UN languages with Arabic right-to-left in the app. Free-text descriptions are
  translated to English at intake by a self-hosted LibreTranslate, and the original is kept.
- Self-proposing crises: a cluster of community reports can propose a new crisis for an
  analyst to confirm or dismiss, with global admin-area tagging that needs no per-country
  GIS prep.
- Verification and triage console: photo-gated verification with a full audit trail, a
  per-building damage timeline (server-side versioning), and a print brief for offline handoff.
- Exports in GeoJSON, CSV+HXL, GeoPackage, KML, and Shapefile. New modular sections show up
  in exports on their own (three stable modular columns plus extras derived from the data).
- Privacy tiers: anonymous reporters (no account, pseudonymous device id); public reads are
  verified-only with coordinates coarsened to about 110 m; analyst access is RBAC + JWT across
  five crisis-scoped roles.
- Measured scale: a 525k-report benchmark with every interactive database query under 30 ms by
  EXPLAIN ANALYZE execution time (end-to-end HTTP is ~140 ms–1 s at 500k; see
  [`docs/LOAD-TEST.md`](docs/LOAD-TEST.md)).

## Quick start

Each component is its own public repo (links in the Components table above); clone the one you
want. Full instructions in [`CONTRIBUTING.md`](CONTRIBUTING.md).

```bash
# Backend (Go 1.26+, Docker for the DB)
cd backend && make db-up && make run          # API on :8080, auto-migrate + seed

# Dashboard (Node 20+)
cd dashboard && npm install && npm run dev    # console on :3000

# Mobile app (JDK 17+; quote the path — it contains a space)
cd "Mobile app" && ./gradlew :androidApp:assembleDebug   # Android APK
open "Mobile app/iosApp/iosApp.xcodeproj"                # iOS via Xcode (simulator)
```

## License & security

Apache-2.0 ([`LICENSE`](LICENSE), a copy ships in each component). Vulnerability reporting:
[`SECURITY.md`](SECURITY.md). Please don't test against the live demo beyond what a report needs.
