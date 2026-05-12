---
name: web-traffic-capture
description: Use when the user asks to record or analyze a website action, endpoint call, HAR, Chrome DevTools/CDP trace, JavaScript runtime behavior, WebSocket traffic, mitmproxy capture, or sanitized web reverse-engineering report. Explicit authorization is required before live browser, proxy, packet, login, CAPTCHA, or protected-service activity.
---

# Web Traffic Capture

Use this skill for authorized web action and endpoint capture.

Primary docs:

- `$HOME/.codex/baza/docs/web-traffic-capture.md`
- `$HOME/.codex/baza/docs/web-traffic-capture-pipeline.md`
- `$HOME/.codex/baza/docs/capture-evidence-graph.md`
- `$HOME/.codex/baza/docs/web-protection-analysis.md`
- `$HOME/.codex/baza/docs/reverse-engineering.md`

Helper scripts:

- `plugins/baza/scripts/web_capture/check_deps.py`
- `plugins/baza/scripts/web_capture/record_playwright_cdp.mjs`
- `plugins/baza/scripts/web_capture/js_runtime_observer.js`
- `plugins/baza/scripts/web_capture/build_evidence_graph.py`
- `plugins/baza/scripts/web_capture/diff_capture_runs.py`
- `plugins/baza/scripts/web_capture/analyze_scripts.py`
- `plugins/baza/scripts/web_capture/analyze_coverage.py`
- `plugins/baza/scripts/web_capture/redact_artifacts.py`
- `plugins/baza/scripts/web_capture/summarize_capture.py`
- `plugins/baza/scripts/web_capture/verify_artifacts.py`

## Safety Gate

Before live capture, confirm:

- target origin or local app,
- exact action to perform,
- authorization scope,
- whether login, test account, proxy, packet capture, or protected service
  interaction is involved.

Do not proceed with live capture if authorization is unclear.

Do not perform anti-bot bypass, CAPTCHA solving, credential harvesting, cookie
harvesting, proxy rotation, or live traffic modification unless the user gives
separate explicit authorization for a lawful controlled target.

## Default Workflow

1. Classify the task: browser-only, proxy-assisted, packet-assisted, or
   manual-seed.
2. Create `.baza/web-re/<run-id>/`.
3. Write a non-secret `manifest.json`.
4. Use an isolated browser profile, never a personal profile.
5. Prefer Playwright + Chrome DevTools Protocol as the default recorder.
6. Record trace, HAR, console, runtime exceptions, CDP network/runtime/page/log
   events, and optional JavaScript/CSS coverage.
7. Add `--js-runtime-observer` when the task asks why an endpoint fires, how a
   token-like value is produced, or what browser APIs are used.
8. Add mitmproxy only when independent HTTP/TLS/WebSocket evidence is needed.
9. Add Wireshark/tshark only when transport evidence is needed.
10. Stop tools cleanly and close browser context so artifacts flush.
11. Redact raw artifacts before summarizing.
12. Produce `redacted-summary.md`.
13. Build `evidence-graph.json` when endpoint, token, script, worker, or
   protection provenance matters.
14. Run `analyze_scripts.py` when script ownership, source maps, obfuscation,
   CAPTCHA, fingerprinting, crypto, or auth-token code matters.
15. Add `--js-coverage` and run `analyze_coverage.py` when executed script
   ranges, high-call functions, or provider/application coverage differences
   matter.
16. Compare two runs with `diff_capture_runs.py` when behavior changes by
   login state, challenge result, browser profile, or deployment.
17. Verify dry-runs with `verify_artifacts.py --allow-dry-run`.
18. Verify completed captures with `verify_artifacts.py --require-summary`.
19. Sync only sanitized project documentation.

## Output Rules

Raw files must stay local and ignored:

- HAR files,
- Playwright traces,
- mitmproxy flows,
- packet captures,
- TLS key logs,
- screenshots,
- browser profiles,
- cookies and storage,
- request and response bodies,
- raw JS runtime values,
- raw CAPTCHA/challenge payloads,
- raw browser fingerprints.

The final user-facing answer should mention:

- capture depth used or proposed,
- files created,
- redaction status,
- what was learned,
- what remains unknown,
- whether docs sync completed.

## Official Docs

When stuck, use official docs first:

- Chrome DevTools Network:
  https://developer.chrome.com/docs/devtools/network/reference
- Chrome DevTools Recorder:
  https://developer.chrome.com/docs/devtools/recorder/overview
- Chrome DevTools Protocol:
  https://chromedevtools.github.io/devtools-protocol/
- Playwright Trace Viewer:
  https://playwright.dev/docs/trace-viewer-intro
- Playwright Network:
  https://playwright.dev/docs/network
- Playwright HAR recording:
  https://playwright.dev/docs/api/class-browser#browser-new-context-option-record-har
- Puppeteer CDPSession:
  https://pptr.dev/api/puppeteer.cdpsession
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
