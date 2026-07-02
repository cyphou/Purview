"""
Semantic Labs metadata export for the Finance Report semantic model.

Run this in a Fabric notebook (recommended) or a Python environment that can
authenticate to Fabric and access Semantic Link Labs.

Usage (Fabric notebook cell):
  %pip install semantic-link-labs
  python semantic_labs_extract_finance_report.py \
      --workspace "DDiB-FSI" \
      --dataset "Finance Report" \
      --out "/lakehouse/default/Files/finance_report_semantic_metadata.json"
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from typing import Any, Dict, List

from sempy_labs.tom import connect_semantic_model


def _safe_str(value: Any) -> str:
    if value is None:
        return ""
    try:
        return str(value)
    except Exception:
        return ""


def _iter_collection(obj: Any) -> List[Any]:
    if obj is None:
        return []
    try:
        return list(obj)
    except Exception:
        return []


def extract_semantic_model(workspace: str, dataset: str) -> Dict[str, Any]:
    with connect_semantic_model(dataset=dataset, workspace=workspace) as tom:
        model = tom.model

        tables_out: List[Dict[str, Any]] = []
        measures_out: List[Dict[str, Any]] = []
        relationships_out: List[Dict[str, Any]] = []
        roles_out: List[Dict[str, Any]] = []

        for table in _iter_collection(getattr(model, "Tables", None)):
            t_name = _safe_str(getattr(table, "Name", None))
            t_desc = _safe_str(getattr(table, "Description", None))
            t_hidden = bool(getattr(table, "IsHidden", False))

            cols = []
            for col in _iter_collection(getattr(table, "Columns", None)):
                cols.append(
                    {
                        "name": _safe_str(getattr(col, "Name", None)),
                        "description": _safe_str(getattr(col, "Description", None)),
                        "dataType": _safe_str(getattr(col, "DataType", None)),
                        "isHidden": bool(getattr(col, "IsHidden", False)),
                        "formatString": _safe_str(getattr(col, "FormatString", None)),
                    }
                )

            hierarchies = []
            for h in _iter_collection(getattr(table, "Hierarchies", None)):
                h_levels = []
                for lvl in _iter_collection(getattr(h, "Levels", None)):
                    h_levels.append(
                        {
                            "name": _safe_str(getattr(lvl, "Name", None)),
                            "column": _safe_str(
                                getattr(getattr(lvl, "Column", None), "Name", None)
                            ),
                        }
                    )
                hierarchies.append(
                    {
                        "name": _safe_str(getattr(h, "Name", None)),
                        "description": _safe_str(getattr(h, "Description", None)),
                        "levels": h_levels,
                    }
                )

            for m in _iter_collection(getattr(table, "Measures", None)):
                measures_out.append(
                    {
                        "table": t_name,
                        "name": _safe_str(getattr(m, "Name", None)),
                        "description": _safe_str(getattr(m, "Description", None)),
                        "expression": _safe_str(getattr(m, "Expression", None)),
                        "formatString": _safe_str(getattr(m, "FormatString", None)),
                        "displayFolder": _safe_str(getattr(m, "DisplayFolder", None)),
                        "isHidden": bool(getattr(m, "IsHidden", False)),
                    }
                )

            tables_out.append(
                {
                    "name": t_name,
                    "description": t_desc,
                    "isHidden": t_hidden,
                    "columns": cols,
                    "hierarchies": hierarchies,
                }
            )

        for r in _iter_collection(getattr(model, "Relationships", None)):
            from_col = getattr(r, "FromColumn", None)
            to_col = getattr(r, "ToColumn", None)
            relationships_out.append(
                {
                    "name": _safe_str(getattr(r, "Name", None)),
                    "description": _safe_str(getattr(r, "Description", None)),
                    "fromTable": _safe_str(getattr(getattr(from_col, "Table", None), "Name", None)),
                    "fromColumn": _safe_str(getattr(from_col, "Name", None)),
                    "toTable": _safe_str(getattr(getattr(to_col, "Table", None), "Name", None)),
                    "toColumn": _safe_str(getattr(to_col, "Name", None)),
                    "crossFilteringBehavior": _safe_str(
                        getattr(r, "CrossFilteringBehavior", None)
                    ),
                    "isActive": bool(getattr(r, "IsActive", True)),
                }
            )

        for role in _iter_collection(getattr(model, "Roles", None)):
            table_perms = []
            for p in _iter_collection(getattr(role, "TablePermissions", None)):
                table_perms.append(
                    {
                        "table": _safe_str(getattr(getattr(p, "Table", None), "Name", None)),
                        "filterExpression": _safe_str(getattr(p, "FilterExpression", None)),
                    }
                )
            roles_out.append(
                {
                    "name": _safe_str(getattr(role, "Name", None)),
                    "description": _safe_str(getattr(role, "Description", None)),
                    "modelPermission": _safe_str(getattr(role, "ModelPermission", None)),
                    "tablePermissions": table_perms,
                }
            )

        return {
            "source": "semantic-link-labs",
            "generatedAtUtc": datetime.now(timezone.utc).isoformat(),
            "workspace": workspace,
            "dataset": dataset,
            "tables": tables_out,
            "measures": measures_out,
            "relationships": relationships_out,
            "roles": roles_out,
        }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Export semantic metadata from a Fabric semantic model using Semantic Labs."
    )
    parser.add_argument("--workspace", required=True, help="Fabric workspace name")
    parser.add_argument("--dataset", required=True, help="Semantic model/dataset name")
    parser.add_argument("--out", required=True, help="Output JSON path")
    args = parser.parse_args()

    payload = extract_semantic_model(workspace=args.workspace, dataset=args.dataset)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

    print(f"Exported semantic metadata to: {args.out}")
    print(f"Tables: {len(payload['tables'])}")
    print(f"Measures: {len(payload['measures'])}")
    print(f"Relationships: {len(payload['relationships'])}")
    print(f"Roles: {len(payload['roles'])}")


if __name__ == "__main__":
    main()
