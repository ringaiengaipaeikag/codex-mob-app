# BAZA Architecture

BAZA has one global source and many project projections.

```text
$HOME/.codex/baza
  -> source of truth for BAZA

project-root/plugins/baza
  -> project-local projection copied by baza_init.py

project-root/docs/agents/baza.md
  -> adoption state and local overrides for that project

project-root/docs/status.md
  -> project status, including BAZA adoption and project context-hub category

project-root/plugins/baza/.baza-projection.json
  -> metadata for the local projection copied from the global BAZA source
```

## Source Of Truth

The global source is `$HOME/.codex/baza`.

Project-local copies exist so a project remains self-describing and can run
`make baza-audit`, `make baza-docs-index`, and `make baza-register-module`
without depending on chat history.

Project `.codex/config.toml` should enable the BAZA skills in
`plugins/baza/skills` so the adoption copy is usable from future Codex sessions.

## Documentation Categories

BAZA documentation:

```text
project-baza
```

Project documentation:

```text
project-<project-slug>
```

For example, `norm1 csv` uses:

```text
project-norm1-csv
```

That category documents how `norm1 csv` applies BAZA. It is not the BAZA source
category.

## Main Components

- `baza-manifest.toml` - module metadata and policy flags.
- `.codex-plugin/plugin.json` - plugin-style metadata.
- `docs/` - BAZA's own source documentation.
- `docs/best-practices-policy.md` - global engineering quality rule for all
  BAZA-adopted projects.
- `docs/official-sources.md` - official docs and repository quick access.
- `docs/vector-memory-policy.md` - optional hybrid vector index policy for
  sanitized project documentation.
- `docs/source-dossiers/` - durable source cards for official tools and repos.
- `docs/capture-evidence-graph.md` - sanitized graph and run diff workflow for
  web capture evidence.
- `docs/js-runtime-analysis.md` - sanitized JavaScript API provenance workflow.
- `docs/web-protection-analysis.md` - explicit CAPTCHA/protection observation
  workflow.
- `docs/tls-fingerprint-tooling.md` - explicit TLS/HTTP fingerprint tooling
  research workflow.
- `official-sources/registry.toml` - machine-readable official source registry.
- `profiles/` - lightweight adoption presets for different project types.
- `skills/` - reusable BAZA skills.
- `templates/codex-config.toml` - baseline Codex config that enables BAZA
  skills from a project-local projection.
- `upstreams/registry.toml` - external repository registry for tracked BAZA
  source material.
- `scripts/baza_init.py` - conservative adoption/init script.
- `scripts/baza_doctor.py` - local environment and projection health check.
- `scripts/baza_audit.py` - project baseline audit.
- `scripts/baza_docs_sync.py` - project docs sync wrapper.
- `scripts/baza_docs_health.py` - freshness check across Markdown docs,
  context-hub manifests, and generated vector indexes.
- `scripts/baza_docs_vector_sync.py` - local vector index builder for
  sanitized Markdown docs.
- `scripts/baza_docs_search.py` - hybrid lexical/vector docs search over the
  local generated index.
- `scripts/baza_check_upstreams.py` - read-only upstream drift checker.
- `scripts/baza_check_official_sources.py` - read-only official source URL and
  dossier coverage checker.
- `scripts/context_hub_import_project_docs.js` - generic Markdown importer.
- `scripts/context_hub_maintenance.js` - Mongo support indexes for project
  documentation sources, chunks, and manifests.
- `templates/` - baseline project files.

## Sections

- Best practices: official-doc-first, project-convention-first, secure,
  focused, verified, documented engineering work.
- Reverse engineering: explicit-use workflows for authorized reverse
  engineering, Android APK/API extraction, web traffic capture, JavaScript
  runtime capture, HTTP flow analysis, JavaScript coverage analysis, capture
  evidence graphs, CAPTCHA/protection observation, guarded provider analysis,
  TLS/HTTP fingerprint tooling research, and related safety policy.
- Upstream monitoring: read-only tracking of external repositories used by
  BAZA tools, skills, scripts, MCP routes, or documentation.
- Web traffic capture pipeline: explicit-use orchestration for Playwright,
  Chrome DevTools Protocol, mitmproxy, optional packet capture, redaction,
  reviewer handoff, and sanitized docs sync.
- Official sources: first-party routing for OpenAI/Codex, Zed, ACP,
  codex-acp, and canonical GitHub evidence.
- Source dossiers: reusable local summaries for official tools and repositories
  that BAZA depends on.
- Vector memory: optional local generated index for semantic/hybrid retrieval
  over sanitized project docs, scoped by `project-<slug>`.
- Docs health: hash-based checks proving that local Markdown, Mongo
  context-hub, and generated vector indexes agree before agents rely on them.
- Project profiles: metadata that helps choose relevant BAZA workflows without
  granting permissions or overwriting project-specific rules.

## Safety Model

BAZA does not own or store project secrets. It only stores reusable policy,
templates, scripts, and sanitized documentation.

Project docs imported through BAZA must exclude secrets, raw PII, generated
artifacts, local databases, exports, browser profiles, cookies, HAR files,
screenshots, and API captures.

The generated vector index under `.baza/docs-vector/` is derived only from
sanitized Markdown docs and should remain ignored by default.
