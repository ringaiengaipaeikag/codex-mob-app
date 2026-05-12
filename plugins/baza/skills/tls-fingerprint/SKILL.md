---
name: tls-fingerprint
description: Compatibility alias for `tls-fingerprint-research`. Use for authorized TLS/JA3/JA4-like, HTTP/2, HTTP/3, browser-profile, curl_cffi, curl-impersonate, tls-client, Python-Tls-Client, and fing research. Use for compatibility diagnostics and tool selection, not for default anti-bot bypass, CAPTCHA solving, cookie/session generation, or protected-endpoint replay.
---

# TLS Fingerprint

This BAZA skill is a compatibility route for users and projects that ask for
`tls-fingerprint`.

Use the main policy and workflow:

```text
plugins/baza/skills/tls-fingerprint-research/SKILL.md
plugins/baza/docs/tls-fingerprint-tooling.md
plugins/baza/docs/source-dossiers/tls-fingerprint-tooling.md
```

Keep work in research and diagnostics mode unless the user separately confirms
a controlled, authorized target and a lawful purpose.

Allowed:

- compare official repositories and releases,
- evaluate maintained clients and browser-profile support,
- diagnose owned/test TLS compatibility,
- document version pins, risks, and rollback plans.

Not allowed by default:

- bypass instructions,
- CAPTCHA solving,
- cookie/session/token generation,
- proxy rotation against third-party services,
- replaying protected endpoints.

