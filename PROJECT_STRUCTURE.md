# 🗂️ Project Structure & File Reference

**DemoPurview** — Microsoft Purview Unified Catalog Demo Automation

Last Updated: July 2, 2026

---

## 📁 Directory Overview

```
DemoPurview/
├── .github/                                 # GitHub config & agent definitions
│   ├── copilot-instructions.md             # Hard constraints, workflow rules, git hygiene
│   ├── agent-instructions.md               # Copilot agent setup
│   ├── agents/                             # 14 specialized agent definitions
│   │   ├── orchestrator.agent.md           # Pipeline coordination
│   │   ├── extractor.agent.md              # Source artifact parsing
│   │   ├── converter.agent.md              # Formula conversion (coord.)
│   │   ├── dax.agent.md                    # DAX formula handling
│   │   ├── wiring.agent.md                 # DAX↔M bridge
│   │   ├── semantic.agent.md               # Semantic model (TMDL)
│   │   ├── visual.agent.md                 # Report layout & visuals
│   │   ├── generator.agent.md              # Cross-cutting generation
│   │   ├── assessor.agent.md               # Migration readiness
│   │   ├── merger.agent.md                 # Multi-source merge
│   │   ├── deployer.agent.md               # Deployment & auth
│   │   ├── reviewer.agent.md               # Quality gate (preceptorship)
│   │   ├── tester.agent.md                 # Test coverage & fixtures
│   │   └── shared.instructions.md          # Common rules
│   └── workflows/
│       └── ci.yml                          # GitHub Actions: test on 3.12/3.13 + lint
│
├── docs/                                    # Generated reports & architecture
│   ├── AGENTS.md                           # Multi-agent architecture & preceptorship loop
│   ├── scenario_environment_status.json    # Portal scenario readiness status
│   ├── scenario4_admin_adoption_evidence.md # S4 evidence: roles, personas, coverage
│   ├── dq_coverage_report.md               # Data quality tier distribution
│   ├── lineage_finance_snowflake_salesforce_columns.md  # Full column lineage
│   ├── semantic_labs_extraction_report.md  # Finance semantic model sync results
│   ├── finance_report_semantic_metadata.json  # Extracted Power BI metadata
│   └── entity_*.json                       # Individual entity full definitions
│
├── purview-ux-portal/                      # Demo scenario portal (Node.js + React)
│   ├── README.md                           # Portal launch & config guide
│   ├── src/                                # React components & API layer
│   ├── package.json                        # npm dependencies
│   └── .env                                # Environment config (optional)
│
├── Fabric_Notebooks/                       # Jupyter notebooks for Fabric execution
│   └── SemanticLabs_FinanceReport_Metadata.ipynb  # Semantic Labs extraction workflow
│
├── .git/                                   # Version control
├── .pytest_cache/                          # pytest artifacts
│
├── README.md                               # Main project README (quick start, overview)
├── STATUS.md                               # 📊 **Comprehensive project status** ← START HERE
├── CHANGELOG.md                            # Release history (v1.0.0 → v2.0.0)
├── CONTRIBUTING.md                         # Development setup & coding standards
├── LICENSE                                 # (Internal Microsoft asset)
├── requirements.txt                        # Python dependencies
├── requirements-semantic-labs.txt          # Semantic Labs specific dependencies
│
├── .gitignore                              # Git exclusions
│
└── ===== DEPLOYMENT SCRIPTS =====           # PowerShell orchestration layer
    ├── wipe_and_redeploy.ps1               # Full teardown + rebuild (atomic)
    ├── full_wipe_v3.ps1                    # Aggressive cleanup (all domains, terms, DPs, ghosts)
    │
    ├── ===== SPRINTS (1-5) =====
    ├── sprint1_fix_descriptions.ps1        # Patch existing object descriptions
    ├── sprint2_domains_org.ps1             # Create 16-domain hierarchy (5 LoB + 11 subs)
    ├── sprint2_guids.json                  # Saved domain GUIDs (reference only)
    ├── sprint3_glossary.ps1                # Provision 75 glossary terms with contacts
    ├── sprint4_data_products.ps1           # Create 6 endorsed data products
    ├── sprint5_unified_catalog.ps1         # OKRs, CDEs, custom metadata, business processes
    ├── sprint5_domain_guids.json           # Saved domain GUIDs (latest reference)
    ├── sprint6_all_actions.ps1             # Business processes + app service linking
    │
    ├── ===== UC FEATURES (E-J) =====
    ├── sprint_uc_h_relationships.ps1       # Wire term↔term + CDE↔term relationships (32 links)
    ├── sprint_uc_i_critical_data_columns.ps1  # Create 15 CriticalDataColumns, bridge CDEs
    ├── sprint_uc_j_fake_data_quality.ps1   # Apply 🟢🟡🟠 DQ tier classifications (85 assets)
    ├── uc_sprints_abc.ps1                  # Legacy multi-sprint executor
    │
    ├── ===== BULK OPERATIONS =====
    ├── add_business_features.ps1           # OKRs + CDEs + custom metadata in one pass
    ├── add_lob_umbrella_terms.ps1          # Add 15 LoB-level umbrella glossary terms
    ├── add_purview_roles.ps1               # IAM role assignments for demo users
    ├── add_domain_owner_roles.ps1          # Assign Domain Creator + Domain Owner roles
    ├── add_dp_owner_roles.ps1              # Assign DP owner roles to users
    ├── add_dq_terms_to_domain.ps1          # Map DQ terms to domains
    ├── add_semantic_metadata_finance_report.ps1  # Add semantic metadata to Finance Report
    ├── add_subdomain_data_products.ps1     # Create sub-domain-specific DPs
    │
    ├── ===== TERM & ASSET LINKING =====
    ├── attach_terms_to_dps.ps1             # Bulk DP→Term relationship creation (39 rels)
    ├── attach_assets_terms_to_dp.ps1       # Bulk DP→Asset + DP→Term wiring
    ├── link_terms_to_assets.ps1            # Glossary term → data asset linking
    ├── link_terms_batch.ps1                # Batch term linking with error recovery
    ├── complete_metadata_data_products_dq.ps1  # One-pass DP metadata + linking + DQ API
    │
    ├── ===== DATA PRODUCTS & ENRICHMENT =====
    ├── enrich_data_products.ps1            # Add descriptions, ToU, docs, endorsements
    ├── enrich_commercial_analytics_lineage.ps1  # Add lineage to Commercial Analytics DP
    ├── enrich_snowflake_assets.ps1         # Tag Snowflake assets with DQ/lineage metadata
    ├── update_dp_owners.ps1                # Update data product owner assignments
    │
    ├── ===== OWNERSHIP & ACCESS =====
    ├── assign_owners.ps1                   # Assign owner/steward/CDO contacts to all entities
    ├── verify_and_assign_owners.ps1        # Verify + fix contact assignments
    ├── create_demo_users.ps1               # Provision 15 governance personas in Entra ID
    ├── grant_pbi_workspace_access.ps1      # PBI workspace access for demo users
    ├── demo_users.json                     # 15 governance personas (GUIDs, roles, names)
    │
    ├── ===== METADATA & CONFIG =====
    ├── create_business_processes.ps1       # Atlas-based business process entities
    ├── create_custom_metadata.ps1          # 3 custom metadata groups (11 attributes)
    ├── build_finance_semantic_metadata_from_live_model.ps1  # Extract Finance semantic model
    │
    ├── ===== LINEAGE & DISCOVERY =====
    ├── full_column_lineage_finance_snowflake_salesforce.ps1  # Finance → Snowflake → Salesforce
    ├── set_single_row_lineage_finance.ps1  # Single-hop lineage for Finance report
    ├── review_full_lineage.ps1             # Review full lineage graph
    ├── enrich_commercial_analytics_lineage.ps1  # Add lineage context
    │
    ├── ===== SEMANTIC LABS & FABRIC =====
    ├── semantic_labs_extract_finance_report.py  # Extract Finance semantic model (Python)
    ├── import_semantic_labs_metadata_to_purview.ps1  # Import extracted JSON to Purview
    ├── build_finance_semantic_metadata_from_live_model.ps1  # Alternative extraction method
    ├── upload_notebook_to_fabric.ps1       # Fabric notebook upload
    ├── upload_notebook_ipynb.ps1           # Alternative notebook uploader
    ├── run_notebook_fabric.ps1             # Run uploaded Fabric notebook
    │
    ├── ===== DEMO PORTAL & SCENARIOS =====
    ├── run_scenario_environment.ps1        # Start portal + prepare scenarios
    ├── prepare_scenario_environment.ps1    # Prep scenarios without starting UI
    ├── run_client_all_scenarios.ps1        # Run all scenarios in sequence
    ├── scenario4_admin_adoption_evidence.ps1  # Generate S4 admin adoption evidence
    ├── probe_dp_da.ps1                     # Probe DP→DataAsset relationships
    ├── find_dp_workspaces.ps1              # Discover Fabric workspaces linked to DPs
    │
    ├── ===== QUERY & DIAGNOSTIC =====
    ├── query_purview.ps1                   # General catalog search
    ├── query_governance.ps1                # Governance domain/term/DP enumeration
    ├── query_gov_detail.ps1                # Deep-dive on single governance entity
    ├── query_details.ps1                   # Asset detail retrieval
    ├── generate_dq_coverage_report.ps1     # Data quality tier distribution report
    ├── fix_delete_and_redeploy.ps1         # Recover from partial deployment failure
    ├── fix_subdomain_dq_assets.ps1         # Fix DQ tier on sub-domain assets
    │
    ├── ===== DIAGNOSTIC OUTPUT =====
    ├── last_cde_link_run.txt               # CDE linking debug output (timestamp)
    ├── last_cde_link_run_2.txt             # Alternative CDE linking output
    ├── purview_governance_inventory.md     # 📖 **API discoveries & UC inventory** ← TECHNICAL REFERENCE
    ├── purview_inventory.json              # Machine-readable tenant inventory
    ├── governance_entities_detail.json     # Full entity definitions
    ├── policy_dump.json                    # Purview collection policies
    │
    ├── ===== DOCUMENTATION =====
    ├── demo_story_business.md              # 🎬 **12-min demo script** ("Maya's Monday Morning")
    ├── SEMANTIC_LABS_FABRIC_RUNBOOK.md     # Semantic Labs workflow guide
    │
    └── ===== MISC/NOTEBOOKS =====
        ├── temp_notebook_content.py        # Temporary Python snippets
        ├── Snowflake column lineage To Share.ipynb  # Lineage exploration notebook
        ├── Snowflake lineage - custom.ipynb  # Custom lineage extraction
        └── simple_upload.ps1               # Simple upload utility
```

