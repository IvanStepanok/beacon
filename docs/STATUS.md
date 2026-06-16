# Beacon — Build Status

_Single source of truth for what's done vs. what's not. Last updated 2026-06-12._

Beacon = community crowdsourcing app for post-crisis building-damage assessment (UNDP challenge).
Three clients on one backend: **reporter mobile app** (KMP/Compose, Android+iOS), **analyst console**
(Next.js web), **backend** (Go + PostgreSQL/PostGIS).

## 🌐 Live deployments (stepanok.com server, Docker + Traefik + Let's Encrypt)

| Service | URL | Status |
|---|---|---|
| Backend API | https://beacon-api.stepanok.com | ✅ live (59 reports / 57 buildings / 5 analysts seeded) |
| Analyst console | https://beacon.stepanok.com | ✅ live (`admin@undp.org` / `beacon123`) |
| Help / how-it-works | https://beacon-help.stepanok.com | ✅ live (EN, screenshots) |

---

## 🆕 2026-06-10 session — changelog (verification quality + public tier + submission docs)

Fixes from the security audit + external review, landing as one change set across all three repos:

**Backend:**
- **Public-view coarsening is DONE** (was "in progress" in the 2026-06-09 audit) — anonymous + `external_viewer` callers get verified-only reports through the locked-down public projection (~110 m coords, PII/operational fields stripped). Implemented in `backend/internal/handler/handlers.go` (`publicProjection`), enforced across reports/map/tiles/stats; the security table below was updated accordingly.
- **No earthquake default** — a report with no hazard selected is stored with an empty `crisisNature`, no longer silently defaulted to `earthquake`.
- **Geographic containment** — a report claiming a pinned crisis must fall inside that crisis's spatial extent, else it goes through normal space+time assignment (no more cross-country attachments).
- **Verification photo-gate** — verifying a photo-less report requires an explicit analyst `force` + note, both audited (`report_verification_audit`).
- **New report fields**: `infraName` (named facility), `buildingSource` (`"footprint"` only when a real footprint polygon was tapped — `buildingId` is set solely from that tap, as a stable `fp-` polygon hash; GPS-only reports carry no building identity, just the pin + accuracy; landmark-only reports are `locationResolved=false`), `plusCode` formalized (legacy `what3words` slot retired).
- **Dynamic form-schema endpoint** — clients fetch the capture-form schema (incl. modular questions) from the server, with per-crisis require/hide overrides. Exports keep three stable modular columns (`electricity`/`health_services`/`pressing_needs`) and derive any extra modular sections dynamically from the report data — new modular sections appear in exports automatically.
- **Durable photo storage** — uploaded photos persist on the named `beacon-photos` volume across redeploys; seed photos now ship real CC-attributed imagery with relative timestamps.

**Mobile (KMP):**
- **Dynamic form rendering** — the capture wizard's modular step renders from the server's form schema (per-crisis require/hide overrides honored, required-field gating before submit), with an **offline cache** so the form works with no connectivity.
- **GPS-grid building-id removal** — the app no longer fabricates a coordinate-grid `buildingId`; only a real tapped footprint produces one (`buildingSource="footprint"`), so the server's 25 m / 10 min near-dup guard actually bites.
- **Terminal "Rejected" sync state** — server rejections (409 duplicate, validation) surface as a terminal Rejected state in My Reports instead of silently retrying forever.
- **Durable photo storage** — captured photos persist in app storage (not a temp dir), so queued reports keep their evidence across restarts.
- **Image downscaling on both platforms** (Android + iOS) before upload.
- **Honest points copy** — profile points/badges reflect the server-derived verified-only model (no client-side point math presented as truth).
- **`plusCode` DTOs** — wire DTOs aligned to the canonical `plusCode` contract field.
- **Localized tab labels**; **fake-UI removals** (no simulated affordances left in the shell).
- **`crisisId` pinned on submit** when reporting into a specific crisis (server containment still decides).
- **Landmark/accuracy read-path fixes** — landmark and `gpsAccuracyMeters` round-trip correctly on report reads.

**Dashboard:** "Dispatch" surface renamed **"Verification & triage"** (honest framing: Beacon supports verification + triage handoff, it is not a SAR dispatch system) _(this verification & triage / dispatch console was later removed — not in the current build; the shipped flow is inline verify/flag plus the crisis confirm/dismiss lifecycle)_; public **`/public` heatmap page** (coarsened, verified-only — shareable without login); **print brief** (one-page situation summary for offline handoff).

