# Source Dossier: Zed

Last reviewed: 2026-05-03

## Identity

- Official docs: https://zed.dev/docs
- AI docs: https://zed.dev/docs/ai
- Agent Panel: https://zed.dev/docs/ai/agent-panel
- Agent Settings: https://zed.dev/docs/ai/agent-settings
- External Agents: https://zed.dev/docs/ai/external-agents
- MCP docs: https://zed.dev/docs/ai/mcp
- Official repository: https://github.com/zed-industries/zed
- Releases: https://github.com/zed-industries/zed/releases

## Current BAZA Pin

- Latest checked release: `v1.0.0`
- Checked on: 2026-05-03
- Registry: `upstreams/registry.toml`

## BAZA Usage

Use official Zed docs first for product behavior, Agent Panel behavior,
settings, external agents, and MCP integration.

Use GitHub MCP for release notes, source behavior, issues, PRs, and regressions.
Treat local app behavior as environment-specific until verified on the target
machine.

## Durable Findings

- Zed/Codex behavior can depend on Zed settings, app version, and ACP bridge
  version.
- Do not assume the `codex` CLI is in PATH just because Zed can run Codex
  through ACP.
- Project BAZA adoption should be verified from the project filesystem, not
  from a Zed thread screenshot alone.

## BAZA Impact

- `baza-doctor` distinguishes local CLI availability from project projection
  health.
- Zed-specific integration changes should update this dossier, the official
  sources index, and `upstreams/registry.toml` when relevant.
