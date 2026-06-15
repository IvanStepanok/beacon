# Beacon — Operational Model & Deployability

> Research-grounded model of how UNDP crisis response actually works, and where Beacon fits.
> Derived from a multi-source web sweep (UNDP Crisis Bureau/RAPIDA, PDNA/GFDRR, OCHA clusters,
> Copernicus EMS/ATC-20, OCHA Data Responsibility, CODs/P-codes/HXL, KoBo/ODK/Ushahidi/UNOSAT,
> INSARAG). **This is a strategy + scope-rationale document, reconciled to the shipped build.**
> Where it differs from `docs/STATUS.md`, **STATUS.md is authoritative.**

## The thesis
Beacon is **not "another damage app."** It is the **human ground-truth layer** of UNDP's existing
crisis pipeline. In the first 24–72h, UNDP's AI tool **RAPIDA** fuses satellite damage classes
(UNOSAT/Copernicus) with population + building footprints to estimate damage and steer **SURGE**
first responders. But **satellites systematically under-detect damage (~27% omission)** — low
grades, side/ground-floor collapse are invisible from nadir. **That gap is Beacon's defensible
niche:** crowdsourced + responder ground reports that resolve the "possibly damaged" class and feed
RAPIDA → OCHA clusters → MIRA/HNO → the **PDNA/DaLA** damage tables that drive recovery financing.

To drop into that pipeline rather than sit in a bespoke silo, the data must **speak the standards**
— and Beacon's design choices below are deliberately scoped to *be a feed into* that pipeline,
not to *replace* the response-coordination systems that already own tasking and dispatch.

## Operational model (how it really works → Beacon's approach)
| Aspect | Reality | Beacon's approach (shipped unless noted) |
|---|---|---|
| **Activation & Level** | Per-event; Regional Bureau → Crisis Response Unit runs a rapid Level assessment with the Country Office. L1=CO top-up, L2=Crisis Board+SURGE, L3=exceptional. | Per-crisis **GLIDE event ID** + **UNDP response Level (1/2/3)** carried on the crisis entity (`crises.glide`, `crises.response_level`), on top of `crisis_id` multi-tenancy. |
| **Who's the customer** | The **Country Office (CO)** is the on-ground actor; stands up a Crisis Response Team (CRT). SURGE Advisors deploy as First Responders in days. | Outputs feed a **CO-led** verify workflow + the first-hours rapid assessment. The "SURGE FR verifying satellite-flagged damage" moment is Beacon's exact slot. |
| **24–72h remote layer** | **RAPIDA** (open-source UNDP-Data/rapida) zonal-stats UNOSAT/Copernicus grades over an AOI + WorldPop + footprints. | Be the **field-verification front-end** that resolves "possibly damaged"; export tagged with the **same admin boundaries (COD-AB P-codes) + building footprints** RAPIDA uses. |
| **Regional structure** | 5 Regional Bureaus (RBA/RBAS/RBAP/RBEC/RBLAC) over Country Offices; Crisis Bureau (HQ) holds tools/sets Level. | **Role-based multi-region access** (field validator / CO analyst → one crisis; regional analyst → many; crisis admin → all). 6 langs+RTL map to the bureaus (RBAS=Arabic, RBLAC=Spanish, RBEC=Russian). |
| **Incumbent to beat** | UNOSAT field validation (Myanmar 2025) used **UN-ASIGN** for 1,000+ geolocated photos. | Match UN-ASIGN capture; differentiate with crowdsourcing + offline-first + on-device AI + per-footprint versioning; be a UN-ingestible feed (standards exports below). |
| **Coordination/tasking** | IASC clusters by sector; **2026 Humanitarian Reset → 8 clusters**, shelter/damage → new **SLSC**; standalone Early Recovery (UNDP) phased out end-2026. OCHA runs CODs + 3W/4W + HDX. | **Deliberate boundary:** Beacon does **not** run dispatch/tasking — that belongs to the responder org's existing systems (INSARAG worksite, CAD, cluster 4W). Beacon emits verified, P-code-tagged ground truth those systems ingest. Per-report cluster/sector tagging is **roadmap** (see below). |
| **Recovery financing** | Government-led tripartite **PDNA** (UNDP/WB/EU), structured **by sector × admin area**; **DaLA**: damage = units × replacement cost. ~5–6 week Flash Appeal/CERF window. | Export the **standards pack** (GeoJSON / HXL-CSV / GeoPackage / KML / Shapefile) with ADM0–ADM3 P-code columns + damage-tier counts per admin area — the inputs a PDNA Volume B pivot is built from. (Asset-valuation attributes for full DaLA costing are roadmap.) |

## Report & crisis lifecycle (as shipped)
Beacon's lifecycle is **verification-centred**, not dispatch-centred. Credibility ("is this real?")
is the axis Beacon owns; **disposition/tasking ("who is responding, what happened") is deliberately
left to the responder org's systems** (see *Deliberate scope boundary*).

1. **Capture (offline)** — reporter / field validator: photo + **3-tier damage grade**
   (minimal / partial / complete) + location (footprint snap → Plus Code → landmark fallback) +
   on-device anonymization (EXIF strip). On-device advisory AI suggests a grade; the human always
   sets it.
