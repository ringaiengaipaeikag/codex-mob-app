# Upstream Monitoring

BAZA tracks public repositories that are used as source material for skills,
scripts, MCP routes, workflows, and documentation.

Registry:

```text
$HOME/.codex/baza/upstreams/registry.toml
```

Official docs and repository URL coverage is tracked separately:

```text
$HOME/.codex/baza/official-sources/registry.toml
```

## Policy

BAZA should automatically check upstream status, but it should not
automatically update imported code or guidance without review.

The correct flow is:

```text
scheduled check -> report drift -> review upstream diff -> update BAZA -> test -> docs sync
```

For official docs and source dossiers:

```text
official source check -> update dossier if reusable -> update BAZA docs -> docs sync
```

This avoids silently changing project behavior when an upstream skill, MCP
server, script, or policy changes.

Public GitHub checks can run without a token, but unauthenticated requests are
rate-limited. For stable scheduled checks, provide one of these environment
variables without printing or committing the token:

```text
GITHUB_TOKEN
GH_TOKEN
GITHUB_PERSONAL_ACCESS_TOKEN
```

## What To Track

For each upstream repository, track:

- canonical URL,
- owner and repo,
- license,
- BAZA section,
- adoption status,
- pinned release or tag,
- pinned default branch commit when relevant,
- explicit-only or default-use safety status,
- watchlist PRs/issues that affect BAZA adoption.

## Current Upstreams

- `android-reverse-engineering-skill` in the reverse-engineering section.
- `playwright` for the default web action/network/runtime recorder.
- `devtools-protocol` for Chrome DevTools Protocol reference tracking.
- `mitmproxy` for independent HTTP/TLS/WebSocket capture.
- `puppeteer` as a secondary CDP/browser automation reference.
- `zaproxy` as an optional open-source security proxy reference.
- `stealth-browser-mcp` as explicit-only authorized browser/CDP fallback
  material.
- `openai-codex` for Codex CLI, config, MCP, plugin, skill, and multi-agent
  implementation/release evidence.
- `zed` for official Zed editor and agent behavior evidence.
- `zed-codex-acp` for Zed's Codex ACP bridge release evidence.
- `curl-cffi` for Python TLS/HTTP fingerprint research and diagnostics.
- `lexiforest-curl-impersonate` as the active curl-impersonate fork used by
  curl_cffi.
- `lwthiker-curl-impersonate` as the original curl-impersonate reference.
- `fing` for research-only JA3 and HTTP/2/Akamai-style fingerprint generation.
- `tls-client` and `python-tls-client` as ecosystem references for native/Go
  and Python TLS client behavior.

## Command

Check all registered upstream repositories:

```bash
python3 $HOME/.codex/baza/scripts/baza_check_upstreams.py
```

Machine-readable output:

```bash
python3 $HOME/.codex/baza/scripts/baza_check_upstreams.py --json
```

Use strict mode in scheduled checks or CI-like automation:

```bash
python3 $HOME/.codex/baza/scripts/baza_check_upstreams.py --strict
```

Strict mode exits non-zero when a tracked release or branch has drifted from
the pinned value.

## Scheduling

Recommended cadence:

- weekly for stable upstreams,
- daily only for actively adopted upstreams under development,
- before applying BAZA to a new long-lived project.

Use local cron, launchd, or a trusted project automation. Keep network checks
read-only. GitHub tokens may be supplied through environment or local config for
authenticated read-only checks, but they must not be printed, indexed, or
committed.
