#!/usr/bin/env python3
"""Refresh a project's plugins/baza projection from the global BAZA source."""

import argparse
import json
import shutil
import sys
import tomllib
from datetime import datetime
from datetime import timezone
from pathlib import Path


IGNORE_DIRS = {"__pycache__", ".git"}
IGNORE_FILES = {".baza-projection.json"}
IGNORE_SUFFIXES = {".pyc"}
GLOBAL_SOURCE = Path.home() / ".codex" / "baza"
BAZA_SKILL_PATHS = [
    "../plugins/baza/skills/baza-official-docs",
    "../plugins/baza/skills/baza-source-dossier",
    "../plugins/baza/skills/baza-docs-search",
    "../plugins/baza/skills/baza-bootstrap",
    "../plugins/baza/skills/baza-docs-sync",
    "../plugins/baza/skills/baza-orchestration",
    "../plugins/baza/skills/web-traffic-capture",
    "../plugins/baza/skills/http-traffic-analysis",
    "../plugins/baza/skills/js-runtime-analysis",
    "../plugins/baza/skills/js-coverage-analysis",
    "../plugins/baza/skills/tls-fingerprint-research",
    "../plugins/baza/skills/tls-fingerprint",
    "../plugins/baza/skills/captcha-protection-analysis",
    "../plugins/baza/skills/bot-detection-analysis",
    "../plugins/baza/skills/cloudflare-analysis",
    "../plugins/baza/skills/datadome-analysis",
    "../plugins/baza/skills/trustev-fingerprint",
    "../plugins/baza/skills/akamai-bypass",
    "../plugins/baza/skills/recaptcha-solve",
    "../plugins/baza/skills/tps-browser-harvester",
]
CODEX_CONFIG_SKILLS_BLOCK = """
# BAZA skills. Paths are relative to this .codex/config.toml file.
[[skills.config]]
path = "../plugins/baza/skills/baza-official-docs"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/baza-source-dossier"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/baza-docs-search"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/baza-bootstrap"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/baza-docs-sync"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/baza-orchestration"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/web-traffic-capture"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/http-traffic-analysis"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/js-runtime-analysis"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/js-coverage-analysis"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/tls-fingerprint-research"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/tls-fingerprint"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/captcha-protection-analysis"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/bot-detection-analysis"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/cloudflare-analysis"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/datadome-analysis"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/trustev-fingerprint"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/akamai-bypass"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/recaptcha-solve"
enabled = true

[[skills.config]]
path = "../plugins/baza/skills/tps-browser-harvester"
enabled = true
"""

DOCS_VECTOR_TARGET_BLOCK = """
.PHONY: baza-docs-vector-sync

baza-docs-vector-sync:
\t$(PYTHON) $(BAZA)/scripts/baza_docs_vector_sync.py --root . --backend "$(VECTOR_BACKEND)" --model "$(VECTOR_MODEL)"
"""

DOCS_SEARCH_TARGET_BLOCK = """
.PHONY: baza-docs-search

baza-docs-search:
\t@test -n "$(QUERY)" || (echo "Usage: make baza-docs-search QUERY='search terms'" && exit 1)
\t$(PYTHON) $(BAZA)/scripts/baza_docs_search.py --root . --query "$(QUERY)"
"""

DOCS_INDEX_TARGET_BLOCK = """
.PHONY: baza-docs-index

baza-docs-index:
\t$(PYTHON) $(BAZA)/scripts/baza_docs_sync.py --mongo-uri "$(MONGO_URI)" --vector --vector-backend "$(VECTOR_BACKEND)" --vector-model "$(VECTOR_MODEL)"
"""

DOCS_HEALTH_TARGET_BLOCK = """
.PHONY: baza-docs-health

baza-docs-health:
\t$(PYTHON) $(BAZA)/scripts/baza_docs_health.py --root . --mongo-uri "$(MONGO_URI)"
"""

DOCS_MAINTENANCE_TARGET_BLOCK = """
.PHONY: baza-docs-maintenance

baza-docs-maintenance:
\tmongosh --quiet "$(MONGO_URI)" $(BAZA)/scripts/context_hub_maintenance.js
"""


def source_root():
    return Path(__file__).resolve().parents[1]


def default_source():
    if (GLOBAL_SOURCE / "baza-manifest.toml").exists():
        return GLOBAL_SOURCE
    return source_root()


def should_skip(path):
    if any(part in IGNORE_DIRS for part in path.parts):
        return True
    if path.name in IGNORE_FILES:
        return True
    if path.suffix in IGNORE_SUFFIXES:
        return True
    return False


def prune_projection(src, dst):
    removed = []
    if not dst.exists():
        return removed
    for path in sorted(dst.rglob("*"), key=lambda item: len(item.parts), reverse=True):
        rel = path.relative_to(dst)
        if should_skip(rel):
            continue
        if (src / rel).exists():
            continue
        if path.is_dir():
            try:
                path.rmdir()
            except OSError:
                continue
            removed.append(str(rel) + "/")
        else:
            path.unlink()
            removed.append(str(rel))
    return sorted(removed)


def copy_projection(src, dst):
    copied = []
    for path in sorted(src.rglob("*")):
        rel = path.relative_to(src)
        if should_skip(rel):
            continue
        target = dst / rel
        if path.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
        copied.append(str(rel))
    return copied


