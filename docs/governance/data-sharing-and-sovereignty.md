# Beacon — Data sharing, sovereignty, and transparency

**Document owner:** Data Protection Focal Point / DPO (to be named per deployment, see §3.2). This draft prepared by RaccoonGang (solver) for UNDP review.
**Status:** Deployment governance; binding on all Beacon Country Office, Regional Bureau and Crisis Bureau deployments
**Version:** 1.0 · **Date:** 2026-06-05
**Applies to:** Beacon mobile app (community + field responder), analyst dashboard, and the Go/PostgreSQL+PostGIS backend and its exports (GeoJSON, CSV/HXL, GeoPackage, Shapefile, HDX publication)
**Companion documents:** Beacon Data Impact Assessment; RBAC & Security Standard; Retention & Destruction Schedule; Data Incident Management SOP.

---

## 1. Scope and purpose

This document governs how Beacon data leaves the system (to humanitarian partners, to the open data commons, and across jurisdictions) and what affected people are told and can demand about that data. It is one part of Beacon's data-responsibility framework and must be read with the Data Impact Assessment and the Retention & Destruction Schedule.

The starting premise is the central risk in Beacon's design: while an individual report is partly anonymized on-device (EXIF stripped **[Implemented]**, pseudonymous submitter ID **[Implemented]**; face/plate blur is **[Planned] — not yet built**, so faces in shot are currently stored unblurred), the aggregate dataset of geolocated damage reports is Demographically Identifiable Information (DII), "data that enables the identification of groups of individuals by demographically defining factors, such as ethnicity, gender, age, occupation, religion, or **location**" ([IASC Operational Guidance on Data Responsibility in Humanitarian Action, 2023, §"Key Terms"](https://interagencystandingcommittee.org/sites/default/files/migrated/2023-04/IASC%20Operational%20Guidance%20on%20Data%20Responsibility%20in%20Humanitarian%20Action,%202023.pdf)). A map of where buildings are damaged is, by construction, a map of where affected people are. DII can be sensitive non-personal data, data that "if disclosed or accessed without proper authorization, is likely to cause harm (such as sanctions, discrimination) to any person … or a negative impact on an organization's capacity to carry out its activities" (IASC OG 2023, "Sensitive Data"). Beacon therefore treats its aggregate dataset as sensitive by default and applies the controls below.

Governing standards (cited inline throughout):

