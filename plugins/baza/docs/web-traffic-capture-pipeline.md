# Web Traffic Capture Pipeline

This document defines how BAZA should execute an authorized request to record a
website action, endpoint call, JavaScript runtime behavior, or network event.

Related documentation:

- `$HOME/.codex/baza/docs/web-traffic-capture.md`
- `$HOME/.codex/baza/docs/js-runtime-analysis.md`
- `$HOME/.codex/baza/docs/capture-evidence-graph.md`
- `$HOME/.codex/baza/docs/web-protection-analysis.md`
- `$HOME/.codex/baza/docs/reverse-engineering.md`
- `$HOME/.codex/baza/skills/web-traffic-capture/SKILL.md`
- `$HOME/.codex/baza/skills/http-traffic-analysis/SKILL.md`
- `$HOME/.codex/baza/skills/js-runtime-analysis/SKILL.md`
- `$HOME/.codex/baza/skills/js-coverage-analysis/SKILL.md`
- `$HOME/.codex/baza/skills/captcha-protection-analysis/SKILL.md`
- `$HOME/.codex/baza/skills/bot-detection-analysis/SKILL.md`

## Intake Contract

When a user asks to record what happens on a site, the operator must identify:

- target origin or local app,
- exact action to perform,
- endpoint or URL pattern of interest if known,
- whether login or a test account is required,
- authorization scope,
- preferred capture depth: browser-only, proxy, packet, or manual DevTools.

If any safety-critical part is missing, ask before running live browser,
proxy, packet capture, login, or protected-service automation.

## Default Capture Mode

Default mode is `browser-cdp`.

It uses:

- Playwright for deterministic browser control,
- Chrome DevTools Protocol for browser/runtime/network events,
- Playwright HAR recording for request archive,
- Playwright trace for action timeline, screenshots, DOM snapshots, console,
  errors, and network context.

This is the most useful default because it ties every observed network event to
the browser action that produced it.

## Capture Depths

### browser-cdp

Use for most tasks.

Enabled layers:

- Playwright trace,
- HAR,
- CDP `Network`,
- CDP `Runtime`,
- CDP `Debugger`,
- CDP `Page`,
- CDP `Log`,
- CDP `Performance`,
- optional sanitized JS runtime observer,
- optional JavaScript/CSS coverage.

### browser-cdp-proxy

Use when independent HTTP/TLS/WebSocket evidence is needed.

Adds:

- mitmproxy flow recording,
- proxy-level HTTP/1, HTTP/2, HTTPS, and WebSocket metadata,
- optional read-only mitmproxy redaction/annotation script.

### browser-cdp-packet

Use only when transport evidence matters.

Adds:

- Wireshark or tshark packet capture,
- optional TLS key log from the controlled browser session,
- DNS, TCP, TLS, ALPN, HTTP/2, QUIC, retransmit, and timing evidence.

This is disabled by default because it is noisy and sensitive.

### manual-seed

Use when a human can reproduce the flow faster than a script.

Sources:

- Chrome DevTools Recorder export,
- manual DevTools Network HAR export,
- DevTools Performance recording.

The exported flow can then become the input for a deterministic Playwright run.

## End-To-End Pipeline

1. Confirm target, action, and authorization.
2. Create `.baza/web-re/<run-id>/`.
3. Write `manifest.json` with non-secret scope metadata.
4. Check local dependencies: Chrome, Node/npx, Playwright, mitmdump, optional
   Wireshark/tshark.
5. Select capture depth.
6. Start mitmproxy only when proxy capture is selected.
7. Launch an isolated browser profile. Never use a personal profile.
8. Start Playwright trace and HAR recording.
9. Enable CDP domains needed for the selected depth.
10. Enable the sanitized JS runtime observer when API provenance is needed.
11. Start optional JavaScript/CSS coverage.
12. Execute the action through Playwright or imported DevTools Recorder flow.
13. Mark the action boundary in logs before and after the event.
14. Wait for the endpoint, WebSocket message, or network idle condition.
15. Stop trace, HAR, coverage, CDP logging, proxy capture, and packet capture.
16. Close browser context so HAR and trace files are flushed.
17. Generate normalized artifacts.
18. Redact sensitive fields and bodies.
19. Generate `redacted-summary.md`.
20. Run reviewer checks before documentation sync.
21. Sync only sanitized documentation into the project context-hub category.