2. **Submit & stamp** — system: idempotent upsert, PostGIS geometry, per-building version, and
   reverse-geocode to **ADM0–ADM3 P-codes** (official OCHA COD-AB where ingested, `GB:`-prefixed
   geoBoundaries fallback otherwise). H3 cell stamped for hotspot aggregation.
3. **Crisis association** — a report attaches to an existing crisis, or a cluster of independent
   reporters **proposes an emergent crisis** (`status = proposed`) that an analyst confirms
   (`active`) or dismisses. Scope thresholds (distinct submitters + admin spread) gate promotion so
   a single device cannot conjure a crisis.
4. **Verify** — analyst: pending → verified / flagged; duplicates collapse onto the building's
   version history; every decision is written to an immutable audit trail (actor from the JWT).
5. **Aggregate & hand off** — per admin × damage-tier rollups + H3 hotspots for RAPIDA/MIRA/HNO/PDNA;
   export the standards pack; publish de-identified, coarsened aggregates (raw clusters never
   published). Hand-off to cluster IM / responder tasking systems happens **through the export**,
   not inside Beacon.

### Deliberate scope boundary (what Beacon intentionally does NOT do, and why)
These were considered, prototyped, and **removed on purpose** (migrations `00016`–`00019`). Stating
them as scope decisions is itself a design position:

- **No dispatch / task state machine / assignment / disposition codes** (dropped `00018`). Beacon is
  a *ground-truth and verification feed*, not a CAD/dispatch tool. Tasking, en-route/on-scene
  tracking, and terminal dispositions belong to the responder organisation's existing systems
  (INSARAG worksite management, CAD, cluster 4W). Owning that workflow would duplicate mature systems
  and create liability for response decisions Beacon is not positioned to make.
- **No life-safety fast-lane / "people trapped" routing.** A crowdsourced reporting app must **not**
  imply that submitting a report summons rescue. Life-safety dispatch requires a guaranteed
  chain-of-custody to a real responder, which Beacon does not provide. Keeping life-safety out is an
  *ethical* scope decision, not a missing feature.
- **3-tier damage grade, not 5-level EMS-98 / ATC-20** (collapsed `00019`). The challenge mandates a
  3-level core indicator; crowd reporters are not structural engineers, so a coarse,
  photo-illustrated 3-tier grade (minimal / partial / complete) is more reliable from field capture
  than a 5-level engineering scale. Joinability to satellite products is preserved by mapping
  (slight→minimal, severe/destroyed→complete); the rollup logic lives in `internal/model/crisis.go`.
- **No ATC-20 safety placard axis / danger zones** (danger zones dropped `00016`). Placarding a
  building INSPECTED/RESTRICTED/UNSAFE is an authoritative engineering act; Beacon's reporters are
  rapid-evaluation contributors, not certified evaluators.

## Data model — built vs scoped-out vs roadmap
**Built (shipped):**
- **Admin P-code chain ADM0–ADM3** — reverse-geocode GPS to COD-AB (official) with a `GB:`-prefixed
  geoBoundaries fallback; raw lat/lon retained server-side. The join key for the whole system.
- **3-tier damage grade** (minimal / partial / complete) + per-building version history.
- **GLIDE event ID + crisis response Level (1/2/3)** on the crisis entity.
- **Emergent-crisis model** (proposed → analyst-confirmed) with distinct-submitter / admin-spread
  scope thresholds.
- **RBAC role + region scope** (5 roles) with an immutable verification audit trail.
- **H3 cell** per report for hotspot aggregation + privacy-coarsened public reads.

**Deliberately out of scope (see boundary above):** 5-level EMS-98 grade · ATC-20 placard axis ·
task/dispatch state machine + disposition codes + assignment · life-safety triage / fast-lane ·
danger zones.

**Roadmap (genuinely next, not built):** configurable cluster/sector tagging (legacy-11 + 2026-8
incl. SLSC) · asset-valuation attributes (use/occupancy, storeys, construction, footprint area) for
DaLA costing · close-the-loop reporter notification · real analyst IdP (Azure AD / OIDC).

## Interoperability standards
**Supported today:**
- **COD-AB + P-codes** (offline GPS→P-code bundle) — the join key.
- **GeoJSON** (default machine exchange), **GeoPackage (GPKG, OGC)** (single-file, offline-ideal),
  **zipped Shapefile + KML** (desktop-GIS / government compatibility).
- **HXL hashtag row** on CSV export (note: OCHA retired hosted HXL tooling 2026-01-31 → treat as
  self-contained; P-codes are the durable layer).
- **EMS-98/Copernicus/UNOSAT grade alignment** via the 3-tier → satellite-grade mapping.
- **GLIDE number** — cross-org event key.

**Roadmap:** OpenRosa/XLSForm wire-compat (flow into KoBo/ODK Central) · HDX (CKAN/HAPI) publish
endpoint for de-identified aggregates.

