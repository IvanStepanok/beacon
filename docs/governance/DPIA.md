# Data Protection Impact Assessment (DPIA)

## Beacon — UNDP Crisis Building-Damage Crowdsourcing Platform

| Field | Value |
|---|---|
| **Document type** | Data Protection Impact Assessment (DPIA) |
| **System assessed** | Beacon — mobile crowdsourcing app + analyst dashboard + Go/PostgreSQL-PostGIS backend |
| **Version** | 1.0 (pre-deployment) |
| **Date** | 2026-06-05 |
| **Author / role** | Draft prepared by RaccoonGang (solver) for UNDP review — to be owned by the deployment's named Data Controller / DPO |
| **Status** | Draft for review by Country Office, Regional Bureau, Crisis Bureau, and Legal/Privacy |
| **Classification** | Internal — restricted |
| **Next mandatory review** | Before first country deployment, then per the review triggers in §11 |

> **Implementation-status convention (added in honesty pass).** This DPIA describes the *target* control set for a production deployment. Not all controls are built in the current MVP. Each security/privacy control below is tagged **[Implemented]** (present and verified in the current build), **[Planned]** (designed and required pre-deployment, not yet built), or **[In progress — this cycle]**. A control tagged Planned is a binding pre-deployment condition (§10), **not** a current mitigation — residual-risk reasoning that depends on a Planned control is contingent on its delivery. The authoritative build state is `docs/STATUS.md`.

