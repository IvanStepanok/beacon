# Beacon — Data Dictionary

Canonical reference for the report entity, its enumerations, and the export schemas.
Source of truth in code: `backend/internal/model/report.go` (JSON contract) and
`backend/internal/service/export_service.go` (export formats); the HTTP surface is defined
in `backend/internal/api/router.go` and documented in `backend/openapi.yaml`. Wire field
names are **camelCase**; enum wire values are **lowercase**.

> **Provenance caveat: admin codes are official P-codes only where a COD is ingested.**
> The admin-area fields (`adm1Pcode`/`adm2Pcode`/`adm3Pcode`, the nested `admin.admN.pcode`,
> and the export `admin*_pcode` columns / `+code` HXL tags) carry **official OCHA COD-AB
> P-codes where that country's COD has been ingested** (`source='cod'`, fetched lazily from
> HDX and ranked above geoBoundaries; see `docs/STATUS.md` § Admin-boundary follow-ups).
> Where no COD is published for a country the value is a **`GB:`-prefixed geoBoundaries
> shapeID** (or an illustrative seed code in demo data), disclosed per row, so the file
> never asserts blanket P-code provenance and consumers can filter `GB:`-prefixed entries.

---

## 1. Report entity (JSON contract)

The `Report` document is a superset read by both clients: nested objects + flat aliases
coexist (each client ignores keys it doesn't know).

| Field | Type | Nullable | Values / notes |
|---|---|---|---|
| `id` | string | no | Client-generated text id (primary key; makes submit idempotent) |
| `idempotencyKey` | string | no | Client idempotency token |
| `crisisId` | string | no (may be empty) | Owning crisis; empty = pending (not yet attached) |
| `submitterId` | string | yes | Pseudonymous reporter id; stripped in the public projection |
| `damage` | string (enum) | no | Raw grade in the mandated 3-tier scale: `minimal\|partial\|complete` |
| `damageTier` | string (enum) | no | Always-present 3-tier rollup: `minimal\|partial\|complete` (see §3) |
| `possiblyDamaged` | bool | no | Reporter unsure; resolves the satellite "possibly damaged" class |
| `verification` | string (enum) | no | `pending\|verified\|flagged` |
| `debris` | string (enum) | no | `yes\|no\|unsure` |
| `infraTypes` / `infra` (alias) | string[] (enum) | no | `residential\|commercial\|government\|utility\|transport\|community\|public\|other` |
| `infraOtherDetail` | string | yes | Free text when `other` is selected |
| `infraName` | string | yes | Optional facility/building name (e.g. a school or clinic name) for triage context |
| `crisisNature` / `crisis` (alias) | string[] (enum) | no | `earthquake\|flood\|tsunami\|hurricane\|wildfire\|explosion\|chemical\|conflict\|civil_unrest` |
| `lat`, `lng` | number | **yes** | Decimal degrees. `null` for a location-unresolved (landmark-only) report, never `0,0` |
| `locationResolved` | bool | no | `true` when a real GPS fix or tapped footprint produced a point |
| `gpsAccuracyMeters` | number | yes | GPS fix accuracy (inbound alias: `accuracyMeters`) |
| `buildingId` | string | yes | Building key for versioning/timeline, set **only** from a real tapped footprint (stable `fp-` polygon hash); GPS-only reports carry no building identity (pin + accuracy only) |
| `buildingSource` | string | yes | `"footprint"` only when `buildingId` came from a tapped footprint polygon; `null` otherwise, and clients never fabricate a building identity. Landmark-only reports have `locationResolved=false`. See `docs/DATA-QUALITY.md` |
| `plusCode` | string | yes | On-device Open Location Code (replaced the retired `what3words` slot); stripped in public projection |
| `landmark` | string | yes | Free-text landmark; stripped in public projection |
| `place` | string | no | Human-readable place label |
| `photoUrl` | string | yes | Photo endpoint URL; public only for verified reports |
| `location` | object | no | Nested mirror for mobile: `{lat, lng, buildingId?, plusCode?, landmark?, gpsAccuracyMeters?}` (lat/lng nullable) |
| `admin` | object | yes | Resolved chain `{adm0?, adm1?, adm2?, adm3?}`, each `{pcode, name}`; see naming caveat above |
| `adm1Pcode`, `adm2Pcode`, `adm3Pcode` | string | yes | Flat admin aliases for filtering; see naming caveat above |
| `version` | int | no | Server-authoritative per-building version |
| `supersedesReportId` | string | yes | Previous report for the same building |
| `description` | object | yes | `{original, originalLang, translated, translatedLang?}`; `translated` coalesces to the original until LibreTranslate has run; stripped in public projection |
| `aiLevel` | string | yes | Advisory only (the AI helper is a stub today) |
| `aiConfidence` | int | yes | Advisory only |
| `photos` | object[] | no | `{localPath, remoteUrl?, sizeBytes}` |
| `sizeBytes`, `sizeMb` | int64 / number | no | Payload size |
| `modular` | object | yes | Secondary-impacts blob; see §2 |
| `anonymization` | object | no | `{anonymous, exifStripped, facesBlurred, platesBlurred}`; `facesBlurred`/`platesBlurred` are honestly `false` (no blur is implemented) |
| `clusters` | string[] (enum) | no | `slsc\|health\|wash\|education\|food_security\|protection\|logistics\|nutrition\|etc\|cccm\|early_recovery` |
| `isMine` | bool | no | True when the caller's `X-Device-Id` matches the submitter |
| `synced` | bool | no | Always true on server reads |
| `sync` | object | no | Discriminated union `{type: Queued\|Syncing\|Synced\|Failed, ...}` (client-side state echo) |
| `ageMin` | int | no | Minutes since capture (derived) |
| `capturedAt`, `createdAt`, `updatedAt` | RFC 3339 timestamp | no | Capture vs server timestamps |

**Inbound (`SubmitReportRequest`) deltas:** the server accepts flat `lat`/`lng` **or** the
nested `location`; `accuracyMeters` is the inbound alias that coalesces into
`gpsAccuracyMeters`; `lat`/`lng` may be `null` with `locationResolved: false` for
landmark-only reports. Submission requires the `X-Device-Id` header (see §6) and is
idempotent on `id` (`ON CONFLICT` upsert, safe client retries).

## 2. Modular secondary-impacts blob (`modular`)

The capture form, including this modular section, is served to clients by the backend's
**dynamic form-schema endpoint** (with per-crisis require/hide overrides). Exports keep the
three stable modular columns and derive any extra modular sections dynamically from the
report data itself, so new modular sections appear in exports automatically. The
authoritative HTTP shape is in `backend/openapi.yaml`. The seeded schema ships the question
set below.

Wire/stored shape (camelCase keys), all fields optional:

```json
{ "electricity": "severe", "healthServices": "largely_disrupted", "pressingNeeds": ["shelter", "food_water"] }
```

| Key | Type | Enum values |
|---|---|---|
| `electricity` | string | `none_observed\|minor\|moderate\|severe\|destroyed\|unknown` |
| `healthServices` | string | `fully_functional\|partially_functional\|largely_disrupted\|not_functioning\|unknown` |
| `pressingNeeds` | string[] | `food_water\|cash\|healthcare\|shelter\|livelihoods\|wash\|protection\|local_support\|other` |

In exports the modular blob flattens to snake_case columns: the three stable sections
(`electricity` / `health_services` / `pressing_needs`) are always present, and any extra
sections found in the report data are appended dynamically (camelCase key to snake_case;
multi-values `;`-joined). The blob is stripped from the public projection.

## 3. Damage classification: 3-tier mapping

`damageTier` is the challenge's required 3-level core indicator, always derived server-side
from the raw `damage` grade. Exports title-case it as `damage_classification`:

| Raw `damage` value | `damageTier` (internal) | Export `damage_classification` |
|---|---|---|
| `minimal` | `minimal` | `Minimal` |
| `partial` | `partial` | `Partial` |
| `complete` | `complete` | `Complete` |
| *(empty / unknown)* | `minimal` (defensive default) | `Minimal` |

"Worst-of" rankings always compare by tier (`minimal` < `partial` < `complete`). The shipped
capture scale is the mandated 3 tiers (`minimal\|partial\|complete`).

## 4. Export schemas

Endpoint: `GET /api/v1/reports/export?format=geojson|csv|gpkg|kml|shapefile`, analyst-only,
crisis-scoped; the `external_viewer` role is denied (403) and reads the coarsened public
map instead (§5).

All formats share: coordinates in WGS84 decimal degrees; location-unresolved reports carry
**null/blank geometry, never `0,0`**; multi-value fields `;`-joined; timestamps ISO-8601
(UTC, from `capturedAt`); admin columns labelled `admin*_pcode` (see provenance caveat).

### 4.1 GeoJSON (`format=geojson`)

`FeatureCollection` of `Feature`s; `geometry` = `Point [lng, lat]` or `null`. Properties:

| Property | Notes |
|---|---|
| `id` | report id |
| `damage_classification` | `Minimal\|Partial\|Complete` (gate field) |
| `damage` | raw grade (extra detail) |
| `possiblyDamaged` | bool |
| `infrastructure_type` | `;`-joined `infraTypes` |
| `hazard_type` | `;`-joined `crisisNature` |
| `timestamp` | ISO-8601 of `capturedAt` |
| `electricity`, `health_services`, `pressing_needs` | flattened modular blob (§2) |
| `debris`, `buildingId`, `verification`, `synced`, `place` | as in §1 |
| `accuracy_m` | GPS accuracy (string, may be empty) |
| `admin1_pcode`, `admin2_pcode`, `admin3_pcode` | admin areas (COD-AB P-codes, or a `GB:`-prefixed shapeID fallback; see caveat) |

### 4.2 CSV with HXL tags (`format=csv`)

Row 1 = headers, row 2 = HXL hashtags, then data. Admin HXL tags use `+code` (the COD-AB
join key); a `GB:` prefix on a value marks a geoBoundaries shapeID fallback (not an official
P-code), so provenance is disclosed per row rather than asserted blanket.

| Column | HXL tag |
|---|---|
| `id` | `#meta+id` |
| `latitude` | `#geo+lat` |
| `longitude` | `#geo+lon` |
| `timestamp` | `#date` |
| `damage_classification` | `#severity+grade` |
| `damage` | `#severity+raw` |
| `infrastructure_type` | `#sector` |
| `hazard_type` | `#cause` |
| `electricity` | `#indicator+electricity` |
| `health_services` | `#indicator+health` |
| `pressing_needs` | `#indicator+needs` |
| `possiblyDamaged` | `#indicator+possibly` |
| `debris` | `#indicator+debris` |
| `buildingId` | `#loc+building+id` |
| `verification` | `#status+verification` |
| `place` | `#loc+name` |
| `accuracy_m` | `#indicator+accuracy` |
| `admin1_pcode` | `#loc+adm1+code` |
| `admin2_pcode` | `#loc+adm2+code` |
| `admin3_pcode` | `#loc+adm3+code` |

### 4.3 KML (`format=kml`)

One `<Placemark>` per **resolved** report (unresolved reports are skipped): `<name>` = report
id, `<Point><coordinates>lng,lat</coordinates></Point>`, and a text `<description>` carrying
`damage_classification`, `infrastructure_type`, `hazard_type`, `electricity`,
`health_services`, `pressing_needs`, `verification`, `timestamp`. Opens directly in Google
Earth.

### 4.4 GeoPackage (`format=gpkg`)

OGC GeoPackage 1.3 (single SQLite file, pure-Go writer), layer `reports`, SRS EPSG:4326:

| Column | Type | Notes |
|---|---|---|
| `fid` | INTEGER PK | autoincrement |
| `geom` | BLOB | GeoPackageBinary Point (NULL when unresolved) |
| `id` | TEXT | report id |
| `damage` | TEXT | raw grade |
| `possibly_damaged` | INTEGER | 0/1 |
| `verification` | TEXT | `pending\|verified\|flagged` |
| `infrastructure` | TEXT | `;`-joined `infraTypes` |
| `crisis` | TEXT | `;`-joined `crisisNature` |
| `debris` | TEXT | `yes\|no\|unsure` |
| `building_id` | TEXT | building key |
| `place` | TEXT | place label |
| `admin2_pcode`, `admin3_pcode` | TEXT | admin areas (COD-AB P-codes, or a `GB:`-prefixed shapeID fallback) |
| `captured_at` | TEXT | ISO-8601 |

### 4.5 Shapefile (`format=shapefile`)

ESRI Shapefile bundle (`.shp`/`.shx`/`.dbf`/`.prj`) zipped for download, geometry = Point in
WGS84 (EPSG:4326). DBF attribute columns mirror the GeoPackage layer (§4.4), truncated to the
10-character DBF name limit. Unresolved reports carry null geometry.

## 5. Public projection (low-trust reads)

Anonymous callers and the `external_viewer` role get **verified reports only**, through a
locked-down projection: coordinates rounded to 3 decimals (~110 m), and `submitterId`,
`plusCode`, `landmark`, `buildingId`, `buildingSource`, `infraName`, `gpsAccuracyMeters`,
`description`, `clusters`,
`aiLevel`/`aiConfidence`, the `modular` blob and the `anonymization` object are stripped
(`infraName` is reporter free-text naming a specific building; kept public it could
de-coarsen the ~110 m grid); `photoUrl` is exposed only for verified reports.
Authenticated analyst roles see full precision.

## 6. `X-Device-Id` pseudonymity note

Reporters are **anonymous to humans, pseudonymous to the system**. The mobile app generates
a random device id and sends it as the `X-Device-Id` header; the server maps it to an
internal submitter UUID. It is required on `POST /api/v1/reports` (and gates photo upload
and `mine=true` listing), enabling idempotent resubmits, "my reports", and points, without
any account, name, phone number, or email. The id never appears in public responses or
exports. Caveat: it is still a stable pseudonym; combined with precise geolocation it could
contribute to re-identification, which is why low-trust reads go through the §5 projection
and the aggregate dataset is handled per `docs/governance/`.
