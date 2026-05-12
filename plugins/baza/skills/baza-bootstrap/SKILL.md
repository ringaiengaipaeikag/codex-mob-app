---
name: baza-bootstrap
description: Use when initializing, adopting, updating, or auditing BAZA in a new or existing project. Covers AGENTS.md, docs/status.md, project context-hub category, BAZA adoption docs, Make targets, MCP-first routing, and sanitized documentation sync.
---

# BAZA Bootstrap

BAZA is the local reusable Codex project bootstrap layer.

## Workflow

1. Read `AGENTS.md`, `docs/status.md`, and `docs/agents/baza.md` when present.
2. Confirm the project has a unique context-hub category like `project-<slug>`.
3. Do not overwrite existing project rules blindly; preserve local overrides.
4. Ensure BAZA docs-sync rule is present: new modules, integrations, agents,
   skills, MCP routes, APIs, database flows, and major workflows require
   sanitized docs updates and project-scoped docs sync.
5. Run `make baza-audit` after changes when available.
6. Run `make baza-docs-sync` after documentation changes when context-hub is
   available.

## Safety

Never index or document secrets, raw PII, generated exports, local databases,
browser profiles, cookies, HARs, screenshots, API captures, or proxy/session
files.

## Useful Files

- `plugins/baza/baza-manifest.toml`
- `plugins/baza/docs/overview.md`
- `plugins/baza/docs/orchestration-policy.md`
- `plugins/baza/docs/docs-sync-policy.md`
- `plugins/baza/templates/`