- OCHA Data Responsibility Guidelines (October 2021; 2025 revision): [unocha.org](https://www.unocha.org/publications/report/world/data-responsibility-guidelines-october-2021) · [PDF](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/60050608-0095-4c11-86cd-0a1fc5c29fd9/download/ocha-data-responsibility-guidelines_2021.pdf)
- IASC Operational Guidance on Data Responsibility in Humanitarian Action (2023): [PDF](https://interagencystandingcommittee.org/sites/default/files/migrated/2023-04/IASC%20Operational%20Guidance%20on%20Data%20Responsibility%20in%20Humanitarian%20Action,%202023.pdf)
- ICRC Handbook on Data Protection in Humanitarian Action (2nd ed., 2020): [icrc.org](https://www.icrc.org/en/data-protection-humanitarian-action-handbook)
- UN Personal Data Protection and Privacy Principles (HLCM, 11 Oct 2018): [PDF](https://unsceb.org/sites/default/files/imported_files/UN-Principles-on-Personal-Data-Protection-Privacy-2018_0.pdf)
- OCHA Centre for Humanitarian Data, Guidance Note: Data Incident Management (2019): [centre.humdata.org](https://centre.humdata.org/guidance-note-data-incident-management/)
- OCHA Guidance Note: Data Responsibility and Accountability to Affected People in Humanitarian Action (2023): [unocha.org](https://www.unocha.org/publications/report/world/guidance-note-data-responsibility-and-accountability-affected-people-humanitarian-action)
- OCHA Centre for Humanitarian Data, Guidance Note: Statistical Disclosure Control (2019): [centre.humdata.org](https://centre.humdata.org/guidance-note-statistical-disclosure-control/)

---

## 2. Data Sharing Agreements (DSA) and the Information Sharing Protocol (ISP)

### 2.1 When a DSA is required

Per OCHA DR Guidelines 2021 (Action: *Establish Data Sharing Agreements*): "Establish data sharing agreements whenever sharing personal data or **sensitive non-personal data** with other organizations." Because Beacon's report-level and fine-grained aggregate data is sensitive DII, any bilateral or multilateral transfer of below-public-threshold Beacon data requires a signed DSA before a single byte moves. A DSA "establishes the terms and conditions that govern the sharing of specific personal data and sensitive non-personal data between two or more parties" (IASC OG 2023, §Tools).

| Beacon transfer | DSA required? | Notes |
|---|---|---|
| Report-level data (point coordinates, photos, notes) to any external party | **Yes — always** | Highest-sensitivity tier; default answer is *do not share*; DSA + DPO sign-off mandatory. |
| Sub-P-code or settlement-level aggregates to a cluster/OCHA | **Yes** | Below public threshold; treat as sensitive DII. |
| Admin-2/P-code-aggregated, re-identification-cleared dataset for HDX | No DSA, but a **publication record + open licence** | Governed by §3, not by bilateral DSA. |
| Internal transfer between Beacon roles (CO → Regional → Crisis Bureau) | No DSA (single controller) | Governed by RBAC + audit trail, not DSA. |

### 2.2 DSA checklist

Every Beacon DSA must address each item below. The checklist operationalizes the OCHA DSA template and the UN Transfers principle that the discloser must "satisfy itself that the third party affords appropriate protection for the personal data" (UN PDP Principle 9, *Transfers*, 2018).

- [ ] **Parties and roles:** named legal entities; who is controller, who is processor/recipient; named DPO contact on each side.
- [ ] **Data described precisely:** exact fields shared (e.g. *P-code, damage-grade counts, report timestamp band*), explicitly excluding fields not shared (raw lat/long, photos, submitter ID, free-text notes unless redacted).
- [ ] **Specified purpose + purpose limitation:** the single response purpose the data may serve (e.g. shelter-cluster caseload estimation); recipient may not reuse for any incompatible purpose (UN PDP Principle 2, *Purpose Specification*; IASC OG 2023, *Purpose Limitation*).
- [ ] **Legal/legitimate basis:** the basis Beacon relies on (vital/public interest, see §6.2), recorded explicitly; never recorded as "consent" for crisis data.
- [ ] **Sensitivity classification of the shared data:** the tier from §2.4 and the handling rules that attach to it.
- [ ] **Onward-sharing prohibition:** recipient may not re-share to any fourth party without Beacon's written authorization.
- [ ] **Security obligations:** encryption in transit and at rest, access control, the requirement that the recipient affords protection at least equivalent to Beacon's (UN PDP Principle 7, *Security*; Principle 9, *Transfers*).
- [ ] **Re-identification prohibition:** recipient must not attempt to re-identify individuals or groups, nor combine the data with other datasets to do so.
- [ ] **Retention and destruction:** how long the recipient may hold the data and certified secure destruction on expiry (IASC OG 2023, *Retention and Destruction*; UN PDP Principle 4, *Retention*).
- [ ] **Data incident / breach obligations:** recipient must notify Beacon's DPO within a defined window of any suspected incident; "Where the data incident constitutes a personal data breach, obligations established in the relevant data protection framework and in applicable data sharing agreements need to be adhered to" (IASC OG 2023, §Data incident management).
- [ ] **Government-request / compelled-disclosure clause:** recipient must notify Beacon and assert applicable privileges before responding to any third-party or government demand (see §4.3).
- [ ] **Audit and accountability:** Beacon may audit compliance; both parties keep records (UN PDP Principle 10, *Accountability*).
- [ ] **Term, jurisdiction/dispute resolution, and signatures:** with UNDP privileges and immunities preserved (see §4.2).
- [ ] **Internal sign-off:** drafted jointly by the responsible analyst lead and the information-management focal point, reviewed by the DPO/Legal before signing (mirrors OCHA's requirement to "consult OCHA's Executive Office to review data sharing agreements before signing", DR Guidelines 2021).

### 2.3 Information Sharing Protocol (ISP)

Where Beacon operates inside a coordinated response, it adopts (or contributes to) the system-wide Information Sharing Protocol, "the primary document of reference governing data and information sharing in the response," which "should include a context-specific Data and Information Sensitivity Classification … as well as a recommended approach for sharing different types of data" (IASC OG 2023, §Tools). Beacon's deployment ISP records: the data Beacon holds, its sensitivity classification (§2.4), who may receive each tier, under what instrument (DSA / open licence / none), and the named approver. The ISP is endorsed early in the response, not improvised mid-crisis (IASC OG 2023, *Prioritizing the establishment of an ISP at the outset*).

### 2.4 Beacon Data & Information Sensitivity Classification

Sensitivity is contextual: "the same types of data may have different levels of sensitivity in different contexts and sensitivity may change over time" (IASC OG 2023, "Sensitive Data"). The table is the default for a typical Beacon crisis deployment and **must be re-assessed per context** (e.g. in a conflict where damage location reveals a targeted group, even P-code aggregates may rise to HIGH).

| Tier | Beacon data | Default handling | Sharing instrument |
|---|---|---|---|
| **SEVERE** | Raw photos before/without on-device blur; precise coordinates tied to a single building + a vulnerable group; submitter identity if ever de-pseudonymized | Do not export. Never leaves device/secured store. | None — prohibited |
| **HIGH** | Report-level records (point lat/long, damage grade, timestamp, notes, photo — note: face/plate blur is **[Planned]**, not yet built, so a stored photo may contain unblurred faces) | Internal, least-privilege RBAC only; export only under DSA with strong justification | DSA + DPO sign-off |
| **MODERATE** | Sub-P-code / settlement or grid aggregates; small-cell counts | Trusted operational partners with need-to-know | DSA |
| **LOW** | P-code (admin-2 or coarser) aggregated damage-grade counts that pass the re-identification check (§3) | Shareable with humanitarian partners | DSA or open licence |
| **NONE / PUBLIC** | Admin-2+ aggregates, re-identification-cleared, no small cells | Publishable openly | Open licence (§3) |

---

## 3. Open publication: only de-identified, P-code-aggregated data (HDX)

### 3.1 The rule

> **Beacon publishes openly only de-identified data aggregated to P-code (administrative) level that has passed a documented re-identification check. Beacon never publishes raw or sub-aggregate location clusters (no point coordinates, no settlement-level "hot-spot" tables, no individual reports, no photos, no free-text notes) to HDX or any other open channel.**

This implements the principle that aggregate DII is sensitive and that publication must not enable re-identification of individuals **or groups** (IASC OG 2023, *Personal Data Protection*; OCHA DR Guidelines 2021, *Open Data*). The on-device anonymization that protects an individual report does **not** make the aggregate safe to publish; geographic clustering re-creates identifiability at the group level. P-code coarsening is therefore the load-bearing public-release control, not an optional nicety.

### 3.2 Re-identification check before every release

No dataset is published until the **release gate** below is completed and signed. This applies statistical disclosure control as required by OCHA: aggregate/anonymized data may be retained and shared only where "a re-identification assessment is conducted" (OCHA DR Guidelines 2021, *Retention and Destruction*).

1. **Aggregate to the publication unit.** Reduce all geometry to the P-code polygon (admin-2 or coarser). Drop point coordinates, sub-P-code grids, building IDs, photos, raw timestamps (publish a coarse period, not exact times), submitter IDs and free-text notes.
2. **Apply statistical disclosure control (SDC).** Assess disclosure risk and suppress or recode small cells. Beacon adopts the Centre for Humanitarian Data threshold for open HDX data: no record should violate 3-anonymity, i.e. no published combination of attributes (P-code × damage grade × any other dimension) may identify fewer than 3 underlying units; small cells are suppressed or further aggregated ([Centre for Humanitarian Data, Statistical Disclosure Control](https://centre.humdata.org/guidance-note-statistical-disclosure-control/)). In conflict or targeted-violence contexts, raise the threshold and/or coarsen further.
3. **Mosaic / linkage test.** Confirm the release cannot be combined with other public data (election rolls, census, prior Beacon releases, satellite layers) to re-identify a group or a sparsely populated locality. Time-series releases are checked against earlier ones to prevent differencing attacks.
4. **Sensitivity re-confirmation.** Reconfirm the dataset is genuinely NONE/PUBLIC for *this* context (§2.4), not merely in the abstract.
5. **Sign-off.** The analyst lead and the DPO co-sign the release record. The record (dataset, fields, aggregation level, SDC method, residual-risk note, approvers, date) is written to the **immutable audit trail** alongside the publication.

### 3.3 Open licence and HDX metadata

Published Beacon datasets carry an explicit open licence and HDX sensitivity metadata, and are tagged as derived/aggregated (not microdata). The **immutable audit trail** records every publication so any later recall (see §3.4) is traceable.

### 3.4 Recall and re-assessment

If new information shows a published release is re-identifiable in context (e.g. the crisis becomes a conflict and damage maps now endanger a group), the release is withdrawn from HDX, the withdrawal is logged in the audit trail, and partners holding copies are notified per their DSAs. Public-but-still-sensitive data is reassessed on a schedule, consistent with the requirement that sensitivity "is reassessed on a regular basis" (IASC OG 2023, *Retention and Destruction*).

---

## 4. Data sovereignty and hosting

### 4.1 Jurisdiction-aware hosting

Beacon's hosting decision is a data-responsibility decision, not just an engineering one, because the aggregate dataset reveals where affected people are. For each deployment the DPO documents, before go-live:

- the physical/legal **jurisdiction(s)** where Beacon data (PostgreSQL/PostGIS primary, backups, object storage for photos, and any cloud subprocessor) will reside;
- the **legal exposure** that follows from that jurisdiction (which government could compel disclosure, and under what law);
- whether the controller benefits from **UN/UNDP privileges and immunities** in that jurisdiction (§4.2) or whether a **local operator** without such protection is in the chain (§4.2);
- the **data-localization** laws of the affected state and whether they require in-country hosting, balanced against the risk that in-country hosting increases host-government access.

Hosting in a jurisdiction with weak rule-of-law or a party-to-the-conflict government is itself a risk to be assessed and mitigated, not assumed away.

### 4.2 UNDP privileges and immunities vs. a local operator

As a UN entity, UNDP enjoys privileges and immunities under the Convention on the Privileges and Immunities of the United Nations (1946), which means national and regional data-protection legislation generally **does not apply to UNDP** and its premises/archives/data are **inviolable**. UN bodies instead bind themselves to their own data-protection policies and the UN Personal Data Protection and Privacy Principles. OCHA states the equivalent for itself: as part of the UN Secretariat it "enjoys privileges and immunities which entail that national and regional legislation on the handling of data do not apply," and it must instead "manage personal data in accordance with … the Personal Data Protection and Privacy Principles" (OCHA DR Guidelines 2021, Annex B, notes 53–55).

The critical corollary: privileges and immunities protect data only while it sits under the UN entity's legal control. The moment Beacon data is hosted by, processed by, or accessible to a local operator, NGO partner, or commercial cloud provider that does not enjoy those immunities, that party **is** subject to local law and can be compelled by the host government. Therefore:

| Arrangement | Immunity status | Required mitigation |
|---|---|---|
| UNDP-controlled hosting / UNDP-administered infrastructure | Covered by P&I | Maintain UN custody and inviolability; bind to UN PDP Principles |
| Commercial cloud subprocessor | **Not covered** | Encryption with UNDP-held keys; data-residency clause; compelled-disclosure-notification clause; DSA/contract; subprocessor due diligence (§5) |
| Local operator / national partner | **Not covered** | Minimize what they can access (ideally only LOW/PUBLIC tiers); contractual protections; routing of any government request to UNDP DPO |

Where immunity does not cover the host, Beacon reduces the value of any compelled disclosure through encryption (UNDP-controlled keys), strict P-code coarsening of anything that party can reach, and least-privilege RBAC.

### 4.3 Written government-request / compelled-disclosure policy

Beacon maintains a standing, written policy (not an ad-hoc reaction) for any request, demand, subpoena, or informal pressure from a government or third party to hand over Beacon data. The policy is binding on all roles and is referenced in every DSA (§2.2) and hosting contract (§4.2).

1. **Route, do not respond.** No analyst, field staff member, or operator answers a government data request directly. Every request is immediately escalated to the **named UNDP Controller and DPO** and to UNDP Legal.
2. **Assert privileges and immunities.** Where the data is under UNDP control, UNDP asserts its privileges and immunities and the inviolability of its data; disclosure, if any, is a decision for UNDP alone, not the host government.
3. **Apply data-responsibility tests before any disclosure.** Even when UNDP could lawfully disclose, it weighs the request against humanitarian principles, the risk to affected people and groups (the DII risk), purpose limitation, and the "do no harm" obligation. The default answer to a demand for **report-level / SEVERE-HIGH** data is **refuse**.
4. **Compel notification through the chain.** Subprocessor and local-operator contracts require the party to **notify UNDP before responding** to any legal demand and to assert UNDP's interest, so UNDP can intervene.
5. **Minimize the surface.** Because compelled disclosure cannot always be prevented when a non-immune party is in the chain, Beacon limits what such parties can hold or reach (encryption, key custody, P-code coarsening, RBAC).
6. **Log everything.** Every request, the decision, the legal basis, and the outcome is recorded in the **immutable audit trail** and reported to UNDP senior management. Affected communities are informed of the *practice* of resisting compelled disclosure in the transparency notice (§6), consistent with transparency obligations (UN PDP Principle 8).

---

## 5. Transfer due diligence to third parties

Before Beacon shares data with any cluster, OCHA, a PDNA process, a donor, or a cloud subprocessor, the DPO completes a transfer due-diligence assessment. The controlling rule is the UN Transfers principle: a UN entity may transfer personal data to a third party only where it "satisfies itself that the third party affords appropriate protection for the personal data" (UN PDP Principle 9, 2018). The same standard is applied to sensitive non-personal DII.

| Recipient type | Typical Beacon data | Due-diligence focus | Instrument |
|---|---|---|---|
| **Cluster lead / OCHA** (coordination) | LOW/MODERATE aggregates | Recipient ISP & sensitivity classification; need-to-know; onward-sharing controls | DSA, aligned to system-wide ISP (§2.3) |
| **PDNA process** (recovery costing) | Aggregated damage counts (P-code level) | Purpose limitation to PDNA; re-identification prohibition; retention/destruction at PDNA close | DSA |
| **Cloud / IT subprocessor** | Whatever the platform technically stores | Data residency (§4.1); encryption + key custody; **no immunity → compelled-disclosure clause**; security certification; subprocessor list | Contract + DSA terms |
| **Donor** | PUBLIC aggregates only, by default | Donors generally receive only published/aggregate outputs; never report-level data ([OCHA GN #7: Responsible Data Sharing with Donors](https://www.unocha.org/publications/report/world/centre-humanitarian-data-guidance-note-series-data-responsibility-humanitarian-action-5)) | Open output / DSA if any non-public data |
| **HDX / open public** | NONE/PUBLIC only | Full §3 release gate | Open licence, no DSA |

Common due-diligence checks across all transfers:

- [ ] Recipient has a stated lawful/legitimate basis and a compatible purpose (no incompatible reuse; UN PDP Principle 2).
- [ ] Recipient affords protection **at least equivalent** to Beacon's (UN PDP Principle 9); if not, the transfer is reduced in tier or refused.
- [ ] Onward-sharing is contractually controlled; re-identification is prohibited.
- [ ] Data minimization: transfer the **least** data and the **coarsest** geography that meets the purpose (UN PDP Principle 3, *Proportionality and Necessity*).
- [ ] Retention limit and certified destruction defined (UN PDP Principle 4).
- [ ] Breach-notification and government-request-notification obligations are in the instrument (§2.2, §4.3).
- [ ] Subprocessor's own subprocessors are disclosed and bound (flow-down).
- [ ] The transfer, its basis and its approver are written to the immutable audit trail (UN PDP Principle 10, *Accountability*).

---

## 6. In-app transparency notice, data-subject rights, and Accountability to Affected People

### 6.1 Plain-language, localized transparency notice

Beacon must "uphold data subjects' rights to be informed, in an easily accessible and appropriate manner, about the processing of their personal data" (IASC OG 2023, *Personal Data Protection*) and carry out processing "with transparency to the data subjects" (UN PDP Principle 8). Beacon presents a **plain-language transparency notice in-app, before first submission**, in all **6 supported languages with full RTL support**, written for low literacy and avoiding legal/technical jargon (OCHA Guidance Note: Data Responsibility and Accountability to Affected People, 2023). The notice is reachable at any time from the app menu, not just at onboarding.

The notice tells the user, in concrete terms:

- **What is collected:** a photo (with metadata/EXIF removed *on your device* before anything is sent **[Implemented]**), your location, a damage rating, an anonymous ID, and any note you choose to add. *(Automatic on-device face / licence-plate blurring is **[Planned] — not yet built**; until it ships the notice must NOT promise that faces are blurred; instead advise users to photograph structures, not people.)*
- **Why:** to help responders understand where buildings are damaged so help can be directed, and that this is the *only* purpose the data is used for (purpose limitation; UN PDP Principle 2).
- **That help is never conditioned on submitting data.** Using Beacon is voluntary; choosing not to submit, or asking to delete a submission, will **never** reduce a person's access to assistance. This reflects that in crises consent is usually not a valid basis and assistance must not be gated on data sharing (see §6.2).
- **Who can see it:** Beacon analysts (CO / Regional Bureau / Crisis Bureau) under role-based access; and that only **coarse, area-level (P-code) summaries** (never your exact location or photo) are ever published openly.
- **How long it is kept** and that it is securely destroyed afterwards (link to the Retention & Destruction Schedule).
- **The user's rights** and exactly **how to exercise them** (§6.3), and **how to give feedback or complain** (§6.4).
- **A safety note:** advising users not to photograph people, identifying documents, or themselves in a way that could put them at risk, and noting that submitting in some situations may carry personal risk.

### 6.2 Lawful/legitimate basis, and why consent is not the basis

Beacon does **not** rely on consent as its primary lawful basis for processing crisis data. "Humanitarian organizations may not be in a position to rely on consent for all personal data processing" (IASC OG 2023, note 20), and consent is frequently **not freely given or fully informed** in a crisis: people under duress, in fear, or in urgent need cannot give the free, specific, informed consent that consent doctrine requires ([ICRC Handbook on Data Protection in Humanitarian Action, 2nd ed.](https://www.icrc.org/en/data-protection-humanitarian-action-handbook)). Beacon instead relies on **vital interest / public interest** grounds consistent with the controller's humanitarian mandate: "Legitimate grounds for data management include … the best and/or vital interests of communities and individuals affected by crisis, consistent with the organization's mandate; public interest in furtherance of the organization's mandate" (IASC OG 2023, *Fair and Legitimate*); UN PDP Principle 1 lists "the best interests of the data subject" and the organization's mandate among equally valid bases alongside consent. Relying on vital/public interest is also why assistance must never be gated on submitting data: the basis is the affected population's interest, not a transaction with the individual.

### 6.3 Data-subject rights (access / rectify / delete / object)

Even though consent is not the basis, "data subject rights ensure the agency and involvement of individuals with regards to how their personal data is processed" (IASC OG 2023, note 20). Beacon supports all four rights, designed around its pseudonymous submitter ID (the device-held identifier that lets a person reach their own submissions without Beacon ever knowing their real-world identity).

| Right | How Beacon delivers it |
|---|---|
| **Access** ("be informed" + see one's data) | In-app: a user can view their own submissions tied to their pseudonymous ID; the transparency notice (§6.1) explains processing in plain language. |
| **Rectify** (correct) | A user can correct an erroneous submission (e.g. wrong damage grade or note); the change is captured in the **immutable audit trail** so the record's history is preserved. |
| **Delete / erase** | A user can request deletion of their submission, including **purging the offline cache on their own device** and a request to remove it server-side, subject to lawful retention limits (§7). Deletion of an open *aggregate* already published is honored by recall/re-aggregation per §3.4. |
| **Object** (to processing) | A user can object to / stop processing of their submissions; objecting never affects access to assistance (§6.1, §6.2). |

Rights are exercised through accessible in-app controls **and** the human feedback channel (§6.4) for users who cannot use the app interface. Per UN PDP Principle 8, rights are honored "insofar as the specified purpose … is not frustrated," and any limitation is documented.

### 6.4 Accountability to Affected People (AAP)

Beacon implements the IASC Commitments on Accountability to Affected People (2017) as carried into data responsibility (IASC OG 2023, *People-Centered and Inclusive*; OCHA Data Responsibility & AAP Guidance Note, 2023):

- **Feedback and complaint channel.** A two-way feedback/complaint mechanism is built in (in-app, with a non-app fallback such as a hotline/focal point recorded in the notice), so affected people can ask questions, raise concerns, exercise rights (§6.3), and flag harm. Feedback is logged and routed to a responsible human; loops are closed back to communities where possible.
- **Accessible, inclusive UX in 6 languages + RTL.** All user-facing text (notice, rights controls, feedback channel) is localized in the 6 supported languages with full RTL rendering, designed for low-literacy and low-connectivity users, consistent with "leave no one behind."
- **Gender and child sensitivity.** The transparency notice and safety guidance flag the heightened risks for women, children, and marginalized groups (e.g. not photographing children, not capturing identifying features); data is analyzed with age/sex/disability disaggregation only where it serves the purpose and does not increase identifiability (IASC OG 2023, *Quality*); child data receives extra protection.
- **No solely-automated decisions about people.** Beacon's automated components (e.g. damage-grade suggestions, clustering, prioritization) **inform** human analysts; they never make a final decision affecting a person or community without meaningful human review. This implements the data subject's right "to not be subject to automated decision-making except under the specific conditions set out in the legal frameworks applicable to an organization" (IASC OG 2023, *Personal Data Protection*).

---

## 7. Retention, destruction, and offline device caches

Open here because sharing and publication are entangled with how long data lives. Beacon maintains a **retention and destruction schedule** that "indicates how long data will be retained and when data should be destroyed, as well as how to do so in a way that renders data retrieval impossible" (IASC OG 2023, *Retention and Destruction*; UN PDP Principle 4). Sensitive (HIGH/SEVERE) report-level data is kept only as long as necessary for the response purpose and then securely destroyed; NONE/PUBLIC aggregates may persist subject to periodic sensitivity re-assessment and a documented re-identification check (§3.2). The schedule explicitly covers **offline caches on field and community devices**. Beacon is offline-first, so unsynced reports sitting on phones are an exposure that the schedule and the in-app delete control (§6.3) must address through encryption-at-rest, sync-then-purge, and remote/local cache clearing.

---

## 8. Roles, sign-off, and audit

- **UNDP Controller:** named accountable controller for each deployment; owner of the compelled-disclosure decision (§4.3).
- **DPO:** owns this document, the release gate (§3.2), DSAs (§2.2), transfer due diligence (§5), and incident response.
- **Analyst leads (CO / Regional / Crisis Bureau):** co-sign releases and DSAs; operate under least-privilege RBAC.
- **IM / engineering:** implement P-code coarsening, SDC, encryption, key custody, RBAC, and the immutable audit trail that records every share, publication, government request, and rights action (UN PDP Principle 10, *Accountability*; IASC OG 2023, *Security*).

Every sharing, publication, withdrawal, government request, and data-subject-rights action under this document is written to Beacon's **immutable audit trail**, making the framework auditable end-to-end.

---

### Sources

- OCHA, *Data Responsibility Guidelines* (October 2021): [unocha.org](https://www.unocha.org/publications/report/world/data-responsibility-guidelines-october-2021) · [PDF](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/60050608-0095-4c11-86cd-0a1fc5c29fd9/download/ocha-data-responsibility-guidelines_2021.pdf); 2025 revision [PDF](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/8bc5b848-8ece-4f1f-a78b-18dd972bb21a/download/data-responsibility-guidelines-2025.pdf)
- IASC, *Operational Guidance on Data Responsibility in Humanitarian Action* (2023): [PDF](https://interagencystandingcommittee.org/sites/default/files/migrated/2023-04/IASC%20Operational%20Guidance%20on%20Data%20Responsibility%20in%20Humanitarian%20Action,%202023.pdf)
- ICRC, *Handbook on Data Protection in Humanitarian Action* (2nd ed., 2020): [icrc.org](https://www.icrc.org/en/data-protection-humanitarian-action-handbook)
- UN HLCM, *Personal Data Protection and Privacy Principles* (2018): [PDF](https://unsceb.org/sites/default/files/imported_files/UN-Principles-on-Personal-Data-Protection-Privacy-2018_0.pdf) · [unsceb.org](https://unsceb.org/privacy-principles)
- OCHA Centre for Humanitarian Data, *Guidance Note: Data Incident Management* (2019): [centre.humdata.org](https://centre.humdata.org/guidance-note-data-incident-management/)
- OCHA Centre for Humanitarian Data, *Guidance Note: Statistical Disclosure Control* (2019): [centre.humdata.org](https://centre.humdata.org/guidance-note-statistical-disclosure-control/)
- OCHA, *Guidance Note: Data Responsibility and Accountability to Affected People in Humanitarian Action* (2023): [unocha.org](https://www.unocha.org/publications/report/world/guidance-note-data-responsibility-and-accountability-affected-people-humanitarian-action)
- OCHA Centre for Humanitarian Data, *Guidance Note #7: Responsible Data Sharing with Donors*: [unocha.org](https://www.unocha.org/publications/report/world/centre-humanitarian-data-guidance-note-series-data-responsibility-humanitarian-action-5)
