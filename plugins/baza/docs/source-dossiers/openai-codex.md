# Source Dossier: OpenAI Codex

Last reviewed: 2026-05-03

## Identity

- Official docs: https://developers.openai.com/codex
- CLI reference: https://developers.openai.com/codex/cli/reference
- Configuration reference: https://developers.openai.com/codex/config-reference
- Best practices: https://developers.openai.com/codex/learn/best-practices
- MCP docs: https://developers.openai.com/codex/mcp
- Official repository: https://github.com/openai/codex
- Releases: https://github.com/openai/codex/releases

## Current BAZA Pin

- Latest checked release: `rust-v0.128.0`
- Checked on: 2026-05-03
- Registry: `upstreams/registry.toml`

## BAZA Usage

Use OpenAI Developer Docs MCP first for Codex configuration, CLI behavior,
AGENTS.md, skills, MCP, plugins, sandboxing, approvals, web search settings,
and multi-agent behavior.

Use GitHub MCP for release notes, source code, issues, PRs, config schema
assets, and implementation-level behavior.

## Durable Findings

- User-level configuration belongs in `~/.codex/config.toml`.
- Project-scoped overrides belong in `.codex/config.toml`.
- Durable preferences include model defaults, profiles, MCP servers,
  multi-agent setup, feature flags, sandboxing, and approval behavior.
- MCP should be used when context is outside the repo, changes frequently,
  should be retrieved through tools, or must be repeatable across projects.

## BAZA Impact

- BAZA templates enable project-local skills in `.codex/config.toml`.
- BAZA keeps official Codex docs in `docs/official-sources.md`.
- Any reusable Codex behavior change should update this dossier, BAZA docs,
  and `project-baza` in context-hub.
