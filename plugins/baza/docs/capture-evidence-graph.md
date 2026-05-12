# Capture Evidence Graph

BAZA uses an evidence graph to turn authorized web capture artifacts into a
sanitized, explainable model.

Goal:

```text
user action -> JS runtime event -> script or worker -> browser state mutation
-> endpoint -> response -> protection signal
```

This graph is explicit-use reverse-engineering infrastructure. It is for
understanding behavior, not for token replay, CAPTCHA solving, or protected
endpoint automation.

## Tooling

Build the graph:

```bash
python3 plugins/baza/scripts/web_capture/build_evidence_graph.py .baza/web-re/<run-id>
```

Outputs:

```text
evidence-graph.json
evidence-graph.md
initiators.json
storage-summary.json
anti-abuse-observations.md
```

Compare two runs:

```bash
python3 plugins/baza/scripts/web_capture/diff_capture_runs.py \
  .baza/web-re/<left-run-id> \
  .baza/web-re/<right-run-id> \
  --out .baza/web-re/<right-run-id>
```

Outputs:

```text
capture-diff.json
capture-diff.md
```

Analyze scripts:

```bash
python3 plugins/baza/scripts/web_capture/analyze_scripts.py .baza/web-re/<run-id>
```

Optional authorized local sources:

```bash
python3 plugins/baza/scripts/web_capture/analyze_scripts.py \
  .baza/web-re/<run-id> \
  --source-dir <authorized-js-source-dir>
```

Outputs:

```text
script-analysis.json
script-analysis.md
```

Analyze JavaScript coverage:

```bash
python3 plugins/baza/scripts/web_capture/analyze_coverage.py .baza/web-re/<run-id>
```

Outputs:

```text
js-coverage-analysis.json
js-coverage-analysis.md
```

## Evidence Model

Nodes:

- `action`: the labeled user action,
- `script`: CDP script inventory entries or initiator script URLs,
- `worker-target`: worker and service worker targets,
- `js-runtime-event`: sanitized runtime observer events,
- `browser-state`: storage, cookie, and FormData key classes,
- `endpoint`: method, origin, path, status, and resource type,
- `protection-provider`: known protection or CAPTCHA provider patterns.

Edges:

- `observed_js_runtime_event`,
- `observed_request`,
- `initiated_request`,
- `runtime_api_targets_endpoint`,
- `stack_frame_for_event`,
- `mutates_browser_state`,
- `matches_provider_pattern`,
- `coverage_matches_provider_pattern`.

## Run Diff

Run diff is the fastest way to isolate protection and token behavior.

Recommended comparisons:

- before login versus after login,
- failed challenge versus successful challenge,
- same action across two browser profiles,
- same action before and after a frontend deployment,
- normal page load versus action that triggers a protected endpoint.

Diff compares only sanitized metadata:

- endpoints,
- script URLs,
- JavaScript coverage categories and percentages when available,
- JS runtime event types,
- protection provider signals,
- storage key names.

## Reporting Rule

Project docs may include graph summaries, endpoint maps, provider observations,
state key names, and script categories. Project docs must not include raw
tokens, cookies, request bodies, response bodies, CAPTCHA payloads, screenshots,
HAR contents, browser profiles, packet captures, or TLS key logs.
