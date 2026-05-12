# MCP Setup

Last updated: 2026-05-12

BAZA uses MCP-first research. MCP servers are configured in the user/global
Codex or Zed environment, not as secrets inside this repository.

## Route Registry

The global route registry is the source of truth:

```text
$HOME/.codex/mcp-first-routes.md
$HOME/.codex/mcp-first-routes.json
```

Run an audit after changing MCP setup:

```bash
$HOME/.codex/bin/codex-mcp-audit
```

## Recommended Servers

`context_hub`

Required for local project documentation. Use the active project category:

```text
project-zed-mob-app
```

Use `docs_search(category="project-zed-mob-app")`, then `docs_read` on exact
project paths.

`github`

Required for GitHub repository inspection, issues, PRs, releases, commits,
Actions, and CI evidence. For publishing changes, a token needs repository
contents write access. If a change touches `.github/workflows/`, workflow write
access is also required.

`openaiDeveloperDocs`

Required for current OpenAI, Codex, SDK, API, and product behavior. Use it
before relying on memory for version-sensitive behavior.

`context7`

Required for third-party library and framework documentation. Resolve the
library id first, then query versioned docs when relevant.

`stealth-browser`

Optional for authorized local browser inspection, screenshots, DOM/network
debugging, and CDP workflows.

## Token Hygiene

- Store MCP credentials in user-level config or environment variables only.
- Do not commit tokens or generated MCP state.
- Prefer fine-grained GitHub tokens scoped to the exact repository.
- Use the least permissions needed for the task.
- Rotate a token immediately if it is printed, committed, or pasted into public
  chat/logs.

## Project Docs Rule

This repository uses:

```text
project-zed-mob-app
```

BAZA's canonical reusable documentation lives separately in:

```text
project-baza
```

Do not mix these categories when syncing or searching docs.
