# 📊 Project Status — Microsoft Purview Unified Catalog Demo Automation

**Last Updated**: July 2, 2026  
**Status**: ✅ **Production Ready** — All core sprints complete, UC features validated  
**Tenant**: `pdedemopurv.purview.azure.com` | **Region**: West US 2

---

## 🎯 Current State Summary

| Metric | Count | Status |
|--------|-------|--------|
| **Domains** | 16 | ✅ Complete (5 LoB + 11 sub-domains) |
| **Glossary Terms** | 75 | ✅ Published with owner/steward/CDO contacts |
| **Data Products** | 6 | ✅ Enriched with docs, terms of use, business descriptions |
| **Critical Data Elements** | 15 | ✅ Bridged to physical columns via CriticalDataColumns |
| **Critical Data Columns** | 15 | ✅ Linked to CDEs |
| **OKRs** | 5 | ✅ With 15 Key Results, live progress tracking |
| **Relationships** | 85+ | ✅ Term↔term, DP↔term, CDE↔term cross-links |
| **Custom Metadata Groups** | 3 | ✅ 11 named attributes, Published scope |
| **Business Processes** | 5 | ✅ Cross-domain process entities |
| **Demo Users** | 15 | ✅ Governance personas with role assignments |
| **Assets with DQ Tier** | 85 | ✅ 🟢 Gold / 🟡 Silver / 🟠 Bronze classifications |
| **Runnable Scenarios** | 4 | ✅ S1 (KPI) → S4 (Adoption Evidence) |

---

## 📋 Sprints & Features — Complete Timeline

### Sprint 1: Foundation (Feb 2026)
- ✅ Fix descriptions on existing objects
- **Status**: Complete

### Sprint 2: Domain Hierarchy (Feb 2026)
- ✅ Create 5 Lines of Business (LoB) root domains
- ✅ Create 11 sub-domains under LoB hierarchy
- ✅ Assign domain owner roles
- **Output**: 16 domains ready for governance

### Sprint 3: Glossary (Feb 2026)
- ✅ Populate 75 glossary terms
- ✅ Assign owner, steward, CDO contacts to each term
- ✅ Publish all terms
- **Output**: 75 Published terms with full governance metadata

### Sprint 4: Data Products (Mar 2026)
- ✅ Create 6 core data products
- ✅ Enrich with business descriptions (3+ paragraphs each)
- ✅ Add Terms of Use (clickable policy URLs)
- ✅ Add documentation links (runbooks, data dictionaries)
- **Output**: 6 Endorsed data products with rich metadata

### Sprint 5: Unified Catalog Features (Mar 2026)
- ✅ Create OKRs with Key Results + progress tracking
- ✅ Set up Custom Metadata groups (3 groups, 11 attributes)
- ✅ Create Business Processes (5 cross-domain processes)
- ✅ Implement LoB umbrella terms (15 terms, 3 per LoB)
- **Output**: Unified Catalog ready for advanced governance scenarios

### Sprint UC-E: LoB Umbrella Glossary (Mar 2026)
- ✅ Add 15 LoB-level umbrella terms (3 per LoB root)
- ✅ Enable first-class term visibility at LoB level
- **Output**: Glossary count 60→75 terms

### Sprint UC-F: DP→Term Bulk Linking (Apr 2026)
- ✅ Discover & validate REST endpoint for DP↔Term relationships
- ✅ Bulk attach 39 term-to-DP relationships
- ✅ Verify all DPs show terms in UI; all terms show DPs
- **Output**: Full term-DP bidirectional linking

### Sprint UC-G: Custom Metadata (Apr 2026)
- ✅ Discover modern `POST /customMetadata` REST endpoint
- ✅ Create 3 custom metadata groups (Operations, Compliance, Governance)
- ✅ Define 11 named attributes with proper typing
- ✅ Publish all groups; set scope to all domains/DPs
- **Output**: Custom metadata infrastructure ready for values (portal-manual for now)

### Sprint UC-H: Relationship APIs (May 2026)
- ✅ Wire `Add Related Entity` endpoints for relationships
- ✅ Create 32 relationships:
  - 15 term↔term
  - 10 CDE↔term
  - 7 other cross-links
