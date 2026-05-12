#!/usr/bin/env python3
"""Adopt BAZA in a new or existing project without overwriting local rules."""

import argparse
import json
import re
import shutil
import sys
from datetime import date
from datetime import datetime
from datetime import timezone
from pathlib import Path


BAZA_BLOCK = """
## BAZA Project Bootstrap

This project adopts BAZA, the local reusable Codex project bootstrap layer.
BAZA is the source of truth for baseline Codex customization across projects:
MCP-first routing, skills, subagents, orchestration rules, safety boundaries,
project documentation hygiene, and adoption/audit commands.

Use `make baza-doctor` for a full local health check, `make baza-audit` to
check baseline drift, and `make baza-docs-index` after sanitized documentation
changes.

### BAZA Documentation Sync Rule

Whenever a task adds or materially changes a module, service, pipeline stage,
agent, skill, MCP route, hook, plugin, external integration, database flow, API
surface, operational workflow, or orchestration rule, update sanitized project
documentation before finishing the task.

After updating docs, run `make baza-docs-index` when context-hub is available.
If docs sync cannot run, leave Markdown docs updated and report the sync blocker
in the final response.
"""

BEST_PRACTICES_BLOCK = """
## BAZA Best Practices Rule

All project work must follow best practices for the project's actual stack,
risk level, and existing architecture.

Use this precedence order:

1. Official documentation, source dossiers, and canonical repositories for the
   exact tools, APIs, frameworks, and versions in use.
2. Existing project architecture, style, naming, test patterns, operational
   runbooks, and security boundaries.
3. Small, maintainable, reviewable changes with the least necessary blast
   radius.
4. Secure defaults: no secret exposure, no unsafe artifact indexing, no
   broad permissions, and no live external automation without explicit scope.
5. Verification appropriate to risk: static checks, focused tests, smoke tests,
   or documented blockers when verification cannot run.
6. Documentation updates when behavior, architecture, commands, integrations,
   or operational workflows change.

Avoid vague "best practice" rewrites that do not solve the task or conflict
with local project constraints. If a best-practice choice is ambiguous, record
the tradeoff in project docs before making it durable.
"""

MAKE_BLOCK = """
BAZA ?= plugins/baza
ENTRY ?= path/to/file
QUERY ?=
VECTOR_BACKEND ?= local-hash
VECTOR_MODEL ?=

.PHONY: baza-doctor baza-audit baza-docs-sync baza-docs-vector-sync baza-docs-search baza-docs-index baza-docs-health baza-docs-maintenance baza-register-module baza-check-upstreams baza-check-official-sources baza-refresh-projection

baza-doctor:
\t$(PYTHON) $(BAZA)/scripts/baza_doctor.py --root .

baza-audit:
\t$(PYTHON) $(BAZA)/scripts/baza_audit.py

baza-docs-sync:
\t$(PYTHON) $(BAZA)/scripts/baza_docs_sync.py --mongo-uri "$(MONGO_URI)"

docs-import: baza-docs-sync

baza-docs-vector-sync:
\t$(PYTHON) $(BAZA)/scripts/baza_docs_vector_sync.py --root . --backend "$(VECTOR_BACKEND)" --model "$(VECTOR_MODEL)"

baza-docs-search:
\t@test -n "$(QUERY)" || (echo "Usage: make baza-docs-search QUERY='search terms'" && exit 1)
\t$(PYTHON) $(BAZA)/scripts/baza_docs_search.py --root . --query "$(QUERY)"

baza-docs-index:
\t$(PYTHON) $(BAZA)/scripts/baza_docs_sync.py --mongo-uri "$(MONGO_URI)" --vector --vector-backend "$(VECTOR_BACKEND)" --vector-model "$(VECTOR_MODEL)"

baza-docs-health:
\t$(PYTHON) $(BAZA)/scripts/baza_docs_health.py --root . --mongo-uri "$(MONGO_URI)"

baza-docs-maintenance:
\tmongosh --quiet "$(MONGO_URI)" $(BAZA)/scripts/context_hub_maintenance.js

baza-register-module:
\t@test -n "$(MODULE)" || (echo "Usage: make baza-register-module MODULE=<name> [ENTRY=path/to/file]" && exit 1)
\t$(PYTHON) $(BAZA)/scripts/baza_register_module.py "$(MODULE)" --entry "$(ENTRY)"

baza-check-upstreams:
\t$(PYTHON) $(BAZA)/scripts/baza_check_upstreams.py

baza-check-official-sources:
\t$(PYTHON) $(BAZA)/scripts/baza_check_official_sources.py

baza-refresh-projection:
\t$(PYTHON) $(BAZA)/scripts/baza_refresh_projection.py --root .
"""

