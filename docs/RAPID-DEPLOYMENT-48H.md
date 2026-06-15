# Beacon — Rapid Deployment: the First 48 Hours

> Written description of how Beacon is deployed to a crisis area within the first 48 hours after a
> disaster — including how we advertise, open-source, and support the tool in the affected region
> (challenge nice-to-have #2, `requirements/solution-requirements.md`).
>
> **Honesty convention** (same as the DPIA and `STATUS.md`): every item is tagged
> **✅ IMPLEMENTED** (present and verified in the current build), **🟡 PARTIAL**, or
> **🔜 PLANNED** (designed, not yet built). The authoritative build state is
> [`docs/STATUS.md`](./STATUS.md); where this document and STATUS.md differ, STATUS.md wins.
> Roles referenced below (Community reporter, Field validator, CO analyst/dispatcher, Regional
> Bureau analyst, Crisis Bureau/CRU admin, External consumer) are defined in
> [`docs/OPERATIONAL-MODEL.md`](./OPERATIONAL-MODEL.md) §"Actor & role model".

---

## Why 48 hours is realistic for Beacon

Most of the per-crisis setup cost that slows other tools down is already engineered away:

| Property | Effect on deployment speed | Status |
|---|---|---|
| **Crisis activation is fast** — an analyst creates the crisis record (extent, time window, GLIDE id) in one step; in parallel, emergent clustering proposes a crisis from nearby pending report clusters even before any official declaration | A crisis record can exist within minutes of T+0 — by analyst creation or by confirming an emergent (report-cluster) proposal; activation is a confirm/create, not a build | ✅ IMPLEMENTED |
| **Reports decoupled from crises** — citizens can report anywhere; the server attaches reports to the nearest covering crisis by space+time, else holds them pending | Reporting works **before** an analyst touches anything | ✅ IMPLEMENTED |
| **Global auto-Area** — embedded country baseline + lazy per-country geoBoundaries ADM1, fetched automatically on the first report in a country | **Zero per-country GIS preparation**; admin tagging self-bootstraps (geoBoundaries shapeIDs today; official OCHA COD P-code layer on roadmap) | ✅ IMPLEMENTED |
| **Offline-first by design** — outbox queue, auto-flush on reconnect, offline map packs, on-device Plus Codes | Works in the degraded-connectivity window when it matters most | ✅ IMPLEMENTED |
| **6 UN languages + Arabic RTL baked into the app**; LibreTranslate auto-translates report descriptions to English on submit | No per-crisis localization work for the UN languages | ✅ IMPLEMENTED |
| **Multi-crisis tenancy + scale-validated schema** — one deployment serves many concurrent crises; 525k-report benchmark | No new infrastructure per crisis | ✅ IMPLEMENTED ([`LOAD-TEST.md`](./LOAD-TEST.md)) |

What the 48-hour plan therefore consists of is mostly **people and process**, not software setup —
which is exactly what this runbook scripts.

---

## 0. Pre-positioning (T-minus — done once, before any crisis)

The 48-hour clock only holds if these are standing arrangements, not T+0 work:

| # | Item | Owner | Status |
|---|---|---|---|
| 0.1 | **Standing infrastructure**: backend + dashboard + LibreTranslate run as Docker Compose behind Traefik/Let's Encrypt; embedded migrations mean a fresh region re-host is `docker compose up` + env vars. The current MVP host is the demo server; a UNDP-controlled host (region chosen per the sovereignty policy, [`governance/data-sharing-and-sovereignty.md`](./governance/data-sharing-and-sovereignty.md)) is part of handover | Crisis Bureau / platform team | ✅ IMPLEMENTED (demo host live); 🔜 PLANNED (UNDP-controlled hosting per deployment) |
| 0.2 | **Open source**: repository licensed Apache-2.0 (`LICENSE`), build instructions in `CONTRIBUTING.md`, vulnerability reporting in `SECURITY.md` — any partner can audit, self-host, or fork | RaccoonGang → UNDP | 🟡 READY — Apache-2.0 licensed, publication checklist prepared ([`docs/PUBLISH-CHECKLIST.md`](./PUBLISH-CHECKLIST.md)); the repos have **no public remotes yet** |
| 0.3 | **Governance pack adopted**: DPIA reviewed, retention schedule and breach SOP signed, controller-naming template ready ([`governance/`](./governance/README.md)) | Crisis Bureau DPO | ✅ IMPLEMENTED (documents); adoption is per-deployment |
| 0.4 | **Security go/no-go gates closed**: encryption at rest, MFA for export roles, retention purge job, cert pinning — DPIA §10 binding pre-deployment conditions, tracked in [`STATUS.md`](./STATUS.md) §"Security & privacy controls" | platform team | 🔜 PLANNED — **must be closed before a real production deployment**; the 48h plan assumes they are closed at T-minus, never rushed at T+0 |
| 0.5 | **Dormant store listings**: app pre-published on Google Play + App Store as a generic "Beacon — crisis reporting" app, updated rarely, so no store review sits on the critical path at T+0 | platform team | 🔜 PLANNED (no listings exist today) |
| 0.6 | **Signed release APK pipeline**: reproducible signed build + hosting under a stable URL | platform team | 🟡 PARTIAL (Android debug build verified green; release signing + hosting checklist not yet produced) |
| 0.7 | **Roster**: per-region on-call analyst accounts and a validator-trainer roster (maps to SURGE/CRT deployment in OPERATIONAL-MODEL.md) | Regional Bureaus | 🔜 PLANNED (operational arrangement) |

---

## 1. T+0 activation runbook (who flips what)

### T+0 → T+2h — declare and scope

| Step | Action | Owner (OPERATIONAL-MODEL.md role) | Status |
|---|---|---|---|
| 1.1 | Create or confirm the crisis record. An analyst creates the crisis directly, or confirms an emergent (report-cluster) crisis via `PATCH /api/v1/crises/{id}/status` → `active` | CO analyst / Regional Bureau analyst | ✅ IMPLEMENTED |
| 1.2 | Verify GLIDE id and set the crisis response **Level (1/2/3)** on the crisis record (mirrors the Regional Bureau → CRU Level assessment) | Regional Bureau analyst | ✅ IMPLEMENTED (fields exist) |
| 1.3 | The reporter damage scale is the mandated 3-tier scale (minimal / partial / complete) — no per-deployment toggle is needed — see §5 | Crisis Bureau / Regional Bureau admin | ✅ IMPLEMENTED (fixed 3-tier scale) |
| 1.4 | Name the **data controller** for this deployment and record it per [`governance/data-controller-and-breach-response.md`](./governance/data-controller-and-breach-response.md); confirm DPIA review triggers | Crisis Bureau admin + CO | ✅ IMPLEMENTED (template/process documented) |

### T+2h → T+12h — stand up people

| Step | Action | Owner | Status |
|---|---|---|---|
| 1.6 | Provision CO analyst + field-validator accounts (5-role RBAC, crisis-scoped JWT). Today accounts are seeded/managed by the platform team; production target is Azure AD/OIDC on the same JWT contract | Crisis Bureau admin | 🟡 PARTIAL (RBAC ✅; real IdP 🔜 PLANNED) |
| 1.7 | Push distribution assets to the region: APK link + QR, store links, help-site link (§2) | CO comms focal point | 🟡 PARTIAL (see §2) |
| 1.8 | Run validator quick-training (§4) for CO staff + partner volunteers | SURGE first responder / validator-trainer | runbook action (materials 🟡 PARTIAL) |

### T+12h → T+48h — open the tap and support it

| Step | Action | Owner | Status |
|---|---|---|---|
| 1.9 | Launch community awareness (§3) through national authorities, partner NGOs, radio/SMS | CO comms + government counterpart | runbook action |
| 1.10 | Analyst verification live: analysts review reports and set the verification state (`PATCH /api/v1/reports/{id}/verification`); per-building versioning shows the latest report per building — first verified reports feed RAPIDA's "possibly damaged" resolution within the 24–72h window | CO analyst | ✅ IMPLEMENTED (analyst verification + per-building timeline) |
| 1.11 | First structured exports to response partners (GeoJSON / HXL-CSV / GPKG / KML / Shapefile) under the Data Sharing Agreement; public release only coordinate-coarsened (~110 m, verified-only) per the sharing policy | CO analyst; External consumers receive | ✅ IMPLEMENTED (exports); sharing gates per [`governance/data-sharing-and-sovereignty.md`](./governance/data-sharing-and-sovereignty.md) |
| 1.12 | In-region support loop: monitored support channel + feedback to reporters | CO + platform on-call | 🔜 PLANNED (operational arrangement; reporter push notification not wired) |

---

## 2. Distribution without store-approval delays

App-store review (hours–days, unpredictable) must never gate a crisis response. Pathways, in the
order they work **today**:

1. **Signed APK direct download + QR code** — 🟡 PARTIAL. The Android app builds green today
   (`assembleDebug` verified); producing and hosting a **signed release** APK under a stable URL
   (e.g. `get.beacon.example/beacon.apk`) plus a printable QR is a T-minus checklist item (§0.6),
   not new engineering. Sideloading requires the user to allow installs from the browser — the
   1-page reporter guide (§4) covers this in one illustrated step.
2. **Help / how-it-works site** — ✅ IMPLEMENTED. https://beacon-help.stepanok.com is live (EN,
   screenshots) and is the landing target for every QR and short link.
