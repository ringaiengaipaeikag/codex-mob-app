---
name: captcha-protection-analysis
description: Use for explicit authorized analysis of CAPTCHA, challenge pages, bot protection, anti-abuse JavaScript, token provenance, iframe/worker challenge flows, and provider detection from sanitized BAZA web capture artifacts. This skill documents behavior and evidence; it must not solve CAPTCHA, replay tokens, bypass access controls, or automate protected endpoints outside the confirmed scope.
---

# CAPTCHA Protection Analysis

Use this skill when the task is to understand how a site protection flow works
during an authorized browser action.

Primary docs:

- `plugins/baza/docs/web-protection-analysis.md`
- `plugins/baza/docs/capture-evidence-graph.md`
- `plugins/baza/docs/web-traffic-capture-pipeline.md`

Primary scripts:

- `plugins/baza/scripts/web_capture/record_playwright_cdp.mjs`
- `plugins/baza/scripts/web_capture/build_evidence_graph.py`
- `plugins/baza/scripts/web_capture/diff_capture_runs.py`
- `plugins/baza/scripts/web_capture/analyze_scripts.py`
- `plugins/baza/scripts/web_capture/analyze_coverage.py`

## Safety Gate

Confirm:

- target origin,
- exact action,
- authorization scope,
- whether login/test account is involved,
- whether CAPTCHA/protection artifacts may appear,
- whether the user wants observation, comparison, or a sanitized report.

Do not solve CAPTCHA, harvest tokens, replay challenge payloads, automate
protected endpoints, or provide bypass steps. Do not print raw challenge
payloads, cookies, browser fingerprints, screenshots, request/response bodies,
or tokens.

## Default Workflow

1. Record an authorized action with JS runtime observer and JS coverage enabled
   when script execution path evidence matters.
2. Summarize the capture.
3. Build the evidence graph.
4. Analyze scripts by URL, coverage, and optional authorized source directory.
5. Load provider-specific guarded skills only when evidence matches:
   `cloudflare-analysis`, `datadome-analysis`, `akamai-bypass`,
   `recaptcha-solve`, or `trustev-fingerprint`.
6. Produce an observations-only report.
7. For uncertainty, record a second run and diff the two captures.

Commands:

```bash
node plugins/baza/scripts/web_capture/record_playwright_cdp.mjs \
  --authorized \
  --js-runtime-observer \
  --js-coverage \
  --url <authorized-url> \
  --action-label "<action>" \
  --out .baza/web-re/<run-id>

python3 plugins/baza/scripts/web_capture/summarize_capture.py .baza/web-re/<run-id>
python3 plugins/baza/scripts/web_capture/build_evidence_graph.py .baza/web-re/<run-id>
python3 plugins/baza/scripts/web_capture/analyze_scripts.py .baza/web-re/<run-id>
python3 plugins/baza/scripts/web_capture/analyze_coverage.py .baza/web-re/<run-id>
python3 plugins/baza/scripts/web_capture/verify_artifacts.py .baza/web-re/<run-id> --require-summary
```

Diff two runs:

```bash
python3 plugins/baza/scripts/web_capture/diff_capture_runs.py \
  .baza/web-re/<left-run-id> \
  .baza/web-re/<right-run-id> \
  --out .baza/web-re/<right-run-id>
```

## Evidence To Report

Report only sanitized evidence:

- provider signals: reCAPTCHA, hCaptcha, Turnstile, Arkose, DataDome, Akamai,
  PerimeterX/HUMAN, AWS WAF, Kasada, GeeTest, FingerprintJS,
- challenge iframe/script origins,
- token-like key names and value classes, never values,
- JS API categories: crypto, storage, cookie, network, worker, canvas, WebGL,
- endpoint sequence and status codes,
- request initiator script or stack when available,
- what is directly observed versus inferred.

## Output Rule

Use:

- `evidence-graph.md`,
- `anti-abuse-observations.md`,
- `script-analysis.md`,
- `capture-diff.md`.

Never import raw HAR, trace, screenshots, token values, cookies, CAPTCHA
payloads, browser profiles, or packet captures into context-hub.
