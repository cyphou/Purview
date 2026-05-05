# 🏛️ Purview Unified Catalog — Demo Tenant Automation

**Fully automated provisioning of a production-grade Microsoft Purview Unified Catalog demo environment via PowerShell + REST APIs.**

> 🎯 From zero to a boardroom-ready data governance demo in **< 30 minutes**, fully reproducible, fully idempotent.

---

## ✨ What This Deploys

| Layer | What you get | Count |
|-------|-------------|-------|
| 🏢 **Domain hierarchy** | 5 Lines of Business → 11 sub-domains | 16 domains |
| 📖 **Business glossary** | Published terms with owners, stewards, CDO contacts & acronyms | 75 terms |
| 📦 **Data products** | Endorsed, enriched DPs with docs, terms of use & business descriptions | 6 DPs |
| 🎯 **OKRs** | Objectives + Key Results with live progress tracking | 5 OKRs / 15 KRs |
| 🔑 **Critical Data Elements** | CDEs bridged to physical columns via CriticalDataColumns | 15 CDEs / 15 CDCs |
| 🏷️ **Custom metadata** | Named attribute groups scoped to DPs and terms | 3 groups / 11 attrs |
| 🔗 **Relationships** | Term↔term, DP↔term, CDE↔term, CDE↔CDC cross-links | 85+ relationships |
| 🟢🟡🟠 **Data quality tiers** | Atlas classification chips on every scanned asset | 85 assets tiered |
| 🔄 **Business processes** | Cross-domain process entities linked to app services | 5 processes |
| 👥 **Demo users** | Governance personas (CDO, DPO, owners, stewards) with role assignments | 15 users |

---

## 🏗️ Domain Architecture

```
💰 Finance and ESG
├── Accounting and Reporting        (7 terms · 1 DP)
├── Treasury and Risk               (4 terms)
└── ESG and Sustainability          (6 terms · 1 DP)

🤝 Customer and Sales
├── CRM and Customer Data           (6 terms · 1 DP)
└── Commercial Analytics            (5 terms)

👥 HR and People
├── Talent Management               (5 terms · 1 DP)
└── Workforce Analytics             (5 terms)

⚙️ Operations and Industrial
├── Industrial Assets               (7 terms · 1 DP)
└── Supply Chain and Logistics      (5 terms)

💻 Technology and Data Platform
├── Data Engineering                (5 terms)
└── BI and Analytics                (5 terms · 1 DP)
```

---

## 🚀 Quick Start

### Prerequisites

- PowerShell 7+
- Azure CLI (`az login` authenticated)
- Purview account with **Governance Domain Creator** + **Data Curator** roles
- `az account get-access-token --resource https://purview.azure.net` must succeed

### Full deployment (wipe + rebuild)

```powershell
# Nuclear option — tears down everything and redeploys from scratch
.\wipe_and_redeploy.ps1
```

### Sprint-by-sprint (incremental)

```powershell
# 1. Fix descriptions on existing objects
.\sprint1_fix_descriptions.ps1

# 2. Create domain hierarchy (5 LoBs + 11 sub-domains)
.\sprint2_domains_org.ps1

# 3. Populate glossaries (75 terms with contacts)
.\sprint3_glossary.ps1

# 4. Create and enrich data products
.\sprint4_data_products.ps1
.\enrich_data_products.ps1

# 5. Unified Catalog features (OKRs, CDEs, custom metadata)
.\sprint5_unified_catalog.ps1
.\add_business_features.ps1

# 6. Business processes + cross-domain linking
.\sprint6_all_actions.ps1
.\create_business_processes.ps1
```

### Use-case sprints (advanced features)

```powershell
.\add_lob_umbrella_terms.ps1          # LoB-level umbrella glossary terms
.\attach_terms_to_dps.ps1             # Bulk DP→Term linking (39 relationships)
.\attach_assets_terms_to_dp.ps1       # DP→Asset + DP→Term wiring
.\sprint_uc_h_relationships.ps1       # Term↔term + CDE↔term relationships (32 links)
.\sprint_uc_i_critical_data_columns.ps1  # CDE→CriticalDataColumn bridge (15 CDCs)
.\sprint_uc_j_fake_data_quality.ps1   # DQ tier classifications (Gold/Silver/Bronze)
.\create_custom_metadata.ps1          # Custom metadata groups (3 groups, 11 attributes)
.\assign_owners.ps1                   # Owner/steward/CDO contact assignment
.\add_purview_roles.ps1               # IAM role assignments for demo users
```

---

## 📂 Repository Structure

