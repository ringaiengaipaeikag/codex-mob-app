# Local Databases

Last updated: 2026-05-12

This project uses local-only data stores. They make the gateway useful on one
developer machine, but they must not be committed or synced into public docs as
raw data.

## Documentation Database

BAZA stores sanitized Markdown documentation in local context-hub MongoDB.

Default URI:

```text
mongodb://localhost:27017/context-hub
```

Project category:

```text
project-zed-mob-app
```

Refresh the documentation database:

```bash
make baza-docs-sync
```

Check that Markdown, MongoDB, and generated indexes agree:

```bash
make baza-docs-health
```

Use scoped reads only:

```text
docs_search(category="project-zed-mob-app")
docs_read(exact_project_path)
```

Do not use broad or unscoped summaries for project-specific answers.

## Vector Index

BAZA also builds a generated local vector index from sanitized Markdown docs.

Generated path:

```text
.baza/docs-vector/project-zed-mob-app/index.json
```

Default backend:

```text
local-hash
```

Refresh the index:

```bash
make baza-docs-vector-sync
```

Search it:

```bash
make baza-docs-search QUERY="BAZA preflight"
```

Optional local semantic backend:

```bash
BAZA_VECTOR_BACKEND=ollama BAZA_VECTOR_MODEL=bge-m3 make baza-docs-vector-sync
```

The vector index is generated data. Keep it ignored.

## Project Catalog

The gateway catalog is the ignored file:

```text
config/projects.json
```

It contains local absolute paths and context-hub categories for projects the
mobile UI may control. Start from the public example:

```bash
cp config/projects.example.json config/projects.json
```

The gateway can also read recent Zed workspaces from Zed's local SQLite
database.

Default macOS path:

```text
~/Library/Application Support/Zed/db/0-stable/db.sqlite
```

Override:

```bash
ZED_MOB_ZED_DB=/path/to/db.sqlite npm run dev
```

Zed SQLite is read-only input. Imported projects are written into
`config/projects.json` only after trusted-root filtering.

## Never Commit

- `config/projects.json`
- `.zed-mob/`
- `.baza/docs-vector/`
- local MongoDB files
- Zed SQLite databases
- logs, captures, cookies, browser profiles, or uploaded images
- tokens, API keys, passwords, or credentials