REFRESH_TARGET_BLOCK = """
.PHONY: baza-refresh-projection

baza-refresh-projection:
\t$(PYTHON) $(BAZA)/scripts/baza_refresh_projection.py --root .
"""

DOCTOR_TARGET_BLOCK = """
.PHONY: baza-doctor

baza-doctor:
\t$(PYTHON) $(BAZA)/scripts/baza_doctor.py --root .
"""

OFFICIAL_SOURCES_TARGET_BLOCK = """
.PHONY: baza-check-official-sources

baza-check-official-sources:
\t$(PYTHON) $(BAZA)/scripts/baza_check_official_sources.py
"""

UPSTREAMS_TARGET_BLOCK = """
.PHONY: baza-check-upstreams

baza-check-upstreams:
\t$(PYTHON) $(BAZA)/scripts/baza_check_upstreams.py
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

CODEX_CONFIG_SOURCE_DOSSIER_BLOCK = """
[[skills.config]]
path = "../plugins/baza/skills/baza-source-dossier"
enabled = true
"""

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

IGNORE_DIRS = {"__pycache__", ".git"}
IGNORE_FILES = {".baza-projection.json"}
IGNORE_SUFFIXES = {".pyc"}


def slugify(value):
    value = re.sub(r"[^a-z0-9]+", "-", value.strip().lower())
    return value.strip("-") or "project"


def source_root():
    return Path(__file__).resolve().parents[1]


def manifest_version():
    manifest = source_root() / "baza-manifest.toml"
    text = manifest.read_text(encoding="utf-8") if manifest.exists() else ""
    match = re.search(r'^version\s*=\s*"([^"]+)"', text, re.MULTILINE)
    return match.group(1) if match else "unknown"


def profile_exists(profile):
    if profile == "generic":
        return True
    return (source_root() / "profiles" / f"{profile}.toml").exists()


def should_skip_projection(path):
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
        if should_skip_projection(rel):
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
        if should_skip_projection(rel):
            continue
        target = dst / rel
        if path.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
        copied.append(str(rel))
    return copied


def copy_baza(root, force):
    src = source_root()
    dst = root / "plugins" / "baza"
    if src.resolve() == dst.resolve():
        return "ok: plugins/baza is already the active BAZA source", "source"
    if dst.exists() and not force:
        removed = prune_projection(src, dst)
        copied = copy_projection(src, dst)
        return f"refreshed: plugins/baza ({len(copied)} copied, {len(removed)} removed)", "refresh"
    if dst.exists() and force:
        shutil.rmtree(dst)
    ignore = shutil.ignore_patterns("__pycache__", "*.pyc", ".DS_Store")
    shutil.copytree(src, dst, ignore=ignore)
    return "wrote: plugins/baza", "init"


def write_projection_metadata(root, category, profile, action):
    dst = root / "plugins" / "baza"
    if not dst.exists():
        return "skip: projection metadata, plugins/baza missing"
    metadata = {
        "schema": "baza-projection-v1",
        "action": action,
        "project_root": str(root),
        "source": str(source_root()),
        "refreshed_at": datetime.now(timezone.utc).isoformat(),
        "baza_version": manifest_version(),
        "context_hub_category": category,
        "profile": profile,
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
    return "wrote: plugins/baza/.baza-projection.json"


def write_if_missing(path, content, force):
    if path.exists() and not force:
        return f"exists: {path}"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return f"wrote: {path}"


def append_if_missing(path, marker, block):
    if path.exists():
        text = path.read_text(encoding="utf-8")
        if marker in text:
            return f"ok: {path} already contains {marker}"
        path.write_text(text.rstrip() + "\n\n" + block.strip() + "\n", encoding="utf-8")
        return f"updated: {path}"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(block.strip() + "\n", encoding="utf-8")
    return f"wrote: {path}"


def ensure_codex_config(root, content, force):
    path = root / ".codex" / "config.toml"
    if not path.exists() or force:
        return write_if_missing(path, content, force)
    text = path.read_text(encoding="utf-8")
    if "BAZA skills" in text:
        additions = []
        for skill_path in BAZA_SKILL_PATHS:
            if skill_path not in text:
                additions.append(f'[[skills.config]]\npath = "{skill_path}"\nenabled = true')
        if additions:
            path.write_text(text.rstrip() + "\n\n" + "\n\n".join(additions) + "\n", encoding="utf-8")
            return f"updated: {path} added missing BAZA skills"
        return f"ok: {path} already contains BAZA skills"
    path.write_text(text.rstrip() + "\n\n" + CODEX_CONFIG_SKILLS_BLOCK.strip() + "\n", encoding="utf-8")
    return f"updated: {path} added BAZA skills"


def agents_template(category):
    template = source_root() / "templates" / "AGENTS.md"
    if template.exists():
        return template.read_text(encoding="utf-8").replace("project-REPLACE_ME", category)
    return BAZA_BLOCK


def status_doc(project_name, category, profile):
    today = date.today().isoformat()
    return f"""# Project Status

