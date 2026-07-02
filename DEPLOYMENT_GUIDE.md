# 🚀 Deployment Guide — Step-by-Step

**Microsoft Purview Unified Catalog Demo Automation**

Latest Update: July 2, 2026 | Status: ✅ Production Ready

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Setup & Environment](#setup--environment)
3. [Deployment Paths](#deployment-paths)
4. [Verification Checklist](#verification-checklist)
5. [Troubleshooting](#troubleshooting)

---

## ✅ Prerequisites

### Azure Environment
- **Microsoft Purview** account (Standard or Premium SKU)
  - Account name: `pdedemopurv` (or your own)
  - Region: West US 2 (or your region)
- **Azure subscription** with contributor or higher role
- **Entra ID** access to create demo users (optional, but recommended)

### Local Machine
- **PowerShell 7+** (Core) — not Windows PowerShell 5
  - Check: `$PSVersionTable.PSVersion`
  - Install: https://github.com/PowerShell/PowerShell/releases
  
- **Azure CLI** (latest)
  - Check: `az --version`
  - Install: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
  - Authenticate: `az login` (interactive)

- **Git** (optional, but recommended)
  - Clone: `git clone <repo-url>`

- **Node.js 18+** (for demo portal)
  - Check: `node --version`
  - Install: https://nodejs.org/
  - Verify npm: `npm --version`

### Purview Permissions
Your Azure user must have:
- **Governance Domain Creator** role in Purview
- **Data Curator** role in Purview (or roles on specific domains)
- (Or higher: Purview Resource Admin)

**To check**:
```powershell
az account show --query "user.name"
# Then in Purview portal: Settings → Access Control → verify your roles
```

### Network
- Firewall/proxy must allow:
  - `https://pdedemopurv.purview.azure.net` (Purview API)
  - `https://login.microsoftonline.com` (Entra auth)
  - `https://graph.microsoft.com` (Microsoft Graph, for user provisioning)

---

## 🔧 Setup & Environment

### Step 1: Clone Repository

```bash
git clone https://github.com/cyphou/DemoPurview.git
cd DemoPurview
```

Or download as ZIP and extract.

### Step 2: Authenticate with Azure

```powershell
# Interactive login
az login

# Verify access to Purview
az account get-access-token --resource https://purview.azure.net

# Set your subscription (if you have multiple)
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

**Should return**: `accessToken` and `expiresOn` (not an error)

### Step 3: Review Configuration

Optional: Edit the first few lines of deployment scripts to override defaults:

```powershell
# In any sprint*.ps1 or wipe_and_redeploy.ps1:
$purviewAccount = "pdedemopurv"          # Change to your account
$apiVersion = "2026-03-20-preview"       # Or latest API version
```

(Most scripts auto-detect these from Azure CLI)

### Step 4: Verify Demo Users JSON (Optional)

If you want to use pre-defined demo personas, check [demo_users.json](demo_users.json):

```json
{
  "personas": [
    {
      "name": "Maya Chen (CDO)",
      "email": "maya.chen@microsoft.com",
      "role": "Chief Data Officer",
      ...
    },
    ...
  ]
}
```

---

## 🚀 Deployment Paths

### **Option A: Full Wipe & Rebuild (Recommended for First-Time)**

**Use when**: You want a clean slate from zero.

```powershell
cd DemoPurview
.\wipe_and_redeploy.ps1
```

**What it does**:
1. Tears down all existing domains, terms, DPs, OKRs, CDEs, processes
2. Cleans up ghost/orphaned entities
3. Rebuilds everything from the Sprint definitions
4. Wires all relationships (term-term, DP-term, CDE-column)
5. Applies data quality tiers
6. Assigns owners/stewards/CDOs

**Timeline**:
- Setup: ~2 min
- Teardown: ~3 min
- Domain creation: ~3 min
- Glossary creation: ~5 min
- Data Products: ~3 min
- UC features (OKRs, CDEs, etc.): ~5 min
- Relationship wiring: ~3 min
- **Total**: ~25 minutes

**Output** (verify):
```powershell
# Verify completion:
.\query_governance.ps1
# Should show: 16 domains, 75 terms, 6 DPs, 5 OKRs, 15 CDEs
```

---

### **Option B: Incremental Build (Sprint-by-Sprint)**

**Use when**: You want to see each layer build, or you have existing data you want to preserve.

**Timeline**: ~45 minutes total

#### **Step 1: Domains (5 min)**
```powershell
.\sprint2_domains_org.ps1
```
**Creates**: 5 Lines of Business + 11 sub-domains (16 total)  
**Output**: 16 domains published with owner roles

#### **Step 2: Glossary (10 min)**
```powershell
.\sprint3_glossary.ps1
```
**Creates**: 75 glossary terms (60 sub-domain + 15 LoB umbrella)  
**Adds**: Owner, steward, CDO contacts; acronyms  
**Output**: All terms published and queryable

#### **Step 3: Data Products (8 min)**
```powershell
.\sprint4_data_products.ps1
.\enrich_data_products.ps1
```
**Creates**: 6 endorsed data products  
**Enriches**: Business descriptions (3+ paragraphs), Terms of Use URLs, documentation links  
**Output**: 6 DPs ready for demo

#### **Step 4: UC Features (8 min)**
```powershell
.\sprint5_unified_catalog.ps1
.\add_business_features.ps1
```
**Creates**: OKRs (5) with Key Results (15), CDEs (15), custom metadata (3 groups)  
**Creates**: 5 business processes with app service links  
**Output**: Full UC feature set

#### **Step 5: Relationships & Linking (10 min)**
```powershell
# DP ← → Term linking (39 relationships)
.\attach_terms_to_dps.ps1

# Term ← → Term + CDE ← → Term relationships (32 links)
.\sprint_uc_h_relationships.ps1

# CDE → CriticalDataColumn bridging (15 CDEs + 15 CDCs)
.\sprint_uc_i_critical_data_columns.ps1

# Apply DQ tier classifications (85 assets: 🟢🟡🟠)
.\sprint_uc_j_fake_data_quality.ps1
```
**Output**: Full relationship graph wired, DQ visibility

#### **Verify After Each Sprint**
```powershell
.\query_governance.ps1                  # Check counts
.\generate_dq_coverage_report.ps1       # Check DQ tiers
```

---

### **Option C: Quick Enrichment (Linking & DQ Only)**

**Use when**: You already have domains/terms/DPs and just want to add relationships and DQ tiers.

```powershell
# Bulk link DPs ← → Terms (39 relationships)
.\attach_terms_to_dps.ps1

# Add all relationships (term-term, CDE-term, etc.)
.\sprint_uc_h_relationships.ps1
.\sprint_uc_i_critical_data_columns.ps1

# Classify all assets with DQ tiers
.\sprint_uc_j_fake_data_quality.ps1
```

**Timeline**: ~10 minutes  
**Output**: Linked graph + DQ visibility on assets

---

### **Option D: Portal & Scenarios (Demo-Ready)**

**After deploying via Option A/B, launch the demo portal:**

```powershell
.\run_scenario_environment.ps1
```

**What it does**:
1. Prepares metadata and relationships in Purview
2. Generates Scenario 4 adoption evidence
3. Starts local Node.js portal on `http://localhost:7071`

**What you get**:
- ✅ Scenario 1: KPI search in Unified Catalog
- ✅ Scenario 2: Data Product drill-down
- ✅ Scenario 3: Governed Asset + DQ tier
- ✅ Scenario 4: Admin/Adoption evidence with role mappings
- ✅ Live readiness board with checks

**Stop portal**: `Ctrl+C` in terminal

---

## ✅ Verification Checklist

After **any** deployment path, verify:

### A. Domains
```powershell
.\query_governance.ps1 | grep -i "domain"
```
**Should show**: 16 domains (5 LoB + 11 subs)

### B. Glossary Terms
```powershell
.\query_governance.ps1 | grep -i "term" | wc -l
```
**Should show**: 75 terms

### C. Data Products
```powershell
.\query_governance.ps1 | grep -i "dataproduct"
```
**Should show**: 6 DPs (Customer 360, Executive Financial Dashboards, ESG Reporting, etc.)

### D. OKRs
```powershell
.\query_gov_detail.ps1 -EntityType objective
```
**Should show**: 5 OKRs with 15 Key Results total

### E. CDEs & CDCs
```powershell
.\query_gov_detail.ps1 -EntityType cde
```
**Should show**: 15 CDEs with 15 linked CriticalDataColumns

### F. DP→Term Relationships
```powershell
.\probe_dp_da.ps1
```
**Should show**: 39 DP↔Term relationships

### G. Data Quality Tiers
```powershell
.\generate_dq_coverage_report.ps1
```
**Should show**: 85 assets classified (🟢 Gold / 🟡 Silver / 🟠 Bronze)

### H. Custom Metadata
```powershell
.\query_gov_detail.ps1 -EntityType customMetadata
```
**Should show**: 3 groups (Data Product Operations, Compliance, Glossary Governance)

### I. Demo Portal
```powershell
# If deployed via Option D:
# Open browser: http://localhost:7071
# Should see 4 scenario tiles (S1, S2, S3, S4) + readiness board
```

---

## 🐛 Troubleshooting

### Issue: "az account get-access-token fails"

**Error**: `ERROR: AADSTS some_code: description`

**Solution**:
```powershell
az logout
az login
# Interactive browser window should open
```

Then retry:
```powershell
az account get-access-token --resource https://purview.azure.net
```

---

### Issue: "Not authorized for Governance Domain Creator"

**Error**: `401 Unauthorized` or `403 Forbidden` in script output

**Solution**:
1. Go to **Azure Portal** → **Purview accounts** → your account
2. Click **Access Control (IAM)**
3. Verify your Azure user has role:
   - **Governance Domain Creator** (minimum)
   - **Or Purview Resource Admin** (higher)
4. May take 5-10 min to propagate

---

### Issue: "PowerShell: File cannot be loaded because running scripts is disabled"

**Error**: `File cannot be loaded because running scripts is disabled`

**Solution**:
```powershell
# Check current policy:
Get-ExecutionPolicy

# Set to allow running local scripts:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

### Issue: "Portal won't start; npm not found"

**Error**: `npm: command not found` or `Node version too old`

**Solution**:
```bash
node --version                    # Should be 18+
npm install                       # Install dependencies
npm start                         # Start portal
# Then open: http://localhost:7071
```

---

### Issue: "DQ tiers not visible in Purview portal"

**Error**: Assets show no 🟢🟡🟠 tier

**Solution**:
```powershell
# Re-run the DQ classification script:
.\sprint_uc_j_fake_data_quality.ps1

# Then wait 2-3 min for portal to refresh
# Refresh browser: F5
```

---

### Issue: "Semantic Labs extraction fails"

**Error**: `semantic-link-labs not found` or `Python 3.13+ error`

**Solution**:
```bash
# If Python 3.13+, use Fabric notebook instead:
# 1. Open Fabric workspace DDiB-FSI
# 2. Create new notebook
# 3. Copy cells from: Fabric_Notebooks/SemanticLabs_FinanceReport_Metadata.ipynb
# 4. Run in notebook
# 5. Download JSON from /lakehouse/default/Files/
# 6. Then locally: .\import_semantic_labs_metadata_to_purview.ps1

# OR use local machine with Python 3.12 or earlier:
python --version                  # Check version
pip install -r requirements-semantic-labs.txt
python semantic_labs_extract_finance_report.py \
  --workspace "DDiB-FSI" \
  --dataset "Finance Report" \
  --out "docs/finance_report_semantic_metadata.json"
```

---

### Issue: "Relationship linking fails; 'Entity not found'"

**Error**: `404 Not Found` or `Entity not found`

**Solution**:
1. Verify entities exist:
```powershell
.\query_governance.ps1 | grep -i "term_name"  # Check term exists
.\query_governance.ps1 | grep -i "dp_name"    # Check DP exists
```

2. Re-run relationship script:
```powershell
.\sprint_uc_h_relationships.ps1
```

3. If still failing, run incremental approach:
```powershell
# Start fresh:
.\full_wipe_v3.ps1                           # Full cleanup
.\wipe_and_redeploy.ps1                      # Full rebuild
```

---

### Issue: "Tests failing locally"

**Error**: `pytest` fails with assertion errors

**Solution**:
```bash
# Check Python version:
python --version                  # Should be 3.12+

# Install dependencies:
pip install -r requirements.txt

# Run tests with verbose output:
pytest tests/ --tb=short -vv

# If specific test fails, check .github/copilot-instructions.md for conventions
```

---

## 📝 Common Configuration Changes

### Change Purview Account Name

In any script, before running:
```powershell
$purviewAccount = "your-account-name"
```

### Change API Version

```powershell
$apiVersion = "2026-04-10-preview"  # Or whatever is current
```

(Check latest at: https://learn.microsoft.com/en-us/rest/api/purview/servicrest/versioning)

### Change Subscription

```powershell
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

---

## 🎓 Next Steps After Deployment

1. ✅ **Launch demo** → `.\run_scenario_environment.ps1`
2. ✅ **Review demo script** → [demo_story_business.md](demo_story_business.md)
3. ✅ **Dry-run 12-min walkthrough** → Practice the scenes
4. ✅ **Gather stakeholders** → CDOs, LoB heads, risk officers
5. ✅ **Present** → Go through Maya's Monday Morning
6. ✅ **Collect feedback** → What resonated? What questions?

---

## 📞 Support

- **Documentation**: [README.md](README.md) | [STATUS.md](STATUS.md) | [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)
- **Demo Script**: [demo_story_business.md](demo_story_business.md)
- **Quick Commands**: [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- **Architecture**: [docs/AGENTS.md](docs/AGENTS.md)
- **Development**: [CONTRIBUTING.md](CONTRIBUTING.md)

---

**Status**: ✅ Production Ready | **Last Updated**: July 2, 2026
