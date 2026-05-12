---
name: bot-detection-analysis
description: Use for explicit authorized, observations-only analysis of multi-layer bot/protection systems from sanitized BAZA captures: TLS/HTTP fingerprints, headers, browser JS signals, protection-provider scripts, challenge widgets, device fingerprinting, endpoint sequence, and run diffs. Do not use for bypass, CAPTCHA solving, cookie harvesting, proxy rotation, or protected endpoint automation.
---

# Bot Detection Analysis

Use this skill to coordinate the safe reverse-engineering skills when a site
action appears to involve anti-abuse or bot-protection logic.

## Load Order

Use only what the evidence needs:

1. `http-traffic-analysis` for endpoint sequence and request initiators.
2. `js-runtime-analysis` for browser API provenance.
3. `js-coverage-analysis` for executed script ranges and run comparison.
4. `captcha-protection-analysis` for provider/challenge observations.
5. Provider-specific observation skills:
   `cloudflare-analysis`, `datadome-analysis`, `trustev-fingerprint`,
   `akamai-bypass`, `recaptcha-solve`.
6. `tls-fingerprint-research` or `tls-fingerprint` for tooling research and
   compatibility diagnostics.

## Safety Boundary

This skill is not an automation recipe. It must not produce:

- CAPTCHA solving steps,
- bypass sequences,
- reusable cookies or token replay guidance,
- proxy-rotation strategies,
- protected endpoint automation,
- raw challenge payloads or third-party script source dumps.

## Analysis Matrix

For each observed layer, record:

- evidence source: HAR, CDP, runtime observer, coverage, DevTools, mitmproxy,
- direct evidence,
- inference and confidence,
- affected endpoint/action,
- provider or application-owned script,
- safe next capture or official-doc lookup.

Common layers:

- transport: TLS/ALPN/HTTP2/HTTP3 compatibility,
- HTTP: header classes, fetch metadata, status codes, redirects,
- browser state: cookies/storage key names, service workers, iframes,
- JavaScript: canvas/WebGL/navigator/crypto/network/runtime categories,
- provider: Cloudflare, DataDome, Akamai, reCAPTCHA, hCaptcha, Turnstile,
  Arkose, PerimeterX/HUMAN, AWS WAF, Kasada, GeeTest, FingerprintJS,
- application: auth/session/device fingerprint integrations.

## Output

Produce `anti-abuse-observations.md` or a project note with:

- scope and authorization,
- observed layers,
- evidence/inference split,
- run-diff findings,
- missing evidence,
- safe next steps.

