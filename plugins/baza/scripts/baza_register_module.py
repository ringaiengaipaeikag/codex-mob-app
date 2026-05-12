#!/usr/bin/env python3
"""Create a sanitized docs/modules entry for a new project module."""

import argparse
import re
import sys
from datetime import date
from pathlib import Path


TEMPLATE = """# {title}

Last updated: {today}

## Purpose

Describe what this module owns.

## Entry Points

- `{entry}`

## Data Flow

Describe inputs, outputs, persistence, and side effects.

## Configuration

List sanitized config shapes only. Do not include secrets.

## Operational Notes

List run commands, rebuild/restart needs, and known failure modes.

## Verification

List narrow checks that prove this module still works.
"""


def slug(value):
    value = re.sub(r"[^a-zA-Z0-9]+", "-", value.strip().lower())
    return value.strip("-") or "module"


def title(value):
    return re.sub(r"[-_]+", " ", value).strip().title() or "Module"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("name", help="module name")
    parser.add_argument("--entry", default="path/to/file", help="primary entry point")
    parser.add_argument("--root", default=".", help="project root")
    parser.add_argument("--force", action="store_true", help="overwrite existing module doc")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    modules = root / "docs/modules"
    modules.mkdir(parents=True, exist_ok=True)
    path = modules / f"{slug(args.name)}.md"
    if path.exists() and not args.force:
        print(f"SKIP module doc already exists: {path}")
        return 0

    path.write_text(TEMPLATE.format(title=title(args.name), today=date.today().isoformat(), entry=args.entry), encoding="utf-8")
    print(f"OK wrote module doc: {path}")
    print("Next: fill the module doc, update docs/status.md if needed, then run `make baza-docs-sync`.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
