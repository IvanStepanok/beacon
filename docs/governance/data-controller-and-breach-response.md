# Beacon — Data Controller, Roles & Breach/Incident Response

**Document type:** Deployment governance (data responsibility)
**System:** Beacon — UNDP crisis building-damage crowdsourcing platform (mobile reporter app + analyst dashboard + Go / PostgreSQL/PostGIS backend)
**Status:** Governance baseline for deployment review
**Date:** 2026-06-05
**Owner:** Data Controller (to be named per deployment — deploying UNDP Country Office / designated entity). This draft prepared by RaccoonGang (solver) for UNDP review.

---

## 1. Purpose and scope

This document defines, for the Beacon platform: (a) the **named data controller** and the accountability split between the UNDP Crisis Bureau and the deploying Country Office (CO); (b) the **role-to-permission matrix** (RBAC) and the data-access scope of each role; (c) the **security-by-design controls** that protect Beacon data in transit, at rest and in use; and (d) a step-by-step **Data Incident Response Standard Operating Procedure (SOP)** covering detection, containment, assessment, notification, remediation and learning, including **internal misuse**.

Beacon collects and processes: building-damage photographs (EXIF stripped **on-device** before upload **[Implemented]**; on-device face blur **[Implemented]** — ML Kit on Android, Apple Vision on iOS; licence-plate redaction best-effort, with a blur-failure fallback and server-side re-check **[Planned]**, see §5.1); GPS location reverse-geocoded to administrative **P-codes**; a 3-level damage grade; an anonymous/pseudonymous submitter identifier; and optional free-text notes. Critically, **the aggregate dataset of geolocated damage reports is Demographically Identifiable Information (DII)** — "data that enables the identification of groups of individuals by demographically defining factors, such as ethnicity, gender, age, occupation, religion, or **location**" ([OCHA Data Responsibility Guidelines, October 2021](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/60050608-0095-4c11-86cd-0a1fc5c29fd9/download/ocha-data-responsibility-guidelines_2021.pdf), §Definitions). A dense cluster of damage reports reveals where affected, often displaced, people are. Beacon therefore treats its aggregate location dataset as **sensitive data**, "data that is likely to lead to harm when exposed" (ibid.), regardless of the fact that individual reports are pseudonymous.

This document is grounded in and should be read alongside:

