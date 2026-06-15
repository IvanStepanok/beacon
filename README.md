# Beacon — community ground truth for crisis damage mapping

Beacon is an open-source (Apache-2.0) crowdsourcing system for post-crisis building-damage
assessment, built for the UNDP "Build the Future of Crisis Mapping" challenge. Affected
community members report building damage from a phone — **offline-first, anonymous, in all
6 UN languages** — and analysts verify, triage, and export the result in the formats the
humanitarian system already speaks (GeoJSON, HXL-tagged CSV, GeoPackage, KML, Shapefile).
Beacon is deliberately **not** another satellite product: it is the **verification layer
that complements UNDP RAPIDA and satellite workflows**, supplying the ground-level signal
(low damage grades, side/ground-floor collapse, "possibly damaged" resolution) that nadir
imagery systematically misses.

## Components

| Component | Stack | Where |
|---|---|---|
| **Reporter mobile app** | Kotlin Multiplatform + Compose (Android + iOS), Voyager + MVI + Koin, MapLibre | [`Mobile app/`](Mobile%20app/) |
| **Backend API** | Go (chi + pgx) + PostgreSQL 16 / PostGIS, embedded migrations, LibreTranslate sidecar | [`backend/`](backend/) |
| **Analyst console + public view** | Next.js 16 + React 19 + Tailwind + MapLibre | [`dashboard/`](dashboard/) |

Docs live in [`docs/`](docs/): start with [`docs/STATUS.md`](docs/STATUS.md) (the honest
single source of truth for what is built vs not), then
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

_All four links above are live now (the `/public` heatmap requires no login)._

## What it does (all implemented — see STATUS.md for the equally honest not-done list)

- **Offline-first capture**: in-app camera (EXIF stripped on device), 3-level damage
  classification (minimal / partial / complete), building-footprint snap (stable building
  identity), on-device Plus Codes, outbox sync that survives dead networks, offline map packs.
- **6 UN languages + Arabic RTL** in the app; free-text descriptions auto-translated to
  English at intake by self-hosted LibreTranslate (original always preserved).
- **Crises that bootstrap themselves**: emergent crises proposed from clusters of community
  reports (an analyst confirms or dismisses), with global admin-area tagging that needs zero
  per-country GIS preparation.
- **Verification & triage console**: photo-gated verification with full audit trail,
  per-building damage timeline (server-side versioning), print brief for offline handoff.
- **Interop exports**: GeoJSON · CSV+HXL · GeoPackage · KML · Shapefile —
  new modular sections appear in exports automatically (three stable modular columns plus
  dynamic extras derived from the report data).
- **Privacy tiers**: anonymous reporters (no account, pseudonymous device id); public
  reads are verified-only with coordinates coarsened to ~110 m; analyst access is
  RBAC + JWT with 5 crisis-scoped roles.
- **Scale, measured**: 525k-report benchmark, every interactive query sub-30 ms
  ([`docs/LOAD-TEST.md`](docs/LOAD-TEST.md)).

## Quick start

Each component runs independently; full instructions in [`CONTRIBUTING.md`](CONTRIBUTING.md).

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

Apache-2.0 ([`LICENSE`](LICENSE) — a copy ships in each component).
Vulnerability reporting: [`SECURITY.md`](SECURITY.md) — please don't test against the live
demo beyond what a report needs.
