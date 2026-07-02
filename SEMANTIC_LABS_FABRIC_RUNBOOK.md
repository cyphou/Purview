# Semantic Labs Runbook (Finance Report)

This runbook executes Semantic Labs extraction in Fabric (Python 3.10-3.12 compatible), then imports the JSON into Purview from this repo.

## Why this is needed

- `semantic-link-labs` currently supports Python `<3.13`.
- This local machine has only Python `3.14`, so extraction must run in Fabric Notebook environment.

## 1) Run in Fabric Notebook

Use a Fabric notebook attached to workspace `DDiB-FSI`.

You can import and run the ready notebook from this repo:

- `Fabric_Notebooks/SemanticLabs_FinanceReport_Metadata.ipynb`

### Cell A: install package

```python
%pip install semantic-link-labs
```

### Cell B: upload and run extractor

Upload `semantic_labs_extract_finance_report.py` to the notebook files area (or paste content in a cell), then run:

```python
!python semantic_labs_extract_finance_report.py --workspace "DDiB-FSI" --dataset "Finance Report" --out "/lakehouse/default/Files/finance_report_semantic_metadata.json"
```

### Cell C: copy output JSON to local machine

Download the file:

`/lakehouse/default/Files/finance_report_semantic_metadata.json`

Save it locally, for example:

`C:\Users\pidoudet\OneDrive - Microsoft\Boulot\PBI SME\OracleToPostgre\DemoPurview\docs\finance_report_semantic_metadata.json`

## 2) Import into Purview from this repo

From this repository folder:

```powershell
.\import_semantic_labs_metadata_to_purview.ps1 -MetadataJsonPath ".\docs\finance_report_semantic_metadata.json"
```

## 3) Verify in Purview

Open Finance Report entity and check:

- Updated dataset description includes Semantic Labs sync summary.
- `FinanceModel` table and columns contain synchronized descriptions and datatype context.
- Dataset process description includes semantic relationships/roles summary.
