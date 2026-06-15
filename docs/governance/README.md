# Beacon — Data Responsibility & Governance

Deployment-grade data-responsibility documentation for Beacon, grounded in the OCHA Data Responsibility Guidelines, the IASC Operational Guidance on Data Responsibility (2023), the ICRC Handbook on Data Protection in Humanitarian Action, and the UN Personal Data Protection & Privacy Principles (2018). These are **go-live prerequisites** for a real UNDP deployment — not optional polish — because the aggregate dataset of geolocated damage reports is Demographically Identifiable Information (DII).

| Document | Purpose |
|---|---|
| [DPIA.md](DPIA.md) | Data Protection Impact Assessment — purpose & legal basis (vital/public interest, not consent), data inventory, data-flow, risk table, conditional go/no-go, review triggers. |
| [retention-and-destruction.md](retention-and-destruction.md) | Retention period + secure destruction method per data type, incl. purging offline device caches and crypto-shredding. |
| [data-controller-and-breach-response.md](data-controller-and-breach-response.md) | Named controller, RBAC role→permission matrix, security-by-design controls, and the data-incident response SOP. |
| [data-sharing-and-sovereignty.md](data-sharing-and-sovereignty.md) | Data Sharing Agreement + Information Sharing Protocol, P-code-only public release, sovereignty/government-request policy, transfer due diligence, transparency notice & data-subject rights (AAP). |

The core principle running through all four: **the aggregate is sensitive even when every individual record is anonymised** — never publish raw location clusters; coarsen to P-code for any external view; gate fine-grained geolocation behind least-privilege RBAC. See also the system-level [OPERATIONAL-MODEL.md](../OPERATIONAL-MODEL.md).
