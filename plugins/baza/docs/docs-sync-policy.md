# BAZA Documentation Sync Policy

BAZA requires project documentation to stay current enough that a fresh Codex
thread can resume work from files instead of relying on chat history.

## Required Updates

Update docs when any of these changes happen:

- new module, service, package, CLI, route, worker, pipeline stage, or database flow
- new agent, skill, MCP route, hook, plugin, or orchestration rule
- new external dependency or integration
- changed safety boundary, credential location, config shape, or deployment flow
- repeated operational failure that needs a runbook
- architectural decision that affects future work

## Required Files

At minimum:

- `docs/status.md` for current architecture and active setup
- `docs/modules/<module>.md` for each substantial module
- `docs/architecture.md` for architecture-level changes
- `docs/decisions/ADR-*.md` for durable decisions
- `docs/runbooks/*.md` for repeated operational failures
- `docs/agents/baza.md` for BAZA adoption state

## Sync Rule

After docs are updated, run the combined project index command:

```bash
make baza-docs-index
```

If sync cannot run because Mongo/context-hub is unavailable, state that in the
final answer and leave the Markdown docs updated.

For Mongo-only sync, use:

```bash
make baza-docs-sync
```

When the project uses local vector docs search, `make baza-docs-index` also
refreshes the generated vector index. To refresh only the vector layer:

```bash
make baza-docs-vector-sync
```

Verify freshness after documentation changes:

```bash
make baza-docs-health
```

Use hybrid search before broad file search when answering from project docs:

```bash
make baza-docs-search QUERY="<query>"
```

For projects that have not adopted BAZA yet, load it first:

```bash
python3 $HOME/.codex/baza/scripts/baza_init.py --root . --category project-my-project
```

## Sensitive Data

Never import or write secrets, raw PII, exports, local databases, generated
artifacts, browser profiles, cookies, HAR files, screenshots, API captures, or
proxy/session files into project documentation or context-hub.

The same boundary applies to vector indexing. The vector index may only be
derived from sanitized Markdown documentation.

## Freshness Rule

BAZA stores a hash manifest for each project category in context-hub. A project
is healthy when:

- local sanitized Markdown docs match the Mongo `doc_manifests.docsHash`,
- `doc_sources` and `doc_chunks` counts match the manifest,
- chunk paths are unique within the project category,
- the generated vector index, when present, has the same docs hash.

Use `make baza-docs-maintenance` to create or refresh context-hub support
indexes before relying on health checks in a new local database.
