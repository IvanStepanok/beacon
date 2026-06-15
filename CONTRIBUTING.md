# Contributing to Beacon

Thanks for helping improve Beacon — a community crowdsourcing app for post-crisis
building-damage assessment. The project is Apache-2.0 (`LICENSE`); by contributing you agree
your contributions are licensed under the same terms. For security issues, follow
[`SECURITY.md`](SECURITY.md) instead of opening an issue.

## Repository layout

| Path | Stack |
|---|---|
| `backend/` | Go 1.26 (chi + pgx) + PostgreSQL 16 / PostGIS |
| `dashboard/` | Next.js 16 + React 19 + Tailwind + MapLibre (analyst console) |
| `Mobile app/` | Kotlin Multiplatform + Compose Multiplatform (Android + iOS reporter app) |
| `docs/` | Status, architecture, data quality, incentives, operational model, governance, data dictionary, load test, publication checklist |

Start with [`docs/STATUS.md`](docs/STATUS.md) — the single source of truth for what is done
vs not. The API surface is defined in `backend/internal/api/router.go` (overview in
`backend/README.md`, field-level contract in
[`docs/DATA-DICTIONARY.md`](docs/DATA-DICTIONARY.md), OpenAPI spec for the core
reporting surface in `backend/openapi.yaml`).

## Building

### Backend (Go 1.26+, Docker for the DB)

```bash
cd backend
go build ./... && go test ./...   # the CI gate — must pass before any PR
make db-up        # start Postgres+PostGIS (localhost:5544)
make run          # run the server with embedded migrations + seed
make build        # static binary (CGO_ENABLED=0)
```

### Dashboard (Node 20+)

```bash
cd dashboard
npm install
npm run dev       # against the API base URL in .env.local
npm run lint && npm run build
```

### Mobile app (JDK 17+, Android Studio / Xcode 16)

The path contains a space — quote it.

```bash
cd "Mobile app"
./gradlew :shared:compileCommonMainKotlinMetadata    # fast shared-code compile check
./gradlew :androidApp:assembleDebug                  # Android debug APK
./gradlew :shared:compileKotlinIosSimulatorArm64     # KMP iOS compile check
open iosApp/iosApp.xcodeproj                         # full iOS app via Xcode (simulator)
```

## Pull request expectations

- **Keep it small and focused** — one logical change per PR, with a description of what and why.
- **Don't break the builds**: `go build ./... && go test ./...` (backend),
  `npm run lint && npm run build` (dashboard, no new lint errors),
  `:shared:compileCommonMainKotlinMetadata` + `:androidApp:assembleDebug` (mobile) must pass
  for the parts you touched.
- **Match the surrounding style** — the codebase favors explicit, commented decisions; Go code
  is `gofmt`-formatted (`make fmt`).
- **Honesty rule for docs and UI copy**: never claim a control or feature that isn't
  implemented. Anything aspirational is marked PLANNED (see the convention in
  `docs/STATUS.md` and `docs/RAPID-DEPLOYMENT-48H.md`).
- **API changes** must keep the one camelCase JSON contract serving both clients
  (mobile + dashboard) backward compatible, and update
  [`docs/DATA-DICTIONARY.md`](docs/DATA-DICTIONARY.md) in the same PR.
- **Localization**: user-facing mobile strings ship in all 6 UN languages (en, ar, es, fr,
  ru, zh). Flag machine translations for native review in the PR description.
- **No secrets** in commits; never point tests at the production deployment.
