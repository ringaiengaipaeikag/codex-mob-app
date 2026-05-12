# Web Traffic And JavaScript Capture

BAZA uses this workflow for authorized analysis of what a website does during a
specific user action or endpoint interaction.

The goal is to reconstruct a high-fidelity timeline:

```text
user action -> browser state -> JavaScript execution -> network request ->
server response -> follow-up browser state
```

This workflow is part of the explicit-use reverse engineering section. It is
not a default scraping, bypass, credential harvesting, or protected-service
automation workflow.

Pipeline:

```text
$HOME/.codex/baza/docs/web-traffic-capture-pipeline.md
```

Skill:

```text
$HOME/.codex/baza/skills/web-traffic-capture/SKILL.md
$HOME/.codex/baza/skills/http-traffic-analysis/SKILL.md
$HOME/.codex/baza/skills/js-runtime-analysis/SKILL.md
$HOME/.codex/baza/skills/js-coverage-analysis/SKILL.md
$HOME/.codex/baza/skills/captcha-protection-analysis/SKILL.md
$HOME/.codex/baza/skills/bot-detection-analysis/SKILL.md
```

## Official Documentation Index

Use official documentation first when debugging or extending this module.

Browser and DevTools:

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
- CDP Target:
  https://chromedevtools.github.io/devtools-protocol/tot/Target/

Automation:

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

Proxy and packet capture:

- mitmproxy:
  https://docs.mitmproxy.org/stable/
- mitmproxy Wireshark/TLS:
  https://docs.mitmproxy.org/stable/howto/wireshark-tls/
- Wireshark TLS:
  https://wiki.wireshark.org/TLS

Security/manual review:

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

## Research Summary

Primary findings from official documentation and upstream repositories:

- Chrome DevTools Network records browser requests while DevTools is open and
  exposes request headers, payloads, cookies, timing, screenshots, and HAR
  export.
- Chrome DevTools Recorder records, replays, edits, and exports user flows as
  JSON or Puppeteer-compatible scripts.
- Chrome DevTools Performance records page activity during runtime
  interactions, including JavaScript execution and timeline evidence.
- Chrome DevTools Protocol is the lowest-level browser interface for this
  workflow. The `Network`, `Runtime`, `Debugger`, `Profiler`, `Page`, `Log`,
  `Performance`, and `Tracing` domains are the key capture surfaces.
- Playwright provides the best BAZA default automation layer because it can
  combine deterministic actions, HAR recording, traces, console data,
  screenshots, DOM snapshots, network evidence, and optional proxy routing.
- BAZA's JS runtime observer adds an optional sanitized provenance layer for
  API calls that often explain why a request happened: `fetch`, XHR,
  WebSocket, storage/cookie writes, Web Crypto, base64 encoding, FormData,
  canvas, and WebGL access.
- BAZA's JS coverage analyzer adds an optional CDP Profiler layer for executed
  script ranges, high-call functions, and provider/application coverage
  categories without storing raw script source in docs.
- Puppeteer is a useful secondary runtime because it has direct CDP ergonomics,
  request/response events, tracing, and JavaScript/CSS coverage APIs. It is not
  the first BAZA default because Playwright trace artifacts are more complete
  for later agent review.
- mitmproxy is the best open-source independent HTTP/TLS/WebSocket capture
  layer. It can save full HTTP conversations for later analysis and run
  read-only scripts for annotation and redaction.
- Wireshark or tshark is useful only as an optional packet/transport layer. It
  adds DNS, TCP, TLS, HTTP/2, and QUIC visibility, but it does not explain which
  JavaScript or UI action caused a request.
- OWASP ZAP is a useful optional open-source security proxy for manual review,
  passive scanning, WebSocket review, and HAR import/export. It should not be
  the default recorder because it is heavier and less tied to browser action
  timelines.
- HTTP Toolkit, Fiddler, Charles, and Burp Suite are useful manual GUI
  alternatives, but BAZA should not depend on them as the baseline because of
  licensing, GUI dependency, and weaker automation fit.
