---
name: baza-source-dossier
description: Use when researching an official tool, documentation site, GitHub repository, release, MCP route, or reusable BAZA dependency where the result should become durable local knowledge instead of a one-off answer.
---

# BAZA Source Dossier

Use this skill when official-source research should be reusable in future
projects.

## Workflow

1. Read `docs/official-sources.md` and `official-sources/registry.toml` from
   the active BAZA source.
2. Use the registered MCP route first:
   - OpenAI/Codex docs: OpenAI Developer Docs MCP.
   - GitHub repositories/releases/issues/PRs/code: GitHub MCP.
   - Third-party library docs: Context7 first when available, official docs
     fallback.
   - Zed docs: official Zed docs, then GitHub MCP for repository evidence.
3. Produce findings in this structure:
   - `Answer`
   - `Official docs evidence`
   - `Repository evidence`
   - `Version or release status`
   - `BAZA impact`
   - `Dossier update needed`
4. If the finding changes reusable BAZA behavior, update the matching
   `docs/source-dossiers/*.md` file.
5. Run `python3 scripts/baza_check_official_sources.py --offline` from the
   global BAZA source after local dossier edits.
6. Sync `project-baza` docs when context-hub is available.

## Dossier Rules

- Keep dossiers sanitized and link-heavy.
- Record decisions, official links, current pins, known risks, and BAZA usage.
- Do not copy long docs pages into dossiers.
- Do not store credentials, cookies, local configs, HARs, screenshots, traces,
  captures, or private URLs.
- Community evidence may be listed only as fallback context and must not
  override official docs or repository evidence.
