---
name: akamai-bypass
description: Guarded compatibility skill for requests that mention Akamai bypass. In BAZA this means authorized Akamai/protection observation, official documentation lookup, status/header/cookie-key analysis, and run diffs. It must not provide bypass instructions, solve challenges, harvest cookies, replay payloads, rotate proxies, or automate protected endpoints.
---

# Akamai Guarded Analysis

This skill intentionally does not implement Akamai bypass. It exists so legacy
or project-specific requests using `akamai-bypass` are routed to safe
observations-only analysis.

Allowed:

- identify Akamai-related status codes, headers, script origins, and cookie key
  names in sanitized captures,
- compare authorized successful and failed runs,
- document direct evidence versus inference,
- research official Akamai documentation and public repository evidence,
- diagnose owned/test integration behavior without replaying challenges.

Not allowed:

- challenge solving,
- token or cookie harvesting,
- replaying verification payloads,
- bypass sequences,
- proxy rotation,
- protected endpoint automation.

Use:

```text
plugins/baza/skills/captcha-protection-analysis/SKILL.md
plugins/baza/skills/http-traffic-analysis/SKILL.md
plugins/baza/skills/js-coverage-analysis/SKILL.md
plugins/baza/skills/tls-fingerprint-research/SKILL.md
```

Report only sanitized facts: key names, origins, paths, status codes, script
categories, coverage percentages, and what remains unknown.