- `stealth-browser-mcp` exposes valuable CDP and network inspection tools, but
  upstream positions it for anti-bot bypass. BAZA must keep it explicit-only
  and authorized-only. It is a fallback for controlled browser/CDP inspection,
  not a default bypass module.

## Recommended BAZA Stack

BAZA should implement web traffic capture as a layered recorder, not as a
single tool.

### Layer 1: Playwright + CDP

Default capture layer.

Responsibilities:

- launch an isolated browser profile,
- execute deterministic user actions,
- record Playwright trace artifacts,
- record full HAR files,
- subscribe to browser console and page errors,
- collect CDP network events,
- collect CDP runtime exceptions and console events,
- collect script metadata through `Debugger.scriptParsed`,
- collect worker and service worker target metadata,
- optionally inject the sanitized JS runtime observer and export
  `js-runtime-events.json`,
- optionally collect JavaScript coverage with `--js-coverage` and summarize it
  with `analyze_coverage.py`,
- save screenshots and DOM snapshots through Playwright trace.

Why this is the default:

- connects network events to exact browser actions,
- produces reviewable `trace.zip` artifacts,
- runs headless or headed,
- supports proxy routing for mitmproxy,
- works well with future Codex skills and local scripts.

### Layer 2: mitmproxy

Independent HTTP/TLS/WebSocket capture layer.

Responsibilities:

- record HTTP/1, HTTP/2, HTTPS, and WebSocket flows,
- store replayable `.flows` files,
- export sanitized summaries,
- annotate requests with timing and host metadata,
- run read-only redaction scripts.

BAZA default use is passive capture and redaction only. Request or response
modification is out of scope unless the user separately authorizes a controlled
test against an owned or permitted target.

### Layer 3: Packet Capture

Optional transport layer using Wireshark or tshark.

Responsibilities:

- capture DNS, TCP, TLS, HTTP/2, QUIC, packet timing, retransmits, and ALPN,
- decrypt TLS only when a lawful key log is available from the controlled
  browser session,
- preserve low-level evidence when proxy-level capture is incomplete.

This layer is heavy and sensitive. It should be disabled by default.

### Layer 4: Manual DevTools Evidence

Optional human-in-the-loop layer.

Responsibilities:

- use DevTools Network for quick manual request inspection and HAR export,
- use DevTools Recorder to capture a user flow that can be replayed,
- use DevTools Performance when the question is about JavaScript runtime
  behavior, long tasks, call stacks, or UI timing.

This is useful when a human needs to reproduce the action first and then hand
the flow to an automated recorder.

### Layer 5: Security Proxy Review

Optional manual security layer.

Recommended open-source baseline:

- OWASP ZAP for passive review, WebSocket review, session visibility, and HAR
  import/export.

Commercial or GUI alternatives are optional only:

- Burp Suite,
- Fiddler Everywhere,
- HTTP Toolkit,
- Charles Proxy.

These tools can be useful, but they should not be required by BAZA.

### Layer 6: Explicit Browser MCP Fallback

Optional explicit-only layer.

Use `stealth-browser-mcp` only when the user explicitly asks for authorized
browser/CDP inspection and the target is owned, local, or clearly permitted.

Allowed BAZA use:

- inspect DOM and browser state,
- list captured requests,
- inspect request and response details,
- run CDP read-only diagnostics,
- export sanitized debug evidence.

Disallowed default use:

- anti-bot bypass,
- CAPTCHA solving,
- credential or cookie harvesting,
- proxy rotation against third-party services,
- traffic modification on protected services.

## Artifact Layout

Raw artifacts must stay project-local and ignored by git.

Recommended path:

```text
.baza/web-re/<run-id>/
  manifest.json
  action-flow.json
  playwright-trace.zip
  network.har.zip
  cdp-events.ndjson
  requests.ndjson
  responses.ndjson
  console.ndjson
  runtime-exceptions.ndjson
  scripts.ndjson
  workers.ndjson
  js-runtime-events.json
  evidence-graph.json
  evidence-graph.md
  initiators.json
  storage-summary.json
  script-analysis.json
  script-analysis.md
  anti-abuse-observations.md
  capture-diff.json
  capture-diff.md
  js-coverage.json
  websocket.ndjson
  mitmproxy.flows
  packet-capture.pcapng
  sslkeylogfile.txt
  redacted-summary.md
```

