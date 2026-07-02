# ⚡ Quick Reference — Commands & Common Tasks

**DemoPurview** — One-page cheat sheet for deployment, diagnostics, and demo scenarios

---

## 🚀 Deploy (Choose One Path)

### Path A: Full Rebuild (Clean Slate)
```powershell
.\wipe_and_redeploy.ps1
```
**What happens**: Tears down all domains/terms/DPs/OKRs/CDEs, then rebuilds everything from scratch.  
**Time**: ~25 minutes  
**Output**: Fully populated UC tenant ready for demo

### Path B: Incremental Sprints (Add Features Step-by-Step)
```powershell
# Step 1: Domains (5 LoB + 11 sub-domains)
.\sprint2_domains_org.ps1

# Step 2: Glossary terms (75 terms with contacts)
.\sprint3_glossary.ps1

# Step 3: Data products (6 DPs with docs)
.\sprint4_data_products.ps1

# Step 4: UC features (OKRs, CDEs, custom metadata)
.\sprint5_unified_catalog.ps1

# Step 5: Advanced linking (terms↔DPs, CDEs↔columns, relationships)
.\attach_terms_to_dps.ps1
.\sprint_uc_h_relationships.ps1
.\sprint_uc_i_critical_data_columns.ps1
.\sprint_uc_j_fake_data_quality.ps1
```
**Time**: ~45 minutes total  
**Benefit**: See each layer build, easier troubleshooting

### Path C: Just Deploy Linked Terms & DQ Tiers (Quick Enrichment)
```powershell
.\attach_terms_to_dps.ps1                      # Wire 39 DP↔Term relationships
.\sprint_uc_h_relationships.ps1                # Add 32 cross-links (term-term, CDE-term)
.\sprint_uc_j_fake_data_quality.ps1            # Apply 🟢🟡🟠 DQ classifications (85 assets)
```
**Time**: ~10 minutes  
**Use case**: Already have domains/terms/DPs; just want linking & DQ

---

## 🎮 Launch Demo Portal

```powershell
# One-shot: prep metadata + relationships, then start portal on http://localhost:7071
.\run_scenario_environment.ps1
```

**Includes**:
- ✅ Scenario 1 (KPI search in Unified Catalog)
- ✅ Scenario 2 (Data Product drill-down)
- ✅ Scenario 3 (Governed Asset with DQ tier)
- ✅ Scenario 4 (Admin/Adoption evidence + role mappings)
- ✅ Live readiness board with checks

**Or prep without UI** (useful for CI/CD):
```powershell
.\prepare_scenario_environment.ps1 -SkipEvidence
```

---

## 🔗 Bulk Operations (One-Pass Solutions)

| Task | Command | Output |
|------|---------|--------|
| Link all DPs to terms | `.\attach_terms_to_dps.ps1` | 39 relationships |
| Wire all relationships | `.\sprint_uc_h_relationships.ps1` | 32 cross-links |
| Add all CDEs & columns | `.\sprint_uc_i_critical_data_columns.ps1` | 15 CDEs + 15 CDCs |
| Classify all assets with DQ | `.\sprint_uc_j_fake_data_quality.ps1` | 85 assets tiered |
| Do everything at once | `.\complete_metadata_data_products_dq.ps1` | Complete DP enrichment + all linking + DQ |
| Add LoB umbrella terms | `.\add_lob_umbrella_terms.ps1` | 15 additional terms (3 per LoB) |
| Create custom metadata | `.\create_custom_metadata.ps1` | 3 groups, 11 attributes |
| Assign all owners | `.\assign_owners.ps1` | Owner/Steward/CDO contacts on all entities |

---

## 📊 Diagnostic Queries

| Question | Command |
|----------|---------|
| What's the current state? | `.\query_governance.ps1` |
| Show me all domains | `.\query_governance.ps1 \| grep -i "domain"` |
| List all terms in a domain | `.\query_gov_detail.ps1 -EntityType domain -Name "Finance and ESG"` |
| Get DP details | `.\query_gov_detail.ps1 -EntityType dataproduct -Name "Customer 360"` |
| Data quality tier report | `.\generate_dq_coverage_report.ps1` |
| Show assets by DQ tier | `.\query_purview.ps1 -Classification "DQ_Gold"` |
| Check CDE links | `.\query_gov_detail.ps1 -EntityType cde` |
| Verify term-DP links | `.\probe_dp_da.ps1` |
| Find Fabric workspaces | `.\find_dp_workspaces.ps1` |

---

## 🎬 Demo Narrative (Talking Points)

**"Maya's Monday Morning"** — 12-minute executive walkthrough  
See [demo_story_business.md](demo_story_business.md) for full script.

### Scene-by-Scene Talking Points

| Time | Scene | Show | Say |
|------|-------|------|-----|
| **09:02** | Home page | 5 LoB tiles (Finance, Sales, HR, Operations, Tech) | "One operating model, every line of business" |
| **09:04** | Term page | "ESG Disclosure Metric" with owner/steward/CDO + related DP + related terms | "Terms link to products and people" |
| **09:06** | DP page | "ESG Reporting Pack": use case + ToU + docs + CDEs + endorsed badge | "Data products, not data dumps" |
| **09:08** | DQ tiers | Assets with 🟢Gold / 🟡Silver / 🟠Bronze | "Trust is not a vibe; DQ is color-coded" |
| **09:09** | CDE page | "Customer Master ID" → related term → related column | "CDEs bridge policy to implementation" |
| **09:10** | OKR page | "Customer 360" ← KR with progress bar (78% / 100%) | "OKRs live in the data layer" |
| **09:11** | Lineage | Finance Report → Snowflake fact_sale → Salesforce Opportunity | "Source byte to boardroom slide" |

