# TLS Fingerprint Tooling

BAZA tracks TLS, HTTP/2, and HTTP/3 fingerprint tooling for authorized
compatibility diagnostics and controlled security research.

This section is explicit-use only. These tools must not become default bypass,
CAPTCHA, token-generation, proxy-rotation, or protected-endpoint replay
automation.

## Current Upstream Findings

Evidence gathered from official GitHub repositories on 2026-05-03:

- `lexiforest/curl_cffi` is a Python binding for a `curl-impersonate` fork. Its
  README documents browser TLS/JA3 and HTTP/2 fingerprint support, HTTP/3
  support, WebSocket support, a requests-like API, and a `curl-cffi` CLI. Latest
  GitHub release observed: `v0.15.1b1`.
- `lexiforest/curl-impersonate` is an active fork of `curl-impersonate` with
  newer browser profiles, HTTP/3/QUIC fingerprint support, ECH-related work,
  and broader binaries. Latest GitHub release observed: `v1.5.6`.
- `lwthiker/curl-impersonate` is the original special curl build that modifies
  TLS and HTTP/2 handshakes to resemble browsers. Latest GitHub release
  observed: `v0.6.1`.
- `muzzii255/fing` is a small MIT-licensed toolkit for generating TLS and
  HTTP/2/Akamai-style fingerprints and integrating with `curl_cffi`. It has no
  latest GitHub release endpoint at the time of review.
- `bogdanfinn/tls-client` is a Go/native TLS client library ecosystem with
  browser profiles, WebSocket support, and HTTP/3 fingerprinting in the latest
  observed release `v1.14.0`.
- `FlorianREGAZ/Python-Tls-Client` is a Python wrapper around `tls-client` with
  requests-like syntax and custom JA3/HTTP2 settings. Latest GitHub release
  observed: `1.0.1`.

## BAZA Selection Guidance

Default Python candidate:

```text
curl_cffi
```

Reasons:

- active Python package,
- requests-like API,
- documented browser impersonation profiles,
- HTTP/2, HTTP/3, WebSocket, async support,
- official docs and release channel.

Command-line/libcurl diagnostic baseline:

```text
lexiforest/curl-impersonate
```

Research-only references:

```text
fing
tls-client
Python-Tls-Client
lwthiker/curl-impersonate
```

Use these when the primary candidate cannot answer the research question or
when comparing ecosystem behavior.

## Required Integration ADR

Before any project adopts TLS fingerprint tooling, create a short ADR covering:

1. Authorized target and scope.
2. Why normal HTTP clients are insufficient.
3. Tool chosen and official repository/release.
4. Safer alternatives considered.
5. Test endpoint or controlled environment.
6. Secret, token, cookie, HAR, and proxy boundaries.
7. Verification plan.
8. Rollback/removal plan.

## Upstream Registry

Tracked repositories live in:

```text
$HOME/.codex/baza/upstreams/registry.toml
```

Use:

```bash
make baza-check-upstreams
```

or:

```bash
python3 plugins/baza/scripts/baza_check_upstreams.py
```

GitHub checks can use `GITHUB_TOKEN`, `GH_TOKEN`, or
`GITHUB_PERSONAL_ACCESS_TOKEN` for read-only authenticated rate limits. Never
print or commit the token.

## Safety Notes

Some upstream README files explicitly discuss bypass/evasion use cases. BAZA
may track those repositories as evidence, but project guidance must stay on
authorized diagnostics, interoperability, and controlled security research.

Do not copy upstream bypass examples into project docs or generated code.