**Docs:** new `ARCHITECTURE.md`, `DATA-QUALITY.md`, `INCENTIVES.md`, `PUBLISH-CHECKLIST.md`, root `README.md`; honesty pass over STATUS / LOAD-TEST / RAPID-DEPLOYMENT-48H (stale "in progress"/"roadmap" rows, flat-vs-partitioned schema wording, open-source publication status).

---

## 🆕 2026-06-09 session — changelog (all deployed + verified)

A full emulator run of the mobile app + analyst review of the dashboard surfaced bugs; all fixed, plus a new global Area feature. **Build artifacts: mobile `assembleDebug` + `compileKotlinIosSimulatorArm64` green; backend at migration v11; dashboard redeployed.**

**Mobile (KMP) — 1 critical + 6 polish fixes:**
- 🔴 **CRITICAL: app crashed ~6s after cold-launch when the backend was unreachable** (offline / DNS fail / rate-limit). Root cause: unprotected cold flows `flow { emit(api.x()) }` in `RemoteRepositories.kt` (`observeProfile`/`observeReport`/`observeBuildingTimeline`/`observeActiveCrisis`/`observeDangerZones` — `observeDangerZones` was later removed with the `/danger-zones` endpoint, not in the current build) threw `UnknownHostException` into a ScreenModel coroutine with no handler; amplified by `MainShellScreen` composing all tabs eagerly. **Fix:** `.catch { emit(fallback) }` on each; `observeProfile` falls back to a `DeviceId`-based offline profile. Reproduced in airplane mode → now stays alive. (This is a must-have for the "offline-first" requirement.)
- **Export "my reports"** exported the (empty) community feed → now `observeMyReports()`. **Profile stats** (0/0/0) → derived from `_mine` (reports/buildings/points). **Captured photo** not shown in list/detail → `ReportPhoto`/`CapturedImage`. **Own report** now appears as a map pin (merge `_mine` into pins). **Debris "No"** misleading green-check → Leaf icon. **System Back** in the capture wizard stepped back instead of discarding the flow (`expect/actual BeaconBackHandler`).

**Analyst dashboard:**
- **Multi-crisis Reports view** — backend `/reports` no longer hard-defaults to `crisis-antakya` (new `listScope`: org-wide scope → all crises, finite scope → `crisis_id = ANY(scope)`); dashboard got a **crisis selector** (default "All crises", options = crises with reports). Fixes "newly-submitted reports from other crises were invisible".
- **Right-side detail panel** — clicking a report opens a drawer (no full-page nav), verify/flag inline with live row update, quick switching; `/reports/[id]` kept for deep links.
- **Photo loading** — pending-report photos 404'd for the analyst because `<img>` sends no JWT (the photo endpoint serves unverified photos only to authenticated analysts). New `AuthImage` fetches with the Bearer token → blob URL.
- **Location label** — "Your location" replaced with a real place → Plus Code → coords (`locationLabel`); **removed the Sync column** (every report the dashboard sees is by definition synced).

**Backend — global auto-Area (the big one):** see the Area roadmap note below — every report now auto-gets an admin region, worldwide, via an embedded country baseline + lazy geoBoundaries ADM1.

---

## ✅ DONE

### Backend (Go + chi + pgx + PostgreSQL 16 / PostGIS)
- ✅ One camelCase JSON contract serving both clients; idempotent submit (client text id PK, ON CONFLICT).
- ✅ Server-authoritative per-building **versioning** (version + supersedes computed in tx).
- ✅ **3-level** damage scale (minimal / partial / complete) + `possiblyDamaged`.
- ✅ **Admin-area tagging** — PostGIS `admin_areas`, reverse-geocode via `ST_Contains`, adm1/2/3 + filters (geoBoundaries shapeIDs; official OCHA COD P-code layer on roadmap).
- ✅ **Global auto-Area (2026-06-09)** — `internal/boundary`: embedded Natural Earth ADM0 baseline (177 countries, gives every point a country + resolves ISO3) + **lazy per-country geoBoundaries ADM1** fetched on first report in a country, then existing reports re-geocoded. On-submit hook + startup sweep. `source`/`iso3` precedence (migration 00011). Verified: Ukraine auto-loaded → Kyiv reports got Area "Kyiv". See roadmap note for the geoBoundaries-vs-OCHA-P-code nuance.
- ✅ **GLIDE** event id + crisis response **Level**.
- _(Removed — not in current build)_ **Two-axis verification & triage / dispatch lifecycle** (task_status × disposition + assignee/severity/life_safety/clusters). The shipped flow is analyst verify/flag + the crisis emergent confirm/dismiss lifecycle; there is no dispatch/task lifecycle. Audit trail (`report_verification_audit`) is real.
- ✅ **Interop exports**: GeoJSON, HXL-tagged CSV, GeoPackage (pure-Go), KML, Shapefile.
- ✅ **RBAC + JWT** — 5 roles (field_validator, co_analyst, regional_analyst, crisis_admin, external_viewer), bcrypt, crisis-scoping, audit actor from token. Reporters stay anonymous (X-Device-Id).
- ✅ Stats overview in one SQL aggregate; rate limiting; health/readiness; embedded migrations (v15); seed (golden test).
- ✅ Deployed (Docker compose, PostGIS, env-configured, HTTPS).