- ✅ Validate REST-created relationships render in portal
- **Output**: Full graph linking complete

### Sprint UC-I: Critical Data Elements at Scale (May 2026)
- ✅ Define Critical Data Element governance at scale
- ✅ Create 15 CDEs with descriptions
- ✅ Link 15 CriticalDataColumns to physical schema positions
- ✅ Wire relationships CDE↔term
- **Output**: CDE→Column policy→implementation chain complete

### Sprint UC-J: Fake Data Quality Tiers (May 2026)
- ✅ Add 🟢🟡🟠 DQ tier classifications to 85 assets
- ✅ Set rules: scanned assets → Gold, unscanned → Bronze, mixed → Silver
- ✅ Wire classifications to data product DQ custom metadata
- **Output**: Data quality visibility at catalog level

### Additional Features (May–Jun 2026)
- ✅ Semantic Labs extraction & import (Finance Report Power BI semantic model)
- ✅ Full column lineage (Finance↔Snowflake↔Salesforce via REST)
- ✅ Scenario environment portal (4 live scenarios, S1–S4)
- ✅ Demo story narrative ("Maya's Monday Morning" — 12-min walkthrough)
- ✅ Business process linking to app services

---

## 🏗️ Architecture

### Multi-Agent System
Located in `.github/agents/` — 14 specialized agents for coordinated migration tasks:
- **@orchestrator**: Pipeline coordination, CLI dispatch
- **@extractor**: Microsoft Purview artifact parsing
- **@converter**: Formula conversion coordination
- **@dax**, **@wiring**: DAX/M query generation
- **@semantic**, **@visual**: Model/report generation
- **@reviewer**: Quality gate (preceptorship loop)
- **@tester**: Test coverage and regression
- *And 6 others for assessment, merging, deployment*

**Preceptorship Loop**: All artifacts go through @reviewer (5-star scoring); ≥4★ average → approve.

### Deployment
- **CI/CD**: GitHub Actions (`.github/workflows/ci.yml`)
  - Tests on Python 3.12, 3.13
  - Lint with ruff
  - Auto-runs on push/PR
- **Local Development**: `.venv` with `requirements.txt`

### Demo Portal
- **Location**: `purview-ux-portal/`
- **Stack**: Node.js 18+, live Purview API calls
- **Launch**: `.\run_scenario_environment.ps1` from root

---

## 📁 Key Files & Directories

| Path | Purpose |
|------|---------|
| `README.md` | Main project overview & quick start |
| `CHANGELOG.md` | Release history |
| `CONTRIBUTING.md` | Development setup & standards |
| `docs/AGENTS.md` | Multi-agent architecture & preceptorship loop |
| `.github/agents/` | Individual agent definitions (14 files) |
| `.github/copilot-instructions.md` | Project guardrails & workflow rules |
| `purview-ux-portal/` | Local scenario demo portal |
| `demo_story_business.md` | "Maya's Monday" 12-min demo narrative |
| `purview_governance_inventory.md` | Sprint UC inventory & gap analysis |
| `SEMANTIC_LABS_FABRIC_RUNBOOK.md` | Semantic Labs extraction workflow |
| `requirements.txt` | Python dependencies |
| `demo_users.json` | 15 governance personas |

---

## 🚀 Deployment Paths

### Scenario A: Full Wipe + Rebuild (from zero)
```powershell
.\wipe_and_redeploy.ps1
```
**Time**: ~25 min | **Output**: Complete UC environment ready for demo

### Scenario B: Incremental Sprints (step-by-step)
```powershell
.\sprint1_fix_descriptions.ps1
.\sprint2_domains_org.ps1
.\sprint3_glossary.ps1
.\sprint4_data_products.ps1
.\sprint5_unified_catalog.ps1
.\sprint_uc_h_relationships.ps1
.\sprint_uc_i_critical_data_columns.ps1
.\sprint_uc_j_fake_data_quality.ps1
```

### Scenario C: Launch Demo Portal
```powershell
.\run_scenario_environment.ps1
```
**Output**: Live portal on `http://localhost:7071` with 4 scenarios