## Data responsibility (go-live prerequisites)
- **The aggregate is sensitive (DII)**: a cluster of geolocated reports reveals where affected people
  are. EXIF strip / anonymity do NOT make it safe → never publish raw location clusters; coarsen to
  ~110 m / P-code in public views; fine geo behind access control. **[Implemented]** in the backend
  projection.
- **DPIA** documented (`docs/governance/DPIA.md`) — review before launch & on major change.
- **Legal basis**: consent is usually invalid in crisis → rely on vital/public interest under
  mandate; inform in plain local language; genuine right to object/delete; never gate help on data.
- **Data minimization + purpose limitation**; pseudonymous by default; contact optional.
- **Retention & destruction schedule** documented (`retention-and-destruction.md`); the **automated
  purge job is [Planned]**.
- **Data sovereignty**: named controller, hosting-jurisdiction + government-request policy, Data
  Sharing Agreements — documented (`data-sharing-and-sovereignty.md`,
  `data-controller-and-breach-response.md`); **named controller is a binding pre-deployment gate**.
- **Security by design** — **[Implemented]:** TLS at edge + enforced DB-transit TLS, RBAC + audit,
  at-rest AES-256-GCM for photos + sensitive secrets, MFA (TOTP), mobile certificate pinning.
  **[Planned]:** full-cluster/backup/device-cache at-rest encryption, on-device face/plate blur,
  automated retention/purge job. (Authoritative: STATUS.md security table.)
- **Accountability to Affected People**: accessible UX (6 langs+RTL, low-literacy-friendly,
  offline-first), feedback channel, gender/child sensitivity.

## Gap analysis vs the shipped build
> **Authoritative build state is `docs/STATUS.md`.** This is the research-time strategy snapshot,
> reconciled. Two clarifications on "HAVE": on-device anonymization = **EXIF stripping only**
> (face/plate blur is **[Planned]**, only a boolean flag is stored), and the on-device AI is a real
> **MobileNetV3 advisory classifier** (human-in-the-loop, never authoritative).

**HAVE (built):** per-crisis multi-tenancy · PostGIS geometry · per-building versioning ·
verification states + immutable audit · offline-first idempotent submission · on-device EXIF
stripping · location fallbacks (footprint/Plus Code/landmark) · **P-code/admin tagging (COD-AB + GB
fallback)** · **RBAC multi-region (5 roles)** · **GLIDE + crisis Level** · **emergent-crisis
lifecycle** · **H3 hotspots** · **export pack: GeoJSON / HXL-CSV / GeoPackage / KML / Shapefile with
P-code columns** · **governance pack: DPIA + retention + controller + breach SOP + DSA** ·
**security: enforced DB-TLS + at-rest (photos+secrets) + MFA + cert-pinning**.

**DELIBERATELY OUT OF SCOPE:** 5-level grade · ATC-20 placard · task/dispatch lifecycle + disposition
codes · life-safety routing · danger zones (rationale in *Deliberate scope boundary*).

**ROADMAP (not built):** configurable cluster/sector tagging · asset-valuation attributes ·
close-the-loop reporter notification · real analyst IdP · OpenRosa/XLSForm + HDX publish · full
at-rest/backup encryption + automated purge job + on-device face/plate blur.

## Recommended roadmap
**NOW (deployability core) — DONE:** P-code stamping ✅ · governance pack (DPIA + retention + named-
controller policy + government-request/sharing policy; stop publishing raw clusters) ✅ ·
interoperability export pack (HXL-CSV + GPKG + Shapefile + KML + GeoJSON, P-code columns) ✅ ·
core security controls (DB-TLS, at-rest for photos+secrets, MFA, cert-pinning) ✅.

**NEXT:** configurable cluster/sector tagging + 4W overlay · asset-valuation attributes (DaLA) ·
real analyst IdP (Azure AD/OIDC) · automated retention/purge job · on-device face/plate blur ·
full-cluster/backup at-rest encryption.

**LATER:** OpenRosa/XLSForm + HDX (CKAN/HAPI) publish · close-the-loop reporter notification +
reconstruction-tracking mode · consume RAPIDA/Copernicus + open-footprints baseline; benchmark vs
UN-ASIGN.

## Key citations
UNDP crisis Level SOP (popp.undp.org/taxonomy/term/7326) · UNDP deployment/SURGE
(undp.org/crisis-response/deployment-mechanism, /crisis/surge) · RAPIDA (github.com/UNDP-Data/rapida) ·
Myanmar 2025 mapping (undp.org/stories) · PDNA Volume A (gfdrr.org) · 2026 SLSC cluster (iom.int) ·
COD/P-codes (data.humdata.org/cod, knowledge.base.unocha.org P-codes) · HXL (hxlstandard.org) ·
GeoPackage (ogc.org/standards/geopackage) · Copernicus EMS grading (mapping.emergency.copernicus.eu) ·
ATC-20 (atcouncil.org/atc-20) · GLIDE (glidenumber.net) · OCHA Data Responsibility Guidelines
(data.humdata.org) · IASC Operational Guidance on Data Responsibility 2023 · ICRC Handbook on Data
Protection · UN Personal Data Protection Principles 2018 · INSARAG worksite triage (insarag.org) ·
OpenRosa (docs.getodk.org/openrosa).