### Analyst console (Next.js 16 + React 19 + Tailwind + MapLibre)
- ✅ Live API (no mock layer) + auth (login, token, 401→/login) + role-based UI gating.
- ✅ Overview (stats, 3-level damage breakdown, time-series, areas, **Verified %** tile), Live map (clustered pins, filters), Reports (filter/verify/flag + building timeline), public **/public heatmap** (coarsened, verified-only). _(The "Verification & triage console" with a life-safety fast lane / assign-advance-close tasks was removed — not in the current build; the shipped flow is inline verify/flag plus the crisis confirm/dismiss lifecycle.)_
- ✅ Export buttons (GeoJSON / HXL-CSV / GeoPackage / KML / Shapefile). Deployed as standalone Node container.

### Reporter mobile app (KMP + Compose Multiplatform, Android + iOS)
- ✅ Architecture: Voyager nav + MVI + Koin; offline-first repository interfaces; MapLibre map.
- ✅ Wired to the **live backend** over Ktor (Android OkHttp / iOS Darwin), pointed at beacon-api.stepanok.com.
- ✅ **Real connectivity** (Android ConnectivityManager / iOS NWPathMonitor) — honest online/offline, no fake banner.
- ✅ **Real sync** — optimistic outbox + real POST + auto-flush on reconnect (no simulated byte-progress).
- ✅ **Real GPS** (Android LocationManager / iOS CLLocationManager) + runtime permission; capture geotags from the device fix; "Locating…" state until a real fix (no fake default accuracy).
- ✅ **Real live in-app camera** — CameraX (Android) / AVFoundation (iOS) live preview, shutter, flash/torch, lens switch; gallery fallback. **EXIF GPS/timestamp/device tags stripped** on capture.
- ✅ **Real offline map packs** — MapLibre OfflineManager (Android, verified) / MLNOfflineStorage (iOS) with real download progress.
- ✅ **Real offline location code** — Open Location Code (**Plus Code**) computed on-device (replaces the placeholder what3words; free, no API key, works offline).
- ✅ Full capture flow (camera → 3-level damage (minimal / partial / complete) → infra → crisis → debris → location/footprint snap + anti-duplication → describe → modular → review → submit).
- ✅ Map (clustered pins, filters, hotspots), My Reports, Crisis & Safety _(the `/danger-zones` endpoint was removed — not in the current build; this surface shows crisis info, not a danger-zones feed)_, Profile (anonymous identity, points, export, offline maps, language).
- ✅ **6 UN languages** + Arabic RTL. On-device export (GeoJSON/CSV) via share sheet.
- ✅ **Safe-area handling** (iOS Dynamic Island + home indicator, Android status/gesture bars) across all chrome.
- ✅ **Onboarding shown once** (persisted via Prefs / SharedPreferences + NSUserDefaults).
- ✅ Builds green: Android `assembleDebug`; **iOS full Xcode app builds + runs on simulator** (MapLibre SPM wired).

### Docs & governance
- ✅ `docs/OPERATIONAL-MODEL.md` + `docs/governance/` (DPIA, retention/destruction, controller+breach SOP, data-sharing+sovereignty), research-grounded.

---

## 🔲 NOT DONE / ROADMAP

### Security & privacy controls — D4 hardening (implemented 2026-06-15) + remaining roadmap

The 2026-06-15 security pass (D4) **implemented the four controls that were previously
[Planned]**: encryption at rest, enforced DB-transit TLS, analyst MFA, and mobile certificate
pinning. Two controls remain roadmap (automated retention purge, on-device photo pruning) —
still tagged **[Planned]** in the DPIA and not to be cited as active.