def manifest_version(src):
    manifest = src / "baza-manifest.toml"
    if not manifest.exists():
        return "unknown"
    with manifest.open("rb") as fh:
        return tomllib.load(fh).get("version", "unknown")


def write_projection_metadata(root, src, dst, copied, removed):
    metadata = {
        "schema": "baza-projection-v1",
        "action": "refresh",
        "project_root": str(root),
        "source": str(src),
        "projection": str(dst),
        "refreshed_at": datetime.now(timezone.utc).isoformat(),
        "baza_version": manifest_version(src),
        "copied_file_count": len(copied),
        "copied_files": copied,
        "removed_file_count": len(removed),
        "removed_files": removed,
        "capabilities": [
            "mcp-first-research",
            "official-source-index",
            "source-dossiers",
            "best-practices-policy",
            "orchestration-policy",
            "project-docs-sync",
            "project-docs-health",
            "project-docs-vector-search",
            "reverse-engineering",
            "upstream-monitoring",
            "web-traffic-capture",
            "http-traffic-analysis",
            "js-runtime-analysis",
            "js-coverage-analysis",
            "tls-fingerprint-research",
            "tls-fingerprint",
            "captcha-protection-analysis",
            "bot-detection-analysis",
            "guarded-provider-analysis",
            "capture-evidence-graph",
        ],
    }
    path = dst / ".baza-projection.json"
    path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    return path


def ensure_codex_skills(root):
    path = root / ".codex" / "config.toml"
    if not path.exists():
        return "skip: .codex/config.toml missing"
    text = path.read_text(encoding="utf-8")
    if "BAZA skills" not in text:
        path.write_text(text.rstrip() + "\n\n" + CODEX_CONFIG_SKILLS_BLOCK.strip() + "\n", encoding="utf-8")
        return "updated: .codex/config.toml added BAZA skills"
    additions = []
    for skill_path in BAZA_SKILL_PATHS:
        if skill_path not in text:
            additions.append(f'[[skills.config]]\npath = "{skill_path}"\nenabled = true')
    if not additions:
        return "ok: .codex/config.toml already contains all BAZA skills"
    path.write_text(text.rstrip() + "\n\n" + "\n\n".join(additions) + "\n", encoding="utf-8")
    return "updated: .codex/config.toml added missing BAZA skills"


def ensure_make_targets(root):
    path = root / "Makefile"
    if not path.exists():
        return "skip: Makefile missing"
    text = path.read_text(encoding="utf-8")
    prefix = ""
    if "QUERY ?=" not in text:
        prefix += "QUERY ?=\n"
    if "VECTOR_BACKEND ?=" not in text:
        prefix += "VECTOR_BACKEND ?= local-hash\n"
    if "VECTOR_MODEL ?=" not in text:
        prefix += "VECTOR_MODEL ?=\n"
    new_text = prefix + text
    added = []
    if "baza-docs-vector-sync:" not in new_text:
        new_text = new_text.rstrip() + "\n\n" + DOCS_VECTOR_TARGET_BLOCK.strip() + "\n"
        added.append("baza-docs-vector-sync")
    if "baza-docs-search:" not in new_text:
        new_text = new_text.rstrip() + "\n\n" + DOCS_SEARCH_TARGET_BLOCK.strip() + "\n"
        added.append("baza-docs-search")
    if "baza-docs-index:" not in new_text:
        new_text = new_text.rstrip() + "\n\n" + DOCS_INDEX_TARGET_BLOCK.strip() + "\n"
        added.append("baza-docs-index")
    if "baza-docs-health:" not in new_text:
        new_text = new_text.rstrip() + "\n\n" + DOCS_HEALTH_TARGET_BLOCK.strip() + "\n"
        added.append("baza-docs-health")
    if "baza-docs-maintenance:" not in new_text:
        new_text = new_text.rstrip() + "\n\n" + DOCS_MAINTENANCE_TARGET_BLOCK.strip() + "\n"
        added.append("baza-docs-maintenance")
    if new_text == text:
        return "ok: Makefile already contains BAZA docs vector targets"
    path.write_text(new_text, encoding="utf-8")
    return "updated: Makefile added " + ", ".join(added or ["BAZA docs vector variables"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="project root")
    parser.add_argument("--source", default=str(default_source()), help="global BAZA source")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    src = Path(args.source).expanduser().resolve()
    dst = root / "plugins" / "baza"

    if not src.exists() or not (src / "baza-manifest.toml").exists():
        print(f"FAIL source is not a BAZA root: {src}")
        return 2
    if src == dst.resolve():
        print("OK plugins/baza is already the global BAZA source")
        return 0
    if not root.exists() or not root.is_dir():
        print(f"FAIL root is not a directory: {root}")
        return 2

    dst.mkdir(parents=True, exist_ok=True)
    removed = prune_projection(src, dst)
    copied = copy_projection(src, dst)
    metadata_path = write_projection_metadata(root, src, dst, copied, removed)
    codex_config_status = ensure_codex_skills(root)
    makefile_status = ensure_make_targets(root)
    print(f"project_root: {root}")
    print(f"source: {src}")
    print(f"projection: {dst}")
    print(f"copied_files: {len(copied)}")
    print(f"removed_files: {len(removed)}")
    print(f"metadata: {metadata_path}")
    print(codex_config_status)
    print(makefile_status)
    print("next: run `make baza-audit` and `make baza-docs-index` when docs changed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
