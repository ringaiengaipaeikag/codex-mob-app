---
name: js-coverage-analysis
description: Use for authorized JavaScript coverage analysis from Chrome DevTools Protocol Profiler data, Playwright/Puppeteer coverage output, or BAZA `js-coverage.json` artifacts to understand which scripts and function ranges executed during a browser action. Use for observation, provenance, and comparison; do not use to bypass bot protections, extract secrets, replay tokens, or automate protected endpoints.
---

# JS Coverage Analysis

Use this skill when the question is which JavaScript actually executed during
an authorized browser action.

Primary docs:

- `plugins/baza/docs/js-runtime-analysis.md`
- `plugins/baza/docs/web-traffic-capture-pipeline.md`
- `plugins/baza/docs/web-protection-analysis.md`

Primary scripts:

- `plugins/baza/scripts/web_capture/record_playwright_cdp.mjs`
- `plugins/baza/scripts/web_capture/analyze_coverage.py`
- `plugins/baza/scripts/web_capture/analyze_scripts.py`
- `plugins/baza/scripts/web_capture/diff_capture_runs.py`

## Safety Gate

Coverage shows execution structure and script URLs. It must not be used to
extract secrets, copy proprietary third-party source into docs, reverse
challenge payloads for bypass, or replay token-generation logic.

Only analyze:

- owned code,
- local/test environments,
- third-party sites where the user has explicit authorization,
- sanitized coverage artifacts that omit raw script source.

## Capture

Enable CDP precise coverage:

```bash
node plugins/baza/scripts/web_capture/record_playwright_cdp.mjs \
  --authorized \
  --js-coverage \
  --url <authorized-url> \
  --action-label "<action>" \
  --out .baza/web-re/<run-id>
```

For token provenance or protection-provider analysis, combine with runtime
observer:

```bash
node plugins/baza/scripts/web_capture/record_playwright_cdp.mjs \
  --authorized \
  --js-runtime-observer \
  --js-coverage \
  --url <authorized-url> \
  --action-label "<action>" \
  --out .baza/web-re/<run-id>
```

Analyze:

```bash
python3 plugins/baza/scripts/web_capture/analyze_coverage.py .baza/web-re/<run-id>
python3 plugins/baza/scripts/web_capture/analyze_scripts.py .baza/web-re/<run-id>
```

## Interpretation

Use coverage to answer:

- which scripts were active,
- which providers or application bundles were involved,
- which function ranges executed often,
- whether an action reached expected application code,
- what changed between two authorized runs.

Treat provider classification as a pattern match, not proof. Confirm with
script origins, iframe origins, endpoint sequence, runtime events, and official
documentation.

## Output

Use:

- `js-coverage-analysis.json`,
- `js-coverage-analysis.md`,
- `script-analysis.md`,
- `capture-diff.md` when comparing runs.

Report offsets, percentages, call counts, categories, and redacted URLs. Do not
paste raw third-party source or token-generation code into project docs.