### Scenario D: Fabric Semantic Labs Sync
```powershell
# In Fabric notebook:
!python semantic_labs_extract_finance_report.py --workspace "DDiB-FSI" --dataset "Finance Report" --out "/lakehouse/default/Files/finance_report_semantic_metadata.json"

# Then locally:
.\import_semantic_labs_metadata_to_purview.ps1 -MetadataJsonPath ".\docs\finance_report_semantic_metadata.json"
```

---

## 🔍 Validation Checklist

- ✅ All 16 domains exist, published, with owners
- ✅ All 75 terms published, with owner/steward/CDO
- ✅ All 6 DPs endorsed, documented, with terms attached
- ✅ All 15 CDEs linked to 15 CriticalDataColumns
- ✅ All 85+ relationships wired (term-term, DP-term, CDE-term, CDE-column)
- ✅ 3 custom metadata groups published with 11 attributes
- ✅ 5 OKRs with 15 KRs, progress tracking active
- ✅ 5 business processes linked to app services
- ✅ 85 assets have 🟢🟡🟠 DQ tiers
- ✅ Portal scenarios (S1–S4) all runnable
- ✅ Demo narrative fully scripted & backed by live data
- ✅ CI/CD green (all tests passing)

---

## 📞 Demo Readiness

**Status**: 🟢 **BOARDROOM READY**

### Maya's Monday Morning — 12-minute walkthrough
1. **Scene 1**: Home page → governance domains (5 LoB tiles visible)
2. **Scene 2**: Glossary search → term with contacts + related DP + related terms
3. **Scene 3**: DP page → business use + ToU + documentation + endorsement + CDEs
4. **Scene 4**: DQ tiers 🟢🟡🟠 on assets → trust & compliance messaging
5. **Scene 5**: CDE page → related term → related column → DQ tier
6. **Scene 6**: OKR page with 3 KRs, progress tracking, status alerts

**Estimated Demo Time**: 12 minutes | **Audience**: CDOs, Risk Officers, LoB heads, regulators

---

## 🎓 Learning Resources

- **Architecture Deep Dive**: [docs/AGENTS.md](docs/AGENTS.md) — preceptorship loop, 5-star scoring
- **Demo Narrative**: [demo_story_business.md](demo_story_business.md) — scene-by-scene script
- **Governance Inventory**: [purview_governance_inventory.md](purview_governance_inventory.md) — all UC features documented
- **Development Workflow**: [CONTRIBUTING.md](CONTRIBUTING.md) — local setup, testing, coding standards
- **Portal Guide**: [purview-ux-portal/README.md](purview-ux-portal/README.md) — scenario environment docs

---

## 🔧 Troubleshooting

| Issue | Resolution |
|-------|-----------|
| Token failure | `az login` to re-authenticate |
| Scenario portal won't start | Check Node.js version (18+) and `npm install` |
| Tests failing | Run `pytest tests/ --tb=short -q` locally first |
| DP→Term links missing | Re-run `attach_terms_to_dps.ps1` |
| DQ tiers not showing | Verify asset classifications via `sprint_uc_j_fake_data_quality.ps1` |

---

## 📈 Metrics & KPIs

- **Governance Coverage**: 85 assets across 5 LoB + 11 sub-domains
- **Term Adoption**: 75 terms in 6 data products (39 relationships)
- **Relationship Density**: 85+ cross-links (term-term, DP-term, CDE-term, CDE-CDC)
- **Custom Metadata Readiness**: 3 groups, 11 attributes, 0 portal values (manual entry ready)
- **Demo Scenario Success Rate**: 4/4 scenarios runnable (100%)
- **CI/CD Pass Rate**: 100% (all tests green)

---

## 🗺️ Future Roadmap

- **Q3 2026**: Power BI asset lineage (bi-directional column-level)
- **Q3 2026**: Automatic data quality tier scoring (from actual scanners)
- **Q4 2026**: Multi-tenant federation support
- **Q4 2026**: Custom metadata value persistence via REST (currently portal-only)

---

**Questions?** See [CONTRIBUTING.md](CONTRIBUTING.md) or review `.github/copilot-instructions.md` for project rules.
