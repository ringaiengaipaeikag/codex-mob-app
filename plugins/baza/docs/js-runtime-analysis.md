# JavaScript Runtime Analysis

BAZA uses JavaScript runtime analysis to understand what happens inside an
authorized browser session during a specific action.

Goal:

```text
user action -> JS API call -> script/call stack -> state mutation ->
network request -> response -> next browser state
```

This is part of the explicit-use reverse engineering section. It is not a
default scraping, bypass, token replay, credential harvesting, or protected-site
automation workflow.

## Default Tooling

Primary recorder:

```text
plugins/baza/scripts/web_capture/record_playwright_cdp.mjs
```

Enable runtime API provenance with:

```text
--js-runtime-observer
```

Enable executed script range evidence with:

```text
--js-coverage
```

Observer script:

```text
plugins/baza/scripts/web_capture/js_runtime_observer.js
```

Output:

```text
.baza/web-re/<run-id>/js-runtime-events.json
```

After capture, build the evidence graph:

```bash
python3 plugins/baza/scripts/web_capture/build_evidence_graph.py .baza/web-re/<run-id>
python3 plugins/baza/scripts/web_capture/analyze_scripts.py .baza/web-re/<run-id>
python3 plugins/baza/scripts/web_capture/analyze_coverage.py .baza/web-re/<run-id>
```

The observer records sanitized metadata only. It records key names, API names,
value types, lengths, event timing, and call stacks. It does not record raw
token values, cookies, request bodies, response bodies, or storage values.

## Runtime Surfaces

The observer tracks:

- `fetch`, XHR, `navigator.sendBeacon`,
- WebSocket and EventSource creation and message metadata,
- localStorage/sessionStorage writes and removals,
- document.cookie reads/writes by key only,
- Web Crypto API operation names,
- base64 encoding/decoding call sites,
- FormData key usage,
- selected canvas and WebGL access signals.

CDP still provides the authoritative browser evidence for:

- `Network.*` request/response lifecycle,
- `Runtime.*` console and exception data,
- `Debugger.scriptParsed` script inventory,
- worker and service worker target metadata,
- Playwright trace screenshots, DOM snapshots, and action timing.

## Analysis Method

For each action, produce a provenance map:

```text
action label
  -> script URL or generated/eval script
  -> observed JS API call
  -> stack frame
  -> storage/cookie/crypto/network event
  -> endpoint path/status
  -> follow-up browser state
```

If a token-like value is involved, document only:

- storage key or header name class,
- value type and length,
- generating API class such as crypto, encoding, storage, fetch, or script
  response,
- script URL and sanitized stack,
- endpoint that receives the value,
- whether the evidence is direct or inferred.

Do not document raw token values or replay steps.

## Evidence Graph

Use `capture-evidence-graph.md` when the question is broader than one API
call. The graph links runtime events, script stack frames, worker targets,
storage key names, endpoints, and protection-provider signals.

Use `diff_capture_runs.py` when token or protection behavior is ambiguous. A
run diff is often the fastest way to isolate which endpoint, script, storage
key, or provider signal appeared only after a challenge or login state changed.

Use `js-coverage-analysis` when the question is whether a specific script or
provider path actually executed. Coverage output reports percentages, offsets,
categories, and high-call function counts only; it must not be used to paste
third-party source or reconstruct bypass logic.

## When To Use Manual DevTools

Use Chrome DevTools in addition to BAZA scripts when:

- a fragile flow needs human reproduction,
- source maps expose readable application code,
- breakpoints are needed to inspect a specific call stack,
- Performance flame charts are needed,
- generated or eval scripts require manual naming and inspection.

Official references:

- Chrome DevTools Protocol Runtime:
  https://chromedevtools.github.io/devtools-protocol/tot/Runtime/
- Chrome DevTools Protocol Debugger:
  https://chromedevtools.github.io/devtools-protocol/tot/Debugger/
- Chrome DevTools Protocol Network:
  https://chromedevtools.github.io/devtools-protocol/tot/Network/
- Playwright tracing:
  https://playwright.dev/docs/trace-viewer-intro
- Playwright network:
  https://playwright.dev/docs/network

## Artifact Rule

Raw artifacts stay local under ignored paths:

```text
.baza/web-re/<run-id>/
```

Only sanitized summaries may be imported into project docs or context-hub.
