#!/usr/bin/env python3
"""Run the project's sanitized docs import through the BAZA sync path."""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path


def derive_category(root):
    status = root / "docs" / "status.md"
    if not status.exists():
        return ""
    text = status.read_text(encoding="utf-8")
    matches = re.findall(r"\bproject-[a-z0-9][a-z0-9-]*\b", text)
    matches = [item for item in matches if item not in {"project-bootstrap"}]
    return matches[-1] if matches else ""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="project root")
    parser.add_argument("--mongo-uri", default=os.environ.get("MONGO_URI", "mongodb://localhost:27017/context-hub"))
    parser.add_argument("--category", default=os.environ.get("PROJECT_DOCS_CATEGORY", ""))
    parser.add_argument("--importer", choices=["baza", "project"], default=os.environ.get("BAZA_DOCS_IMPORTER", "baza"))
    parser.add_argument("--vector", action="store_true", help="also refresh the local vector docs index after Mongo sync")
    parser.add_argument("--vector-backend", default=os.environ.get("BAZA_VECTOR_BACKEND", "local-hash"))
    parser.add_argument("--vector-model", default=os.environ.get("BAZA_VECTOR_MODEL", ""))
    args = parser.parse_args()

    root = Path(args.root).resolve()
    project_importer = root / "scripts/context_hub_import_project_docs.js"
    projected_baza_importer = root / "plugins" / "baza" / "scripts" / "context_hub_import_project_docs.js"
    local_baza_importer = Path(__file__).with_name("context_hub_import_project_docs.js")
    if args.importer == "project" and project_importer.exists():
        importer = project_importer
    elif local_baza_importer.exists():
        importer = local_baza_importer
    elif projected_baza_importer.exists():
        importer = projected_baza_importer
    elif project_importer.exists():
        importer = project_importer
    else:
        importer = local_baza_importer
    if not importer.exists():
        print(f"FAIL missing docs importer: {importer}")
        return 1

    env = os.environ.copy()
    env["MONGO_URI"] = args.mongo_uri
    env["PROJECT_ROOT"] = str(root)
    category = args.category or derive_category(root)
    if category:
        env["PROJECT_DOCS_CATEGORY"] = category

    cmd = ["mongosh", "--quiet", args.mongo_uri, str(importer)]
    print("Running BAZA docs sync via project importer")
    result = subprocess.run(cmd, cwd=root, env=env)
    if result.returncode != 0 or not args.vector:
        return result.returncode

    vector_script = root / "plugins" / "baza" / "scripts" / "baza_docs_vector_sync.py"
    if not vector_script.exists():
        vector_script = Path(__file__).with_name("baza_docs_vector_sync.py")
    vector_cmd = [
        sys.executable,
        str(vector_script),
        "--root",
        str(root),
        "--backend",
        args.vector_backend,
    ]
    if args.vector_model:
        vector_cmd.extend(["--model", args.vector_model])
    print("Running BAZA docs vector sync")
    vector_result = subprocess.run(vector_cmd, cwd=root, env=env)
    return vector_result.returncode


if __name__ == "__main__":
    sys.exit(main())
