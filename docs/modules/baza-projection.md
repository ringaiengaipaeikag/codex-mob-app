# BAZA Projection Module

Last updated: 2026-05-12

## Purpose

This repository contains two first-class modules:

- `zed-mob-gateway`: the mobile Codex control application.
- `plugins/baza`: the project-local BAZA projection that defines how Codex work
  is routed, audited, documented, and kept safe.

BAZA is not the gateway's runtime business logic. It is the reusable Codex
project bootstrap and guardrail layer that makes the repository operable by the
maintainer and outside contributors.

## Architecture

BAZA has one global source and many project projections. In this repository:

```text
global BAZA source
        |
        v
plugins/baza/           project-local projection committed to git
docs/agents/baza.md     project adoption state and local overrides
docs/status.md          project status and active context-hub category
Makefile                local BAZA commands
.codex/config.toml      project skill wiring
```

The projection is committed so a fresh clone remains self-describing and can run
the same checks without access to the maintainer's chat history.

Generated machine-local BAZA state is intentionally ignored:

- `.baza/docs-vector/`
- `plugins/baza/.baza/`
- `plugins/baza/.baza-projection.json`

## Local Data Stores

This project uses two local data stores around BAZA and project discovery.
Both are machine-local and must stay out of git.

The contributor-facing setup guide is `docs/setup/local-databases.md`.

Documentation store:

- Backend: local MongoDB used by context-hub.
- Default URI: `mongodb://localhost:27017/context-hub`.
- Scope: sanitized Markdown from `docs/`, chunked by section and stored under
  the project category `project-zed-mob-app`.
- Write path: `make baza-docs-sync`.
- Read path: context-hub `docs_search(category="project-zed-mob-app")`, then
  `docs_read` on exact section paths.
- Health check: `make baza-docs-health`.

Project catalog store:

- Backend: Zed's local SQLite workspace database, read-only.
- Default path on macOS:
  `~/Library/Application Support/Zed/db/0-stable/db.sqlite`.
- Override: `ZED_MOB_ZED_DB=/path/to/db.sqlite`.
- Scope: recent Zed workspaces and trusted worktrees used to discover local
  projects that can be imported into the mobile gateway.
- Gateway APIs: `GET /api/projects/recent` and
  `POST /api/projects/sync-zed`.
- Import target: `config/projects.json`, the ignored gateway allowlist/catalog
  containing project id, name, path, and context-hub category.

`config/projects.json` is not committed because it contains absolute local
paths. The public template is `config/projects.example.json`.

## Documentation Indexing

BAZA uses layered local retrieval:

```text
sanitized Markdown docs
  -> context-hub MongoDB section chunks
  -> local generated vector index
  -> hybrid docs search
```

Mongo/context-hub is the source of truth for shared local documentation. The
vector index is a generated acceleration and semantic-retrieval layer.

Generated vector index path:

```text
.baza/docs-vector/<project-category>/index.json
```

For this repository:

```text
.baza/docs-vector/project-zed-mob-app/index.json
```

The default vector backend is `local-hash`, which is dependency-free and
deterministic. For stronger local semantic retrieval, BAZA supports local
Ollama embeddings:

```bash
BAZA_VECTOR_BACKEND=ollama BAZA_VECTOR_MODEL=bge-m3 make baza-docs-vector-sync
```

Recommended indexing workflow after documentation changes:

```bash
make baza-docs-sync
make baza-docs-vector-sync
make baza-docs-health
```

Use hybrid search before broad file searching when answering from project docs:

```bash
make baza-docs-search QUERY="BAZA project catalog"
```

The vector index is generated from sanitized Markdown only. Do not index or
commit local databases, runtime state, secrets, credentials, cookies, HAR files,
screenshots, exports, API captures, or raw reverse-engineering artifacts.

## What BAZA Provides Here

Contributor and agent workflow:

- root `AGENTS.md` routing rules
- project-scoped Codex configuration
- reusable Codex skills under `plugins/baza/skills/`
- task routing through MCP-first research policy
- anti-hang and orchestration policy for long-running work

