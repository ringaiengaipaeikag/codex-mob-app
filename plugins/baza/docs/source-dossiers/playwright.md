# Source Dossier: Playwright

Last reviewed: 2026-05-03

## Identity

- Official docs: https://playwright.dev/docs/intro
- Official repository: https://github.com/microsoft/playwright
- Releases: https://github.com/microsoft/playwright/releases

## Current BAZA Pin

- Latest checked release: `v1.59.1`
- Checked on: 2026-05-03
- Registry: `upstreams/registry.toml`

## BAZA Usage

Playwright is the primary BAZA runtime for authorized browser action capture,
HAR/trace capture, console capture, and CDP-backed runtime collection.

Use Context7 or official Playwright docs for APIs. Use GitHub MCP for releases,
issues, PRs, and source-level behavior.

## Durable Findings

- Playwright availability is project-local: Node can be installed while the
  `playwright` package is not resolvable from a project root.
- BAZA doctor reports missing Playwright as a warning, not a baseline failure.

## BAZA Impact

- Web capture workflows should check dependencies before capture.
- Missing Playwright should trigger setup guidance, not block unrelated BAZA
  adoption.
