# Vector Memory Policy

BAZA uses a hybrid local documentation memory:

```text
sanitized Markdown docs -> context-hub Mongo chunks -> optional local vector index
```

Mongo/context-hub remains the source of truth for project documentation. The
vector index is an optional generated retrieval layer that improves semantic
lookup, Russian/English query tolerance, and discovery of related decisions,
skills, runbooks, and module docs.

## Storage

Default generated path:

```text
.baza/docs-vector/<project-category>/index.json
```

The index is local generated data. It should not be treated as source
documentation and should not be committed unless a project explicitly decides
otherwise.

## Commands

Build an index:

```bash
python3 plugins/baza/scripts/baza_docs_vector_sync.py --root .
```

Search an index:

```bash
python3 plugins/baza/scripts/baza_docs_search.py --root . --query "<query>"
```

Make targets:

```bash
make baza-docs-vector-sync
make baza-docs-search QUERY="<query>"
make baza-docs-index
```

## Embedding Backends

Default:

```text
local-hash
```

This backend has no dependencies and gives a deterministic vector layer for
hybrid keyword/vector ranking. It is not a true semantic model, but it makes
the workflow available everywhere and supports tests.

Recommended semantic backend:

```bash
BAZA_VECTOR_BACKEND=ollama BAZA_VECTOR_MODEL=bge-m3 make baza-docs-vector-sync
```

Other local Ollama embedding models can be used, such as `nomic-embed-text`.
Do not use paid or remote embedding APIs for BAZA baseline indexing unless a
project explicitly documents that decision.

## Hybrid Search

Search combines:

- lexical score from query terms, titles, headings, keywords, and content,
- vector cosine score from the local index,
- category scoping through `project-<slug>`.

Results must show the source path, title, score, and snippet so the agent can
ground answers in documentation instead of relying on memory.

## Safety Rules

Index only sanitized Markdown under `docs/`.

Never index:

- secrets or credentials,
- raw PII,
- generated exports,
- local databases,
- browser profiles,
- cookies or storage dumps,
- HAR files,
- screenshots,
- API captures,
- packet captures,
- raw reverse-engineering artifacts.

The vector sync script skips chunks with obvious secret-like patterns, but this
is only a last line of defense. The project documentation policy remains the
primary control.

## BAZA Rule

When documentation changes materially:

1. Update Markdown docs.
2. Run `make baza-docs-index` when context-hub is available.
3. Run `make baza-docs-health` to verify Mongo and vector freshness.
4. Use `baza-docs-search` before broad file searching when answering from
   project docs.

The vector index stores the local docs hash and chunker version. If
`baza-docs-search` reports a stale index, rebuild it with
`make baza-docs-vector-sync`.