**Total time**: 12 minutes (with pauses for questions)

---

## 🧬 Semantic Labs (Power BI Metadata Extraction)

### Local machine (Python 3.12 or earlier only)
```bash
# Skip if you have Python 3.13+ — use Fabric notebook instead
python semantic_labs_extract_finance_report.py \
  --workspace "DDiB-FSI" \
  --dataset "Finance Report" \
  --out "docs/finance_report_semantic_metadata.json"
```

### Fabric notebook (recommended for Python 3.13+)
```python
# Cell 1: Install
%pip install semantic-link-labs

# Cell 2: Run extraction (from file or paste)
!python semantic_labs_extract_finance_report.py \
  --workspace "DDiB-FSI" \
  --dataset "Finance Report" \
  --out "/lakehouse/default/Files/finance_report_semantic_metadata.json"

# Cell 3: Download the JSON to local machine
# (then run PowerShell command below)
```

### Import to Purview
```powershell
.\import_semantic_labs_metadata_to_purview.ps1 `
  -MetadataJsonPath "C:\path\to\finance_report_semantic_metadata.json"
```

**Verify**: Open Purview → Finance Report dataset → check updated description & semantic relationships

---

## 🔐 Access & Permissions

### Minimum Purview Roles (To Run Scripts)
- **Governance Domain Creator**
- **Data Curator**
- Roles on specific domains/DPs you want to modify

### Minimum Azure CLI Permissions
```bash
# Must succeed:
az account get-access-token --resource https://purview.azure.net
```

### Grant Demo User Roles
```powershell
# Provision 15 governance personas in Entra ID
.\create_demo_users.ps1

# Assign Purview roles to demo users
.\add_purview_roles.ps1

# Assign Power BI workspace access (if applicable)
.\grant_pbi_workspace_access.ps1
```

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| **"Token expired"** | `az login` then retry |
| **"Not authorized for Governance Domain Creator"** | Check Purview role assignments in Azure portal |
| **"Portal won't start"** | Check Node.js version (`node --version` → 18+), then `npm install` |
| **"Tests failing locally"** | `pytest tests/ --tb=short -q` to see details |
| **"DQ tiers not visible in portal"** | Re-run `sprint_uc_j_fake_data_quality.ps1` |
| **"DP→Term links missing"** | Re-run `attach_terms_to_dps.ps1` |
| **"CDE columns not linked"** | Re-run `sprint_uc_i_critical_data_columns.ps1` |
| **"Syntax error in PowerShell"** | Use PowerShell 7+ (Core), not Windows PowerShell 5 |
| **"Can't authenticate to Fabric"** | `az login` and ensure workspace exists in Fabric |

---

## 📁 Key Files at a Glance

| When You Need To... | See File |
|-------------------|----------|
| Understand the project | [README.md](README.md) |
| Check current status & metrics | [STATUS.md](STATUS.md) |
| Learn the full file structure | [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) |
| See all sprints & releases | [CHANGELOG.md](CHANGELOG.md) |
| Get development setup | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Understand agent architecture | [docs/AGENTS.md](docs/AGENTS.md) |
| Prep a demo | [demo_story_business.md](demo_story_business.md) |
| Dig into REST API discoveries | [purview_governance_inventory.md](purview_governance_inventory.md) |
| Extract Semantic Labs metadata | [SEMANTIC_LABS_FABRIC_RUNBOOK.md](SEMANTIC_LABS_FABRIC_RUNBOOK.md) |
| Understand all demo users | [demo_users.json](demo_users.json) |

---

## ✅ Pre-Demo Checklist

- [ ] Run `.\wipe_and_redeploy.ps1` or chosen sprint path
- [ ] Verify output: `.\query_governance.ps1` (should show 16 domains, 75 terms, 6 DPs)
- [ ] Launch portal: `.\run_scenario_environment.ps1`
- [ ] Test Scenario 1: Search "ESG Disclosure Metric" in KPI search
- [ ] Test Scenario 2: Drill into "Customer 360" DP → see related terms + assets
- [ ] Test Scenario 3: Check DQ tier on "fact_sale" (should be 🟢 Gold)
- [ ] Review demo script: [demo_story_business.md](demo_story_business.md)
- [ ] Dry-run the 12-minute walkthrough (take ~15 min)

---

## 🎓 Learning Path

1. **First time?** → Read [README.md](README.md) (5 min)
2. **Understand the project?** → Read [STATUS.md](STATUS.md) (10 min)
3. **Want to deploy?** → Pick a path above (25–45 min execution)
4. **Ready to demo?** → Read [demo_story_business.md](demo_story_business.md) (5 min script review)
5. **Need to troubleshoot?** → See this Quick Reference or [CONTRIBUTING.md](CONTRIBUTING.md)
6. **Deep dive on architecture?** → Read [docs/AGENTS.md](docs/AGENTS.md) (20 min)

---

**Questions?** Check [CONTRIBUTING.md](CONTRIBUTING.md) or review `.github/copilot-instructions.md` for project rules.

**Last Updated**: July 2, 2026 | **Status**: ✅ Production Ready
