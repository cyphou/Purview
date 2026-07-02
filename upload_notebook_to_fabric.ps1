# Upload notebook definition to Fabric
param(
    [string]$WorkspaceId = "7000dcc5-3063-4dc7-99f5-965d551c2083",
    [string]$NotebookId = "76a29990-3e0c-4532-bbbd-a14ce1e5e489",
    [string]$LakehouseId = "8bb51eb0-5507-46c3-8b08-676acacd88e1"
)

$ErrorActionPreference = "Stop"

# Get token
$token = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

# Notebook content in .py format
$notebookContent = @"
# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "$LakehouseId",
# META       "default_lakehouse_name": "SemanticLabsOutput",
# META       "default_lakehouse_workspace_id": "$WorkspaceId"
# META     }
# META   }
# META }

# MARKDOWN ********************

# # Semantic Labs Metadata Export - Finance Report

# CELL ********************

%pip install semantic-link-labs -q

# CELL ********************

import json
from datetime import datetime, timezone
from sempy_labs.tom import connect_semantic_model

WORKSPACE = "DDiB-FSI"
DATASET = "Finance Report"
OUT_PATH = "/lakehouse/default/Files/finance_report_semantic_metadata.json"

def _safe_str(value):
    return "" if value is None else str(value) if value else ""

def _iter_collection(obj):
    return list(obj) if obj else []

# CELL ********************

tables_out, measures_out, relationships_out, roles_out = [], [], [], []

with connect_semantic_model(dataset=DATASET, workspace=WORKSPACE) as tom:
    model = tom.model
    for table in _iter_collection(getattr(model, "Tables", None)):
        t_name = _safe_str(getattr(table, "Name", None))
        cols = [{"name": _safe_str(getattr(c, "Name", None)), "description": _safe_str(getattr(c, "Description", None)), "dataType": _safe_str(getattr(c, "DataType", None)), "isHidden": bool(getattr(c, "IsHidden", False)), "formatString": _safe_str(getattr(c, "FormatString", None))} for c in _iter_collection(getattr(table, "Columns", None))]
        hierarchies = [{"name": _safe_str(getattr(h, "Name", None)), "description": _safe_str(getattr(h, "Description", None)), "levels": [{"name": _safe_str(getattr(l, "Name", None)), "column": _safe_str(getattr(getattr(l, "Column", None), "Name", None))} for l in _iter_collection(getattr(h, "Levels", None))]} for h in _iter_collection(getattr(table, "Hierarchies", None))]
        for m in _iter_collection(getattr(table, "Measures", None)):
            measures_out.append({"table": t_name, "name": _safe_str(getattr(m, "Name", None)), "description": _safe_str(getattr(m, "Description", None)), "expression": _safe_str(getattr(m, "Expression", None)), "formatString": _safe_str(getattr(m, "FormatString", None)), "displayFolder": _safe_str(getattr(m, "DisplayFolder", None)), "isHidden": bool(getattr(m, "IsHidden", False))})
        tables_out.append({"name": t_name, "description": _safe_str(getattr(table, "Description", None)), "isHidden": bool(getattr(table, "IsHidden", False)), "columns": cols, "hierarchies": hierarchies})
    for r in _iter_collection(getattr(model, "Relationships", None)):
        fc, tc = getattr(r, "FromColumn", None), getattr(r, "ToColumn", None)
        relationships_out.append({"name": _safe_str(getattr(r, "Name", None)), "fromTable": _safe_str(getattr(getattr(fc, "Table", None), "Name", None)), "fromColumn": _safe_str(getattr(fc, "Name", None)), "toTable": _safe_str(getattr(getattr(tc, "Table", None), "Name", None)), "toColumn": _safe_str(getattr(tc, "Name", None)), "crossFilteringBehavior": _safe_str(getattr(r, "CrossFilteringBehavior", None)), "isActive": bool(getattr(r, "IsActive", True))})
    for role in _iter_collection(getattr(model, "Roles", None)):
        roles_out.append({"name": _safe_str(getattr(role, "Name", None)), "description": _safe_str(getattr(role, "Description", None)), "modelPermission": _safe_str(getattr(role, "ModelPermission", None)), "tablePermissions": [{"table": _safe_str(getattr(getattr(p, "Table", None), "Name", None)), "filterExpression": _safe_str(getattr(p, "FilterExpression", None))} for p in _iter_collection(getattr(role, "TablePermissions", None))]})

# CELL ********************

payload = {"source": "semantic-link-labs", "generatedAtUtc": datetime.now(timezone.utc).isoformat(), "workspace": WORKSPACE, "dataset": DATASET, "tables": tables_out, "measures": measures_out, "relationships": relationships_out, "roles": roles_out}
with open(OUT_PATH, "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False, indent=2)
print(f"Wrote: {OUT_PATH}")
print(f"Tables: {len(payload['tables'])}")
print(f"Measures: {len(payload['measures'])}")
print(f"Relationships: {len(payload['relationships'])}")
print(f"Roles: {len(payload['roles'])}")
"@

# Convert to base64
$bytes = [System.Text.Encoding]::UTF8.GetBytes($notebookContent)
$base64Content = [Convert]::ToBase64String($bytes)

# Build definition payload
$definitionBody = @{
    definition = @{
        parts = @(
            @{
                path = "notebook-content.py"
                payload = $base64Content
                payloadType = "InlineBase64"
            }
        )
    }
} | ConvertTo-Json -Depth 10

Write-Host "Uploading notebook definition..."
$uri = "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/notebooks/$NotebookId/updateDefinition"

try {
    $response = Invoke-WebRequest -Uri $uri -Headers $headers -Method Post -Body $definitionBody
    Write-Host "Success! Status: $($response.StatusCode)" -ForegroundColor Green
    
    # Check for long-running operation
    if ($response.Headers["Location"]) {
        $operationUrl = $response.Headers["Location"][0]
        Write-Host "Operation URL: $operationUrl"
        
        # Poll for completion
        $maxAttempts = 30
        for ($i = 0; $i -lt $maxAttempts; $i++) {
            Start-Sleep -Seconds 2
            $opStatus = Invoke-RestMethod -Uri $operationUrl -Headers $headers -Method Get
            Write-Host "Status: $($opStatus.status)"
            if ($opStatus.status -eq "Succeeded") {
                Write-Host "Notebook definition updated successfully!" -ForegroundColor Green
                break
            } elseif ($opStatus.status -eq "Failed") {
                Write-Host "Failed: $($opStatus | ConvertTo-Json)" -ForegroundColor Red
                break
            }
        }
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Host $reader.ReadToEnd()
    }
}