---

## 📖 Key Files Guide

### 🎯 **START HERE**
| File | Purpose | Audience |
|------|---------|----------|
| [STATUS.md](STATUS.md) | 📊 Comprehensive project status, all sprints, deployment paths | Everyone |
| [README.md](README.md) | Project overview, quick start, domain architecture | Everyone |
| [CHANGELOG.md](CHANGELOG.md) | Release history (v1.0.0 → v2.0.0) | Developers, managers |

### 📚 **Documentation**
| File | Purpose | Audience |
|------|---------|----------|
| [docs/AGENTS.md](docs/AGENTS.md) | Multi-agent architecture, preceptorship loop, 5-star review | Architects |
| [demo_story_business.md](demo_story_business.md) | 12-minute demo narrative ("Maya's Monday Morning") | Demo leads, sales |
| [purview_governance_inventory.md](purview_governance_inventory.md) | REST API discoveries, UC features, endpoint status | Technical leads |
| [SEMANTIC_LABS_FABRIC_RUNBOOK.md](SEMANTIC_LABS_FABRIC_RUNBOOK.md) | Semantic Labs extraction workflow | Power BI SMEs |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Development setup, coding standards, workflow rules | Developers |

### ⚙️ **Deployment Orchestrators**
| File | Purpose | Entry Point |
|------|---------|-------------|
| `wipe_and_redeploy.ps1` | Full teardown + rebuild | `.\wipe_and_redeploy.ps1` |
| `sprint2_domains_org.ps1` | Domain hierarchy | `.\sprint2_domains_org.ps1` |
| `sprint3_glossary.ps1` | Glossary terms (75) | `.\sprint3_glossary.ps1` |
| `sprint4_data_products.ps1` | Data products (6) | `.\sprint4_data_products.ps1` |
| `sprint5_unified_catalog.ps1` | UC features (OKRs, CDEs, custom metadata) | `.\sprint5_unified_catalog.ps1` |
| `attach_terms_to_dps.ps1` | Bulk DP↔Term linking (39 rels) | `.\attach_terms_to_dps.ps1` |
| `sprint_uc_h_relationships.ps1` | Relationships (32 links) | `.\sprint_uc_h_relationships.ps1` |
| `sprint_uc_i_critical_data_columns.ps1` | CDEs→CDCs bridge (15) | `.\sprint_uc_i_critical_data_columns.ps1` |
| `sprint_uc_j_fake_data_quality.ps1` | DQ tiers (85 assets) | `.\sprint_uc_j_fake_data_quality.ps1` |