Documentation and retrieval:

- sanitized project docs policy
- context-hub category discipline
- docs sync and local vector-index helpers
- section-level retrieval boundaries for large docs
- docs health and audit scripts

Research and source quality:

- official source registry
- source dossiers for recurring upstream research
- best-practices policy based on official docs, local architecture, secure
  defaults, focused changes, and appropriate verification

Safety boundaries:

- no secret indexing
- no generated artifact publication
- explicit authorization requirements for browser/capture/reverse-engineering
  workflows
- guarded compatibility skills for high-risk terminology

## How the Gateway Uses BAZA

The app treats BAZA as an enforceable preflight layer before mobile-controlled
Codex work. The gateway checks project status, runs BAZA preflight commands, and
blocks session creation or resume when severe BAZA checks fail.

Relevant app flow:

```text
mobile request
  -> allowlisted project
  -> BAZA status / preflight
  -> Codex app-server runtime
  -> streamed mobile chat
```

Preflight commands:

```bash
make baza-doctor
make baza-audit
```

When documentation changes materially:

```bash
make baza-docs-sync
```

For project discovery, the gateway reads Zed's SQLite database read-only,
filters paths through trusted roots, and writes selected projects into the
ignored local allowlist `config/projects.json`. Each imported project receives
a deterministic `project-<slug>` context-hub category unless the catalog entry
sets one explicitly.

## MCP Server Recommendations

BAZA assumes MCP-first research. Configure MCP servers globally or in the
user-level Codex/Zed environment, not in the public repository with secrets.
The contributor-facing setup guide is `docs/setup/mcp.md`.
The route registry is:

```text
$HOME/.codex/mcp-first-routes.md
$HOME/.codex/mcp-first-routes.json
```

Recommended servers for this project:

- `context_hub`: required for local project documentation search and sync.
  Always query with the active category, here `project-zed-mob-app`.
- `github`: required for repository, issue, PR, release, Actions, and CI
  inspection. Use least-privilege tokens; for publishing this repository the
  token needs repository contents write access, and workflow write access when
  `.github/workflows/` is changed.
- `openaiDeveloperDocs`: required for current Codex/OpenAI API and product
  behavior. Use it before relying on memory for version-sensitive behavior.
- `context7`: required for third-party library/framework docs. Resolve the
  library id first, then query versioned docs when relevant.
- `stealth-browser`: optional for authorized local/browser inspection,
  screenshots, DOM/network debugging, and CDP workflows.

Configuration rules:

- Keep MCP credentials in user-level config or environment variables only.
- Do not commit tokens, cookies, browser profiles, captures, local databases,
  or generated MCP artifacts.
- Keep project docs scoped to `project-zed-mob-app`; BAZA's canonical docs live
  in the separate `project-baza` context-hub category.
- Run `$HOME/.codex/bin/codex-mcp-audit` after changing global MCP setup.
- When adding a new durable route, update the global MCP route registry and
  document the project impact before relying on it in BAZA workflows.

## Public Repository Model

For GitHub contributors, the repository should be read as:

```text
Application surface:
  src/
  public/
  config/
  ios/

Codex/BAZA project surface:
  AGENTS.md
  .codex/
  Makefile
  docs/agents/
  plugins/baza/
```

Application changes should update app docs under `docs/modules/` or
`docs/architecture/` when behavior changes.

BAZA-related changes should update this file, `docs/agents/baza.md`, or
`docs/contributing/public-repo.md` when contributor workflow, routing, audits,
docs sync, or guardrails change.

## Commands

```bash
make baza-doctor
make baza-audit
make baza-docs-sync
make baza-docs-index
make baza-docs-health
make baza-docs-search QUERY="BAZA preflight"
make baza-refresh-projection
make baza-check-upstreams
make baza-check-official-sources
```

## Contributor Notes

Do not commit local generated BAZA output. The committed value is the projection
code and sanitized docs, not local databases, vector indexes, captures, logs, or
runtime state.

If context-hub is unavailable, leave Markdown docs updated and mention the sync
blocker in the PR.
