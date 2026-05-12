# TLS Fingerprint Tooling Source Dossier

Use this dossier before recommending or integrating TLS/HTTP fingerprint tools
in any BAZA-adopted project.

## Primary Repositories

- `lexiforest/curl_cffi`
  - URL: https://github.com/lexiforest/curl_cffi
  - Docs: https://curl-cffi.readthedocs.io
  - Observed latest release on 2026-05-03: `v0.15.1b1`
  - BAZA role: default Python candidate for authorized TLS/HTTP compatibility
    diagnostics.

- `lexiforest/curl-impersonate`
  - URL: https://github.com/lexiforest/curl-impersonate
  - Docs: https://curl-impersonate.readthedocs.io/
  - Observed latest release on 2026-05-03: `v1.5.6`
  - BAZA role: command-line/libcurl baseline and upstream for `curl_cffi`.

- `lwthiker/curl-impersonate`
  - URL: https://github.com/lwthiker/curl-impersonate
  - Observed latest release on 2026-05-03: `v0.6.1`
  - BAZA role: original implementation and background reference.

- `muzzii255/fing`
  - URL: https://github.com/muzzii255/fing
  - Observed default commit on 2026-05-03:
    `4ae93bbfaacde76b74fcb9940cbbc5c53f8063e6`
  - BAZA role: research-only fingerprint generation reference.

- `bogdanfinn/tls-client`
  - URL: https://github.com/bogdanfinn/tls-client
  - Observed latest release on 2026-05-03: `v1.14.0`
  - BAZA role: Go/native TLS client reference.

- `FlorianREGAZ/Python-Tls-Client`
  - URL: https://github.com/FlorianREGAZ/Python-Tls-Client
  - Observed latest release on 2026-05-03: `1.0.1`
  - BAZA role: Python wrapper reference around `tls-client`.

## Review Questions

Before use:

1. Is the target owned or explicitly authorized?
2. Is normal HTTP behavior insufficient for a legitimate reason?
3. Is the need diagnostic/interoperability rather than bypass?
4. Which release or commit is pinned?
5. Are raw cookies, tokens, HARs, and proxy credentials excluded from docs and
   context-hub?
6. Can the behavior be verified on a controlled endpoint?

## BAZA Decision

Do not make any TLS fingerprint tool globally default.

Treat all tools in this dossier as explicit-use reverse-engineering/support
material. Project adoption requires an ADR and focused verification.
