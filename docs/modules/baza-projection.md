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