3. **Pre-published dormant store listings** — 🔜 PLANNED. Keep Beacon published-but-quiet on Google
   Play and the App Store between crises; at T+0 only a metadata/config change ships, so the store
   link works immediately. This is the **only** low-friction iOS channel at citizen scale (iOS
   builds run on simulator today; no TestFlight/App Store presence yet).
4. **MDM push to partner devices** — 🔜 PLANNED. For CO/NGO-owned fleets (validators, SURGE),
   push the APK/IPA via the partner's MDM (Intune/Workspace ONE); bypasses stores entirely for
   the professional tier. No MDM integration exists today; the artifact (APK) is the same as #1.
5. **Web/PWA reporter fallback** — 🔜 PLANNED. The analyst dashboard is web and live, but there is
   **no reporter web client today**. A minimal PWA submission form (photo + damage + location
   against the same `POST /api/v1/reports` API) is the designed fallback for users who cannot or
   will not install an app; the existing public submit API (anonymous, `X-Device-Id`-keyed — see
   `backend/README.md` and [`docs/DATA-DICTIONARY.md`](./DATA-DICTIONARY.md)) already supports it.

**Open-sourcing as distribution**: the Apache-2.0 license (§0.2 — publication itself is pending,
see [`docs/PUBLISH-CHECKLIST.md`](./PUBLISH-CHECKLIST.md)) lets national authorities or NGOs
re-host the entire stack inside their own jurisdiction when data-sovereignty rules require it —
see the transfer/due-diligence rules in
[`governance/data-sharing-and-sovereignty.md`](./governance/data-sharing-and-sovereignty.md).