| Control | State |
|---|---|
| **Encryption at rest** (photos + MFA secrets) | **IMPLEMENTED 2026-06-15.** Report photos are AES-256-GCM encrypted on the volume (upload + seed paths) and analyst TOTP secrets are encrypted in the DB, via `DATA_ENCRYPTION_KEY` (32-byte; required in prod — config fails closed without it). `internal/crypto` (round-trip/tamper/wrong-key unit-tested). Host-level volume encryption complements this for the remainder of the DB. |
| **DB-transit TLS** | **IMPLEMENTED 2026-06-15.** Postgres runs `ssl=on` (self-signed cert minted by the compose `db` service) and the backend connects with `sslmode=require`; `ENV=prod` fails closed if the URL ever weakens to disable/prefer (`config.sslEnforced`). TLS at the edge (Traefik + Let's Encrypt) is also live. |
| **MFA (analyst)** | **IMPLEMENTED 2026-06-15.** TOTP (RFC 6238 — SHA-1 / 6-digit / 30 s; `internal/auth/totp.go`, RFC-vector-tested) with `/auth/mfa/{enroll,verify,disable}`; the login flow requires a valid code when MFA is enabled and fails closed if the secret can't be decrypted. The secret is stored encrypted at rest. |
| **Certificate pinning (mobile)** | **IMPLEMENTED 2026-06-15.** Both platforms pin the API host to the Let's Encrypt / ISRG roots (X1 + X2): Android via OkHttp `CertificatePinner` (SPKI pins), iOS via an NSURLSession server-trust evaluation in the Ktor Darwin engine (cert-DER pins; the SecTrust is reached through a small cinterop shim because K/N's Foundation binding omits `serverTrust`). Both targets compile green; iOS runtime behavior is device/simulator-verifiable (like the live camera). |
| **On-device face / licence-plate blur** | **IMPLEMENTED 2026-06-11.** Face pixelation runs fully offline before upload: ML Kit face detection (Android) / Apple Vision (iOS) in `Mobile app/shared/src/{android,ios}Main/.../core/media/ImageRedactor.*.kt`, verified output in `test-shots/blur/`. Licence plates are **best-effort** (text + aspect-ratio heuristic), not a trained plate detector — keep that caveat in any claim. |
| **Automated data-retention / purge job** (incl. partition-DROP purge) | **NOT implemented (roadmap).** Retention SOP is documented; no scheduled purge/retention job exists in code yet. Crypto-shred is now operable in principle (at-rest encryption exists), but the job itself is not built. |
| **On-device photo pruning (mobile)** | **NOT implemented (roadmap).** Captured photos persist in app storage for offline viewing (by design — evidence survives restarts); automated pruning after sync / a retention window is roadmap. |

**KEEP IN MIND — these security/privacy controls ARE real and implemented (do not downgrade):**
RBAC + audit FKs (server-side, 5 roles, audit actor from token) · **public-view coordinate
coarsening (~110 m) + verified-only public reads** (`publicProjection` in
`backend/internal/handler/handlers.go`, enforced on reports/map/tiles/stats; `external_viewer`
export denied 403) · TLS at the edge · on-device EXIF stripping · client-side image downscaling ·
idempotent submit · latest-per-building versioning · per-device + per-IP submit rate limits ·
near-duplicate submit guard.

### Other roadmap items