## Runtime Interaction

```text
User task
  -> Web Capture Operator
    -> scope and safety gate
    -> capture depth selection
    -> Playwright isolated browser
      -> CDP event collector
      -> optional sanitized JS runtime observer
      -> HAR recorder
      -> trace recorder
      -> optional JS/CSS coverage
    -> optional mitmproxy recorder
    -> optional packet recorder
    -> artifact normalizer
    -> redactor
    -> reviewer
    -> sanitized docs sync
```

## Artifact Normalization

The normalizer should produce:

- `timeline.ndjson`: timestamped browser, CDP, proxy, and action events,
- `endpoint-map.json`: grouped endpoints by host, path, method, status, and
  initiator,
- `initiators.json`: request-to-script or request-to-frame map,
- `scripts.ndjson`: script URLs, hashes, source map hints, and execution
  relevance,
- `js-coverage.json`: CDP precise coverage without raw script source,
- `js-coverage-analysis.json`: coverage percentages, categories, offsets, and
  high-call function metadata,
- `js-runtime-events.json`: sanitized API provenance events with raw values
  omitted,
- `evidence-graph.json`: action, script, worker, endpoint, state, and
  protection-provider graph,
- `initiators.json`: sanitized request initiator and stack evidence,
- `websocket.ndjson`: connection and frame direction metadata,
- `storage-summary.json`: high-level storage/cookie/localStorage/sessionStorage
  mutations with values redacted,
- `script-analysis.json`: script URL/source pattern categories,
- `capture-diff.json`: sanitized comparison of two runs,
- `anti-abuse-observations.md`: observations only, no bypass instructions,
- `redacted-summary.md`: project-safe report.

## Redaction Gate

Redact before any agent summary, chat paste, commit, or context-hub import:

- cookies,
- authorization headers,
- API keys,
- CSRF tokens,
- bearer tokens,
- session identifiers,
- account identifiers,
- personal data,
- request bodies,
- response bodies,
- raw browser fingerprints,
- CAPTCHA material,
- TLS key logs.

Keep raw artifacts only in ignored local paths.

## Operator Role

BAZA defines a role profile named `Web Capture Operator`.

Responsibilities:

- run the intake contract,
- choose capture depth,
- orchestrate Playwright, CDP, mitmproxy, and optional packet capture,
- keep raw artifacts local,
- produce normalized artifacts,
- generate the sanitized summary,
- build evidence graphs and run diffs when requested.

Rules:

- do not run live capture without authorization,
- do not use a personal browser profile,
- do not attempt anti-bot bypass or CAPTCHA solving by default,
- do not modify live traffic by default,
- do not import raw artifacts into context-hub.

BAZA also defines a role profile named `Web Protection Analyst`.

Responsibilities:

- read `evidence-graph.json`, `anti-abuse-observations.md`, and
  `script-analysis.md`,
- identify CAPTCHA/protection provider signals,
- separate direct observations from inference,
- recommend additional authorized captures when evidence is incomplete,
- produce an observations-only sanitized report.

Rules:

- do not solve CAPTCHA,
- do not replay challenge payloads or token values,
- do not give bypass instructions,
- do not treat pattern-based provider detection as proof without supporting
  evidence.

## Supporting Roles

Use supporting roles when the environment supports delegation and the user has
authorized agent work:

- `docs_researcher`: official docs lookup only.
- `reviewer`: redaction, safety, and correctness review.
- `project_documentarian`: sanitized docs update and context-hub sync.
- `ops_debugger`: local dependency, proxy, or tool runtime issues.

If custom subagents are not available, the main Codex thread should follow
these roles sequentially.

## Skill Contract

BAZA includes a dedicated skill:

```text
$HOME/.codex/baza/skills/web-traffic-capture/SKILL.md
$HOME/.codex/baza/skills/http-traffic-analysis/SKILL.md
$HOME/.codex/baza/skills/js-runtime-analysis/SKILL.md
$HOME/.codex/baza/skills/js-coverage-analysis/SKILL.md
$HOME/.codex/baza/skills/captcha-protection-analysis/SKILL.md
$HOME/.codex/baza/skills/bot-detection-analysis/SKILL.md
```

