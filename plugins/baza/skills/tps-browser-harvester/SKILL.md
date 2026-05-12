---
name: tps-browser-harvester
description: Guarded compatibility skill for requests that mention TPS browser harvesting. In BAZA this routes to authorized browser capture and sanitized evidence analysis only. It must not harvest third-party cookies, extract protected personal data, automate people-search sites, bypass Cloudflare/DataDome, or create reusable sessions.
---

# TPS Browser Harvester Guard

This skill intentionally does not port project-specific cookie harvesting or
people-search extraction workflows into BAZA.

Allowed BAZA use:

- explain why browser capture/cookie harvesting is sensitive,
- run authorized capture against owned/local/test sites,
- inspect sanitized evidence from a project-approved run,
- help design a lawful internal test harness that does not collect third-party
  personal data or reusable session artifacts.

Not allowed:

- harvesting cookies or clearance sessions from third-party services,
- scraping people-search records,
- extracting protected personal data,
- bypassing Cloudflare/DataDome or similar services,
- integrating harvested cookies into HTTP clients,
- proxy rotation or reusable session generation.

Use safe alternatives:

```text
plugins/baza/skills/web-traffic-capture/SKILL.md
plugins/baza/skills/http-traffic-analysis/SKILL.md
plugins/baza/skills/datadome-analysis/SKILL.md
plugins/baza/skills/cloudflare-analysis/SKILL.md
```

If a project has a legacy `tps-browser-harvester` skill, treat it as
project-specific and explicit-only. Do not promote its operational harvesting
steps into global BAZA defaults.

