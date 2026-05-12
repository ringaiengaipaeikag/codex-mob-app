---
name: recaptcha-solve
description: Guarded compatibility skill for requests that mention reCAPTCHA solving. In BAZA this means authorized reCAPTCHA integration analysis, official documentation lookup, test-key diagnostics, and sanitized protection observations. It must not solve third-party CAPTCHA, use CAPTCHA-solving services, harvest or replay tokens, or automate protected endpoints.
---

# reCAPTCHA Guarded Analysis

This skill intentionally does not implement CAPTCHA solving. It exists so
requests that use the legacy/project term `recaptcha-solve` are routed into a
safe BAZA workflow.

Allowed:

- analyze an owned site's reCAPTCHA integration,
- use official Google test keys or a controlled test environment,
- inspect sanitized browser evidence for widget/script/iframe presence,
- document key names and endpoint sequence with values redacted,
- troubleshoot why a project-owned test integration fails.

Not allowed:

- third-party CAPTCHA solving,
- CAPTCHA-solving API integration for protected targets,
- token harvesting,
- token replay,
- bypass instructions,
- automating protected endpoints.

Use:

```text
plugins/baza/skills/captcha-protection-analysis/SKILL.md
plugins/baza/docs/web-protection-analysis.md
plugins/baza/docs/source-dossiers/web-protection-providers.md
```

For owned integration debugging, cite official Google reCAPTCHA documentation
and keep all site keys, tokens, request bodies, cookies, and screenshots out of
project docs unless they are official test values.

