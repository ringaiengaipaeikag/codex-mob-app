# Applying BAZA To Projects

BAZA is applied to projects, but it is not part of those projects' business
logic.

Use this command from any location:

```bash
python3 $HOME/.codex/baza/scripts/baza_init.py --root /path/to/project --category project-my-project
```

The command creates or updates:

- `plugins/baza`
- `AGENTS.md`
- `docs/status.md`
- `docs/agents/baza.md`
- `.codex/config.toml`
- `.gitignore` web-capture and docs-vector generated artifact rules
- `Makefile` BAZA targets

It also appends the `BAZA Best Practices Rule` to `AGENTS.md` when missing.
For existing `.codex/config.toml` files, it appends any missing BAZA skill
entries without replacing project-local config.

It does not overwrite project-owned files unless `--force` is provided. When
`plugins/baza` already exists, it refreshes that projection from the global BAZA
source and removes stale projection files that no longer exist globally.

The `.gitignore` block protects raw web-capture artifacts such as HAR files,
proxy flows, packet captures, browser profiles, traces, TLS key logs, and the
generated `.baza/docs-vector/` index.

When the global BAZA source changes after a project was already initialized,
refresh only the project projection:

```bash
make baza-refresh-projection
```

This updates `plugins/baza` and prunes stale projection files while preserving
project-specific documentation and instructions outside `plugins/baza`.
It also appends newly added BAZA skill entries to an existing
`.codex/config.toml` without replacing project-local settings.

## Existing Projects

For an older project:

1. Run `baza_init.py`.
2. Inspect `AGENTS.md`, `docs/status.md`, and `docs/agents/baza.md`.
3. Confirm `AGENTS.md` contains `BAZA Best Practices Rule`.
4. Record local overrides.
5. Run `make baza-audit`.
6. Update sanitized project docs.
7. Run `make baza-docs-maintenance` once per local context-hub database.
8. Run `make baza-docs-index`.
9. Run `make baza-docs-health`.

## New Projects

For a new project:

1. Create the project directory.
2. Run `baza_init.py` with a unique `project-<slug>` category.
3. Add project-specific docs.
4. Run `make baza-audit`.
5. Run `make baza-docs-index` when context-hub is available.
6. Run `make baza-docs-health`.

## Adoption Docs

Each project documents only:

- BAZA version applied,
- project context-hub category,
- local overrides,
- project-specific safety boundaries,
- project-specific best-practices constraints when stricter than BAZA,
- project-specific skills, agents, and MCP additions.

General BAZA design belongs in category `project-baza`.
