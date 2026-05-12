# BAZA Adoption

Last updated: 2026-05-03

## Status

BAZA version: 0.1.0
BAZA profile: `mobile-app`

This project is BAZA-enabled.

Projection refreshed: 2026-05-03.

Current projection includes MCP-first research policy, official source index,
source dossiers, best-practices policy, orchestration policy, docs sync,
upstream monitoring, reverse-engineering policy, web traffic capture helpers,
BAZA skills, raw capture artifact `.gitignore` rules, and projection refresh
metadata.

## Project Category

```text
project-zed-mob-app
```

## Commands

```bash
make baza-doctor
make baza-audit
make baza-docs-sync
make baza-register-module MODULE=<name> ENTRY=<path/to/file>
make baza-check-upstreams
make baza-check-official-sources
make baza-refresh-projection
```

## Rule

New modules, services, agents, skills, MCP routes, integrations, APIs, database
flows, operational workflows, and orchestration rules require sanitized docs
updates and `make baza-docs-sync`.

## Best Practices Rule

Project work must follow official documentation, canonical repositories,
project-local architecture, security boundaries, focused maintainable changes,
appropriate verification, and sanitized documentation updates.
