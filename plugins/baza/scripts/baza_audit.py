#!/usr/bin/env python3
"""Audit a project for the BAZA baseline without printing sensitive content."""

import argparse
import json
import re
import sys
from pathlib import Path


REQUIRED_FILES = [
    "AGENTS.md",
    "docs/status.md",
    "docs/agents/baza.md",
    ".codex/config.toml",
    "plugins/baza/baza-manifest.toml",
    "plugins/baza/docs/orchestration-policy.md",
    "plugins/baza/docs/reverse-engineering.md",
    "plugins/baza/upstreams/registry.toml",
]

SECRET_REGEXES = [
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(r"\b\d{3}-\d{2}-\d{4}\b"),
    re.compile(r"(?i)\b(api[_-]?key|password|passwd|secret|token)\b\s*[:=]\s*[\"']?[A-Za-z0-9_./+=-]{12,}"),
    re.compile(r"(?i)\bbearer\s+[A-Za-z0-9_./+=-]{20,}"),
]


def read_text(path):
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""


def find_project_category(status_text):
    matches = re.findall(r"\bproject-[a-z0-9][a-z0-9-]*\b", status_text)
    matches = [item for item in matches if item not in {"project-bootstrap"}]
    return matches[-1] if matches else ""


def scan_docs(root):
    docs = root / "docs"
    warnings = []
    if not docs.exists():
        return warnings
    for path in sorted(docs.rglob("*.md")):
        text = read_text(path)
        for pattern in SECRET_REGEXES:
            if pattern.search(text):
                rel = path.relative_to(root)
                warnings.append(f"{rel}: contains secret-like pattern; verify it is sanitized")
                break
    return warnings


def audit(root):
    failures = []
    warnings = []

    for rel in REQUIRED_FILES:
        if not (root / rel).exists():
            failures.append(f"missing required BAZA file: {rel}")

    status = read_text(root / "docs/status.md")
    category = find_project_category(status)
    if not category:
        failures.append("docs/status.md does not declare a project-<slug> context-hub category")
    elif category == "project-replace-me":
        failures.append("docs/status.md still uses project-REPLACE_ME")

    status_lower = status.lower()
    if (
        "general/project_documentation" in status_lower
        and "must not be used" not in status_lower
        and "do not use" not in status_lower
    ):
        failures.append("docs/status.md may allow broad general/PROJECT_DOCUMENTATION context")

    agents = read_text(root / "AGENTS.md")
    if "BAZA Documentation Sync Rule" not in agents:
        warnings.append("AGENTS.md does not include the explicit BAZA Documentation Sync Rule heading")
    if "BAZA Best Practices Rule" not in agents:
        warnings.append("AGENTS.md does not include the explicit BAZA Best Practices Rule heading")

    makefile = read_text(root / "Makefile")
    for target in [
        "baza-audit",
        "baza-docs-sync",
        "baza-docs-vector-sync",
        "baza-docs-search",
        "baza-docs-index",
        "baza-docs-health",
        "baza-docs-maintenance",
        "docs-import",
        "baza-check-upstreams",
    ]:
        if f"{target}:" not in makefile:
            warnings.append(f"Makefile does not expose `{target}`")

    module_docs = list((root / "docs/modules").glob("*.md")) if (root / "docs/modules").exists() else []
    if not module_docs:
        warnings.append("docs/modules has no module docs")

    warnings.extend(scan_docs(root))
    return category, failures, warnings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="project root")
    parser.add_argument("--json", action="store_true", help="print machine-readable result")
    parser.add_argument("--strict", action="store_true", help="treat warnings as failures")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    category, failures, warnings = audit(root)
    ok = not failures and not (args.strict and warnings)

    if args.json:
        print(json.dumps({
            "ok": ok,
            "root": str(root),
            "category": category,
            "failures": failures,
            "warnings": warnings,
        }, indent=2))
    else:
        print(f"BAZA audit root: {root}")
        print(f"Project category: {category or 'missing'}")
        for item in failures:
            print(f"FAIL {item}")
        for item in warnings:
            print(f"WARN {item}")
        if ok:
            print("OK BAZA baseline checks passed")

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