- [OCHA Data Responsibility Guidelines (October 2021)](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/60050608-0095-4c11-86cd-0a1fc5c29fd9/download/ocha-data-responsibility-guidelines_2021.pdf) and the [2025 update](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/8bc5b848-8ece-4f1f-a78b-18dd972bb21a/download/data-responsibility-guidelines-2025.pdf)
- [IASC Operational Guidance on Data Responsibility in Humanitarian Action (2023)](https://interagencystandingcommittee.org/sites/default/files/migrated/2023-04/IASC%20Operational%20Guidance%20on%20Data%20Responsibility%20in%20Humanitarian%20Action,%202023.pdf)
- [OCHA Guidance Note: Data Incident Management (Centre for Humanitarian Data, Aug 2019)](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/51949711-43d0-4c08-accc-109154510ef6/download/guidancenote2_dataincidentmanagement.pdf)
- [UN Personal Data Protection and Privacy Principles (2018)](https://unsceb.org/sites/default/files/imported_files/UN-Principles-on-Personal-Data-Protection-Privacy-2018_0.pdf)
- [ICRC Handbook on Data Protection in Humanitarian Action, 2nd ed.](https://www.icrc.org/en/publication/430501-handbook-data-protection-humanitarian-action-second-edition) ([full text PDF](https://rm.coe.int/handbook-data-protection-and-humanitarian-action-low/168076662a))
- [OCHA Guidance Note: Statistical Disclosure Control](https://centre.humdata.org/guidance-note-statistical-disclosure-control/)
- [OCHA Guidance Note: Data Responsibility and Accountability to Affected People](https://www.unocha.org/publications/report/world/guidance-note-data-responsibility-and-accountability-affected-people-humanitarian-action)

---

## 2. Governing principles (the rules every control below must satisfy)

Beacon's controls implement, and must remain consistent with, the ten [UN Personal Data Protection and Privacy Principles (2018)](https://unsceb.org/sites/default/files/imported_files/UN-Principles-on-Personal-Data-Protection-Privacy-2018_0.pdf): **Fair and Legitimate Processing; Purpose Specification; Proportionality and Necessity; Retention; Accuracy; Confidentiality; Security; Transparency; Transfers; and Accountability.** The following points are load-bearing for this document:

1. **Legitimate basis is the mandate / vital and public interest, not consent.** The UN Principles list legitimate bases as "(i) the consent of the data subject; (ii) the best interests of the data subject…; (iii) the mandates and governing instruments of the United Nations System Organization concerned; or (iv) any other legal basis" (UN Principles 2018, Principle 1 — *Fair and Legitimate Processing*). The ICRC Handbook is explicit that **in emergencies consent is frequently *invalid*** because it cannot be freely given or fully informed, "in particular… where consenting to the Processing of Personal Data is a precondition to receive assistance," and that processing "may often be based on vital interest or on important grounds of public interest" ([ICRC Handbook, Ch. 3 — Legal bases](https://www.cambridge.org/core/books/handbook-on-data-protection-in-humanitarian-action/legal-bases-for-personal-data-processing/DF71FB331569DA5B83B60DC925017278)). **Consequence for Beacon:** the platform must **never gate humanitarian assistance on whether a person submits a report**, and consent must not be the recorded legal basis. Beacon processes on the basis of UNDP's mandate and the vital/public interest in rapid, accurate post-crisis damage assessment.
2. **Aggregate DII is sensitive and must never be published as raw clusters.** Public and external outputs must be coarsened to an administrative P-code level determined by Statistical Disclosure Control (SDC); raw point geometry and tight clusters are not exported externally ([OCHA SDC Guidance Note](https://centre.humdata.org/guidance-note-statistical-disclosure-control/) — re-identification "by combining answers to different questions, even after anonymisation is applied").
3. **Data minimization and purpose limitation** (Principles 2 and 3): Beacon collects only what is necessary for damage assessment; on-device anonymization (EXIF stripping **[Implemented]**; face blur **[Implemented]** via ML Kit / Apple Vision; licence-plate redaction best-effort) is the first minimization control.
4. **No solely-automated decisions about people.** Any AI-assisted damage grade is decision *support*; a human validator confirms the grade, and no eligibility, targeting or enforcement decision about an individual is made automatically.
5. **Security by design and Accountability** (Principles 7 and 10): a **named controller**, least-privilege RBAC, encryption, an immutable audit trail, documented retention, and a tested incident SOP are mandatory.
6. **Data sovereignty / host-government request risk.** Because Beacon's dataset reveals where affected populations are, it is attractive to parties who may wish to harm them. Hosting location, controllership and any disclosure to a host government must be governed by UNDP privileges and immunities and a documented disclosure-decision process (Section 4.4).

---

## 3. Named data controller and accountability

### 3.1 Controllership model

Beacon uses a **two-tier controller model** mirroring the platform's own role hierarchy (Country Office → Regional Bureau → Crisis Bureau). This reflects the IASC principle that data responsibility must be assigned at the level where data management decisions are actually made ([IASC Operational Guidance 2023](https://interagencystandingcommittee.org/sites/default/files/migrated/2023-04/IASC%20Operational%20Guidance%20on%20Data%20Responsibility%20in%20Humanitarian%20Action,%202023.pdf)).

| Function | Accountable body | Role |
|---|---|---|
| **System / platform data controller** | **UNDP Crisis Bureau** | Controller of the Beacon platform as a system: sets the global data-protection policy, the RBAC model, the retention schedule, the encryption and key-management standard, and this incident SOP. Owns the platform-level risk acceptance, the HDX/external-release policy, and any decision to disclose data to a host government. Designates the platform **Data Protection Focal Point (DPFP)**. |
| **Deployment / operational data controller** | **UNDP Country Office (CO) of the affected country** | Controller for a specific crisis deployment: determines the lawful basis in-context, runs the in-country Data Protection Impact Assessment (DPIA), approves which validators/analysts get accounts, sets context-specific sensitivity (e.g. whether ethnicity/location combinations are dangerous in that conflict), operates the feedback channel to affected people, and is first responder for in-country incidents. Designates the deployment **Data Steward**. |
| **Joint processing / coordination** | **Regional Bureau** | Acts on delegated authority; provides regional oversight, surge support to the CO during incidents, and is the escalation tier between CO and Crisis Bureau. Not an independent controller. |
| **Processors** | Hosting provider, any third-party service | Bound by a written data-processing agreement that flows down the controls in this document, including breach-notification timelines (Section 6). No processor may use Beacon data for any secondary purpose (echoing the DIM example of "use of 'anonymised' beneficiary data for non-humanitarian purposes" as a data incident — [DIM Guidance Note](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/51949711-43d0-4c08-accc-109154510ef6/download/guidancenote2_dataincidentmanagement.pdf)). |

### 3.2 Split of responsibilities

| Decision / duty | Crisis Bureau (system controller) | Country Office (deployment controller) | Regional Bureau |
|---|---|---|---|
| Global policy, RBAC schema, retention schedule, key-management standard | **Owns** | Implements | Oversees |
| Lawful basis in context; DPIA for the deployment | Reviews | **Owns** | Endorses |
| Account approval & periodic access recertification | Sets standard | **Approves CO/field accounts** | Approves RB analyst accounts |
| Context sensitivity classification (which fields are dangerous here) | Reviews | **Owns** | Advises |
| External release / HDX publication & SDC sign-off | **Final approval** | Proposes & runs SDC | Reviews |
| Host-government disclosure request | **Decides** (with UNDP Legal) | Escalates immediately, does not respond unilaterally | Escalates |
| Incident command (see Section 6) | **Incident Owner** for High/major incidents | **First responder & local IC** | Surge support / IC for cross-country incidents |
| Notifying affected people & partners | Approves comms | **Executes** locally via AAP feedback channel | Coordinates |

### 3.3 Named accountable roles (to be filled at deployment)

- **Platform Data Protection Focal Point (DPFP)** — Crisis Bureau. Accountable owner of this document and the incident register.
- **Deployment Data Steward** — Country Office. Day-to-day data responsibility lead and local incident first responder.
- **Security Lead** — Crisis Bureau ICT/security. Owns encryption, keys, logging, and technical containment.
- **AAP / Community Engagement Focal Point** — Country Office. Owns the feedback channel and data-subject-rights intake.

> Names, titles and 24/7 contact details for each role are recorded in **Annex A — Incident Contact Card** and must be reviewed at the start of every deployment and after any staff rotation.

---

## 4. RBAC role → permission matrix

Beacon enforces **least privilege** (UN Principle 7 — *Security*): each role receives the minimum data access required for its task, and the **aggregate raw-location dataset (DII) is the most tightly held asset.** Geographic scope is enforced by P-code: a role can only see data inside the admin areas assigned to it.

### 4.1 Roles and data-access scope

| Role | Who | Can read | Can write / do | Location granularity | Cannot |
|---|---|---|---|---|---|
| **Community reporter** | Affected community member (mobile app), anonymous/pseudonymous | Only their **own** submissions and status | Create a report (photo + damage grade + GPS + optional note); withdraw their own report | Sees only own report location | See other people's reports, any map of clusters, any dashboard, any other user's data |
| **Field validator** | Vetted field responder (mobile app) | Reports **within their assigned P-code area**, for verification | Confirm/correct damage grade; mark verified/rejected; add validation note | Point-level **only within their assigned area** | See reports outside assigned area; bulk-export; edit RBAC; see submitter identity beyond pseudonym |
| **CO analyst** | Country Office staff (dashboard) | All reports **within their CO's country/admin areas**; point geometry for verification and triage | Verify, triage, annotate, run **internal** exports (audited); hand verified ground truth off to responders' own tasking systems (Beacon does not run dispatch) | Point-level, **own country only** | Access other countries' data; approve external/HDX release; change global policy or keys |
| **Regional Bureau analyst** | Regional Bureau staff (dashboard) | Reports across **countries in their region**, default **aggregated to P-code**; point-level only with documented operational need | Regional analysis, cross-country comparison, surge support | P-code aggregate by default; point-level by exception (audited) | Approve external release alone; administer accounts outside delegation; access other regions |
| **Crisis Bureau admin** | Crisis Bureau platform admin | All data, all regions; system configuration and audit logs | Manage RBAC, retention jobs, keys (split duty — see 5.4), **approve external/HDX releases after SDC**, run incident command | Full, but external publication forced through **SDC coarsening** | Be the sole party to publish (requires SDC sign-off + four-eyes); silently alter the audit trail (immutable) |
| **External read-only consumer** | Partner agency, donor, public (HDX) | **Only published, SDC-processed, P-code-coarsened aggregates** (GeoJSON / CSV-HXL / GeoPackage / Shapefile) | Read/download published products | **Coarsened to safe admin level only** — never raw points or tight clusters | Access raw reports, photos, submitter IDs, free-text notes, or any non-published data |

### 4.2 Principles encoded in the matrix

- **Reporters and validators are kept off the cluster map.** Only a clustered/aggregated picture of where affected people are is itself DII; exposing it to broad accounts would defeat the protection. (OCHA Data Responsibility Guidelines 2021: aggregate DII is sensitive.)
- **Geographic scoping** means a compromise of a CO account cannot leak another country's data.
- **The external boundary is hard.** Everything an external consumer sees has passed Statistical Disclosure Control and been coarsened to a P-code level signed off by the Crisis Bureau. Re-identification "by combining answers to different questions, even after anonymisation is applied" is the risk SDC mitigates ([OCHA SDC Guidance Note](https://centre.humdata.org/guidance-note-statistical-disclosure-control/)).
- **Photos and free-text notes never leave the internal tier.** They are not part of any external product.
- **No solely-automated decisions:** an AI-suggested damage grade is always confirmed by a human field validator before it is treated as verified.

### 4.3 Access lifecycle

- Accounts are **provisioned by the relevant controller** (CO for field/CO roles; Crisis Bureau for admin), are **role-based not person-based in capability**, and are **time-boxed to the deployment**.
- **Quarterly access recertification** and **immediate de-provisioning on staff rotation/separation.** Stale accounts are a primary internal-misuse vector.
- All grants/changes are written to the immutable audit trail (Section 5.3).

### 4.4 Data sovereignty / host-government requests

No role, including Crisis Bureau admin, may unilaterally hand Beacon data to a host government or third party. Any such request is **escalated to the Crisis Bureau DPFP and UNDP Legal**, assessed against UNDP privileges and immunities and the Do-No-Harm test, logged, and decided centrally. This protects the affected populations whose locations the dataset reveals (OCHA Data Responsibility Guidelines 2021; UN Principle 9 — *Transfers*, which requires that any transfer afford "appropriate protection").

---

## 5. Security-by-design controls

Implements UN Principle 7 (*Security*), "Appropriate organizational, administrative, physical and technical safeguards… to protect the security of personal data, including against… unauthorized or accidental access, damage, loss," and the IASC 2023 expectation of security commensurate with sensitivity.

### 5.1 Encryption

> **Implementation status (honesty pass).** This section is the **target** security baseline for production. In the current build the following are **[Implemented]**: TLS at the edge, on-device EXIF stripping, on-device face blur (ML Kit on Android / Apple Vision on iOS), enforced DB-transit TLS (`sslmode=require`, fail-closed in prod), mobile certificate pinning (ISRG roots X1+X2, Android + iOS), MFA (TOTP, RFC 6238) on analyst accounts, and at-rest AES-256-GCM encryption of **report photos + the stored TOTP secret**. Still **[Planned] — not yet built**: full-cluster / backup / device-cache encryption at rest, a managed KMS/vault for key custody, and a trained licence-plate detector + blur-failure fallback + server-side anonymisation re-check, which are binding pre-deployment conditions. Tags below: **[Implemented]** / **[Partial]** / **[Planned]**. Authoritative build state: `docs/STATUS.md`.

| Layer | Control | Status |
|---|---|---|
| **In transit** | TLS at the edge (Traefik + Let's Encrypt) for all app↔backend and dashboard↔backend traffic; HSTS. Certificate pinning in the mobile app and enforced DB-transit TLS to resist interception in hostile-network field conditions. | **[Implemented]** — edge TLS; backend↔DB runs `sslmode=require` (fail-closed in prod); mobile certificate pinning to ISRG roots X1+X2 on Android (OkHttp SPKI) and iOS (Ktor/Darwin cert-DER) |
| **At rest (server)** | Full-disk/volume encryption plus database-level encryption for PostgreSQL/PostGIS; photo blobs encrypted at rest in object storage with server-side encryption. | **[Partial]** — report photos + the stored TOTP secret are sealed with **AES-256-GCM** (app-layer, `DATA_ENCRYPTION_KEY`, prod-required); **[Planned]:** full-cluster PostgreSQL/PostGIS + backup encryption (`pgcrypto` is present only for `gen_random_uuid()`) |
| **At rest (device)** | The mobile app stores its offline submission queue and cached map tiles in an encrypted local store; the queue is purged after confirmed upload. Offline device caches are explicitly in scope for secure destruction (Section 5.6) because a seized or lost device is a realistic threat (cf. the DIM scenario of armed actors "seizing hard-drives… [that] were unencrypted" — [DIM Guidance Note](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/51949711-43d0-4c08-accc-109154510ef6/download/guidancenote2_dataincidentmanagement.pdf)). | **[Planned] — NOT implemented.** Cache purge after sync is Implemented; **cache encryption is not** |
| **On-device anonymization** | EXIF metadata is stripped **[Implemented]** before any image leaves the device. On-device face blur runs before upload **[Implemented]** (ML Kit on Android, Apple Vision on iOS). Licence-plate redaction is best-effort (heuristic); a low-confidence blur-failure fallback and a server-side anonymisation re-check are **[Planned]**, so a face missed by the detector could still be transmitted. | **[Implemented]** — EXIF strip + on-device face blur; plate redaction best-effort |

### 5.2 Least privilege

- RBAC (Section 4) is the primary access control; service accounts and DB roles follow the same principle (the API service connects with a least-privilege DB role; analytics/export run under separate scoped roles).
- **Separation of duties:** the person who can run an external export cannot also approve its publication; SDC sign-off and publication are split.
- Network segmentation: database and object storage are not internet-exposed; admin interfaces require VPN/bastion and MFA. *(VPN/bastion is **[Planned]**; **MFA (TOTP) is [Implemented]** and available on analyst accounts.)*

### 5.3 Immutable audit trail (existing safeguard, formalized)

Beacon's **audit trail of verification and task changes (RBAC + audit FKs, actor from token) is [Implemented]**. Its **planned extension** to a full data-responsibility audit log (hash-chained tamper-evidence + the additional event types below) is **[Planned] — not yet built**.

The audit trail records, with actor, timestamp, role and target:

- Every report verification, grade change and task assignment — **[Implemented]**.
- Every **read of point-level data outside a role's default scope**, every **bulk export**, and every **external/HDX publication** (so internal misuse, e.g. an analyst exporting clusters they have no operational need for, is detectable) — **[Planned]**.
- Every RBAC grant/change, retention/destruction job, and key-management action — **[Planned]** (depends on the retention job and key management, which are themselves Planned).

This directly supports detection of **internal misuse** and is the evidentiary backbone of the incident SOP (Section 6).

### 5.4 Key management

> **[Partial].** At-rest encryption of photos + the TOTP secret uses a single 32-byte `DATA_ENCRYPTION_KEY` supplied via environment (prod-required, never in source). **[Planned] — NOT yet implemented:** a managed KMS/vault, automated key rotation, and split control / dual custody.

- Encryption keys are held in a managed **Key Management Service / vault**, never in source code or config.
- **Split control / dual custody** for master keys (no single admin holds full key authority).
- Documented **key rotation** schedule and emergency rotation procedure (invoked during containment, Section 6.2).
- Access to keys is itself logged to the audit trail.

### 5.5 Additional hardening

- MFA for dashboard and admin accounts — **[Implemented]** (TOTP, RFC 6238: enrol/verify/disable, encrypted secret, login gate). Making it **mandatory** for every dashboard/admin account is a deployment-policy toggle (**[Planned]** to enforce org-wide).
- Server-side validation re-checks that uploaded images are anonymized; rejects non-conforming payloads — **[Planned]** (the on-device blur pipeline ships today; the server-side re-validation of it does not yet).
- Dependency and vulnerability scanning in CI; least-privilege container/runtime.
- Backups encrypted, access-controlled, and covered by the retention schedule and incident SOP.

### 5.6 Retention and secure destruction (UN Principle 4 — *Retention*)

- A **documented retention schedule** ties each data category to the purpose and the deployment lifecycle; data is "only… retained for the time that is necessary for the specified purposes" (UN Principles 2018, Principle 4). The OCHA Data Responsibility Guidelines call for explicit policies on the "Retention and Destruction" of data ([2021 Guidelines](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/60050608-0095-4c11-86cd-0a1fc5c29fd9/download/ocha-data-responsibility-guidelines_2021.pdf)).
- **Photos and free-text notes** (highest-sensitivity, lowest-reuse) have the shortest retention and are destroyed once the damage grade is verified and the PDNA cycle no longer needs them.
- **Secure destruction** uses cryptographic erasure (key destruction) plus deletion, and covers **offline device caches**, backups, and any processor copies (flowed down by the processing agreement).
- Destruction events are logged to the immutable audit trail.

---

## 6. Data Incident Response SOP

This SOP is built on the [OCHA Guidance Note: Data Incident Management](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/51949711-43d0-4c08-accc-109154510ef6/download/guidancenote2_dataincidentmanagement.pdf), which the OCHA Data Responsibility Guidelines require as an Advanced Preparedness Action ("develop a Standard Operating Procedure for Data Incident Management"). It also aligns with the [OCHA Guidance Note on Data Incident Management overview](https://centre.humdata.org/guidance-note-data-incident-management/).

### 6.1 Definitions

A **data incident** is an "event involving the management of data that [has] caused harm or [has] the potential to cause harm to crisis-affected populations, humanitarian organisations and their operations, and other individuals or groups" ([DIM Guidance Note](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/51949711-43d0-4c08-accc-109154510ef6/download/guidancenote2_dataincidentmanagement.pdf)). Crucially, **a data incident can occur without any technical breach**: e.g. publishing a correctly-collected dataset at too fine a geographic resolution can itself harm affected people.

Every incident is analyzed by its **four factors** (DIM Guidance Note): **(i) threat source, (ii) threat event, (iii) vulnerability, (iv) adverse impact.**

**Beacon-specific example incidents** (note that **internal misuse is explicitly in scope**):

| # | Source | Event | Vulnerability | Adverse impact |
|---|---|---|---|---|
| 1 | External attacker | Exfiltration of the reports database | Mis-scoped DB role / exposed service | Raw location clusters of affected people exposed |
| 2 | **Insider (authorized analyst)** | Bulk-exports point clusters and shares outside the operation | Over-broad export rights / no need-to-know enforcement | DII leaked to a party that can target displaced people |
| 3 | Operation itself | Publishes a GeoJSON product at building-point resolution to HDX | SDC step skipped / coarsening misconfigured | Public re-identification of where affected groups are |
| 4 | Armed actor | Seizes a field device | Lost/stolen device with un-purged offline queue | Cached reports and tasks exposed |
| 5 | Host authority | Demands the dataset | No central disclosure-decision process | Sovereignty/Do-No-Harm breach against affected people |

### 6.2 The six-phase lifecycle (mapping to the OCHA 5-step model)

The OCHA model defines five steps: **Notification, Classification, Treatment, Closure, and Knowledge base** ([DIM Guidance Note](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/51949711-43d0-4c08-accc-109154510ef6/download/guidancenote2_dataincidentmanagement.pdf)). Beacon expands these into a six-phase operational SOP, **Detect → Contain → Assess → Notify → Remediate → Learn**, without departing from the OCHA model: *Contain* and *Notify* are made explicit phases of OCHA's *Treatment* step, and *Learn* is OCHA's *Knowledge base* step.

| Beacon phase | OCHA step | What happens | Lead role | Target timeline |
|---|---|---|---|---|
| **0. Report/Detect** | Notification | Anyone (staff, validator, partner, or affected person via the feedback channel) reports a suspected incident; automated alerts from audit-trail anomalies (e.g. unusual bulk export) and monitoring also trigger here. Reporter records the four factors if known. | Whoever detects → **Deployment Data Steward** | **Report within 1 hour of detection** |
| **1. Contain** | Treatment | Contain before assessing fully: revoke/suspend the implicated account, rotate keys, take the affected export/endpoint offline, pull a wrongly-published HDX product, remote-wipe a lost device's queue if possible. Preserve the audit trail and evidence. | **Security Lead** + Data Steward | **Initial containment within 4 hours** of report |
| **2. Assess / Classify** | Classification | Classify by **impact (High / Medium / Low)** and **urgency of treatment (High / Medium / Low)** per the OCHA model; identify data categories, number of records, whether DII/photos/notes are involved, who is at risk, and whether harm is realized or potential. Assign Incident Owner by severity (CO Data Steward for Low/Medium; **Crisis Bureau DPFP for High/major**). | **Deployment Data Steward** (escalates to **Crisis Bureau DPFP** for High) | **Classification within 24 hours**; reassess as facts evolve |
| **3. Notify** | Treatment | Internal notification up the chain (CO → Regional Bureau → Crisis Bureau) per severity; notify affected people and partners where harm to them is possible, through the AAP feedback channel in accessible language; notify processors/host as required by agreement; notify UNDP Legal for any host-government or rights dimension. Notification "should contain… a description of the key risk factors involved: source, event, vulnerability and impact" (DIM Guidance Note). | **Incident Owner** + **AAP Focal Point** | **Internal escalation immediate for High; ≤24h for Medium.** Affected-people notification **without undue delay** once risk and message are confirmed |
| **4. Remediate / Treat** | Treatment | A technical expert "decides on the necessary measures to treat the incident" (DIM Guidance Note): fix the root-cause vulnerability (e.g. tighten the DB role, re-enable SDC enforcement, correct retention job), confirm data recovered/destroyed as appropriate, restore service safely, and for **internal misuse** trigger HR/conduct/access-revocation process. | **Security Lead** | Per agreed treatment time from classification (High: hours; Medium: days) |
| **5. Close** | Closure | "All information generated during the treatment is recorded and the person who first sent notification… is informed that the incident is closed" (DIM Guidance Note). Incident record finalized in the register. | **Incident Owner** | On verified remediation |
| **6. Learn** | Knowledge base | Post-incident review; update this SOP, RBAC, controls and the risk model; feed lessons into staff training and drills. Reporting culture is **"incentivized, not punished"** so incidents surface early (DIM Guidance Note). | **Crisis Bureau DPFP** | Review within **10 working days** of closure |

### 6.3 Severity classification grid

Classification combines impact and urgency (OCHA *Classification* step). Beacon weights any exposure of **DII (location clusters), photos, or free-text notes** as automatically **High impact**.

| Impact \ Urgency | Low urgency | Medium urgency | High urgency |
|---|---|---|---|
| **Low impact** (no sensitive data; contained internally) | Routine | Routine | Priority |
| **Medium impact** (limited internal exposure; pseudonymous IDs) | Priority | Priority | **Escalate to CB** |
| **High impact** (DII / cluster / photo / notes exposed, or affected people at risk) | **Escalate to CB** | **Escalate to CB** | **Major incident — Crisis Bureau IC** |

### 6.4 Notification duties (summary)

| Who is notified | When | By whom | Trigger |
|---|---|---|---|
| Deployment Data Steward | ≤1h of detection | Detector | Any suspected incident |
| Crisis Bureau DPFP | Immediate | Data Steward | Any **High/major** incident or DII exposure |
| Regional Bureau | ≤24h | Data Steward | Medium+; cross-country incidents |
| **Affected people / community** | Without undue delay, once risk confirmed | AAP Focal Point | Any incident posing potential harm to them |
| Partners / data-sharing recipients | Without undue delay | Incident Owner | Shared data affected |
| Processor / host | Per processing agreement | Security Lead | Processor-side incident |
| UNDP Legal | Immediate | Incident Owner | Host-government request, rights, or legal exposure |

### 6.5 Internal misuse — specific handling

Internal misuse (an authorized user exceeding need-to-know, exporting clusters, or sharing data improperly) is its own incident type. It is detected primarily through the **immutable audit trail** (out-of-scope reads, anomalous bulk exports). On confirmation: the account is suspended (Contain), the misuse is classified by the data at risk, affected people are notified if harmed, and the matter is referred to the appropriate conduct/HR/oversight process in addition to technical remediation. Consistent with OCHA guidance, the **reporting** of incidents is incentivized and not punished: sanction attaches to the *misuse*, not to good-faith reporting.

### 6.6 Preparedness

Per the [OCHA DIM recommendations](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/51949711-43d0-4c08-accc-109154510ef6/download/guidancenote2_dataincidentmanagement.pdf): maintain a current Beacon **risk model** (threat actors and vulnerabilities per office/system); keep this SOP and the **Annex A contact card** current; run **incident drills** at the start of each deployment using the scenarios in Section 6.1; and document every real incident as a case in the knowledge base.

---

## 7. Accountability to Affected People (AAP)

Per the [OCHA Guidance Note on Data Responsibility and Accountability to Affected People](https://www.unocha.org/publications/report/world/guidance-note-data-responsibility-and-accountability-affected-people-humanitarian-action): Beacon provides an **accessible feedback and complaints channel** (in the app's six supported languages, including RTL), supports **data-subject rights** to access, rectify, delete and object to the extent the humanitarian purpose is not frustrated (UN Principle 8 — *Transparency*), applies **gender- and child-sensitive** handling of imagery and notes, and **never conditions assistance on reporting**. The AAP Focal Point is the intake point for both rights requests and incident reports from communities (Sections 3.3 and 6.4).

---

## 8. Open items for the deployment review

- Confirm and name the **hosting provider and hosting jurisdiction**; execute the processor agreement with flow-down of Sections 5–6.
- Finalize the **retention periods** per data category with the CO and Crisis Bureau.
- Complete the in-context **DPIA** and the **context sensitivity classification** (which field combinations are dangerous in this crisis).
- Populate **Annex A — Incident Contact Card** with named individuals and 24/7 contacts.
- Configure and test **SDC coarsening** on the export pipeline before any external/HDX publication.

---

## Annex A — Incident Contact Card (template)

| Role | Name | Org unit | 24/7 contact | Backup |
|---|---|---|---|---|
| Platform Data Protection Focal Point | _TBD_ | Crisis Bureau | _TBD_ | _TBD_ |
| Deployment Data Steward | _TBD_ | Country Office | _TBD_ | _TBD_ |
| Security Lead | _TBD_ | Crisis Bureau ICT/Security | _TBD_ | _TBD_ |
| AAP / Community Engagement Focal Point | _TBD_ | Country Office | _TBD_ | _TBD_ |
| UNDP Legal contact | _TBD_ | Legal | _TBD_ | _TBD_ |

---

## Sources

- [UN Personal Data Protection and Privacy Principles (2018)](https://unsceb.org/sites/default/files/imported_files/UN-Principles-on-Personal-Data-Protection-Privacy-2018_0.pdf)
- [OCHA Data Responsibility Guidelines (October 2021)](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/60050608-0095-4c11-86cd-0a1fc5c29fd9/download/ocha-data-responsibility-guidelines_2021.pdf) · [2025 update](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/8bc5b848-8ece-4f1f-a78b-18dd972bb21a/download/data-responsibility-guidelines-2025.pdf)
- [IASC Operational Guidance on Data Responsibility in Humanitarian Action (2023)](https://interagencystandingcommittee.org/sites/default/files/migrated/2023-04/IASC%20Operational%20Guidance%20on%20Data%20Responsibility%20in%20Humanitarian%20Action,%202023.pdf)
- [OCHA Guidance Note: Data Incident Management (Centre for Humanitarian Data, 2019)](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/51949711-43d0-4c08-accc-109154510ef6/download/guidancenote2_dataincidentmanagement.pdf) · [overview](https://centre.humdata.org/guidance-note-data-incident-management/)
- [ICRC Handbook on Data Protection in Humanitarian Action, 2nd ed.](https://www.icrc.org/en/publication/430501-handbook-data-protection-humanitarian-action-second-edition) · [Ch. 3 — Legal bases](https://www.cambridge.org/core/books/handbook-on-data-protection-in-humanitarian-action/legal-bases-for-personal-data-processing/DF71FB331569DA5B83B60DC925017278)
- [OCHA Guidance Note: Statistical Disclosure Control](https://centre.humdata.org/guidance-note-statistical-disclosure-control/)
- [OCHA Guidance Note: Data Responsibility and Accountability to Affected People](https://www.unocha.org/publications/report/world/guidance-note-data-responsibility-and-accountability-affected-people-humanitarian-action)
