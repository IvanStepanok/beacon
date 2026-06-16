# Beacon — Data Retention & Destruction Schedule

**Document type:** Deployment governance, Data Responsibility
**System:** Beacon (UNDP crisis building-damage crowdsourcing platform)
**Owner:** Data Controller (to be named per deployment, see §8) / Data Protection Focal Point
**Status:** Baseline schedule for review and adoption by the deploying Country Office, in consultation with the Regional Bureau and Crisis Bureau
**Version:** 1.0, 2026-06-05
**Review cycle:** Every 6 months while a response is active; otherwise annually, and on any change of purpose, controller, or hosting arrangement.

> **⚠️ Implementation status (honesty pass).** This schedule is the **target** retention/destruction regime for a production deployment; it is **documented policy, not yet implemented in code.** Specifically, in the current build: there is **no encryption at rest** (DB, object store, backups, or device cache; `pgcrypto` is used only for `gen_random_uuid()`), and there is **no automated retention/purge job** (the partition-DROP purge described in `../LOAD-TEST.md` is validated at scale but not wired to a live job). Because **Cryptographic Erase presupposes encryption at rest** (§5), crypto-shredding is **not operable today.** It becomes available only once at-rest encryption and the purge orchestration are built (both are **[Planned]** pre-deployment conditions in the DPIA, §10). Treat every "encrypted" / "crypto-shred" / "purge job" statement below as the **intended** control. Authoritative build state: `../STATUS.md`.

---

## 1. Purpose and scope

This schedule defines, for each category of data that Beacon collects, processes, derives, or caches, **how long it is kept, what triggers the retention clock, where it lives, and how it is destroyed**. It is a binding control, not a recommendation: no Beacon data may be retained beyond the periods below without a documented, time-bound extension authorised under §7.

