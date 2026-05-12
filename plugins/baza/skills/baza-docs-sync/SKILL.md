---
name: baza-docs-sync
description: Use when a task adds or changes a module, service, workflow, API, database flow, agent, skill, MCP route, integration, architecture decision, or local docs retrieval setup and project documentation must be updated, synced into the project-scoped local docs database, and optionally refreshed in the local vector docs index.
---

# BAZA Docs Sync

## Required Behavior

When architecture or module surface changes:

1. Update sanitized Markdown under `docs/`.
2. Add or update `docs/modules/<module>.md` for substantial modules.
3. Update `docs/status.md` for active architecture and operational state.
4. Add an ADR under `docs/decisions/` for durable architectural decisions.
5. Run `make baza-docs-index` when available.
6. Run `make baza-docs-health` to verify Markdown, Mongo, and vector freshness.

If context-hub or Mongo is unavailable, keep Markdown docs updated and state the
sync failure in the final response.

If only Mongo sync is needed, run `make baza-docs-sync`. If only the vector
index is unavailable or stale, run:

```bash
make baza-docs-vector-sync
```

Then query it with:

```bash
make baza-docs-search QUERY="<query>"
```

If health reports missing Mongo support indexes, run:

```bash
make baza-docs-maintenance
```

## Do Not Import

Secrets, raw PII, generated exports, local DBs, cookies, HARs, screenshots,
browser profiles, API captures, proxy/session files, or config JSONs with live
credentials. The vector index must be derived only from sanitized Markdown.
