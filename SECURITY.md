# Security Policy

Zed Mob Gateway controls local Codex sessions and can trigger file edits or
commands through Codex. Treat the gateway as a local operator tool, not a public
web service.

## Supported Security Boundary

- Default bind: `127.0.0.1`.
- LAN bind requires `ZED_MOB_TOKEN`.
- Projects must be explicitly allowlisted.
- Local runtime data lives in `.zed-mob/` and is ignored by git.
- Raw Codex app-server is kept behind the gateway.

## Do Not Expose

Do not expose this service directly to the public internet. For remote access,
use a private network layer such as Tailscale or WireGuard, or a hardened tunnel
with strong access controls.

Never commit:

- tokens, API keys, passwords, cookies, or credentials
- `.env` files
- `config/projects.json`
- `.zed-mob/`
- browser profiles
- HAR, pcap, trace, or proxy capture artifacts
- generated BAZA vector indexes
- uploaded images or local session state

## Reporting Vulnerabilities

If this repository is public, report security issues privately through GitHub
Security Advisories when enabled. If advisories are not enabled yet, open a
minimal issue that says a private security report is needed, without publishing
exploit details or secrets.

Include:

- affected version or commit
- setup needed to reproduce
- expected and actual behavior
- impact
- suggested fix, if known

## Contributor Expectations

Security-sensitive changes should include focused verification and documentation
updates. Examples include auth behavior, LAN binding, project allowlisting,
filesystem access, upload handling, Codex approval handling, and runtime state.
