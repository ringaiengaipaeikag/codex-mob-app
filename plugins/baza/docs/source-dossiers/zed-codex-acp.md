# Source Dossier: Zed Codex ACP

Last reviewed: 2026-05-03

## Identity

- Official repository: https://github.com/zed-industries/codex-acp
- Releases: https://github.com/zed-industries/codex-acp/releases
- Related Zed external agents docs: https://zed.dev/docs/ai/external-agents

## Current BAZA Pin

- Latest checked release: `v0.12.0`
- Checked on: 2026-05-03
- Registry: `upstreams/registry.toml`

## BAZA Usage

Use GitHub MCP for release notes, bridge behavior, issues, PRs, and source
changes. Use official Zed docs for user-facing external agent setup.

## Durable Findings

- The ACP bridge version may lag behind the latest Codex release.
- Changes in ACP behavior can affect Zed project adoption, working directory,
  shell environment, and whether project-local BAZA config is loaded.

## BAZA Impact

- When Zed/Codex behavior changes, check both `zed-industries/zed` and
  `zed-industries/codex-acp`.
- Update BAZA Zed guidance only after checking official docs and repository
  release evidence.