---

## 3. Community awareness in the affected region

All items here are operational runbook actions executed by the CO with its government counterpart;
the digital assets they point to are listed with their status.

| Channel | What happens | Assets needed |
|---|---|---|
| **National authorities / NDMA** | Government counterpart endorses and relays the reporting call through civil-protection channels; aligns with the government-led PDNA posture | Endorsement brief (1 page) — 🔜 PLANNED template |
| **Local radio + SMS broadcast** | 30-second radio script + SMS text with the short link/QR, read in local languages; SMS via NDMA/telco cell-broadcast arrangements (works on feature phones — reaches people who can then borrow a smartphone) | Script template — 🔜 PLANNED; help site to link to — ✅ IMPLEMENTED |
| **Partner NGOs + volunteer networks** | Cluster partners and local CSOs cascade the app through existing community groups (the channel UN-ASIGN deployments relied on) | APK/QR pack (§2) — 🟡 PARTIAL |
| **QR posters at aid points** | Printed A4 QR posters at aid-distribution points, shelters, water points — where affected people physically queue | Poster template (QR + 3 pictogram steps, local language) — 🔜 PLANNED; QR generation is trivial once §0.6 lands |
| **Social media** | CO accounts + partners post the link with the same 3-step pictogram | Same asset pack |

Messaging rule (from the governance pack): the call to report must be **plain-language, in local
languages, never gate aid on reporting, and state what happens to the data** — the transparency
notice requirements in [`governance/data-sharing-and-sovereignty.md`](./governance/data-sharing-and-sovereignty.md) apply to recruitment messaging too.

---

## 4. Volunteer / validator quick-training

Two tiers, sized for the first 48 hours:

**Community reporters — zero-training design + 1-page guide.** The capture flow is a guided
wizard (photo → damage grade → life-safety → infrastructure → location → review) in 6 UN languages
— ✅ IMPLEMENTED. A printable 1-page illustrated reporter guide (install → capture → what the app
does offline → privacy in plain words) — 🔜 PLANNED as a static asset; its content already exists
on the live help site (✅, EN only — translations needed).

**Field validators / CO analysts — 30-minute session + checklist.** Run by the SURGE first
responder or validator-trainer (§1.8) against the live dashboard:

1. Log in; understand your crisis scope (RBAC) — ✅ IMPLEMENTED
2. Verify vs flag: photo consistency, location plausibility, duplicate awareness (building versioning shows the timeline) — ✅ IMPLEMENTED
3. Set the verification state on a report (`PATCH /api/v1/reports/{id}/verification`) — ✅ IMPLEMENTED
4. Export discipline: who may export what, and that public release is coarsened — per the RBAC matrix in [`governance/data-controller-and-breach-response.md`](./governance/data-controller-and-breach-response.md)