### 🎮 **Demo Portal**
| File | Purpose |
|------|---------|
| `run_scenario_environment.ps1` | Launch portal on http://localhost:7071 |
| `purview-ux-portal/` | React/Node.js scenario environment (S1–S4) |

### 📊 **Reference Data**
| File | Purpose |
|------|---------|
| `demo_users.json` | 15 governance personas (GUIDs, names, roles) |
| `sprint2_guids.json` | Domain GUIDs (Sprint 2 reference) |
| `sprint5_domain_guids.json` | Domain GUIDs (latest) |
| `purview_inventory.json` | Machine-readable tenant snapshot |
| `governance_entities_detail.json` | Full governance entity definitions |

### 🧪 **Testing & CI/CD**
| File | Purpose |
|------|---------|
| `.github/workflows/ci.yml` | GitHub Actions: test on Python 3.12/3.13 + lint |
| `requirements.txt` | Python dependencies (pytest, ruff, etc.) |

---

## 🔄 Common Workflows

### Deploy Everything (Full Wipe + Rebuild)
```powershell
.\wipe_and_redeploy.ps1
```
**Time**: ~25 min | **Output**: 16 domains, 75 terms, 6 DPs, OKRs, CDEs, DQ tiers, all linked

### Incremental Build (Sprint by Sprint)
```powershell
.\sprint2_domains_org.ps1
.\sprint3_glossary.ps1
.\sprint4_data_products.ps1
.\sprint5_unified_catalog.ps1
.\attach_terms_to_dps.ps1
.\sprint_uc_h_relationships.ps1
.\sprint_uc_i_critical_data_columns.ps1
.\sprint_uc_j_fake_data_quality.ps1
```