Sensitive files:

- `network.har*`,
- `mitmproxy.flows`,
- `packet-capture.pcapng`,
- `sslkeylogfile.txt`,
- screenshots,
- trace files,
- cookies,
- local storage,
- session storage,
- request and response bodies.

These files must not be imported into context-hub and must not be pasted into
chat. Only `redacted-summary.md` can become project documentation after review.

## Manifest Contract

Each capture run should write `manifest.json` with:

- run id,
- timestamp,
- project name and context-hub category,
- target origin or local app identifier,
- authorization note,
- action label,
- browser name and version,
- Playwright or Puppeteer version,
- mitmproxy version when used,
- proxy mode,
- capture layers enabled,
- artifact paths,
- redaction status,
- reviewer status.

Do not store secrets in the manifest.

## Capture Flow

1. Confirm scope, target, and lawful authorization.
2. Create an isolated browser profile. Do not use a personal browser profile.
3. Start mitmproxy only if independent HTTP/TLS capture is needed.
4. Launch Playwright with HAR and trace recording enabled.
5. Enable CDP domains for `Network`, `Runtime`, `Debugger`, `Page`, `Log`,
   `Performance`, and optionally `Profiler` and `Tracing`.
6. Start JavaScript/CSS coverage only if code execution mapping is needed.
7. Use `--js-runtime-observer` when provenance of fetch/XHR/WebSocket,
   storage, cookie, crypto, encoding, FormData, canvas, or WebGL calls is
   needed.
8. Execute the action through a deterministic script, DevTools Recorder export,
   or a controlled manual step.
9. Stop capture cleanly and close the browser context so HAR files are flushed.
10. Redact secrets, cookies, auth headers, CSRF tokens, personal data, request
   bodies, and response bodies unless the project explicitly needs a sanitized
   sample.
11. Generate a redacted endpoint map and action timeline.
12. Build an evidence graph when script, worker, token-like state, endpoint, or
    protection provenance matters.
13. Run script analysis when CAPTCHA, fingerprinting, crypto, auth-token,
    obfuscation, or dynamic-code patterns matter.
14. Diff two runs when challenge state, login state, browser profile, or site
    deployment changes the behavior.
15. Import only the sanitized summary into the project documentation category.

## What To Extract

The redacted summary should include:

- action name,
- observed entry URLs,
- endpoint inventory,
- request methods and content types,
- status codes,
- dependency domains,
- initiator stack or script URL when available,
- service worker involvement,
- worker target involvement,
- WebSocket open/close and message direction metadata,
- timing sequence,
- storage mutations at a high level,
- scripts loaded during the action,
- evidence graph observations,
- run diff observations when available,
- suspected anti-abuse or bot-detection checkpoints as observations only,
- unknowns and follow-up questions.

Do not include live tokens, cookies, account identifiers, raw fingerprints,
CAPTCHA material, or bypass instructions.

## Tool Decision Matrix

Use Playwright + CDP when:

- the action must be reproducible,
- agent review needs trace artifacts,
- JavaScript, console, network, and UI state must be correlated.

Add mitmproxy when:

- browser APIs miss a request,
- independent HTTP/TLS evidence is needed,
- WebSocket or HTTP/2 flow review matters,
- the target can be safely proxied through an isolated profile.

Add Wireshark or tshark when:

- DNS, TLS, TCP, ALPN, HTTP/2, or QUIC behavior matters,
- proxy capture is insufficient,
- packet timing is part of the question.

Use DevTools Recorder when:

- a human can reproduce the flow more easily than a script,
- the flow should be exported and replayed later.

Use OWASP ZAP when:

- the task is manual security review,
- passive findings are useful,
- HAR import/export or WebSocket review is needed.

Use stealth-browser MCP only when:

