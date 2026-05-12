# BAZA Status

Last updated: 2026-05-03

## Identity

BAZA is the internal reusable Codex project bootstrap layer.

BAZA is not owned by any application project. It is developed as a global local
module and then applied to projects such as `norm1 csv`.

Global source path:

```text
$HOME/.codex/baza
```

Local project copies under `plugins/baza` are projections/adoption copies.

## Context Hub

Use only this category for BAZA documentation:

```text
project-baza
```

Do not store BAZA documentation as if it belonged to an application project's
category. Application projects should document only their adoption state and
local overrides.

## Current Version

BAZA version: 0.1.2

## Active Scope

BAZA defines:

- baseline AGENTS guidance,
- MCP-first research policy,
- orchestration rules for main thread, subagents, skills, and MCP servers,
- global best-practices policy for implementation, verification, safety, and
  maintainability,
- project documentation sync policy,
- optional local vector memory and hybrid docs search for sanitized project
  documentation,
- explicit-use reverse engineering workflows,
- explicit-use web traffic and JavaScript capture workflows,
- explicit-use JavaScript runtime provenance workflow,
- explicit-use HTTP traffic and endpoint flow analysis workflow,
- explicit-use JavaScript coverage analysis workflow,
- explicit-use capture evidence graph and run diff workflow,
- explicit-use CAPTCHA/protection observation workflow,
- guarded Cloudflare, DataDome, Akamai, reCAPTCHA, TPS-harvester, and
  Trustev/ThreatMetrix compatibility skills,
- explicit-use TLS/HTTP fingerprint tooling research workflow,
- reusable `web-traffic-capture` skill and `Web Capture Operator` role profile,
- reusable `Web Protection Analyst` role profile,
- reusable `http-traffic-analysis` skill,
- reusable `js-runtime-analysis` skill,
- reusable `js-coverage-analysis` skill,
- reusable `bot-detection-analysis` skill,
- reusable `captcha-protection-analysis` skill,
- reusable `tls-fingerprint-research` skill,
- reusable `tls-fingerprint` compatibility skill,
- reusable `baza-official-docs` skill,
- reusable `baza-source-dossier` skill,
- reusable `baza-docs-search` skill,
- official source index for Codex/OpenAI/Zed/ACP/codex-acp,
- source dossiers for repeatedly used official tools and repositories,
- TLS fingerprint tooling source dossier,
- web protection provider source dossier,
- project profile metadata,
- web capture helper scripts for dependency checks, Playwright/CDP dry-run and
  capture, evidence graph generation, run diff, script analysis, redaction,
  summarization, and verification,
- upstream repository monitoring,
- official source URL and dossier coverage checks,
- conservative adoption/init scripts,
- project projection refresh command with stale projection-file pruning,
- project projection metadata,
- local doctor command,
- audit checks,
- generic context-hub documentation importer.
- local vector docs index and hybrid search scripts.
- hash-based docs health check and context-hub maintenance scripts.

## Commands

Apply BAZA to a project:

```bash
python3 $HOME/.codex/baza/scripts/baza_init.py --root /path/to/project --category project-my-project
```

Apply BAZA with a profile:

```bash
python3 $HOME/.codex/baza/scripts/baza_init.py \
  --root /path/to/project \
  --category project-my-project \
  --profile web-app
```

Run a local BAZA health check:

```bash
make baza-doctor
```

Audit an adopted project:

```bash
make baza-audit
```

Build/search an adopted project's local docs vector index:

```bash
make baza-docs-vector-sync
make baza-docs-search QUERY="<query>"
make baza-docs-health
make baza-docs-maintenance
```

Sync BAZA's own documentation:

```bash
PROJECT_ROOT=$HOME/.codex/baza \
PROJECT_DOCS_DIR=$HOME/.codex/baza/docs \
PROJECT_DOCS_CATEGORY=project-baza \
mongosh --quiet mongodb://localhost:27017/context-hub \
  $HOME/.codex/baza/scripts/context_hub_import_project_docs.js
```
