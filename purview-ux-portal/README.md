# Purview Scenario Environment (Local)

Business-friendly scenario environment (S1 to S4), backed by live Purview APIs and preflight preparation scripts.

## What it provides

- Scenario-first live guide (S1 KPI, S2 Domain/DP, S3 Governed Asset, S4 Roles/Adoption)
- Scenario readiness board with real checks against Purview and evidence artifacts
- KPI and governed-asset search on catalog API
- Data product and linked assets drill-down
- Scenario 4 evidence loading from generated docs artifacts

## Prerequisites

- Node.js 18+
- Azure CLI logged in with access to Purview tenant

## One-command run (recommended)

From repository root:

```powershell
.\run_scenario_environment.ps1
```

This will:
1. Prepare metadata/relationships for scenarios
2. Regenerate scenario 4 evidence artifacts
3. Start the portal

## Preparation only

```powershell
.\prepare_scenario_environment.ps1
```

Options:
- `-SkipMetadata`
- `-SkipEvidence`

Status artifact generated:
- `docs/scenario_environment_status.json`

## Manual run (portal only)

1. Open a terminal in this folder.
2. Install dependencies:

```bash
npm install
```

3. Start the portal:

```bash
npm start
```

4. Open:

```text
http://localhost:7071
```

## Configuration

Optional environment variables:

- `PURVIEW_ACCOUNT_NAME` (default: `pdedemopurv`)
- `PURVIEW_API_VERSION` (default: `2026-03-20-preview`)
- `PORT` (default: `7071`)

Example PowerShell:

```powershell
$env:PURVIEW_ACCOUNT_NAME = "pdedemopurv"
$env:PURVIEW_API_VERSION = "2026-03-20-preview"
$env:PORT = "7071"
npm start
```

## Notes

- Backend gets a token via `az account get-access-token --resource https://purview.azure.net`.
- If token retrieval fails, run `az login` first.
- This is local-first and scenario-ready for demos; for enterprise production hosting, add Entra auth and secrets management.
