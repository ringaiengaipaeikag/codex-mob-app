---
name: http-traffic-analysis
description: Use for authorized analysis of HTTP traffic, HAR files, CDP network logs, DevTools exports, mitmproxy captures, endpoint sequences, request/response dependency graphs, header classes, cookie/state key names, WebSocket metadata, and sanitized API flow reconstruction. Do not use for bypass, CAPTCHA solving, cookie harvesting, token replay, or live protected-service automation without separate explicit authorization.
---

# HTTP Traffic Analysis

Use this skill to turn authorized browser/proxy traffic into a sanitized,
reviewable map of what happened.

Primary docs:

- `plugins/baza/docs/web-traffic-capture.md`
- `plugins/baza/docs/web-traffic-capture-pipeline.md`
- `plugins/baza/docs/capture-evidence-graph.md`
- `plugins/baza/docs/web-protection-analysis.md`

Primary scripts:

- `plugins/baza/scripts/web_capture/record_playwright_cdp.mjs`
- `plugins/baza/scripts/web_capture/summarize_capture.py`
- `plugins/baza/scripts/web_capture/build_evidence_graph.py`
- `plugins/baza/scripts/web_capture/diff_capture_runs.py`
- `plugins/baza/scripts/web_capture/redact_artifacts.py`
- `plugins/baza/scripts/web_capture/verify_artifacts.py`

## Safety Gate

Before live capture, confirm:

- target origin or local app,
- exact user action or endpoint,
- authorization scope,
- whether login, test account, proxy, packet capture, CAPTCHA/protection
  artifacts, cookies, storage, HAR, or screenshots are involved.

Raw HAR, cookies, authorization headers, request bodies, response bodies,
tokens, browser profiles, screenshots, and packet captures must stay in ignored
`.baza/web-re/<run-id>/` paths.

Do not use this skill to harvest cookies, replay tokens, solve CAPTCHA, bypass
access controls, or automate protected third-party endpoints. If the user asks
for those actions, stop and restate the allowed observations-only workflow.

## Workflow

1. Choose input: BAZA capture directory, HAR export, CDP log, mitmproxy flow, or
   manual DevTools notes.
2. Redact before summarizing. Prefer BAZA summaries over raw artifact content.
3. Build the endpoint map:
   `method -> origin -> path -> status -> count -> resource type`.
4. Build dependency evidence:
   `user action -> request initiator -> script/worker -> storage key ->
   endpoint -> response status -> follow-up request`.
5. Separate required facts from inference. Never infer that a field is safe to
   reuse just because it appears in a trace.
6. When behavior differs by state, compare two captures with `diff_capture_runs.py`.
7. Write only sanitized conclusions into project docs.

## What To Report

Report:

- endpoint inventory by origin/path/status,
- sequence of core XHR/fetch/WebSocket events,
- initiator script or stack when available,
- state key names and header classes, not values,
- response field names that appear to drive later requests, not raw data,
- protection-provider signals as observations,
- unknowns and recommended next capture.

Do not report:

- raw cookies, auth headers, tokens, challenge payloads, account data,
  request bodies, response bodies, or screenshots,
- instructions for bypass, replay, credential harvesting, proxy rotation, or
  CAPTCHA solving.

## Commands

For BAZA capture output:

```bash
python3 plugins/baza/scripts/web_capture/summarize_capture.py .baza/web-re/<run-id>
python3 plugins/baza/scripts/web_capture/build_evidence_graph.py .baza/web-re/<run-id>
python3 plugins/baza/scripts/web_capture/verify_artifacts.py .baza/web-re/<run-id> --require-summary
```

For two runs:

```bash
python3 plugins/baza/scripts/web_capture/diff_capture_runs.py \
  .baza/web-re/<left-run-id> \
  .baza/web-re/<right-run-id> \
  --out .baza/web-re/<right-run-id>
```

