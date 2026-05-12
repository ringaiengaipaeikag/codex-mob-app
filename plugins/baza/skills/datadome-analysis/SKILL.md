---
name: datadome-analysis
description: Use for explicit authorized observation of DataDome signals in sanitized captures: DataDome script/collector origins, `datadome` cookie key names, interstitial or challenge redirects, browser-signal categories, and run diffs. This skill documents evidence only; it must not harvest cookies, solve slider/CAPTCHA challenges, replay collector payloads, or bypass DataDome.
---

# DataDome Analysis

Use this skill when sanitized traffic, script inventory, or runtime events show
DataDome indicators.

## Safety Boundary

Allowed:

- identify DataDome origins and collector endpoints,
- document cookie key names and state transitions without values,
- identify interstitial/challenge redirects,
- map browser API categories used during authorized runs,
- compare two sanitized captures.

Not allowed:

- cookie harvesting,
- slider/CAPTCHA solving,
- collector payload replay,
- protected endpoint automation,
- proxy rotation or evasion guidance.

## Evidence Checklist

Look for:

- URL/script patterns: `datadome`, `geo.datadome.co`, `/tag/js/`, `/js/`,
  `/interstitial/`,
- cookie key name: `datadome`,
- redirect/status evidence: 302, 403, interstitial pages,
- JS runtime categories: canvas, WebGL, navigator, storage, cookie, network,
  worker, timing,
- coverage entries for DataDome script URLs,
- differences between successful and blocked authorized runs.

## Report Shape

Report only:

- observed origins, paths, and statuses,
- involved script URLs with query redacted,
- cookie/header key names,
- browser API categories,
- direct evidence versus inference,
- next safe capture or official-doc lookup.

Do not include raw collector bodies, cookie values, challenge payloads, or
instructions to obtain reusable sessions.