> **Note on scope.** This DPIA is conducted because Beacon processes data about identifiable persons (photos, pseudonymous submitter IDs) **and** produces an aggregate dataset of geolocated damage reports that constitutes **Demographically Identifiable Information (DII)** — data that reveals where affected and potentially displaced people are. A DPIA / Data Impact Assessment is the established instrument required by the [IASC Operational Guidance on Data Responsibility in Humanitarian Action (2023)](https://interagencystandingcommittee.org/sites/default/files/migrated/2023-04/IASC%20Operational%20Guidance%20on%20Data%20Responsibility%20in%20Humanitarian%20Action,%202023.pdf) and the [OCHA Data Responsibility Guidelines (2021/2025)](https://www.unocha.org/publications/report/world/data-responsibility-guidelines-october-2021) before deploying any system of this kind.

---

## 1. Executive Summary

Beacon enables affected community members and field responders to photograph damaged buildings after a crisis and submit a 3-level damage grade with geolocation. The data feeds an analyst dashboard (Country Office / Regional Bureau / Crisis Bureau roles) and a Go + PostgreSQL/PostGIS backend, with exports (GeoJSON, CSV/HXL, GeoPackage, Shapefile) potentially published to the [Humanitarian Data Exchange (HDX)](https://data.humdata.org/).

The **primary protection concern is not the individual record but the aggregate**. Individual records are anonymised at source to the extent currently built — EXIF stripping (**[Implemented]**) and pseudonymous submitter IDs (**[Implemented]**); on-device face/plate blurring is **[Planned]**, not yet implemented (see §6, R2). However, a dense, fine-grained map of where buildings are damaged is, in a crisis, a map of where vulnerable people are or recently were. Under OCHA and IASC frameworks this aggregate is **non-personal data that is nonetheless sensitive**, because the likelihood and severity of harm from its exposure are high in conflict and disaster settings (see [Centre for Humanitarian Data glossary](https://centre.humdata.org/glossary/)).

This DPIA concludes that Beacon can be deployed **subject to mandatory conditions** (§10). The dominant residual risks — re-identification from location clusters, misuse of photos of identifiable persons, and compulsion of data by a host government — are reducible but not eliminable. They are managed primarily through (a) never publishing raw coordinates (public-view coordinate coarsening (~110 m) + verified-only public reads are **[Implemented]** on the backend), (b) on-device anonymisation (EXIF stripping is **[Implemented]**; face/plate blur is **[Planned]**), (c) least-privilege RBAC and audit logging (**[Implemented]**), (d) a named controller and incident SOP, and (e) strict purpose limitation. The legal basis is **public interest / vital interest under UNDP's mandate — not consent** — because valid consent is generally unobtainable in a crisis (§2).

**Go/No-Go: Conditional Go.** Deployment is approved only when the conditions in §10 are met, foremost a named data controller, a confirmed hosting jurisdiction with an assessed sovereignty risk, and a documented retention/destruction schedule including offline device caches.

---

## 2. Purpose, Necessity, and Legal Basis

### 2.1 Purpose (purpose specification & limitation)

Beacon's sole specified purposes are:

1. **Rapid building-damage assessment** to direct life-saving response, shelter, and early recovery after a disaster or conflict event.
2. **Post-Disaster Needs Assessment (PDNA) and recovery planning**, including aggregated damage statistics by administrative area.
3. **Coordination** with humanitarian partners through responsibly shared, aggregated outputs.

No other use is authorised. Any new use (e.g., feeding individual records to authorities, law-enforcement, property-dispute adjudication, or eviction/return decisions) is **function creep** and is prohibited without a fresh DPIA (§11). This reflects the **Purpose Specification** and **Proportionality and Necessity** principles of the [UN Personal Data Protection and Privacy Principles (2018)](https://unsceb.org/personal-data-protection-and-privacy-principles) and the purpose-limitation requirement of the [OCHA Data Responsibility Guidelines](https://www.unocha.org/publications/report/world/data-responsibility-guidelines-october-2021).

### 2.2 Necessity and proportionality

Photographing damage with geolocation is necessary to assess habitability and target assistance; coarser methods (e.g., remote sensing alone) miss ground truth and interior damage. The data collected is the minimum required: a photo, a damage grade, a location, and an optional note — see the minimisation analysis in §3.3. Collecting submitter contact details, names, or identity documents is **not** necessary and is therefore prohibited.

### 2.3 Legal basis — why consent is invalid in a crisis

Beacon does **not** rely on consent as its legal basis. The [ICRC Handbook on Data Protection in Humanitarian Action (2nd ed.), Chapter 3 "Legal bases for Personal Data Processing"](https://www.cambridge.org/core/books/handbook-on-data-protection-in-humanitarian-action/legal-bases-for-personal-data-processing/DF71FB331569DA5B83B60DC925017278) explains that in emergencies it is frequently impossible to satisfy the conditions of valid consent — that it be **freely given, specific, informed and unambiguous** — especially where "consenting to personal data processing is a precondition to receive assistance." In a crisis, a person who has just lost their home cannot give freely-given consent if assistance appears to depend on it.

Accordingly, Beacon relies on the alternative bases identified in the same Handbook chapter:

- **Vital interest** of the data subject and of other affected persons (assistance and protection of life), and
- **Important grounds of public interest**, namely the **performance of UNDP's institutional mandate** for crisis response and recovery established under international law and UN General Assembly resolutions.

Two operational consequences follow directly from this basis, and are binding requirements for Beacon:

- **Help is never gated on data.** No person may be denied, delayed, or down-prioritised for assistance because they did not submit a report or declined to be photographed. (Vital interest may be used "only to provide assistance," per the ICRC Handbook.)
- **The right to object and a privacy notice** must be available. Where vital/public interest is the basis, the data subject must be offered the right to object and the processing must be governed by an accessible privacy notice (§9, §10).

This approach is consistent with the **Fair and Legitimate Processing** principle of the [UN Principles (2018)](https://unsceb.org/personal-data-protection-and-privacy-principles), under which UN entities process personal data fairly and in accordance with their mandates.

---

## 3. Data Inventory

### 3.1 Data elements, source, and sensitivity

| Data element | Collected by / source | Personal? | Sensitivity | Notes |
|---|---|---|---|---|
| Building photo (post-anonymisation) | Community member or field responder, on device | Possibly (if persons visible) | Medium–High | EXIF stripped on-device **[Implemented]**. Face/plate blur is **[Planned]** — *not* yet implemented, so a face captured in shot is currently stored as-is. Elevated residual risk until blur ships (§7, R2). |
| EXIF metadata (raw) | Device camera | Yes (can contain GPS, device IDs, timestamps) | High | **Stripped on-device; never transmitted or stored. [Implemented]** |
| GPS coordinates → admin **area code** | Device GPS, reverse-geocoded | DII when aggregated | **High in aggregate** | Admin-area reverse-geocode is **[Implemented]** (official OCHA COD-AB P-codes where a country's COD has been ingested, otherwise a `GB:`-prefixed geoBoundaries fallback — **[Implemented]**). Precise lat/long is retained server-side; role-gating exists (RBAC **[Implemented]**), and **public-view coordinate coarsening (~110 m) + verified-only public reads are [Implemented]** in the backend (§4, §7). |
| Damage grade (3-level) | Submitter / responder | No (alone) | Low individually; High in aggregate | Combined with location it is the core DII payload. |
| Pseudonymous / anonymous submitter ID | Generated on device | Pseudonymous personal data | Medium | No name, phone, or account by default. Linkable across submissions — treat as personal data. |
| Optional free-text note | Submitter | Possibly (may contain names, "my neighbour", health info) | **Variable / High** | Free text is the highest-risk minimisation gap — see §3.3 and Risk R2/R4. |
| Verification & task-change records | Analysts | Yes (staff) | Medium | Immutable audit trail; identifies which analyst did what. |
| Analyst account & role | UNDP identity system | Yes (staff) | Medium | RBAC: Country Office / Regional Bureau / Crisis Bureau. |
| Derived aggregate damage dataset | System | **DII (non-personal but sensitive)** | **High** | The principal protection concern of this DPIA. |

### 3.2 The aggregate as sensitive DII

Per the [Centre for Humanitarian Data glossary](https://centre.humdata.org/glossary/), **Demographically Identifiable Information (DII)** is data enabling identification of groups of individuals by factors including **location**, and **sensitive data** is data whose exposure is likely to cause harm "based on the likelihood and severity of potential harm … in a particular context." A geolocated damage-report layer, even fully de-identified at record level, is therefore **sensitive non-personal data**: in conflict it can reveal which neighbourhoods are emptied/occupied; after disaster it reveals where displaced and vulnerable populations are concentrated. This classification drives the controls in §4 and §7.

### 3.3 Data minimisation analysis

- **Keep:** photo (anonymised), damage grade, coarsenable location, pseudonymous ID.
- **Do not collect:** submitter name, phone, email, government ID, biometric identifiers, ethnicity/religion, household roster.
- **Free-text notes** are retained but flagged as a minimisation risk: the UI must warn submitters not to enter names or personal details, and notes must be (a) excluded from all exports/HDX by default and (b) reviewable/redactable by analysts before any sharing. This implements the **Proportionality and Necessity** principle ([UN Principles 2018](https://unsceb.org/personal-data-protection-and-privacy-principles)) and the minimisation requirement of the [IASC Operational Guidance (2023)](https://interagencystandingcommittee.org/sites/default/files/migrated/2023-04/IASC%20Operational%20Guidance%20on%20Data%20Responsibility%20in%20Humanitarian%20Action,%202023.pdf).

---

## 4. Data-Flow Description

```
[1] CAPTURE (mobile, often offline)
    Community member / field responder photographs a damaged building,
    assigns 3-level damage grade, optional note. Device captures GPS.
        |
        v
[2] ON-DEVICE ANONYMISATION (privacy by design / by default)
    - EXIF metadata stripped (incl. embedded GPS, device serials, timestamps)
      [IMPLEMENTED]
    - Faces and licence plates auto-detected and blurred BEFORE the photo
      leaves the device  [PLANNED — NOT YET IMPLEMENTED]
    - GPS reverse-geocoded to an admin area (official OCHA COD-AB P-codes
      where ingested, GB:-prefixed geoBoundaries fallback otherwise)
      [IMPLEMENTED]; precise coordinate retained for the authenticated server path
    - Submitter identified only by a pseudonymous on-device ID  [IMPLEMENTED]
        |
        v
[3] LOCAL CACHE (offline-first)
    Report queued in local storage until connectivity returns.
    Encryption of the device cache is  [PLANNED — NOT YET IMPLEMENTED].
    >>> RISK: device loss/seizure exposes the (currently unencrypted) cache (R3, R5).
        |
        v  (TLS at the edge [IMPLEMENTED]; certificate pinning to ISRG roots
        |   X1+X2 [IMPLEMENTED]; authenticated sync [IMPLEMENTED])
[4] SYNC -> Go BACKEND -> PostgreSQL/PostGIS
    - TLS terminated at the edge (Traefik) [IMPLEMENTED]. The backend↔PostgreSQL
      link runs sslmode=require, fail-closed in production — DB-transit TLS is
      [IMPLEMENTED].
    - Encryption at rest: report photos + the stored TOTP secret are sealed with
      AES-256-GCM (app-layer, DATA_ENCRYPTION_KEY) [IMPLEMENTED]; full-cluster DB,
      backup, and device-cache encryption remain [PLANNED — NOT YET IMPLEMENTED]
      (pgcrypto is present only for gen_random_uuid()).
    - Reports validated, deduplicated (idempotent submit [IMPLEMENTED]),
      geocoded; precise geometry stored in PostGIS; latest-per-building
      versioning [IMPLEMENTED]
    - Immutable audit trail (RBAC + audit FKs) records verification and task
      changes  [IMPLEMENTED]
        |
        v
[5] ANALYST ACCESS (RBAC dashboard)  [IMPLEMENTED]
    Country Office / Regional Bureau / Crisis Bureau roles see only what
    their role permits. Public/partner-view coarsening to P-code +
    verified-only public reads are  [IN PROGRESS — THIS CYCLE].
        |
        v
[6] EXPORT (GeoJSON / CSV-HXL / GeoPackage / Shapefile)
    - Disclosure control applied: P-code coarsening, free-text excluded,
      small-count suppression / k-anonymity thresholds
        |
        v
[7] OPTIONAL PUBLICATION TO HDX
    Only AFTER sensitivity classification + disclosure-control review.
    Raw coordinate clusters are NEVER published.
```

**Controls anchored to the flow.** Steps [2]–[3] implement *privacy/security by design and by default*; step [4] implements *Security* and *Confidentiality* ([UN Principles 2018](https://unsceb.org/personal-data-protection-and-privacy-principles)); steps [6]–[7] implement HDX policy that public data must be "sufficiently aggregated or anonymized so as to prevent identification of people or harm," and that DII "that may put affected people at risk" is not published (see [Improving the management of sensitive data on HDX](https://centre.humdata.org/improving-the-management-of-sensitive-data-on-hdx/)).

---

## 5. Actors, Roles, and Accountability

| Role | Responsibility | Access |
|---|---|---|
| **Data Controller (TBD — MUST be named pre-deployment)** | Determines purposes/means; accountable for this DPIA's conditions; owns retention, incident SOP, request handling | N/A |
| **Country Office analysts** | Verify reports, manage tasks within their country | Country-scoped, may include finer geometry |
| **Regional Bureau analysts** | Regional aggregation/oversight | Regional, default coarsened |
| **Crisis Bureau analysts** | Global crisis coordination | Cross-country, aggregated views |
| **Submitters (affected people / responders)** | Provide reports; hold data-subject rights | App only |
| **DPO / Privacy function** | Reviews DPIA, advises on incidents, signs off on HDX publication | Oversight |

A **named controller is a non-negotiable precondition** ([UN Principles 2018 — Accountability](https://unsceb.org/personal-data-protection-and-privacy-principles); [IASC Operational Guidance 2023](https://interagencystandingcommittee.org/sites/default/files/migrated/2023-04/IASC%20Operational%20Guidance%20on%20Data%20Responsibility%20in%20Humanitarian%20Action,%202023.pdf)). "Hosting/controller TBD" is itself a finding (see §10, Condition C1).

---

## 6. Security by Design

- **Encryption in transit:** **[Implemented]** TLS at the edge (Traefik + Let's Encrypt) for all app↔backend and dashboard↔backend traffic. **[Implemented]** DB-transit TLS — the backend↔PostgreSQL connection runs `sslmode=require`, and the config fails closed in production if TLS is disabled or downgraded to `prefer`. **[Implemented]** Certificate pinning on the mobile client — Android (OkHttp SPKI pins) and iOS (Ktor/Darwin server-trust evaluation, certificate-DER pins) both pin to the ISRG / Let's Encrypt roots X1 + X2; any other CA is rejected (fail-closed).
- **Encryption at rest:** **[Implemented for photos + sensitive secrets].** Report photos and the stored TOTP secret are sealed with AES-256-GCM (authenticated, tamper-detecting, app-layer) under a 32-byte `DATA_ENCRYPTION_KEY` that is required in production; photo files are written `0600`. This makes the crypto-shred destruction control in `retention-and-destruction.md` operable for photos. **[Planned — NOT yet implemented]:** full-cluster PostgreSQL/PostGIS encryption, encrypted backups, and on-device offline-cache encryption remain deployment-environment responsibilities (a binding pre-deployment condition, §10). (`pgcrypto` is enabled, but only for `gen_random_uuid()`.)
- **Least-privilege RBAC:** **[Implemented]** role scoping (5 roles incl. Country/Regional/Crisis) enforced server-side, not just in the UI, with audit-actor derived from the token. Note: **public-view coarsening gating precise coordinates away from public reads is [Implemented]** (see R1).
- **Audit logging:** **[Implemented]** immutable audit trail (RBAC + audit FKs) of verification and task changes. **[Planned]** extension to log access to precise-location data and bulk exports.
- **Authentication:** **[Implemented]** analyst auth (JWT + bcrypt) with session/token handling, plus **[Implemented]** MFA (TOTP, RFC 6238): analysts can enrol an authenticator (`/auth/mfa/{enroll,verify,disable}`), validation is constant-time with ±1-step skew, the secret is stored encrypted, and login is gated (fail-closed) once enabled. Enforcing MFA as *mandatory* for export / de-coarsen roles is a deployment-policy toggle (§10, C2).
- **Key management & backup destruction:** **[Planned]** documented but not built; depends on encryption-at-rest landing first. Backups will inherit the retention/destruction schedule (§8).

These align with the **Security** and **Confidentiality** principles ([UN Principles 2018](https://unsceb.org/personal-data-protection-and-privacy-principles)) and the data-security guidance in the [OCHA Tip Sheet on Data Security](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/a23b2ace-0a1a-41d5-9e22-becfd1bc8c7b/download/tip-sheet-on-data-security-in-ocha-data-management.pdf).

---

## 7. Risk Table

Likelihood and Impact scored Low / Medium / High. Risk priority is the combination, with humanitarian harm (physical safety of affected people) weighted highest.

| # | Risk | Likelihood | Impact | Priority | Mitigations |
|---|---|---|---|---|---|
| **R1** | **Re-identification of affected/displaced people from location clusters.** Aggregate DII reveals where vulnerable people are; dense clusters of "destroyed" grades map displacement and can be exploited by parties to a conflict. | High | High | **Critical** | Classify the aggregate as sensitive DII (policy, done). **Public-view coordinate coarsening (~110 m) + verified-only public reads: [Implemented]** on the backend (unverified reports 404 to public callers; public projection strips landmark/buildingId/description). **[Planned]:** small-count suppression / k-anonymity before export; disclosure-control review (sdcMicro-style) before HDX per [HDX sensitive-data approach](https://centre.humdata.org/improving-the-management-of-sensitive-data-on-hdx/). **[Implemented]:** server-side RBAC role-gating of analyst views. |
| **R2** | **Photos of identifiable persons** (bystanders, residents) captured and stored; faces visible in interior shots. | Medium | High | **High** | **[Implemented]:** EXIF strip before storage; UI guidance to photograph structures not people; notes/photos excluded from default exports. **[Planned — NOT yet implemented]:** on-device face/plate blurring (only a boolean flag is currently stored — no detection or blur runs), blur-failure fallback (block/queue when detector confidence low), and periodic QA sampling of stored photos. **Until blur ships, a person captured in a photo is stored unblurred — this risk is currently only partly mitigated.** |
| **R3** | **Host-government compulsion** — authorities demand raw reports, coordinates, or device data (data sovereignty risk), e.g. to locate returnees, occupants, or property claimants. | Medium | High | **High** | Host jurisdiction selected and risk-assessed **before** deployment; prefer hosting outside compulsion reach where mandate/privileges-and-immunities allow; data minimisation so there is little of individual value to compel; only aggregated, coarsened outputs leave the system by default; legal escalation protocol; document and resist requests inconsistent with mandate; addressed under [IASC 2023](https://interagencystandingcommittee.org/sites/default/files/migrated/2023-04/IASC%20Operational%20Guidance%20on%20Data%20Responsibility%20in%20Humanitarian%20Action,%202023.pdf) data-sovereignty/handling-of-requests guidance. |
| **R4** | **Internal misuse / unauthorised access** — an analyst de-coarsens or exports data for non-mandate use; insider links pseudonymous IDs across submissions. | Medium | High | **High** | **[Implemented]:** least-privilege RBAC enforced server-side; immutable audit trail (RBAC + audit FKs); **MFA (TOTP) available for analyst accounts** (mandatory enforcement for export/de-coarsen roles is a deployment-policy toggle). **[Planned — NOT yet implemented]:** audit coverage extended to precise-location access and exports; alerting on bulk export. **[Policy]:** purpose-limitation with disciplinary consequences; "use of anonymised beneficiary data for non-humanitarian purposes" is a recognised data incident ([Data Incident Management](https://centre.humdata.org/guidance-note-data-incident-management/)). |
| **R5** | **Insecure transfer / device loss/seizure** — offline cache or sync intercepted or read from a lost/confiscated device. | Medium | High | **High** | **[Implemented]:** TLS at the edge; **certificate pinning to the ISRG roots (Android + iOS)**, which closes the rogue-CA / interception path; authenticated sync; cache purge after successful sync; minimal data retained on device. **[Planned — NOT yet implemented]:** encryption of the offline cache (currently unencrypted), remote wipe / forced cache purge on logout, passcode/biometric app lock. **Until offline-cache encryption ships, a lost/seized device with queued reports is still a real exposure.** |
| **R6** | **Function creep** — data repurposed for law-enforcement, eviction/return adjudication, property disputes, surveillance, or automated targeting. | Medium | High | **High** | Hard purpose limitation (§2); new use requires fresh DPIA and DPO sign-off (§11); contractual/MOU constraints with any recipient; **no solely-automated decisions** about individuals (damage grade never auto-determines a person's eligibility); export logging surfaces unusual downstream demand. |
| **R7** | **False / malicious / coerced reports** (data quality) — bad grades misdirect aid or are weaponised to draw responders to a location. | Medium | Medium | Medium | Analyst verification workflow + immutable audit trail; pseudonymous-ID reputation/rate controls; cross-check against remote sensing; no automated action on a single unverified report. |
| **R8** | **Inaccessible UX / exclusion** undermines Accountability to Affected People (AAP) — vulnerable groups, low-literacy, non-dominant-language, women, children cannot use the app or a feedback channel. | Medium | Medium | Medium | Multilingual UI (6 languages incl. RTL already built); icon-led, low-literacy-friendly flows; offline-first; in-app feedback/complaint channel and clear privacy notice; gender- and child-sensitive design; per [OCHA Guidance Note: Data Responsibility and Accountability to Affected People](https://www.unocha.org/publications/report/world/guidance-note-data-responsibility-and-accountability-affected-people-humanitarian-action). |
| **R9** | **Indefinite retention** — reports, photos, backups, and offline caches kept beyond their usefulness, expanding the attack/compulsion surface. | Medium | Medium | Medium | **[Implemented/Policy]:** documented retention schedule with secure destruction incl. backups and device caches (§8). **[Planned — NOT yet implemented]:** the automated retention/purge job (incl. partition-DROP purge) — the SOP is documented but no purge job exists in code yet; destruction logging depends on it. |
| **R10** | **Unsafe publication to HDX** — a dataset is published before sensitivity/disclosure review. | Low | High | Medium | Publication gated behind mandatory DPO + IM sensitivity classification and disclosure-control review; default to **not** publishing free text, photos, or sub-P-code geometry; "under review" hold before any release ([HDX](https://centre.humdata.org/improving-the-management-of-sensitive-data-on-hdx/)). |

---

## 8. Retention and Secure Destruction

The **Retention** principle of the [UN Principles (2018)](https://unsceb.org/personal-data-protection-and-privacy-principles) requires retention only as long as necessary for the specified purpose. Beacon's controller must publish a schedule covering:

| Data | Retention | Destruction |
|---|---|---|
| Offline device cache | Until successful sync, then **purge**; force-purge on logout | Cryptographic erase on device |
| Precise coordinates (server) | Active response window + recovery/PDNA period defined per operation; then coarsen-in-place to P-code or delete | Secure deletion, logged |
| Photos | Same as precise coordinates; re-review blur before any retention extension | Secure deletion, logged |
| Pseudonymous IDs | Minimum needed for dedup/quality; then unlink | Logged |
| Aggregated/published outputs | Per coordination need; versioned | Withdraw from HDX if context shifts |
| Audit trail | Retained for accountability beyond operational data | Per UNDP records policy |

Destruction must include **all copies**: backups, replicas, analyst local downloads, and device caches.

---

## 9. Data-Subject Rights and Transparency

Even where consent is not the basis, transparency and rights apply (**Transparency** principle, [UN Principles 2018](https://unsceb.org/personal-data-protection-and-privacy-principles); [OCHA Data Responsibility & AAP guidance](https://www.unocha.org/publications/report/world/guidance-note-data-responsibility-and-accountability-affected-people-humanitarian-action)):

- **Privacy notice** in-app, in plain language and all supported languages, stating who the controller is, what is collected, why, the legal basis (vital/public interest), retention, and rights.
- **Right to object** to processing (consistent with the vital-interest basis per the [ICRC Handbook, Ch.3](https://www.cambridge.org/core/books/handbook-on-data-protection-in-humanitarian-action/legal-bases-for-personal-data-processing/DF71FB331569DA5B83B60DC925017278)).
- **Access / rectification / deletion** insofar as a pseudonymous ID allows a submitter to reference their own submissions; a feedback channel handles requests.
- **No solely-automated decisions** affecting individuals: a damage grade or model output must never, by itself, determine a person's assistance, return, or eligibility — a human analyst is always in the loop.

---

## 10. Residual Risk and Go/No-Go Decision

### 10.1 Residual risk

**Note:** this residual-risk reasoning assumes the §6–§9 controls are *all in place*. Since the last pass, MFA (TOTP), mobile certificate pinning, enforced DB-transit TLS (`sslmode=require`), and at-rest encryption of **photos + sensitive secrets** (AES-256-GCM) are now **[Implemented]**, alongside public-view coarsening + verified-only public reads. Several controls remain **[Planned]**, not yet built: **full-cluster / backup / device-cache** encryption at rest, on-device face/plate blur, and the automated retention/purge job. Until those land, the *current deployed* residual risk is **higher** than the target stated here.

With the mitigations in §6–§9 *fully applied*, individual-record risk drops to **Low–Medium** (on-device EXIF stripping + face/plate blur, minimisation, pseudonymity). In the **current build**, on-device blur is not yet implemented, so individual-record risk from photos of bystanders is currently **Medium–High** rather than the target Low–Medium. The **aggregate DII risk (R1)** and **host-government compulsion (R3)** remain the dominant residual risks at **Medium likelihood / High impact** because they are partly contextual and cannot be fully engineered away. They are reduced to an acceptable level only if coarsening is enforced by default everywhere outside the most restricted internal role (public/viewer reads: **[Implemented]**; precise geometry is still visible to all analyst roles, single least-privilege-role gating **[Planned]**), and if the hosting jurisdiction is chosen to minimise compulsion exposure.

### 10.2 Decision: **CONDITIONAL GO**

Beacon may be deployed once all of the following conditions are met and verified by the DPO:

| ID | Condition (must be satisfied before go-live) |
|---|---|
| **C1** | **Name the Data Controller and confirm the hosting jurisdiction**, with a documented data-sovereignty / government-request risk assessment for that jurisdiction (resolves the "TBD" gap; R3). |
| **C2** | **Default coordinate coarsening** enforced server-side for all Regional, Crisis, partner, and public/export views; precise geometry gated to a single least-privilege role with MFA and audit (R1, R4). *Status: public-view coarsening (~110 m) + verified-only public reads are **[Implemented]**; MFA (TOTP) is **[Implemented]** and available on analyst accounts; **[Planned]:** making MFA mandatory for the de-coarsen role and gating precise geometry to a single least-privilege role.* |
| **C3** | **Disclosure-control gate before any HDX publication** (sensitivity classification + small-count suppression; free text and photos excluded by default) (R1, R10). |
| **C4** | **On-device face/plate blur + blur-failure fallback** implemented (block/queue-for-review when detector confidence is low) and QA sampling in place (R2). *Status: **[Planned]** — neither the blur nor the fallback is implemented yet; only a boolean flag is stored.* |
| **C5** | **Documented retention & secure-destruction schedule**, including offline device-cache purge and remote wipe (R5, R9). *Status: schedule is **documented**; the automated retention/purge job, device-cache encryption, and remote wipe are **[Planned]**, not yet built.* |
| **C6** | **Data Incident Management SOP** adopted per the five-step OCHA model — notification, classification, treatment, closure, learning ([Data Incident Management guidance](https://centre.humdata.org/guidance-note-data-incident-management/)). |
| **C7** | **Privacy notice + right-to-object + feedback channel** live in all supported languages; explicit "help is never gated on data" policy communicated to field staff (§2.3, R8). |
| **C8** | **Purpose-limitation / no-function-creep policy** signed; any new purpose triggers a fresh DPIA (R6). |

If any of C1–C8 cannot be met, the decision reverts to **No-Go** for that deployment context.

---

## 11. Review Triggers

This DPIA must be re-performed or updated when any of the following occur (per [IASC Operational Guidance 2023](https://interagencystandingcommittee.org/sites/default/files/migrated/2023-04/IASC%20Operational%20Guidance%20on%20Data%20Responsibility%20in%20Humanitarian%20Action,%202023.pdf) and [OCHA Data Responsibility Guidelines](https://www.unocha.org/publications/report/world/data-responsibility-guidelines-october-2021)):

- A **new country / crisis context** deployment (context drives the sensitivity of DII and the compulsion risk).
- A **change of controller or hosting jurisdiction**.
- A **new data element** collected, or any new export/recipient, or any **new purpose** (function creep).
- A **change in conflict/displacement dynamics** that raises re-identification harm.
- Any **data incident** affecting Beacon data.
- Introduction of any **automated decisioning or analytics** on individuals.
- Otherwise, **at minimum annually**.

---

## 12. Sources

- OCHA Data Responsibility Guidelines (2021) and (2025): https://www.unocha.org/publications/report/world/data-responsibility-guidelines-october-2021 ; https://centre.humdata.org/the-ocha-data-responsibility-guidelines/
- IASC Operational Guidance on Data Responsibility in Humanitarian Action (2023): https://interagencystandingcommittee.org/sites/default/files/migrated/2023-04/IASC%20Operational%20Guidance%20on%20Data%20Responsibility%20in%20Humanitarian%20Action,%202023.pdf
- ICRC / Brussels Privacy Hub, Handbook on Data Protection in Humanitarian Action (2nd ed.), Ch. 3 "Legal bases for Personal Data Processing": https://www.cambridge.org/core/books/handbook-on-data-protection-in-humanitarian-action/legal-bases-for-personal-data-processing/DF71FB331569DA5B83B60DC925017278 ; full handbook: https://www.icrc.org/en/data-protection-humanitarian-action-handbook
- UN Personal Data Protection and Privacy Principles (2018): https://unsceb.org/personal-data-protection-and-privacy-principles
- OCHA Guidance Note: Data Incident Management: https://centre.humdata.org/guidance-note-data-incident-management/
- OCHA Guidance Note: Data Responsibility and Accountability to Affected People: https://www.unocha.org/publications/report/world/guidance-note-data-responsibility-and-accountability-affected-people-humanitarian-action
- Centre for Humanitarian Data — Glossary (DII, sensitive data): https://centre.humdata.org/glossary/
- HDX — Improving the management of sensitive data on HDX: https://centre.humdata.org/improving-the-management-of-sensitive-data-on-hdx/
- OCHA Tip Sheet on Data Security in OCHA Data Management: https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/a23b2ace-0a1a-41d5-9e22-becfd1bc8c7b/download/tip-sheet-on-data-security-in-ocha-data-management.pdf