Last updated: {today}

## Project

- Name: {project_name}
- Context-hub category: `{category}`
- BAZA version: {manifest_version()}
- BAZA profile: `{profile}`

## BAZA

This project follows BAZA project-scoped Codex customization.

Project work must follow the BAZA Best Practices Rule: official docs and
canonical repositories first, then local project conventions, then focused
maintainable implementation with appropriate verification.

Reverse-engineering capabilities are explicit-use only and include web traffic
capture, HTTP flow analysis, sanitized JavaScript runtime and coverage
analysis, capture evidence graphs, CAPTCHA/protection observation, guarded
provider analysis, and TLS fingerprint tooling research for authorized targets.

## Context Hub

Use only this category for project documentation:

```text
{category}
```

Do not index secrets, generated artifacts, local databases, browser profiles,
cookies, HAR files, screenshots, API captures, or raw PII.
"""


def adoption_doc(category, profile):
    today = date.today().isoformat()
    return f"""# BAZA Adoption

Last updated: {today}

## Status

BAZA version: {manifest_version()}
BAZA profile: `{profile}`

This project is BAZA-enabled.

## Project Category

```text
{category}
```

## Commands

```bash
make baza-doctor
make baza-audit
make baza-docs-sync
make baza-docs-vector-sync
make baza-docs-search QUERY="<query>"
make baza-docs-health
make baza-docs-maintenance
make baza-register-module MODULE=<name> ENTRY=<path/to/file>
make baza-check-upstreams
make baza-check-official-sources
make baza-refresh-projection
```

## Rule

New modules, services, agents, skills, MCP routes, integrations, APIs, database
flows, operational workflows, and orchestration rules require sanitized docs
updates and `make baza-docs-index`.

## Best Practices Rule

Project work must follow official documentation, canonical repositories,
project-local architecture, security boundaries, focused maintainable changes,
appropriate verification, and sanitized documentation updates.

## Local Docs Search

Use `make baza-docs-vector-sync` to build the optional local vector index from
sanitized Markdown docs, then `make baza-docs-search QUERY="<query>"` for
hybrid docs retrieval.
"""


def web_capture_gitignore():
    template = source_root() / "templates" / "web-capture.gitignore"
    if template.exists():
        return template.read_text(encoding="utf-8")
    return """# BAZA web traffic capture artifacts.