### Launch Demo Portal (With Scenarios)
```powershell
.\run_scenario_environment.ps1
# Opens http://localhost:7071 with S1–S4 scenarios
```

### Extract Semantic Metadata (Finance Report)
```powershell
# In Fabric notebook:
%pip install semantic-link-labs
!python semantic_labs_extract_finance_report.py --workspace "DDiB-FSI" --dataset "Finance Report"

# Then locally:
.\import_semantic_labs_metadata_to_purview.ps1 -MetadataJsonPath ".\docs\finance_report_semantic_metadata.json"
```

### Query Governance State
```powershell
.\query_governance.ps1                  # List all domains, terms, DPs
.\query_gov_detail.ps1 -EntityType term # Deep-dive on a term
.\generate_dq_coverage_report.ps1       # DQ tier distribution
```

---

## 📈 Metrics & Counts

| Entity Type | Count | Linked To |
|-------------|-------|-----------|
| **Domains** | 16 | All 75 terms distributed |
| **Glossary Terms** | 75 | 6 DPs (39 relationships) |
| **Data Products** | 6 | 75 terms + 85 assets + 5 OKRs |
| **Critical Data Elements** | 15 | 15 CriticalDataColumns + 10 terms |
| **Critical Data Columns** | 15 | Physical schema positions |
| **Relationships** | 85+ | Term-term, DP-term, CDE-term, CDE-CDC |
| **Custom Metadata Groups** | 3 | 11 named attributes |
| **OKRs / Key Results** | 5 / 15 | Linked to DPs with progress |
| **Business Processes** | 5 | Cross-domain process linking |
| **Demo Users** | 15 | Governance personas with roles |
| **Assets (Total)** | 9,541 | 85 with DQ tiers |

---

## 🔗 Dependencies

### PowerShell Requirements
- PowerShell 7+ (Core)
- Azure CLI (`az login`)
- Purview REST API (`2026-03-20-preview`)

### Python Requirements (if running locally)
```bash
pip install -r requirements.txt          # Core: pytest, requests
pip install -r requirements-semantic-labs.txt  # Semantic Labs: semantic-link-labs
```

### Node.js Requirements (for portal)
- Node.js 18+
- npm (with `npm install` before running)

---

## 🚀 CI/CD Pipeline

Runs on **push** and **pull_request** to `main` branch:

1. ✅ **Setup**: Python 3.12 + 3.13 matrix
2. ✅ **Dependencies**: `pip install pytest && pip install -r requirements.txt`
3. ✅ **Tests**: `pytest tests/ --tb=short -q`
4. ✅ **Lint**: `ruff check . --select E9,F63,F7,F82`

All tests must pass before merge.

---

## 📞 Support & Contributing

- **Development**: See [CONTRIBUTING.md](CONTRIBUTING.md)
- **Architecture**: See [docs/AGENTS.md](docs/AGENTS.md)
- **Workflow Rules**: See `.github/copilot-instructions.md`
- **Bug Reports**: Create an issue with reproduction steps
- **Features**: Discuss in PRs; follow sprint naming convention

---

**Last Updated**: July 2, 2026 | **Status**: ✅ Production Ready
