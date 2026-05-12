---
name: baza-docs-search
description: Use when searching BAZA/project local documentation, syncing sanitized Markdown docs into context-hub, building or querying the local vector docs index, comparing keyword versus semantic results, or answering from project-scoped documentation. Keep searches scoped to the active project category and never index secrets, raw captures, PII, cookies, HARs, screenshots, exports, or generated artifacts.
---

# BAZA Docs Search

Use this skill when project-local documentation should answer a question.

Primary docs:

- `plugins/baza/docs/docs-sync-policy.md`
- `plugins/baza/docs/vector-memory-policy.md`
- `plugins/baza/docs/commands.md`

Primary scripts:

- `plugins/baza/scripts/baza_docs_sync.py`
- `plugins/baza/scripts/baza_docs_health.py`
- `plugins/baza/scripts/baza_docs_vector_sync.py`
- `plugins/baza/scripts/baza_docs_search.py`

## Retrieval Order

1. Use context-hub with the active `project-<slug>` category for source-of-truth
   project docs.
2. Run `make baza-docs-health` if freshness is uncertain.
3. Use `baza_docs_search.py` when semantic/hybrid retrieval would help or when
   the user asks for local docs search.
4. Use BAZA `project-baza` docs only for BAZA itself, not for application
   project facts.
5. Fall back to shell file search only when the docs index is stale or missing.

## Commands

Build the local vector index from sanitized Markdown:

```bash
make baza-docs-vector-sync
```

Check freshness across Markdown, Mongo, and vector index:

```bash
make baza-docs-health
```

Search it:

```bash
make baza-docs-search QUERY="what changed in reverse engineering capture"
```

Direct commands:

```bash
python3 plugins/baza/scripts/baza_docs_vector_sync.py --root .
python3 plugins/baza/scripts/baza_docs_search.py --root . --query "<query>"
```

For local semantic embeddings through Ollama:

```bash
BAZA_VECTOR_BACKEND=ollama BAZA_VECTOR_MODEL=bge-m3 make baza-docs-vector-sync
```

The default backend is `local-hash`, which is dependency-free and useful for
hybrid keyword/vector ranking. Use Ollama with `bge-m3`, `nomic-embed-text`, or
another local embedding model when true semantic search is needed.

## Safety Rules

- Search and index only sanitized Markdown documentation.
- Keep raw/generated vector indexes in `.baza/docs-vector/`.
- Do not index raw HAR files, cookies, browser profiles, screenshots, exports,
  local databases, secrets, raw PII, packet captures, or API captures.
- Report stale or missing indexes instead of guessing from chat history.