The skill should trigger on:

- recording browser action logs,
- endpoint call analysis,
- HAR/CDP/DevTools/mitmproxy capture,
- JavaScript runtime and request initiator analysis,
- JavaScript coverage analysis,
- token provenance analysis without raw token capture or replay,
- CAPTCHA and protection-provider observation without solving or bypass,
- evidence graph generation and run diff,
- WebSocket capture,
- sanitized web reverse-engineering reports.

## Future Enhancements

Implemented helpers:

- `scripts/web_capture/check_deps.py` for deterministic dependency checks,
- `scripts/web_capture/record_playwright_cdp.mjs` as the default recorder,
- `scripts/web_capture/js_runtime_observer.js` for sanitized JavaScript API
  provenance,
- `scripts/web_capture/build_evidence_graph.py` for action/script/state/
  endpoint/protection graphs,
- `scripts/web_capture/diff_capture_runs.py` for sanitized run comparisons,
- `scripts/web_capture/analyze_scripts.py` for script inventory and optional
  authorized source pattern analysis,
- `scripts/web_capture/analyze_coverage.py` for sanitized JavaScript coverage
  summaries,
- `scripts/web_capture/redact_artifacts.py` for repeatable redaction,
- `scripts/web_capture/summarize_capture.py` for endpoint/timeline reports,
- `scripts/web_capture/verify_artifacts.py` for artifact completeness checks,
- project template `.gitignore` additions for raw capture artifacts,

Future additions:

- a tiny local dashboard for reading `timeline.ndjson` and endpoint maps.
- a local MCP wrapper over sanitized `evidence-graph.json` and
  `capture-diff.json` so agents can query captures without reading raw HARs.

## Official Documentation Index

Use these primary sources when debugging or extending the pipeline:

- Chrome DevTools Network:
  https://developer.chrome.com/docs/devtools/network/reference
- Chrome DevTools Recorder:
  https://developer.chrome.com/docs/devtools/recorder/overview
- Chrome DevTools Performance:
  https://developer.chrome.com/docs/devtools/performance/reference/
- Chrome DevTools Protocol:
  https://chromedevtools.github.io/devtools-protocol/
- CDP Network:
  https://chromedevtools.github.io/devtools-protocol/tot/Network/
- CDP Runtime:
  https://chromedevtools.github.io/devtools-protocol/tot/Runtime/
- CDP Debugger:
  https://chromedevtools.github.io/devtools-protocol/tot/Debugger/
- CDP Profiler:
  https://chromedevtools.github.io/devtools-protocol/tot/Profiler/
- CDP Tracing:
  https://chromedevtools.github.io/devtools-protocol/tot/Tracing/
- Playwright Trace Viewer:
  https://playwright.dev/docs/trace-viewer-intro
- Playwright Network:
  https://playwright.dev/docs/network
- Playwright HAR recording:
  https://playwright.dev/docs/api/class-browser#browser-new-context-option-record-har
- Puppeteer Network Logging:
  https://pptr.dev/guides/network-logging
- Puppeteer CDPSession:
  https://pptr.dev/api/puppeteer.cdpsession
- Puppeteer Coverage:
  https://pptr.dev/api/puppeteer.coverage
- Puppeteer Tracing:
  https://pptr.dev/api/puppeteer.tracing
- mitmproxy:
  https://docs.mitmproxy.org/stable/
- mitmproxy Wireshark/TLS:
  https://docs.mitmproxy.org/stable/howto/wireshark-tls/
- Wireshark TLS:
  https://wiki.wireshark.org/TLS
- OWASP ZAP WebSockets:
  https://www.zaproxy.org/docs/desktop/addons/websockets/
- OWASP ZAP Import/Export:
  https://www.zaproxy.org/docs/desktop/addons/import-export/
- HTTP Toolkit:
  https://httptoolkit.com/docs/
- Burp Suite HTTP History:
  https://portswigger.net/burp/documentation/desktop/tools/proxy/http-history
- Burp Suite WebSockets History:
  https://portswigger.net/burp/documentation/desktop/tools/proxy/websockets-history
- Fiddler Everywhere Capture Modes:
  https://www.telerik.com/fiddler/fiddler-everywhere/documentation/capture-traffic/capturing-modes