The written validator checklist distilling the above into one laminated page — 🔜 PLANNED
(content exists across the dashboard + governance docs; needs assembling and translating).

---

## 5. Per-crisis configuration & language localization workflow

**Per-crisis configuration — what is configurable today:**

| Knob | Mechanism | Status |
|---|---|---|
| Crisis extent, time window, status, GLIDE, Level | Crisis entity (analyst-managed) | ✅ IMPLEMENTED |
| Damage scale shown to reporters | Fixed 3-tier scale (minimal / partial / complete) — no toggle | ✅ IMPLEMENTED (mandated 3-tier) |
| Modular question section (electricity, health services, pressing needs) | Question schema is **served by the backend's dynamic form-schema endpoint**, with per-crisis **require/hide overrides** (`PATCH /api/v1/crises/{id}/form`) — no app release needed to tighten or trim the form per crisis; exports pick up modular sections from the report data automatically. **Authoring entirely new question types per crisis is 🔜 PLANNED** | 🟡 PARTIAL |

**Language localization workflow:**

1. **The 6 UN languages need no per-crisis work** — full UI localization incl. Arabic RTL ships in
   the app; users switch in Profile or follow the system locale — ✅ IMPLEMENTED.
2. **Free-text in any language is handled at intake**: self-hosted LibreTranslate auto-detects the
   source language and translates descriptions to English on submit; the original is preserved and
   the dashboard shows a translate/original toggle — ✅ IMPLEMENTED (verified live; container ships
   UN languages + uk/tr — additional LibreTranslate language models are a config/pull change).
3. **Adding a local (non-UN) UI language** — 🔜 PLANNED workflow: add a strings file (the app's
   i18n layer is string-resource based), translate the ~screenful of capture-flow strings first
   (the only path reporters must understand), ship via the direct-APK channel (§2.1) without
   waiting for store review. Realistic inside the 48h window for the capture flow; full UI
   coverage follows.
4. **Print/radio assets** (§3) are translated by the CO with the government counterpart — local
   review is mandatory, machine translation only as a draft.

---

## 6. Data controller & handover

Deployment is not only technical activation — the data-responsibility chain must be live from the
first report. This document deliberately **points** rather than duplicates:

- **Named controller + accountability split (Crisis Bureau ↔ CO), RBAC matrix, breach/incident SOP**
  → [`governance/data-controller-and-breach-response.md`](./governance/data-controller-and-breach-response.md). Naming the controller is runbook step 1.5.
- **DPIA** — reviewed **before first country deployment** and on the §11 review triggers; its §10
  go/no-go conditions are binding (see §0.4 above for the security gates that remain open in the
  current build) → [`governance/DPIA.md`](./governance/DPIA.md).
- **Retention & destruction schedule** — adopted by the deploying CO at activation; note the purge
  job is documented policy, **not yet implemented in code** → [`governance/retention-and-destruction.md`](./governance/retention-and-destruction.md).
- **Data Sharing Agreements, sovereignty, government-request policy, transparency notice &
  data-subject rights** — governs every export in step 1.11 and any handover of the dataset or the
  hosting to national authorities → [`governance/data-sharing-and-sovereignty.md`](./governance/data-sharing-and-sovereignty.md).
- **Handover beyond the response**: because the stack is Apache-2.0 and Docker-packaged (§0.1–0.2),
  handover to UNDP or a national authority is a re-host + data transfer executed under the
  sovereignty policy, with the controller hand-off recorded per the controller document.

---

## Summary: implemented today vs planned

**Working now (✅):** analyst-created + emergent crisis activation; decoupled reporting with
auto-attach; global auto-Area (zero GIS prep); offline-first capture/sync; 6 UN languages + RTL;
LibreTranslate intake translation; RBAC dashboard with analyst verification; interop exports
(GeoJSON / HXL-CSV / GPKG / KML / Shapefile); per-crisis capture-form configuration (require/hide
of existing sections via crisis form overrides — §5); live help site; Apache-2.0 licensed (public
publication pending — [`docs/PUBLISH-CHECKLIST.md`](./PUBLISH-CHECKLIST.md)); governance
documentation pack; scale-validated schema.

**Planned (🔜) — the honest gap list:** dormant store listings; signed-release APK pipeline +
hosted QR (partial); MDM channel; reporter web/PWA fallback; real IdP; push notifications;
authoring entirely new form question types per crisis; printed reporter/validator one-pagers and
awareness asset templates; the DPIA §10 security gates (encryption at rest, MFA, retention purge,
cert pinning) — which are pre-deployment conditions, not 48-hour-window work.
