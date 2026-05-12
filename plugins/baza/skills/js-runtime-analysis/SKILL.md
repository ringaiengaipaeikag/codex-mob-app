---
name: js-runtime-analysis
description: Use for authorized analysis of JavaScript executed during a website action: script loading, fetch/XHR/WebSocket calls, storage/cookie writes, crypto/encoding calls, token provenance, browser API access, CDP Debugger/Runtime evidence, and sanitized runtime timelines. Requires explicit authorization before live browser activity, login, protected-service interaction, or collection of sensitive artifacts.
---

# JS Runtime Analysis

Use this skill when the task is to understand what JavaScript does during a
specific authorized browser action.

Primary BAZA docs:

- `plugins/baza/docs/reverse-engineering.md`
- `plugins/baza/docs/web-traffic-capture.md`
- `plugins/baza/docs/js-runtime-analysis.md`

Helper scripts:

- `plugins/baza/scripts/web_capture/record_playwright_cdp.mjs`
- `plugins/baza/scripts/web_capture/js_runtime_observer.js`
- `plugins/baza/scripts/web_capture/analyze_coverage.py`
- `plugins/baza/scripts/web_capture/summarize_capture.py`
- `plugins/baza/scripts/web_capture/redact_artifacts.py`
- `plugins/baza/scripts/web_capture/verify_artifacts.py`

## Safety Gate

Before live browser work, confirm:

- target origin or local app,
- exact user action,
- authorization scope,
- whether login, test account, protected service, proxy, packet capture,
  cookies, storage, HAR, or screenshots are involved.

Do not collect or print raw credentials, cookies, tokens, PII, request bodies,
response bodies, screenshots, browser profiles, or HAR contents. Raw artifacts
stay in ignored `.baza/web-re/<run-id>/` paths. Project docs get sanitized
summaries only.

Do not use this skill to bypass access controls, solve CAPTCHA, evade bot
defenses, replay third-party tokens, or operate extracted endpoints outside the
authorized scope.

## Workflow

1. Define the question: token provenance, data collection, endpoint trigger,
   storage mutation, crypto use, WebSocket flow, or script ownership.
2. Prefer Playwright + CDP capture with `--js-runtime-observer`.
3. Record action evidence: trace, HAR without bodies, CDP events, scripts,
   console, runtime exceptions, and `js-runtime-events.json`.
4. Add `--js-coverage` when you need executed script ranges or high-call
   function evidence, then run `analyze_coverage.py`.
5. Summarize artifacts with `summarize_capture.py`; inspect redacted summary
   and timeline, not raw secrets.
6. Build a provenance map:
   `user action -> JS event/API -> script URL/stack -> browser state change ->
   network request -> response/status -> follow-up action`.
7. Separate facts from inference. If a token-like value is present, report only
   the source API, key name class, length/type/hash metadata, and call stack.
8. If static source review is needed, use official source maps or script files
   from the authorized capture. Do not import raw scripts into context-hub.

## Capture Command

Dry-run:

```bash
node plugins/baza/scripts/web_capture/record_playwright_cdp.mjs \
  --authorized \
  --dry-run \
  --js-runtime-observer \
  --url http://127.0.0.1:3000 \
  --out .baza/web-re/example
```

Live authorized capture:

```bash
node plugins/baza/scripts/web_capture/record_playwright_cdp.mjs \
  --authorized \
  --js-runtime-observer \
  --js-coverage \
  --url <authorized-url> \
  --action-label "<action>" \
  --out .baza/web-re/<run-id>
```

Then:

```bash
python3 plugins/baza/scripts/web_capture/summarize_capture.py .baza/web-re/<run-id>
python3 plugins/baza/scripts/web_capture/analyze_coverage.py .baza/web-re/<run-id>
python3 plugins/baza/scripts/web_capture/verify_artifacts.py .baza/web-re/<run-id> --require-summary
```

## Runtime Surfaces

The observer records sanitized metadata for:

- `fetch`, XHR, `sendBeacon`,
- WebSocket and EventSource creation/messages,
- localStorage/sessionStorage writes,
- document.cookie reads/writes by key only,
- Web Crypto API operation names,
- base64 encoding/decoding call sites,
- FormData key usage,
- selected canvas/WebGL access signals.

It does not record raw values by default.

## When To Add Manual DevTools

Use Chrome DevTools manually when:

- a human must reproduce a fragile flow,
- call stacks need breakpoints,
- Performance flame chart is needed,
- source maps reveal readable application code,
- a script is generated/evaluated dynamically and CDP metadata is insufficient.