| Item | Notes |
|---|---|
| **AI / computer-vision damage suggestion** | **IMPLEMENTED 2026-06-11** — advisory-only, fully on-device. MobileNetV3Small transfer-learned on the CC-BY-4.0 `structure_wildfire_damage_classification` dataset (3 classes → damage tiers, **94.5% overall test accuracy** on a held-out 3,736-image split, but that headline is carried by the two easy, visually distinct tiers (minimal F1 0.95 / complete F1 0.98); the **middle "partial" tier is weak — F1 0.226 (precision 0.221 / recall 0.231) on only 91 examples** (sqrt-dampened class weights lifted it from ~0.06, but it stays the model's real limitation, stated openly). Per-class precision/recall + a 95% CI are in `ml/out/metadata.json`). Bundled as TFLite (`damage_classifier.tflite`, Android) and Core ML (`DamageClassifier.mlmodelc`, iOS), wired into the capture flow as a suggestion the reporter confirms or overrides. Domain shift caveat: trained on wildfire structure damage, advisory framing is deliberate. |
| **Real identity provider** | Analyst auth is JWT with seeded users; drop-in Azure AD / OIDC on the same JWT contract for production. |
| **Push notifications** | "Crisis alerts when detected nearby" — not wired (needs FCM/APNs). |
| **iOS live camera on-device test** | Code builds; live preview only verifiable on a physical iPhone (simulator has no camera). |
| **Brand fonts** | DM Sans/Mono not bundled yet (system font + CJK/Arabic fallback). |

### Admin-boundary / Area follow-ups (from the 2026-06-09 global auto-Area work)
The auto-Area feature ships global ADM tagging: a Natural Earth ADM0 baseline + lazy per-country **geoBoundaries ADM1** and, where a COD is published, **official OCHA COD-AB ADM1+ADM2 P-codes** (`source='cod'`, ranked highest). Status / remaining nuances (COD-AB P-codes are implemented; the rest are follow-ups):
- **OCHA COD-AB P-code layer (authoritative) — IMPLEMENTED.** A `source='cod'` layer is fetched lazily per country from HDX on first report (`internal/boundary/cod.go`; reads both the `adm{n}_pcode` and legacy `ADM{n}_PCODE` attribute schemas), giving official ADM1+ADM2 P-codes that `ResolveAdmin` ranks above geoBoundaries; exports emit `admin*_pcode` (`#loc+admN+code`). **Remaining nuance:** coverage depends on a country having a published COD on HDX — countries without one fall back to a `GB:`-prefixed geoBoundaries shapeID, disclosed as such in the export so consumers can filter.
- **ADM2 (districts).** The COD-AB path provides ADM1+ADM2 (parent-linked via the COD parent P-code); the geoBoundaries fallback is ADM1 only.
- **⚠️ License review (ODbL).** geoBoundaries **gbOpen** is OpenStreetMap-derived **ODbL 1.0** for many countries (incl. UKR/GTM), NOT CC BY — ODbL has share-alike/attribution obligations heavier than CC BY. Confirm legal is OK with ODbL-sourced boundaries in a UNDP-licensed product, or restrict to **gbHumanitarian / OCHA CODs** (cleaner licensing). The loader logs `licenseDetail` per country.
- **Boundary freshness.** Admin boundaries change slowly (months/years), so no live refresh — but version-stamp (`source_version`, already stored) and consider a periodic re-pull; note P-codes can change across COD versions (provenance).
- **Country baseline precision.** ADM0 baseline is Natural Earth 110m (coarse borders) — fine for point→country, but near-border points could misattribute; a finer ADM0 (or per-country geoBoundaries ADM0) would tighten it if needed.

### Crisis model + open-feed ingestion (2026-06-08) — deployed & live-verified
- ✅ **Crisis = discrete event** with spatial extent (`center` + `radius_km`), time window (`started_at`…`ended_at`), `status` (active/proposed/closed/dismissed), optional `response_id` umbrella, GLIDE dedup key (migration `00008`).
- ✅ **Reports decoupled from crises** — `crisis_id` nullable (= pending); a citizen can report anywhere/anytime. Server assigns by **space+time** on submit (nearest covering active/proposed crisis), else pending.
- ✅ **Emergent crises** — a cluster of ≥3 pending reports within 2 km / 24 h auto-creates a `proposed` crisis (source `emergent`), pulls the reports in; analyst **confirms** (→active) or **dismisses** (→reports back to pending). The "Shahed/strike reported before any official declaration" case, working.
- ✅ **`GET /crises/near?lat&lng`** — location-first launch query (distance + covers).
- ⛔️ _(later removed — not in the current build)_ **Open disaster-feed ingestion (live):** **USGS** (124 real earthquakes) + **GDACS** (multi-hazard EQ/TC/FL/WF/DR, Orange+Red, carries GLIDE) — background poller (30 min) + analyst `POST /feeds/refresh`; idempotent upsert-by-source-id; pending reports swept into feed crises. Other feeds (ReliefWeb/GLIDE, NASA FIRMS, Copernicus, ACLED) designed + documented in `docs/CRISIS-SOURCES.md`. **The USGS/GDACS feed ingestion, the background poller, and `POST /feeds/refresh` were removed — they are NOT in the current build.**
- ✅ Verified end-to-end on prod (historical): report at a real epicenter auto-attaches; full emergent confirm/dismiss lifecycle. _(The crisis count cited automated USGS/GDACS feed crises, which were later removed; the emergent confirm/dismiss lifecycle from report clusters remains real.)_

### Recently completed (2026-06-08)
- ✅ **Photo binary upload, end-to-end** — backend stores the uploaded image on the durable named `beacon-photos` volume, surviving container redeploys (`POST/GET /api/v1/reports/{id}/photo`, `photo_url` column); the mobile app uploads the captured file after submit; the **dashboard report detail shows the real photo** (browser-verified). (Disk volume, not S3/MinIO — fine for this scale; object store is an easy later swap.)
- ✅ **Connectivity** self-heals (recompute on every callback + 4 s safety re-check) — the offline banner can't get stuck.
- ✅ **Translation is REAL** — self-hosted **LibreTranslate** (open-source MT, no paid API; `beacon-libretranslate` container, UN langs + uk/tr). Descriptions are auto-translated to English on submit (source language auto-detected); the original is always preserved; the dashboard shows a translated/original toggle. Verified live (ru→en).
- ✅ **Localization** — privacy / camera / Plus-Code / quick-phrase / sync strings updated across ar · es · fr · ru · zh.

---

## 🤖 AI / Computer Vision — options

**Today (updated 2026-06-12): SHIPPED on both platforms.** The advisory step runs a real
on-device model (MobileNetV3Small → TFLite on Android, Core ML on iOS; see the roadmap
table above and `ml/out/metadata.json`). The section below is kept as the original
option analysis that led to that build.

~~**Today:** the "AI suggests a damage grade from your photo" step is a **stub** — it shows advisory UI but runs no model.~~

**Can we do it on mobile? Yes — on-device is the right fit** (offline-first + privacy: the photo never leaves the phone):
- **Android:** TensorFlow Lite / LiteRT (or MediaPipe) running a small image classifier.
- **iOS:** Core ML (convert the same model).
- **Cross-platform:** ONNX Runtime Mobile, or a KMP wrapper, sharing one model.

### Are there ready-made models? (researched 2026-06)

**No clean drop-in "EMS-98 from a phone photo" model with downloadable, permissively-licensed weights
exists.** But you do **not** train from scratch — there are strong labeled datasets + benchmarks for
**transfer learning**. Match the INPUT domain: our input is a **ground-level facade photo**, not satellite.

| Resource | Domain | Damage labels | Weights? | Fit |
|---|---|---|---|---|
| **PEER Φ-Net / PHI-Net** (UC Berkeley) | ground-level **post-earthquake structural** photos (36k) | "damage level" = undamaged / minor / moderate / heavy (+ damage-state, spalling, collapse-mode) | dataset + benchmark tasks; trained weights **not** publicly packaged | **Best match** — labels ≈ EMS-98 |
| **MEDIC** (QCRI) | ground-level / social-media disaster photos (71k) | damage severity: severe / mild / little | dataset + training scripts (ResNet18 baseline); **no** damage weights; **CC BY-NC-SA (non-commercial)** | Good severity signal; license blocks commercial use |
| **ViT wildfire** (MDPI 2024) | ground-level home photos (18k), 95% acc | severity | data on HF; weights not packaged | Wildfire-only |
| **xBD / xView2** | **satellite / overhead** (850k bldgs) | no / minor / major / destroyed | winning models **open + downloadable** | Wrong input for phone camera — relevant only if we add aerial/drone imagery |

**Recommendation (pragmatic middle):** transfer-learn a small **MobileNet / EfficientNet-Lite** (ImageNet
pre-trained) on **PEER Φ-Net's "damage level"** (4 classes → map to our 3 damage tiers: minimal / partial / complete), advisory only.
Hours-to-days on a modest GPU, not a research project. Verify Φ-Net's license for production; MEDIC is
non-commercial so demo/eval only. Export to **TFLite (Android) / Core ML (iOS)** — ~5–15 MB, <100 ms,
offline; one expect/actual inference seam (mirrors camera/GPS). The model only **suggests** a grade +
confidence; reporter/analyst always confirms. Not started — needs the fine-tune + go-ahead.

Sources: [PEER Φ-Net tasks](https://apps.peer.berkeley.edu/phi-net/?page_id=827) ·
[MEDIC repo](https://github.com/firojalam/medic) · [MEDIC on HF](https://huggingface.co/datasets/QCRI/MEDIC) ·
[xView2/xBD](https://xview2.org/) · [ViT wildfire classifier](https://www.mdpi.com/2571-6255/7/4/133)