.baza/web-re/
.baza/docs-vector/
*.har
*.har.zip
*.flows
*.pcap
*.pcapng
sslkeylogfile*
playwright-trace.zip
trace.zip
browser-profile/
.playwright-mcp/
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="project root")
    parser.add_argument("--name", help="project display name")
    parser.add_argument("--category", help="project context-hub category")
    parser.add_argument("--profile", default="generic", help="BAZA project profile")
    parser.add_argument("--force", action="store_true", help="replace generated BAZA files")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.exists() or not root.is_dir():
        print(f"FAIL root is not a directory: {root}")
        return 2

    project_name = args.name or root.name
    category = args.category or f"project-{slugify(project_name)}"
    if not re.fullmatch(r"project-[a-z0-9][a-z0-9-]*", category):
        print("FAIL category must look like project-<slug>")
        return 2
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", args.profile):
        print("FAIL profile must be a simple slug")
        return 2
    if not profile_exists(args.profile):
        print(f"FAIL unknown BAZA profile: {args.profile}")
        return 2

    messages = []
    copy_message, projection_action = copy_baza(root, args.force)
    messages.append(copy_message)
    messages.append(write_if_missing(root / "AGENTS.md", agents_template(category), args.force))
    messages.append(write_if_missing(root / "docs" / "status.md", status_doc(project_name, category, args.profile), args.force))
    messages.append(write_if_missing(root / "docs" / "agents" / "baza.md", adoption_doc(category, args.profile), args.force))
    config_template = source_root() / "templates" / "codex-config.toml"
    config_content = config_template.read_text(encoding="utf-8") if config_template.exists() else 'model = "gpt-5.5"\n'
    messages.append(ensure_codex_config(root, config_content, args.force))
    messages.append(append_if_missing(root / ".gitignore", "BAZA web traffic capture artifacts", web_capture_gitignore()))
    messages.append(append_if_missing(root / "AGENTS.md", "BAZA Documentation Sync Rule", BAZA_BLOCK))
    messages.append(append_if_missing(root / "AGENTS.md", "BAZA Best Practices Rule", BEST_PRACTICES_BLOCK))
    messages.append(write_projection_metadata(root, category, args.profile, projection_action))

    makefile = root / "Makefile"
    if makefile.exists():
        text = makefile.read_text(encoding="utf-8")
        prefix = ""
        if "PYTHON ?=" not in text:
            prefix += "PYTHON ?= python3\n"
        if "MONGO_URI ?=" not in text:
            prefix += "MONGO_URI ?= mongodb://localhost:27017/context-hub\n"
        if "QUERY ?=" not in text:
            prefix += "QUERY ?=\n"
        if "VECTOR_BACKEND ?=" not in text:
            prefix += "VECTOR_BACKEND ?= local-hash\n"
        if "VECTOR_MODEL ?=" not in text:
            prefix += "VECTOR_MODEL ?=\n"
        if "baza-audit:" not in text:
            makefile.write_text((prefix + text.rstrip() + "\n\n" + MAKE_BLOCK.strip() + "\n"), encoding="utf-8")
            messages.append("updated: Makefile")
        else:
            new_text = prefix + text
            if "baza-docs-vector-sync:" not in new_text:
                new_text = new_text.rstrip() + "\n\n" + DOCS_VECTOR_TARGET_BLOCK.strip() + "\n"
                messages.append("updated: Makefile added baza-docs-vector-sync")
            if "baza-docs-search:" not in new_text:
                new_text = new_text.rstrip() + "\n\n" + DOCS_SEARCH_TARGET_BLOCK.strip() + "\n"
                messages.append("updated: Makefile added baza-docs-search")
            if "baza-docs-index:" not in new_text:
                new_text = new_text.rstrip() + "\n\n" + DOCS_INDEX_TARGET_BLOCK.strip() + "\n"
                messages.append("updated: Makefile added baza-docs-index")
            if "baza-docs-health:" not in new_text:
                new_text = new_text.rstrip() + "\n\n" + DOCS_HEALTH_TARGET_BLOCK.strip() + "\n"
                messages.append("updated: Makefile added baza-docs-health")
            if "baza-docs-maintenance:" not in new_text:
                new_text = new_text.rstrip() + "\n\n" + DOCS_MAINTENANCE_TARGET_BLOCK.strip() + "\n"
                messages.append("updated: Makefile added baza-docs-maintenance")
            if "baza-refresh-projection:" not in new_text:
                new_text = new_text.rstrip() + "\n\n" + REFRESH_TARGET_BLOCK.strip() + "\n"
                messages.append("updated: Makefile added baza-refresh-projection")
            if "baza-doctor:" not in new_text:
                new_text = new_text.rstrip() + "\n\n" + DOCTOR_TARGET_BLOCK.strip() + "\n"
                messages.append("updated: Makefile added baza-doctor")
            if "baza-check-official-sources:" not in new_text:
                new_text = new_text.rstrip() + "\n\n" + OFFICIAL_SOURCES_TARGET_BLOCK.strip() + "\n"
                messages.append("updated: Makefile added baza-check-official-sources")
            if "baza-check-upstreams:" not in new_text:
                new_text = new_text.rstrip() + "\n\n" + UPSTREAMS_TARGET_BLOCK.strip() + "\n"
                messages.append("updated: Makefile added baza-check-upstreams")
            if new_text != text:
                makefile.write_text(new_text, encoding="utf-8")
                if not messages or not messages[-1].startswith("updated: Makefile"):
                    messages.append("updated: Makefile")
            else:
                messages.append("ok: Makefile already has BAZA targets")
    else:
        makefile.write_text("PYTHON ?= python3\nMONGO_URI ?= mongodb://localhost:27017/context-hub\n\n" + MAKE_BLOCK.strip() + "\n", encoding="utf-8")
        messages.append("wrote: Makefile")

    for message in messages:
        print(message)
    print(f"project_root: {root}")
    print(f"context_hub_category: {category}")
    print("next: run `make baza-doctor`, `make baza-audit`, update docs, then run `make baza-docs-index` when context-hub is available")
    return 0


if __name__ == "__main__":
    sys.exit(main())
