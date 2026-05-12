# Source Dossier: mitmproxy

Last reviewed: 2026-05-03

## Identity

- Official docs: https://docs.mitmproxy.org/stable/
- Official repository: https://github.com/mitmproxy/mitmproxy
- Releases: https://github.com/mitmproxy/mitmproxy/releases

## Current BAZA Pin

- Latest checked release: `v12.2.2`
- Checked on: 2026-05-03
- Registry: `upstreams/registry.toml`

## BAZA Usage

mitmproxy is the primary independent HTTP/TLS/WebSocket recorder in BAZA web
traffic capture workflows. It complements Playwright/CDP capture by recording
traffic outside the browser automation layer.

Use official mitmproxy docs for operation and GitHub MCP for release/source
evidence.

## Durable Findings

- mitmproxy capture can include sensitive request/response data and must follow
  explicit authorization and artifact redaction rules.
- Raw flows should stay out of git and context-hub.

## BAZA Impact

- Web traffic capture docs and scripts should keep raw flow artifacts ignored.
- Any new mitmproxy capture workflow must include redaction and sanitized
  summary steps before documentation sync.