- the user explicitly authorizes browser/CDP inspection,
- the project needs live browser-state inspection through MCP,
- Playwright artifacts are not enough.

## BAZA Implementation Plan

1. Maintain explicit Codex skills for `web-traffic-capture`,
   `http-traffic-analysis`, `js-runtime-analysis`, `js-coverage-analysis`,
   `captcha-protection-analysis`, and `bot-detection-analysis`.
2. Maintain local scripts under `scripts/web_capture/`:
   - dependency check,
   - Playwright recorder,
   - coverage analyzer,
   - script analyzer,
   - evidence graph builder,
   - run diff generator,
   - artifact redactor,
   - summary generator,
   - artifact verifier.
3. Add project `.gitignore` rules for `.baza/web-re/`, `*.har`,
   `*.har.zip`, `*.flows`, `*.pcap`, `*.pcapng`, `sslkeylogfile*`,
   `trace.zip`, and browser profiles.
4. Add an audit rule that warns when raw capture artifacts are outside ignored
   paths.
5. Add an upstream monitoring entry for each adopted tool repository.
6. Add a docs-sync rule: every completed capture task must create or update a
   sanitized project doc under `docs/research/` or `docs/reverse-engineering/`.
7. Add reviewer handoff: a reviewer must check redaction before context-hub
   import.
8. Use the `Web Capture Operator` role from
   `web-traffic-capture-pipeline.md` for orchestration.

## Current Local Tooling Snapshot

Observed on the local machine during BAZA research:

- `mitmdump` is installed.
- `node` and `npx` are installed.
- Google Chrome is installed.
- `tshark` is not installed.

This is enough for the first implementation pass with Playwright, Chrome, CDP,
and mitmproxy. Packet capture support can be added later.

## Sources

- Chrome DevTools Network:
  https://developer.chrome.com/docs/devtools/network/reference
- Chrome DevTools Recorder:
  https://developer.chrome.com/docs/devtools/recorder/overview
- Chrome DevTools Performance:
  https://developer.chrome.com/docs/devtools/performance/reference/
- Chrome DevTools Protocol:
  https://chromedevtools.github.io/devtools-protocol/
- Chrome DevTools Protocol Network:
  https://chromedevtools.github.io/devtools-protocol/tot/Network/
- Chrome DevTools Protocol Runtime:
  https://chromedevtools.github.io/devtools-protocol/tot/Runtime/
- Chrome DevTools Protocol Tracing:
  https://chromedevtools.github.io/devtools-protocol/tot/Tracing/
- Playwright Trace Viewer:
  https://playwright.dev/docs/trace-viewer-intro
- Playwright Network:
  https://playwright.dev/docs/network
- Playwright `recordHar`:
  https://playwright.dev/docs/api/class-browser#browser-new-context-option-record-har
- Puppeteer Network Logging:
  https://pptr.dev/guides/network-logging
- Puppeteer CDPSession:
  https://pptr.dev/api/puppeteer.cdpsession
- Puppeteer Coverage:
  https://pptr.dev/api/puppeteer.coverage
- Puppeteer Tracing:
  https://pptr.dev/api/puppeteer.tracing
- mitmproxy documentation:
  https://docs.mitmproxy.org/stable/
- mitmproxy Wireshark/TLS notes:
  https://docs.mitmproxy.org/stable/howto/wireshark-tls/
- Wireshark TLS notes:
  https://wiki.wireshark.org/TLS
- OWASP ZAP WebSockets:
  https://www.zaproxy.org/docs/desktop/addons/websockets/
- OWASP ZAP Import/Export:
  https://www.zaproxy.org/docs/desktop/addons/import-export/
- HTTP Toolkit documentation:
  https://httptoolkit.com/docs/
- Burp Suite HTTP history:
  https://portswigger.net/burp/documentation/desktop/tools/proxy/http-history
- Burp Suite WebSockets history:
  https://portswigger.net/burp/documentation/desktop/tools/proxy/websockets-history
- Fiddler Everywhere capture modes:
  https://www.telerik.com/fiddler/fiddler-everywhere/documentation/capture-traffic/capturing-modes
