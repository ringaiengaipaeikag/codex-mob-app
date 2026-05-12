# Project Name

## BAZA

This project follows BAZA, the local Codex project bootstrap layer.

For non-trivial tasks:

1. Read this file first.
2. Read `docs/status.md`.
3. Use context-hub only with this project's category.
4. Use MCP-first research routing before generic web search.
5. Use official docs and canonical repositories before community sources for
   Codex, OpenAI, Zed, ACP, and upstream tool behavior.
6. Follow the BAZA Best Practices Rule for implementation, verification,
   safety, and documentation.
7. Update sanitized docs and run `make baza-docs-index` when modules,
   integrations, agents, skills, MCP routes, APIs, database flows, or major
   workflows change.
8. Use `make baza-docs-health` to verify Markdown, context-hub, and local
   vector documentation freshness.
9. Use `make baza-docs-vector-sync` and `make baza-docs-search QUERY="<query>"`
   when local hybrid documentation retrieval is useful.

## BAZA Best Practices Rule

All project work must follow best practices for the project's actual stack,
risk level, and existing architecture.

Use this precedence order:

1. Official documentation, source dossiers, and canonical repositories for the
   exact tools, APIs, frameworks, and versions in use.
2. Existing project architecture, style, naming, test patterns, operational
   runbooks, and security boundaries.
3. Small, maintainable, reviewable changes with the least necessary blast
   radius.
4. Secure defaults: no secret exposure, no unsafe artifact indexing, no broad
   permissions, and no live external automation without explicit scope.
5. Verification appropriate to risk: static checks, focused tests, smoke tests,
   or documented blockers when verification cannot run.
6. Documentation updates when behavior, architecture, commands, integrations,
   or operational workflows change.

Avoid vague "best practice" rewrites that do not solve the task or conflict
with local project constraints. If a best-practice choice is ambiguous, record
the tradeoff in project docs before making it durable.

## Context Hub

Project category:

```text
project-REPLACE_ME
```

Do not use broad or shared categories for project-specific answers.

## Sensitive Boundaries

Do not print, index, log, or commit secrets, credentials, raw PII, generated
exports, local databases, cookies, HARs, screenshots, browser profiles, or API
captures.
