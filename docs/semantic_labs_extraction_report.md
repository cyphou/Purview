# Semantic Labs Extraction - Execution Report

**Generated:** 2026-06-02T13:55:00Z  
**Task:** Extract semantic metadata from "Finance Report" dataset

---

## ✅ Resources Created Successfully

| Resource | ID | Location |
|----------|-----|----------|
| **Notebook** | `76a29990-3e0c-4532-bbbd-a14ce1e5e489` | DDiB-FSI workspace |
| **Lakehouse** | `8bb51eb0-5507-46c3-8b08-676acacd88e1` | DDiB-FSI workspace |

**Workspace:** DDiB-FSI (`7000dcc5-3063-4dc7-99f5-965d551c2083`)

---

## ❌ Blocker: API-Based Notebook Execution Failed

**Error Code:** `System_Cancelled_Session_Statements_Failed`  
**Message:** System cancelled the Spark session due to statement execution failures

**Root Cause Analysis:**
- The Fabric REST API notebook execution fails before statements can run
- Likely causes:
  1. Spark session initialization issues
  2. `%pip install semantic-link-labs` may timeout or fail in headless API execution
  3. Notebook format incompatibility with RunNotebook job type

---

## 🔧 Manual Fallback Steps

### Step 1: Open Notebook in Fabric Portal

**Direct URL:**
```
https://app.fabric.microsoft.com/groups/7000dcc5-3063-4dc7-99f5-965d551c2083/synapsenotebooks/76a29990-3e0c-4532-bbbd-a14ce1e5e489
```

### Step 2: Verify Lakehouse Attachment
- Click the lakehouse dropdown in the notebook
- Ensure **SemanticLabsOutput** is selected as default lakehouse

### Step 3: Run All Cells
1. Cell 1: `%pip install semantic-link-labs -q` (may take 1-2 min)
2. Cell 2: Import statements and config
3. Cell 3-5: Extraction logic
4. Cell 6: Write JSON output

### Step 4: Verify Output Location

**OneLake Path:**
```
https://onelake.dfs.fabric.microsoft.com/DDiB-FSI/SemanticLabsOutput/Files/finance_report_semantic_metadata.json
```

**Alternative: Download via Azure Storage Explorer:**
- Account: `onelake.dfs.fabric.microsoft.com`
- Container: `DDiB-FSI`
- Path: `SemanticLabsOutput/Files/finance_report_semantic_metadata.json`

---

## Expected Output

After successful execution, the JSON file will contain:

```json
{
  "source": "semantic-link-labs",
  "generatedAtUtc": "2026-06-02T...",
  "workspace": "DDiB-FSI",
  "dataset": "Finance Report",
  "tables": [...],      // Table definitions with columns
  "measures": [...],    // DAX measures with expressions
  "relationships": [...], // Model relationships
  "roles": [...]        // RLS roles and permissions
}
```

---

## Post-Extraction: Import to Purview

Once JSON is downloaded to local machine:

```powershell
cd "C:\Users\pidoudet\OneDrive - Microsoft\Boulot\PBI SME\OracleToPostgre\DemoPurview"
.\import_semantic_labs_metadata_to_purview.ps1 -MetadataJsonPath ".\docs\finance_report_semantic_metadata.json"
```

---

## Summary

| Step | Status |
|------|--------|
| Locate Finance Report | ✅ Found in DDiB-FSI |
| Create Notebook | ✅ Created |
| Create Lakehouse | ✅ Created |
| Upload Notebook Code | ✅ Uploaded |
| API Execution | ❌ Blocked - Spark session failure |
| **Next Action** | Manual notebook run required |
