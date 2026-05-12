---
name: tls-fingerprint-research
description: Use for authorized research and project selection around TLS, JA3/JA4-like, HTTP/2, HTTP/3, browser impersonation, curl_cffi, curl-impersonate, tls-client, Python-Tls-Client, fing, and related official repositories. Use for compatibility diagnostics and tool evaluation, not for default bypass/evasion automation.
---

# TLS Fingerprint Research

Use this skill when a project needs to understand or choose tooling around
TLS/HTTP fingerprint behavior.

Primary docs:

- `plugins/baza/docs/tls-fingerprint-tooling.md`
- `plugins/baza/docs/upstream-monitoring.md`
- `plugins/baza/docs/reverse-engineering.md`

Tracked upstreams live in:

```text
plugins/baza/upstreams/registry.toml
```

## Safety Gate

Allowed default work:

- read official repos, docs, releases, issues, and examples,
- compare tool capabilities and maintenance status,
- diagnose client/server compatibility on owned or explicitly authorized
  systems,
- document risks, version drift, and integration constraints.

Not allowed by default:

- anti-bot bypass,
- CAPTCHA solving,
- cookie/session/token generation,
- proxy rotation against third-party services,
- automated replay of protected endpoints,
- copying bypass snippets from upstream READMEs into project code.

If the user asks for live traffic or protected targets, require explicit target
and scope confirmation before proceeding.

## Research Route

Use GitHub MCP first for:

- `lexiforest/curl_cffi`
- `lexiforest/curl-impersonate`
- `lwthiker/curl-impersonate`
- `bogdanfinn/tls-client`
- `FlorianREGAZ/Python-Tls-Client`
- `muzzii255/fing`

For each candidate, check:

- latest release or default branch status,
- license,
- maintained docs and examples,
- supported browser/profile versions,
- HTTP/2 and HTTP/3 support,
- Python/Node/Go integration surface,
- packaging constraints and native binary dependencies,
- whether README examples are safe for BAZA adoption.

## Decision Guidance

Prefer `curl_cffi` for Python projects that need a maintained, requests-like
client with browser-profile support and official documentation.

Prefer `lexiforest/curl-impersonate` when the project needs a command-line or
libcurl-level diagnostic baseline.

Treat `fing` as research material for JA3/Akamai-style fingerprint generation,
not as a default runtime dependency. Its README is explicitly evasion-oriented.

Treat `tls-client` and `Python-Tls-Client` as alternative ecosystem references
when curl_cffi cannot cover the project constraints.

Before integrating any TLS fingerprint tool into a project, record a short ADR:

- why this tool is needed,
- target authorization,
- safer alternatives considered,
- version/release pinned,
- test endpoint or controlled environment,
- data/secret handling boundary,
- rollback plan.
