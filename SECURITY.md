# Security Policy

Beacon handles crisis-area damage reports — geolocated photos and free-text submitted by
anonymous community reporters. Even though individual records are pseudonymous, the
**aggregate dataset is sensitive** (Demographically Identifiable Information). We treat
security reports about this project accordingly: seriously and quickly.

## Reporting a vulnerability

**Please do not open a public GitHub issue for security problems.**

- Email **ivan.stepanok@raccoongang.com** with subject `[SECURITY] Beacon: <short summary>`.
- Include: affected component (backend / dashboard / mobile app / deployment), reproduction
  steps or a proof-of-concept, the impact as you understand it, and any suggested fix.
- You will get an acknowledgement within **3 business days** and a triage verdict within
  **10 business days**.
- Please give us a reasonable window to fix the issue before any public disclosure
  (coordinated disclosure; 90 days is our default ask).
- Do not test against the live demo deployment (`*.stepanok.com`) beyond what is needed to
  demonstrate the issue, and never against data you do not own. The demo data is seeded, but
  the infrastructure is shared.

There is no bug-bounty program; we will credit reporters in release notes if desired.

## Current security posture & production gates

This section is intentionally honest. The authoritative, continuously updated list lives in
[`docs/STATUS.md`](docs/STATUS.md) § "Security & privacy controls"; where this file and
STATUS.md differ, STATUS.md wins. The governance pack ([`docs/governance/`](docs/governance/))
describes the **target** control set; the DPIA tags not-yet-built controls as **[Planned]**
and makes them binding pre-deployment conditions.

### Implemented and verified today

- **RBAC + JWT** — 5 analyst roles (field_validator, co_analyst, regional_analyst,
  crisis_admin, external_viewer), bcrypt password hashing, crisis-scoped tokens. Reporters
  stay anonymous (pseudonymous `X-Device-Id`).
- **Audit trail** — every analyst verification and triage decision is recorded server-side
  (`report_verification_audit`, `report_task_audit`) with the actor taken from the JWT, never
  from a client-supplied header.
- **HTTPS / TLS at the edge** — Traefik + Let's Encrypt in front of every public endpoint.
- **On-device EXIF stripping** — GPS/timestamp/device tags removed from photos at capture.
- **On-device face blur** — faces are detected and pixelated **on the device, before upload**
  (ML Kit face detection on Android, Apple Vision on iOS; `Mobile app/shared/src/{android,ios}Main/
  .../core/media/ImageRedactor.*.kt`, sample output in `test-shots/blur/`). Licence-plate
  redaction is **best-effort** (a text + aspect-ratio heuristic, not a trained plate detector) —
  always stated as such.
- **Client-side image downscaling** before upload.
- **Idempotent submit** (client-generated id primary key, `ON CONFLICT`) — no duplicate
  reports from retrying clients.
- **Public-view minimization** — anonymous and `external_viewer` callers receive only
  verified reports through a locked-down projection: coordinates coarsened to ~110 m
  (3 decimals), and submitter id, Plus Code, landmark, building id, building source,
  facility name (`infraName` — reporter free-text naming a specific building, which could
  de-coarsen the grid), GPS accuracy, free-text description, triage fields, and the
  modular blob are all stripped. Unverified photos are never served to unauthenticated
  callers.
- **Rate limiting** per IP; health/readiness probes; embedded, versioned DB migrations.
- **Encryption at rest for photos + sensitive secrets** — report photos and the stored
  TOTP secret are sealed with **AES-256-GCM** (authenticated, tamper-detecting, app-layer)
  under a 32-byte `DATA_ENCRYPTION_KEY` that is **required in production**; photo files are
  written `0600`; the read path decrypts transparently and tolerates legacy plaintext. This
  makes the crypto-shred destruction control in the retention SOP operable for photos.
- **MFA (TOTP, RFC 6238)** — analyst accounts can enrol a TOTP authenticator
  (`/auth/mfa/{enroll,verify,disable}`); validation is constant-time with ±1-step skew, the
  secret is stored encrypted, and login is gated (`mfa_required` / `mfa_invalid`, fail-closed)
  once enabled.
- **DB-transit TLS enforced** — the backend↔PostgreSQL link runs `sslmode=require`; the config
  **fails closed in production** if TLS is disabled or downgraded to `prefer`.
- **Certificate pinning (mobile)** — Android (OkHttp SPKI pins) and iOS (Ktor/Darwin
  server-trust evaluation, certificate-DER pins) both pin to the ISRG / Let's Encrypt roots
  **X1 + X2**; any other CA is rejected (fail-closed).

### NOT yet implemented — production go/no-go gates

These are **designed and documented but not built**. They are binding pre-deployment
conditions (DPIA §10) and must **not** be cited as active mitigations:

| Gate | Real current state |
|---|---|
| **Cluster-wide / backup / device-cache encryption at rest** | App-layer AES-256-GCM now seals photos + the TOTP secret (see above). Full-cluster PostgreSQL encryption, encrypted backups, and offline **device-cache** encryption remain deployment-environment responsibilities, not yet built in code. (`pgcrypto` is enabled but used only for `gen_random_uuid()`.) |
| **Blur-failure fallback + QA sampling** | Not implemented. **On-device face blur IS implemented** (see above) and runs before upload, but there is no automatic block/queue-for-review when the detector confidence is low, and no periodic QA sampling of stored photos. |
| **Automated data-retention / purge job** | Not implemented. The retention SOP is documented policy only; no purge job exists in code. |
| **Real identity provider** | Analyst accounts are seeded; production target is Azure AD / OIDC on the same JWT contract. (MFA/TOTP is now implemented on the local accounts.) |

### Supported versions

This is a pre-production MVP; only the latest commit on the default branch is supported.
There are no backported security fixes.

## Scope notes for researchers

- The seeded demo credentials published in `docs/STATUS.md` are intentional demo fixtures,
  not a finding.
- The `adm*Pcode` fields carry official OCHA COD-AB P-codes where a country's COD has been
  ingested, otherwise a `GB:`-prefixed geoBoundaries shapeID / seed code (documented in
  [`docs/DATA-DICTIONARY.md`](docs/DATA-DICTIONARY.md)) — a disclosed provenance caveat, not
  a data leak.
- Findings about the gates listed above are known; new **bypasses of implemented controls**
  (e.g. de-coarsening the public projection, RBAC scope escapes, photo-gate bypasses,
  JWT/idempotency abuse) are exactly what we want to hear about.