| File | Purpose |
|------|---------|
| **Deployment scripts** | |
| `sprint1_fix_descriptions.ps1` | Patch descriptions on existing catalog objects |
| `sprint2_domains_org.ps1` | Create 16-domain hierarchy |
| `sprint3_glossary.ps1` | Provision 75 glossary terms with contacts & acronyms |
| `sprint4_data_products.ps1` | Create 6 data products |
| `sprint5_unified_catalog.ps1` | OKRs, CDEs, custom attributes |
| `sprint6_all_actions.ps1` | Business processes + app service linking |
| `wipe_and_redeploy.ps1` | Full teardown + rebuild orchestrator |
| `full_wipe_v3.ps1` | Aggressive cleanup (domains, terms, DPs, ghosts) |
| **Use-case scripts** | |
| `sprint_uc_h_relationships.ps1` | Term↔term + CDE↔term cross-linking |
| `sprint_uc_i_critical_data_columns.ps1` | CriticalDataColumn entity creation & CDE bridging |
| `sprint_uc_j_fake_data_quality.ps1` | Atlas DQ classification tiers on 85 assets |
| `add_business_features.ps1` | OKRs, CDEs, and custom attrs in one pass |
| `add_lob_umbrella_terms.ps1` | LoB-level umbrella glossary terms |
| `attach_terms_to_dps.ps1` | Bulk DP→Term relationship creation |
| `attach_assets_terms_to_dp.ps1` | DP→Asset + DP→Term wiring |
| `create_custom_metadata.ps1` | Custom metadata groups (modern UC endpoint) |
| `create_business_processes.ps1` | Atlas-based business process entities |
| `enrich_data_products.ps1` | Rich descriptions, docs, terms of use, endorsements |
| `link_terms_to_assets.ps1` | Glossary term → data asset linking |
| **Identity & access** | |
| `create_demo_users.ps1` | Provision 15 governance personas in Entra ID |
| `assign_owners.ps1` | Assign owner/steward/CDO contacts to all entities |
| `verify_and_assign_owners.ps1` | Verify + fix contact assignments |
| `add_purview_roles.ps1` | IAM role grants for demo users |
| `grant_pbi_workspace_access.ps1` | Power BI workspace access for demo users |
| `demo_users.json` | User GUIDs for all 15 demo personas |
| **Discovery & diagnostics** | |
| `query_purview.ps1` | General-purpose catalog search |
| `query_governance.ps1` | Governance domain/term/DP enumeration |
| `query_gov_detail.ps1` | Deep-dive on a single governance entity |
| `query_details.ps1` | Asset detail retrieval |
| `probe_dp_da.ps1` | Probe DP→DataAsset relationship surface |
| `find_dp_workspaces.ps1` | Discover Fabric workspaces linked to DPs |
| **Documentation** | |
| `purview_governance_inventory.md` | Full tenant inventory & API discovery notes |
| `demo_story_business.md` | 12-min demo script ("Maya's Monday Morning") |
| `governance_entities_detail.json` | Exported governance entity details |
| `purview_inventory.json` | Machine-readable tenant inventory |
| `sprint2_guids.json` / `sprint5_domain_guids.json` | Saved entity GUIDs across sprints |

---

## 🎬 Demo Story: "Maya's Monday Morning"

A **12-minute executive walkthrough** built on top of this tenant, designed for CDOs, CROs, and LoB heads — not a tech demo.

| Scene | What Maya does | Business message |
|-------|---------------|-----------------|
| 🟦 **09:02** | Opens UC home → sees 5 LoB tiles | "One operating model, every LoB" |
| 🟩 **09:04** | Searches "ESG Disclosure Metric" | "Terms link to products and people" |
| 🟨 **09:06** | Opens ESG Reporting Pack DP | "Data products, not data dumps" |
| 🟧 **09:08** | Checks DQ tiers (Gold vs Bronze) | "Trust is not a vibe" |
| 🟥 **09:09** | Drills into Critical Data Elements | "CDEs bridge policy to implementation" |
| 🟪 **09:10** | Reviews OKR progress | "OKRs live in the data layer" |
| 🟫 **09:11** | Shows lineage for a regulator | "Source byte to boardroom slide" |

See [demo_story_business.md](demo_story_business.md) for the full speaker script.

---

## 🔧 API Surface Discoveries

This project reverse-engineered large parts of the **Unified Catalog REST API** (`2026-03-20-preview`). Key findings documented in [purview_governance_inventory.md](purview_governance_inventory.md):

| Endpoint | Status | Notes |
|----------|--------|-------|
| Domains (CRUD) | ✅ Works | PUT requires `id` in body |
| Terms (CRUD + acronyms) | ✅ Works | Full body required for PUT |
| Data Products (CRUD + enrichment) | ✅ Works | `audience`, `useCases` silently dropped |
| Objectives / Key Results | ✅ Works | Must publish via PUT after POST |
| Critical Data Elements | ✅ Works | Links to columns, not DPs |
| CriticalDataColumns | ✅ Works | Bridge layer between CDEs and assets |
| Custom Metadata (groups) | ✅ Works | Modern endpoint preserves attribute names |
| Custom Metadata (values on entities) | ❌ Blocked | PUT accepted, values silently dropped |
| DP→BusinessProcess linking | ❌ Blocked | Only `DataAsset`, `Term`, `CriticalDataColumn` accepted |
| Data Quality scores | ❌ Read-only | Requires separately billed DQ feature + scan jobs |
| Old `/attributes` endpoint | ⚠️ Broken | Silently overwrites `name` with GUID |

---

## 📊 Tenant Stats

| Metric | Value |
|--------|-------|
| **Account** | `pdedemopurv` (West US 2, Standard SKU) |
| **Catalog assets** | 9,541 across 31 collections |
| **Source types** | Azure · Fabric · Snowflake · AWS · GCP · Dynamics · Salesforce · On-prem SQL/PostgreSQL |
| **Entity type definitions** | 731 (Oracle, SAP, Tableau, Fabric, Snowflake, …) |
| **Classifications applied** | PII (name, email, DOB, address) + custom (DQ tiers) |
| **Governance policies** | 32 collection-level metadata policies |

---

## ⚠️ Known Limitations

- **Ghost entries**: ~22 deleted Atlas domains + 4 old DPs still appear in UC listings due to eventual consistency lag
- **PATCH not supported**: All UC endpoints require full-body PUT
- **Published object deletion**: Must transition to `Draft` before DELETE
- **Custom attribute values**: Cannot be set via REST — portal only
- **DP↔CDE direct link**: Not supported; must route through Term or CriticalDataColumn intermediaries
- **DQ scores**: Require the paid Purview Data Quality add-on + profiling jobs

---

## 📜 License

Internal Microsoft demo asset — not for redistribution.
