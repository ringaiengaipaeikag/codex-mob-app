# Reverse Engineering

BAZA keeps reverse engineering workflows in a dedicated, explicit-use section.

Reverse engineering modules are not general default automation. They are
available for authorized security research, interoperability analysis, malware
analysis, education, and analysis of software the user owns or has permission
to inspect.

## Android API Extraction

Tracked upstream:

```text
https://github.com/SimoneAvogadro/android-reverse-engineering-skill
```

Status:

- Upstream type: Claude Code skill.
- BAZA target type: Codex/GPT explicit-use skill.
- License: Apache-2.0.
- Stable base to track: upstream release `v1.1.0`.
- Experimental watchlist: upstream PR #16 for fingerprinting, Ktor/Apollo,
  Koin/HMAC, endpoint path extraction, and Kotlin metadata recovery.

BAZA must not import this repository as-is. The upstream skill depends on
Claude Code plugin layout, slash commands, and `CLAUDE_PLUGIN_ROOT`. A BAZA
port must replace those assumptions with Codex skill metadata, BAZA-relative
scripts, and project-safe output paths.

## Safety Rules

- Use only after the user explicitly requests reverse engineering, API
  extraction, web traffic capture, or JavaScript/runtime capture and confirms
  lawful authorization.
- Do not help bypass access controls, abuse third-party APIs, harvest accounts,
  or run extracted endpoints against live services without separate explicit
  authorization.
- Do not import raw APKs, decompiled source trees, credentials, tokens, cookies,
  HAR files, screenshots, or generated captures into context-hub.
- Store raw artifacts only in ignored project-local paths such as
  `.baza/android-re/<run-id>/`.
- Store only sanitized summaries in project documentation: architecture notes,
  endpoint inventory with secrets redacted, call-flow notes, dependency status,
  and unresolved risks.

## Web Traffic And JavaScript Capture

BAZA tracks a separate workflow for authorized capture of browser actions,
JavaScript execution, network requests, WebSocket frames, and HTTP/TLS evidence:

```text
$HOME/.codex/baza/docs/web-traffic-capture.md
$HOME/.codex/baza/docs/web-traffic-capture-pipeline.md
$HOME/.codex/baza/docs/js-runtime-analysis.md
$HOME/.codex/baza/docs/capture-evidence-graph.md
$HOME/.codex/baza/docs/web-protection-analysis.md
$HOME/.codex/baza/skills/web-traffic-capture/SKILL.md
$HOME/.codex/baza/skills/http-traffic-analysis/SKILL.md
$HOME/.codex/baza/skills/js-runtime-analysis/SKILL.md
$HOME/.codex/baza/skills/js-coverage-analysis/SKILL.md
$HOME/.codex/baza/skills/captcha-protection-analysis/SKILL.md
$HOME/.codex/baza/skills/bot-detection-analysis/SKILL.md
```

Recommended stack:

- Playwright + Chrome DevTools Protocol as the default action/network/runtime
  recorder.
- BAZA JS runtime observer as an optional sanitized provenance layer for
  fetch/XHR/WebSocket, storage, cookie, crypto, encoding, FormData, canvas, and
  WebGL API signals.
- BAZA JS coverage analysis as an optional CDP Profiler layer for executed
  script ranges, high-call functions, and successful/failed run comparison.
- BAZA evidence graph as the normalized model connecting user action, JS
  runtime events, scripts, workers, browser state, endpoints, and protection
  provider signals.
- BAZA run diff for comparing successful/failed challenge runs, login states,
  browser profiles, or frontend versions.
- mitmproxy as the independent HTTP/TLS/WebSocket capture layer.
- Wireshark or tshark only as an optional packet/transport layer.
- Chrome DevTools Recorder and Performance panels for manual reproduction and
  runtime evidence.
- OWASP ZAP as an optional open-source manual security proxy.
- stealth-browser MCP as explicit-only authorized browser/CDP fallback, never
  as default anti-bot bypass automation.

Raw artifacts must stay in ignored project-local paths such as
`.baza/web-re/<run-id>/`. Only redacted summaries may be imported into
context-hub or committed to project documentation.

CAPTCHA and bot-protection work is observations-only by default. It may
identify provider signals, iframe/script origins, endpoint sequence, token-like
key names, and direct/inferred evidence, but it must not solve CAPTCHA, replay
tokens, or document bypass steps.

Provider-specific BAZA skills are guarded observation skills:

```text
$HOME/.codex/baza/skills/cloudflare-analysis/SKILL.md
$HOME/.codex/baza/skills/datadome-analysis/SKILL.md
$HOME/.codex/baza/skills/trustev-fingerprint/SKILL.md
$HOME/.codex/baza/skills/akamai-bypass/SKILL.md
$HOME/.codex/baza/skills/recaptcha-solve/SKILL.md
$HOME/.codex/baza/skills/tps-browser-harvester/SKILL.md
```

The last three names intentionally remain guarded compatibility routes because
legacy/project-specific tasks may use those terms. In BAZA they do not grant
permission to solve CAPTCHA, harvest cookies, replay tokens, rotate proxies, or
bypass third-party protections.

For orchestration, BAZA defines the `Web Capture Operator` role. It is a role
profile that can be performed by the main Codex thread or by a dedicated
subagent when the environment and user authorization allow agent delegation.

## TLS Fingerprint Tooling

BAZA tracks TLS/HTTP fingerprint tooling for authorized compatibility
diagnostics and controlled research:

```text
$HOME/.codex/baza/docs/tls-fingerprint-tooling.md
$HOME/.codex/baza/docs/source-dossiers/tls-fingerprint-tooling.md
$HOME/.codex/baza/skills/tls-fingerprint-research/SKILL.md
$HOME/.codex/baza/skills/tls-fingerprint/SKILL.md
```

Tracked tools include:

- `curl_cffi`,
- `lexiforest/curl-impersonate`,
- `lwthiker/curl-impersonate`,
- `fing`,
- `tls-client`,
- `Python-Tls-Client`.

These are explicit-use only. They are available for authorized diagnostics,
interoperability, and project research, not as global default bypass,
CAPTCHA/token-generation, or protected-endpoint replay tooling.

## BAZA Port Plan

1. Create `skills/android-reverse-engineering/SKILL.md` with explicit trigger
   wording for Codex/GPT.
2. Add BAZA-relative scripts for dependency checks, fingerprinting,
   decompilation, API search, and sanitized report generation.
3. Keep Java 17 and `jadx` as required dependencies. Treat Vineflower,
   dex2jar, apktool, and adb as optional capabilities.
4. Add an initial fingerprint phase before decompilation to identify native
   Android, Flutter, React Native, Cordova/Capacitor, Xamarin/.NET, HTTP stack,
   native libraries, and obfuscation level.
5. Prefer a two-tier output: a broad endpoint inventory first, then detailed
   analysis only for authentication, payment, sensitive, or user-requested
   flows.
6. Add reviewer and documentation checks before syncing any result into
   project docs.

## Upstream Watchlist

- PR #16: fingerprinting, modern Kotlin/KMP API extraction, Kotlin metadata
  recovery, Ktor/Apollo/Koin/HMAC patterns.
- Issue #5: Flutter and React Native support.
- Issue #13: native `.so` analysis.
- Issue #14: Windows PowerShell parity.
- Web traffic capture upstreams tracked in
  `$HOME/.codex/baza/upstreams/registry.toml`: Playwright, Chrome DevTools
  Protocol, mitmproxy, Puppeteer, OWASP ZAP, stealth-browser MCP, curl_cffi,
  curl-impersonate, fing, tls-client, and Python-Tls-Client.