The schedule operationalises the **retention principle** of the *UN Personal Data Protection and Privacy Principles* (HLCM, 2018), which provides that **"personal data should only be retained for the time that is necessary for the specified purposes"** ([UN System Chief Executives Board, 2018](https://unsceb.org/personal-data-protection-and-privacy-principles)). It also gives effect to the **data minimization** and **purpose specification / use limitation** principles in the same instrument, and to the data lifecycle obligations in the **IASC Operational Guidance on Data Responsibility in Humanitarian Action (2023)**, which expressly treats "retention and destruction" as managed steps of the data management cycle ([IASC, 2023](https://emergency.unhcr.org/sites/default/files/2023-11/IASC%20Operational%20Guidance%20on%20Data%20Responsibility%20in%20Humanitarian%20Action,%202023.pdf)).

### 1.1 The specified purpose Beacon retention is measured against

Beacon exists to support **rapid, evidence-based assessment of building damage during and immediately after a crisis**, feeding situational awareness, response prioritisation, and Post-Disaster Needs Assessment (PDNA) products. Retention is therefore anchored to the **operational lifetime of the response**, not to the indefinite value the data might one day have. This matters because the **aggregate set of geolocated damage reports is Demographically Identifiable Information (DII)**: it reveals *where affected people are concentrated*, and so carries a re-identification and targeting risk that grows, not shrinks, the longer it is held in granular form. Consistent with the *OCHA Data Responsibility Guidelines* ([2021](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/60050608-0095-4c11-86cd-0a1fc5c29fd9/download/ocha-data-responsibility-guidelines_2021.pdf) / [2025](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/8bc5b848-8ece-4f1f-a78b-18dd972bb21a/download/data-responsibility-guidelines-2025.pdf)) and the *ICRC Handbook on Data Protection in Humanitarian Action, 2nd ed.* ([ICRC/Brussels Privacy Hub, 2020](https://www.icrc.org/en/data-protection-humanitarian-action-handbook)), this schedule **prohibits the indefinite storage of geotagged photographs** and requires that any data kept beyond the response be either destroyed or irreversibly transformed into a non-identifiable form.

### 1.2 Definitions of destruction methods used in the tables

Destruction methods reference **NIST SP 800-88, *Guidelines for Media Sanitization*** ([NIST](https://csrc.nist.gov/pubs/sp/800/88/r2/final)):

- **Cryptographic Erase / crypto-shredding:** destroy the encryption key(s) protecting the data so that the ciphertext is permanently unrecoverable. This is Beacon's default method for object storage, database columns, and device caches, because it is fast, verifiable, and works even where the underlying cloud/disk blocks cannot be physically overwritten.
- **Purge:** logical or physical sanitisation that defeats laboratory-level recovery (block erase, cryptographic erase, degaussing).
- **Clear:** overwrite/factory reset that defeats simple recovery; acceptable only for low-sensitivity caches as an interim measure.
- **Destroy:** physical destruction of media (shredding/incineration); used for decommissioned servers and any removable backup media.
- **Anonymisation/irreversible transformation:** for derived aggregates, coarsening to administrative P-code level and suppressing small cells such that no individual record or location cluster can be reconstructed. Where this is genuinely irreversible, the output ceases to be personal data and falls outside the retention clock for personal data.

---

## 2. Master retention & destruction table

All periods are **maximums**. Where a shorter period suffices for the purpose, the shorter period governs. "Response close-out" means the formal stand-down of the Beacon deployment for a given crisis, recorded by the Data Controller.

| # | Data type | Default retention (max) | Retention trigger (clock starts) | Storage location | Secure destruction method (NIST SP 800-88) |
|---|---|---|---|---|---|
| 1 | **Raw photographs** (EXIF-stripped on-device **[Implemented]**; face/plate blur **[Planned]**, not yet built) | **180 days** from verification, **or** response close-out, **whichever is sooner** | Submission accepted server-side / report marked verified | Encrypted object storage (server-side encryption, per-object keys); thumbnails in DB-adjacent cache | **Cryptographic Erase** of the per-object/per-tenant key, plus storage-layer purge of the object; CDN/thumbnail cache invalidated and purged. Destruction logged to audit trail (#5). |
| 2 | **Geolocation (raw GPS lat/long)** | **Not retained at full precision past ingest**, converted to an admin **area code** (geoBoundaries shapeID) at ingestion; raw coordinates held ≤ **30 days** only for QA de-duplication, then purged | Ingestion timestamp | PostGIS geometry column (raw); admin-area attribute (derived) | Raw geometry column overwritten/nulled and the column's encryption key rotated (**Cryptographic Erase**); admin-area code retained per row #6/#7 rules. |
| 3 | **Admin-area codes (reverse-geocoded; geoBoundaries shapeIDs / seed codes — official OCHA COD P-codes on roadmap)** | Tied to the report record (#1) for operational data; **retained in coarsened aggregates** per #7 | Same as parent report | PostgreSQL/PostGIS (operational DB) | Deleted with parent report record; surviving copies exist only as coarsened aggregate (#7). |
| 4 | **Free-text notes (optional)** | **90 days** from verification, or response close-out, whichever is sooner (*shorter than photos because free text carries the highest unintended-PII and protection risk*) | Submission accepted / verified | Encrypted DB text column | **Cryptographic Erase** (column-level key rotation) + row-level delete; redacted/flagged notes purged immediately on flag. |
| 5 | **Submitter pseudonymous ID** | **Lifetime of the linked reports + 30 days**, then severed | Last linked report enters its destruction window | Encrypted DB column; salt/pepper in KMS | Severance by destroying the ID→device salt mapping (**Cryptographic Erase** of salt), rendering remaining reports fully anonymous. ID never re-linked. |
| 6 | **Audit logs** (verification actions, RBAC events, deletions) | **Response close-out + 24 months** (accountability/forensics window), then destroy | Action recorded | Append-only, integrity-protected audit store (write-once); offline encrypted backup | **Cryptographic Erase** of the audit store keyset at end of window; backup media **Purged** or physically **Destroyed**. Logs themselves contain no photos and minimal PII (actor role + report ref). |
| 7 | **Exports / derived aggregates** (GeoJSON, CSV-HXL, GeoPackage, Shapefile; incl. any HDX publication) | **Public/shared aggregates: indefinite only if irreversibly anonymised** (P-code-coarsened, small-cell-suppressed). **Granular internal exports: 90 days** or response close-out | Generation timestamp / publication date | Analyst workstations, shared drives, HDX (if published) | Granular exports: **Cryptographic Erase** + recall from any shared location, logged. Public aggregates: retained only after passing the §5 anonymisation gate; otherwise withdrawn from HDX and deleted. |
| 8 | **Offline on-device cache** (queued submissions, draft notes, cached photos, cached map tiles, local pseudonymous ID) | **Purged on successful sync; hard cap 7 days** if sync fails; **immediate purge on logout/uninstall/role removal** | Cache write time / successful upload ACK | Encrypted app sandbox on the field device (KMP app) | App-managed **Cryptographic Erase**: per-item keys destroyed on sync-ACK; full cache key destroyed on logout/uninstall. Remote wipe command available for lost/seized devices (see §6). |

---

## 3. How retention ties back to the specified purpose

The periods above are deliberately keyed to **operational utility, not archival ambition**, in line with the UN retention principle ("only…for the time that is necessary for the specified purposes," [UNSCEB, 2018](https://unsceb.org/personal-data-protection-and-privacy-principles)) and IASC data-minimization expectations ([IASC, 2023](https://interagencystandingcommittee.org/operational-response/iasc-operational-guidance-data-responsibility-humanitarian-action)):

- A **verified damage report's** decision value is largely consumed within the first weeks of a response and is fully captured once it has fed situational picture and PDNA inputs. Holding the **raw geotagged photo** beyond that adds DII/targeting risk with no proportionate purpose, hence the 180-day cap and the rule against indefinite photo storage (§1.1).
- **Raw GPS precision** is needed only to place a report on the map and de-duplicate; once a **P-code** is assigned, full-precision coordinates are surplus and are purged (#2). This is data minimization applied at the field level.
- **Free text** is the least structured and most likely to leak unintended personal or protection-sensitive details, so it is purged first (#4).
- **Anonymous aggregates** (#7) can serve long-term reconstruction/PDNA needs *without* personal data, which is why they, and only they, once they pass the §5 gate, may persist after a response.

This is the mechanism by which Beacon avoids "collect once, keep forever": the personal and DII-bearing layers expire; the value is preserved in a non-identifiable form.

---

## 4. Purging offline on-device caches (field devices)

Field devices are the highest-exposure surface: they may be lost, confiscated at checkpoints, or operate in areas where the **host government could demand access** (a data-sovereignty risk flagged in the OCHA Guidelines and ICRC Handbook). The cache rules (#8) therefore err strongly toward minimisation:

1. **Default state is empty.** The cache exists only to bridge intermittent connectivity. Each queued item is encrypted under a per-item key; on receipt of a server upload-ACK, that key is destroyed (**Cryptographic Erase**) and the plaintext item is gone from the device.
2. **Hard 7-day cap on unsynced items.** If a device cannot sync, queued submissions are crypto-shredded after 7 days regardless, to prevent stale damage-location data accumulating on a vulnerable device.
3. **Event-driven purge.** Logout, uninstall, or **RBAC revocation** triggers destruction of the cache master key, instantly rendering all cached photos, notes, P-codes, and the local pseudonymous ID unrecoverable.
4. **Remote wipe.** For a reported lost/stolen/seized device, the Controller can issue a remote command that destroys the cache key on next connectivity; the audit trail (#6) records the issuance.
5. **No silent map-tile residue.** Cached basemap/map tiles are non-personal but are cleared with the cache to avoid revealing which areas a responder was working in.

This satisfies the IASC requirement to manage **destruction** as an explicit step of the data cycle, including data held outside central servers ([IASC, 2023](https://emergency.unhcr.org/sites/default/files/2023-11/IASC%20Operational%20Guidance%20on%20Data%20Responsibility%20in%20Humanitarian%20Action,%202023.pdf)).

---

## 5. Crypto-shredding (cryptographic erasure): the primary destruction method

Beacon uses **Cryptographic Erase as defined in NIST SP 800-88** ([NIST](https://csrc.nist.gov/pubs/sp/800/88/r2/final)) as its default because, in cloud and mobile environments, you cannot reliably overwrite every physical block (replication, wear-levelling, snapshots, CDN copies). Destroying the key destroys access to *all* copies at once.

**Implementation requirements:**

- **Per-tenant and per-object keys.** Photos, free-text columns, and the submitter-ID salt each have their own key material held in a Key Management Service (KMS / HSM-backed), separate from the data.
- **Destruction = key destruction + tombstone.** When a record reaches its window, the orchestration job destroys the relevant key(s), writes a deletion tombstone, invalidates derived caches/CDN copies, and records the event in the audit trail (#6).
- **Backups and snapshots are in scope.** Backup encryption keys are rotated/destroyed on the same schedule so that crypto-shredded data cannot be resurrected from a backup. Backup retention may **never exceed** the retention of the data it contains plus one backup cycle.
- **Verification.** Each destruction job emits a signed completion record (what, when, method, operator/role). Crypto-shred is only valid if encryption was correctly applied at rest; Beacon's security-by-design baseline (encryption at rest + in transit, least-privilege RBAC) is therefore a precondition for this control. **This precondition is currently UNMET:** RBAC is implemented, but encryption at rest is **[Planned], not yet built**, so crypto-shred is not yet an operable destruction method. The destruction-job orchestration itself is also **[Planned]** (no purge job exists in code).

Where media is decommissioned (server retirement, removable backup), Beacon escalates from Cryptographic Erase to **Purge** or physical **Destroy** per NIST SP 800-88, with a certificate of destruction retained.

---

## 6. Data incidents and emergency destruction

If a device is seized or a breach occurs, the destruction controls above interact with incident response. Beacon follows the five-step model of the **OCHA Guidance Note on Data Incident Management** (*notification, classification, treatment, closure, and learning*) ([Centre for Humanitarian Data](https://centre.humdata.org/guidance-note-data-incident-management/)):

- **Emergency crypto-shred / remote wipe** is a permitted "treatment" action and may be executed *ahead of* normal retention windows to contain harm.
- All emergency destructions are logged (#6) and feed the post-incident "learning" step.
- A confirmed compromise of DII (e.g., exfiltration of granular damage-location data) is treated as a high-severity incident given the targeting risk to affected populations.

---

## 7. Post-response: archival vs deletion

At **response close-out**, the Controller runs a documented disposition review (mirroring the OCHA "retain, publish, transfer, or responsibly dispose" decision tool, [OCHA 2021/2025](https://centre.humdata.org/the-ocha-data-responsibility-guidelines/)). Each category is dispositioned as follows:

| Category | Default disposition at close-out |
|---|---|
| Raw photos (#1) | **Destroy** (crypto-shred). Never archived in identifiable form. |
| Raw GPS (#2) | Already purged; nothing to archive. |
| Free text (#4) | **Destroy.** |
| Submitter ID (#5) | **Sever** (anonymise remaining records). |
| Operational DB rows (#1/#3) | **Destroy** after deriving anonymised aggregates. |
| Audit logs (#6) | **Archive** in integrity-protected store for the close-out + 24-month accountability window, then destroy. |
| Anonymised aggregates (#7) | **Archive / may publish** *only* after passing the anonymisation gate below. |

**Anonymisation gate for any data kept or published after a response:** outputs must be coarsened to **P-code level** with **small-cell suppression**, contain **no raw coordinates, no photos, no free text, and no submitter IDs**, and pass a re-identification review against the DII risk (no publishable raw location clusters). This is the *only* route by which Beacon-derived data persists indefinitely, and it persists as **non-personal, non-DII** information, never as raw geolocated reports. Any extension of a personal-data retention period beyond this schedule requires written, time-bound, purpose-justified authorisation from the Controller, recorded in the audit trail and re-reviewed at expiry.

---

## 8. Roles, accountability, and data-subject rights

- **Named Controller required before go-live.** Hosting/controller is currently TBD; this schedule cannot operate without a named Controller (deploying Country Office or designated UNDP entity) who owns disposition decisions and authorises any extension. This reflects the *accountability* principle of the UN Principles and the OCHA Guidelines' insistence on a named, responsible data controller.
- **Data-subject rights interaction.** A valid request to **delete** (erase) a submitter's data is executed by crypto-shredding the linked reports (#1/#4) and severing the submitter ID (#5) ahead of schedule, and is logged (#6). Rights of **access / rectification / objection** are supported through the in-app feedback channel. Consistent with the *OCHA Guidance Note on Data Responsibility and Accountability to Affected People* ([OCHA](https://www.unocha.org/publications/report/world/guidance-note-data-responsibility-and-accountability-affected-people-humanitarian-action)), these channels must be accessible and gender/child-sensitive, and **help is never gated on data retention**: a deletion request never withdraws assistance.
- **Consent caveat.** Because valid consent is generally unattainable in crises, Beacon does not rely on consent as the lawful basis for retention; it relies on the vital/public-interest basis recognised in the ICRC Handbook and IASC Guidance, which makes disciplined retention limits *more* important, not less.

---

## 9. Source standards

- UN System Chief Executives Board for Coordination — *Personal Data Protection and Privacy Principles* (2018), incl. the **Retention** principle. https://unsceb.org/personal-data-protection-and-privacy-principles
- IASC — *Operational Guidance on Data Responsibility in Humanitarian Action* (2023; first ed. 2021). https://interagencystandingcommittee.org/operational-response/iasc-operational-guidance-data-responsibility-humanitarian-action
- OCHA / Centre for Humanitarian Data — *Data Responsibility Guidelines* ([2021](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/60050608-0095-4c11-86cd-0a1fc5c29fd9/download/ocha-data-responsibility-guidelines_2021.pdf), revised [2025](https://data.humdata.org/dataset/2048a947-5714-4220-905b-e662cbcd14c8/resource/8bc5b848-8ece-4f1f-a78b-18dd972bb21a/download/data-responsibility-guidelines-2025.pdf)).
- OCHA / Centre for Humanitarian Data — *Guidance Note: Data Incident Management*. https://centre.humdata.org/guidance-note-data-incident-management/
- OCHA — *Guidance Note: Data Responsibility and Accountability to Affected People in Humanitarian Action*. https://www.unocha.org/publications/report/world/guidance-note-data-responsibility-and-accountability-affected-people-humanitarian-action
- ICRC / Brussels Privacy Hub — *Handbook on Data Protection in Humanitarian Action*, 2nd ed. (2020). https://www.icrc.org/en/data-protection-humanitarian-action-handbook
- NIST — *SP 800-88, Guidelines for Media Sanitization* (Clear / Purge / Destroy; Cryptographic Erase). https://csrc.nist.gov/pubs/sp/800/88/r2/final

> **Note on citations:** Quoted text for the UN Retention principle and the NIST sanitization method definitions was verified against the sources above. The OCHA and IASC PDFs are image/binary PDFs; their retention, data-cycle, and disposition provisions are cited from the official publication pages and the Centre for Humanitarian Data summaries. Reviewers should confirm exact paragraph references against the authoritative PDFs before adoption.