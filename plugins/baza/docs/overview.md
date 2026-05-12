# BAZA Overview

BAZA is the internal reusable Codex project bootstrap layer.

BAZA is a global local module, not a feature of any application project. Its
source of truth is:

```text
$HOME/.codex/baza
```

When a project contains `plugins/baza`, that directory is a project-local
projection/adoption copy so the project can audit and sync itself.

BAZA's own documentation belongs to context-hub category:

```text
project-baza
```

Official Codex terminology maps it to:

- Codex customization
- project-scoped Codex customization
- Codex plugin when packaged for installation

BAZA is the source of truth for the baseline every new project should receive
and every older project should adopt:

- AGENTS.md rules
- Codex config defaults
- MCP-first research routes
- skills
- subagent orchestration
- command and safety rules
- global best-practices engineering rule
- official docs and canonical repository routing
- source dossiers for reusable official-source research
- project profile metadata
- sanitized project documentation policy
- local context-hub category discipline
- optional local vector memory for hybrid semantic/keyword project docs search
- hash-based docs health checks across Markdown, context-hub, and vector index
- explicit-use reverse engineering workflows
- explicit-use web traffic and JavaScript capture workflows
- explicit-use JavaScript runtime provenance workflow
- explicit-use HTTP traffic and endpoint flow analysis workflow
- explicit-use JavaScript coverage analysis workflow
- explicit-use capture evidence graph and run diff workflow
- explicit-use CAPTCHA/protection observation workflow
- guarded Cloudflare, DataDome, Akamai, reCAPTCHA, TPS-harvester, and
  Trustev/ThreatMetrix compatibility skills
- explicit-use TLS/HTTP fingerprint tooling research workflow
- reusable `web-traffic-capture` skill and `Web Capture Operator` role profile
- reusable `Web Protection Analyst` role profile
- reusable `http-traffic-analysis` skill
- reusable `js-runtime-analysis` skill
- reusable `js-coverage-analysis` skill
- reusable `bot-detection-analysis` skill
- reusable `captcha-protection-analysis` skill
- reusable `tls-fingerprint-research` skill
- reusable `tls-fingerprint` compatibility skill
- reusable `baza-official-docs` skill
- reusable `baza-source-dossier` skill
- reusable `baza-docs-search` skill
- upstream repository monitoring for BAZA tools and skills

BAZA is not a place for secrets, API keys, exports, generated artifacts, local
databases, browser profiles, cookies, HARs, screenshots, or raw PII.

Guarded reverse-engineering skills with names such as `akamai-bypass`,
`recaptcha-solve`, and `tps-browser-harvester` are included only to force
unsafe legacy wording into safe analysis boundaries. They do not make bypass,
CAPTCHA solving, cookie harvesting, or third-party automation part of the BAZA
baseline.

## Core Contract

Every project using BAZA must have:

- `AGENTS.md`
- `docs/status.md`
- `docs/agents/baza.md`
- a unique context-hub category such as `project-my-app`
- deterministic docs import or sync command
- BAZA doctor command
- BAZA audit command
- explicit documentation sync rule for new modules and architectural changes
- explicit best-practices rule for implementation, verification, safety, and
  maintainability
- optional vector docs index command for local hybrid retrieval
- docs health and maintenance commands for freshness and Mongo support indexes

## Load BAZA Into A Project

For a new or existing project, run:

```bash
python3 $HOME/.codex/baza/scripts/baza_init.py --root /path/to/project --category project-my-project
```

Optionally choose a profile:

```bash
python3 $HOME/.codex/baza/scripts/baza_init.py \
  --root /path/to/project \
  --category project-my-project \
  --profile web-app
```

The init script is conservative:

- it copies the BAZA module into `plugins/baza` when missing,
- creates baseline docs when missing,
- appends a BAZA block to `AGENTS.md` only when needed,
- appends the BAZA Best Practices Rule to `AGENTS.md` only when needed,
- appends BAZA skill wiring to `.codex/config.toml` only when needed,
- appends Make targets only when needed,
- writes projection metadata into `plugins/baza/.baza-projection.json`,
- refreshes and prunes an existing `plugins/baza` projection when rerun,
- does not overwrite existing project files unless `--force` is used.

## Current Baseline

BAZA v0.1 intentionally does not add a self-hosted web search backend. General
web search remains available through Codex web search where configured. Research
uses specialized MCP routes first:

- GitHub MCP for repositories, code, issues, PRs, releases, commits, and CI
- OpenAI Developer Docs MCP for OpenAI, Codex, SDKs, and model behavior
- Context7 for third-party library and framework documentation
- context-hub for project-scoped local documentation
- stealth-browser for authorized/local browser and CDP inspection

BAZA now tracks external source repositories through
`upstreams/registry.toml`. Upstream monitoring is read-only by default: it can
report release or branch drift, but updates to BAZA still require review,
testing, and documentation sync.

BAZA also keeps a first-party source index in `docs/official-sources.md`.
Questions about Codex, OpenAI docs, Zed, ACP, and codex-acp should resolve
through that index and the `baza-official-docs` skill before using generic web
search.

For official tools that BAZA uses repeatedly, durable source dossiers live in
`docs/source-dossiers/`. These dossiers keep official links, current pins,
known risks, and BAZA-specific usage notes so new projects do not repeat the
same research loop.

BAZA's best-practices policy lives in `docs/best-practices-policy.md`. It
requires official-documentation-first decisions, respect for project-local
architecture and style, focused changes, secure defaults, appropriate
verification, and documentation updates when behavior changes.

BAZA's vector memory policy lives in `docs/vector-memory-policy.md`. It keeps
Mongo/context-hub as the source of truth and adds an optional generated local
index under `.baza/docs-vector/<category>/index.json` for hybrid docs search.
`baza-docs-health` compares local Markdown docs, the Mongo manifest, and the
generated vector index so agents can detect stale documentation before relying
on it.

## Upgrade Direction

BAZA should stay small at the project entry point. Detailed workflow knowledge
belongs in skills and docs; project-specific rules belong in the target
project's `AGENTS.md` and documentation.
