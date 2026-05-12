---
name: cloudflare-analysis
description: Use for explicit authorized observation of Cloudflare protection signals in sanitized captures: Cloudflare challenge pages, Turnstile widgets, `cdn-cgi/challenge-platform` scripts, Cloudflare headers, cookie key names, iframe/script origins, and endpoint sequence. This skill is for evidence and documentation only; it must not solve challenges, harvest clearance cookies, replay tokens, or bypass Cloudflare.
---

# Cloudflare Analysis

Use this skill when sanitized evidence suggests Cloudflare participates in a
site action.

Load only as needed with:

- `captcha-protection-analysis`,
- `http-traffic-analysis`,
- `js-coverage-analysis`,
- `web-traffic-capture`.

## Safety Boundary

Allowed:

- identify Cloudflare-owned origins and scripts,
- document header/cookie key names and status codes,
- identify Turnstile/challenge iframe presence,
- compare successful and failed authorized runs,
- reference official Cloudflare docs for terminology.

Not allowed:

- solving Turnstile or CAPTCHA,
- harvesting `cf_clearance` or other clearance cookies,
- replaying challenge payloads,
- bypass instructions,
- proxy rotation or evasion guidance.

## Evidence Checklist

Look for sanitized evidence:

- script or path patterns: `cdn-cgi/challenge-platform`, `challenges.cloudflare.com`,
  `turnstile`,
- cookie/header key names: `__cf_bm`, `cf_clearance`, `_cfuvid`,
  `cf-ray`, `cf-mitigated`,
- iframe origins for Turnstile or challenge pages,
- status patterns: 403 challenge, 200 challenge HTML, redirects,
- JS runtime categories: storage, cookie, crypto, canvas/WebGL, worker,
- coverage entries for Cloudflare script URLs.

## Report Shape

Write:

- provider: `cloudflare`,
- direct evidence list,
- inferred evidence list,
- action and endpoint sequence,
- scripts/iframes involved,
- unanswered questions and next capture recommendation.

Do not document raw cookie values, challenge parameters, token values, or
bypass sequences.

