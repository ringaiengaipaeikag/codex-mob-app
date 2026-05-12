---
name: baza-official-docs
description: Use when a task asks for official docs, official repositories, release status, or source-of-truth behavior for BAZA, Codex, OpenAI Codex CLI/config/AGENTS/MCP/plugins/skills/subagents, Zed, Zed external agents, ACP, or codex-acp.
---

# BAZA Official Docs

Use this skill to keep BAZA answers grounded in official sources.

## Workflow

1. Read `docs/official-sources.md` from the active BAZA source.
2. Check `official-sources/registry.toml` for the canonical route and matching
   source dossier.
3. For OpenAI/Codex behavior, use OpenAI Developer Docs MCP first.
4. For repository state, releases, issues, PRs, and code, use GitHub MCP
   against the canonical repository.
5. For Zed behavior, use official Zed docs first, then GitHub MCP for
   `zed-industries/zed` and `zed-industries/codex-acp`.
6. Use generic web search only as fallback when official docs and official
   repositories do not answer the question.
7. If the finding changes a reusable BAZA rule, update the matching
   `docs/source-dossiers/*.md`, BAZA docs, and sync `project-baza`.

## Source Priority

- OpenAI docs MCP for Codex configuration, CLI, MCP, AGENTS.md, skills,
  plugins, subagents, approval, sandboxing, and web search configuration.
- GitHub MCP for `openai/codex`, `zed-industries/zed`,
  `zed-industries/codex-acp`, and BAZA-tracked upstreams.
- Official Zed docs for Zed Agent Panel, external agents, settings, and MCP.
- Local context-hub category `project-baza` for BAZA design decisions already
  captured in the documentation database.

## Safety

Do not paste secrets, tokens, local config values, browser captures, HARs,
screenshots, cookies, or raw PII into docs or citations. Record sanitized
links, decisions, and operational notes only.
