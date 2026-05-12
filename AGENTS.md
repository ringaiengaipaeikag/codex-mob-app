# Project Instructions

## MCP Research

Use MCP-first research when a dedicated MCP server exists.

Source of truth:

```text
$HOME/.codex/mcp-first-routes.md
$HOME/.codex/mcp-first-routes.json
```

For task routing, check the global MCP route registry first. Do not rely on a stale copied list in this file.

Default baseline:

- GitHub repositories, code search, issues, PRs, releases, commits, Actions, and CI logs: use read-only GitHub MCP first. Use `$github-research` for GitHub-heavy tasks. Use `github_operator` only when subagents/delegation are explicitly requested.
- Browser inspection, DOM/network/debugging, screenshots, and CDP/DevTools checks: use `stealth-browser` first for local or explicitly authorized targets. Load `$browser-research` for browser-heavy work.
- OpenAI APIs, Codex, ChatGPT, SDKs, Responses API, Apps SDK, and model behavior: use `openaiDeveloperDocs` first.
- Third-party libraries and frameworks: use Context7 first. Resolve the library ID before querying docs, and prefer versioned docs when relevant.
- Project documentation: use context-hub only with this project's category:

```text
project-zed-mob-app
```

Do not use unrelated context-hub categories or `general/PROJECT_DOCUMENTATION` unless explicitly requested.

For project docs, use context-hub `docs_search` with the category above, then `docs_read` on exact project paths. Do not use context-hub summary tools that cannot scope by category.

## Documentation Hygiene

Sanitized project documentation should live in `docs/`.

Do not index, print, commit, or expose secrets, generated artifacts, logs, credentials, cookies, local databases, exports, browser profiles, screenshots, HAR files, or other sensitive data.

## Verification

For new projects, verify the global research setup once:

- Run `$HOME/.codex/bin/codex-mcp-audit` and inspect failures/warnings.
- Confirm this project's context-hub category exists before querying project docs.
- For any route-specific behavior, follow `$HOME/.codex/mcp-first-routes.md` and the route's preferred skill/safety notes.

## BAZA Project Bootstrap

This project adopts BAZA, the local reusable Codex project bootstrap layer.
BAZA is the source of truth for baseline Codex customization across projects:
MCP-first routing, skills, subagents, orchestration rules, safety boundaries,
project documentation hygiene, and adoption/audit commands.

Use `make baza-audit` to check baseline drift and `make baza-docs-sync` after
sanitized documentation changes.

### BAZA Documentation Sync Rule

Whenever a task adds or materially changes a module, service, pipeline stage,
agent, skill, MCP route, hook, plugin, external integration, database flow, API
surface, operational workflow, or orchestration rule, update sanitized project
documentation before finishing the task.

After updating docs, run `make baza-docs-sync` when context-hub is available.
If docs sync cannot run, leave Markdown docs updated and report the sync blocker
in the final response.

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
4. Secure defaults: no secret exposure, no unsafe artifact indexing, no
   broad permissions, and no live external automation without explicit scope.
5. Verification appropriate to risk: static checks, focused tests, smoke tests,
   or documented blockers when verification cannot run.
6. Documentation updates when behavior, architecture, commands, integrations,
   or operational workflows change.

Avoid vague "best practice" rewrites that do not solve the task or conflict
with local project constraints. If a best-practice choice is ambiguous, record
the tradeoff in project docs before making it durable.
