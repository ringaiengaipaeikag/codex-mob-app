# BAZA Official Sources

This index is the first stop for questions about BAZA's base tooling: Codex,
OpenAI developer docs, Zed, Zed external agents, and the GitHub repositories
that BAZA tracks.

Structured registry:

```text
$HOME/.codex/baza/official-sources/registry.toml
```

Durable source dossiers:

```text
$HOME/.codex/baza/docs/source-dossiers
```

## Source Policy

Use official sources first:

- OpenAI/Codex behavior: OpenAI Developer Docs MCP first, then official OpenAI
  docs URLs.
- Repository state, releases, issues, PRs, and code: GitHub MCP against the
  canonical repository.
- Zed product behavior: official Zed docs first, then the official Zed GitHub
  repository.
- Community blogs, snippets, and forum posts are fallback context only. Do not
  use them to override official docs or repository evidence.

## OpenAI And Codex

- Codex CLI reference: https://developers.openai.com/codex/cli/reference
- Codex configuration reference: https://developers.openai.com/codex/config-reference
- Basic Codex config: https://developers.openai.com/codex/config-basic
- Advanced Codex config: https://developers.openai.com/codex/config-advanced
- Codex best practices: https://developers.openai.com/codex/learn/best-practices
- AGENTS.md guide: https://developers.openai.com/codex/guides/agents-md
- Codex CLI slash commands: https://developers.openai.com/codex/cli/slash-commands
- Codex CLI features: https://developers.openai.com/codex/cli/features
- Codex MCP docs: https://developers.openai.com/codex/mcp
- Codex config schema: https://developers.openai.com/codex/config-schema.json
- OpenAI Codex repository: https://github.com/openai/codex
- OpenAI Codex releases: https://github.com/openai/codex/releases

Confirmed through OpenAI docs on 2026-05-03:

- User-level config belongs in `~/.codex/config.toml`.
- Project-scoped overrides belong in `.codex/config.toml`.
- Durable settings include model defaults, profiles, MCP servers, multi-agent
  setup, feature flags, sandboxing, and approval behavior.
- MCP is appropriate when context lives outside the repo, changes frequently,
  should be fetched by tools, or must be repeatable across projects.

Latest GitHub release checked on 2026-05-03:

- `openai/codex`: `rust-v0.128.0`, published 2026-04-30.

## Zed

- Zed docs: https://zed.dev/docs
- Zed AI docs: https://zed.dev/docs/ai
- Zed Agent Panel: https://zed.dev/docs/ai/agent-panel
- Zed Agent Settings: https://zed.dev/docs/ai/agent-settings
- Zed External Agents: https://zed.dev/docs/ai/external-agents
- Zed MCP docs: https://zed.dev/docs/ai/mcp
- Zed repository: https://github.com/zed-industries/zed
- Zed releases: https://github.com/zed-industries/zed/releases
- Zed Codex ACP repository: https://github.com/zed-industries/codex-acp
- Zed Codex ACP releases: https://github.com/zed-industries/codex-acp/releases

Latest GitHub releases checked on 2026-05-03:

- `zed-industries/zed`: `v1.0.0`, published 2026-04-29.
- `zed-industries/codex-acp`: `v0.12.0`, published 2026-04-24.

## Reverse Engineering Tooling

TLS/HTTP fingerprint research sources:

- curl_cffi repository: https://github.com/lexiforest/curl_cffi
- curl_cffi docs: https://curl-cffi.readthedocs.io
- lexiforest curl-impersonate repository:
  https://github.com/lexiforest/curl-impersonate
- lexiforest curl-impersonate docs:
  https://curl-impersonate.readthedocs.io/
- original curl-impersonate repository:
  https://github.com/lwthiker/curl-impersonate
- fing repository: https://github.com/muzzii255/fing
- tls-client repository: https://github.com/bogdanfinn/tls-client
- Python-Tls-Client repository:
  https://github.com/FlorianREGAZ/Python-Tls-Client

Latest GitHub releases checked on 2026-05-03:

- `lexiforest/curl_cffi`: `v0.15.1b1`.
- `lexiforest/curl-impersonate`: `v1.5.6`.
- `lwthiker/curl-impersonate`: `v0.6.1`.
- `bogdanfinn/tls-client`: `v1.14.0`.
- `FlorianREGAZ/Python-Tls-Client`: `1.0.1`.
- `muzzii255/fing`: no latest release endpoint; default commit observed
  `4ae93bbfaacde76b74fcb9940cbbc5c53f8063e6`.

Use these repositories as explicit-use research sources only. Do not copy
upstream bypass/evasion examples into BAZA defaults or project code.

Web protection and CAPTCHA analysis sources:

- Google reCAPTCHA documentation:
  https://developers.google.com/recaptcha/docs/v3
- hCaptcha documentation: https://docs.hcaptcha.com/
- Cloudflare Turnstile documentation:
  https://developers.cloudflare.com/turnstile/
- Cloudflare challenge pages:
  https://developers.cloudflare.com/cloudflare-challenges/challenge-types/challenge-pages/
- Arkose Labs developer documentation:
  https://developer.arkoselabs.com/
- DataDome documentation: https://docs.datadome.co/
- Akamai Cloud Security bot documentation:
  https://techdocs.akamai.com/cloud-security/docs/about-bots
- AWS WAF CAPTCHA and Challenge:
  https://docs.aws.amazon.com/waf/latest/developerguide/waf-captcha-and-challenge.html
- OWASP Automated Threats to Web Applications:
  https://owasp.org/www-project-automated-threats-to-web-applications/
- Chrome DevTools Protocol Target domain:
  https://chromedevtools.github.io/devtools-protocol/tot/Target/

Use these sources for terminology, lifecycle, and evidence interpretation.
Do not use them as a bypass or token replay playbook.

## BAZA Routing Rules

When a task asks about Codex config, Codex CLI, AGENTS.md, MCP behavior,
skills, plugins, or multi-agent behavior:

1. Search OpenAI Developer Docs MCP.
2. Fetch the exact OpenAI doc page or section when citations are needed.
3. Use GitHub MCP only for official repository state, release drift, issues,
   PRs, source code, and changelogs.
4. Update the matching source dossier when the finding is reusable.
5. Record any reusable rule change in BAZA docs and sync `project-baza`.

When a task asks about Zed, ACP, or Zed/Codex integration:

1. Check official Zed docs.
2. Check `zed-industries/zed` or `zed-industries/codex-acp` through GitHub MCP.
3. Treat app-local behavior and user settings as environment-specific until
   verified in the target machine/project.

## Local Quick Commands

```bash
make baza-doctor
make baza-check-upstreams
make baza-check-official-sources
make baza-refresh-projection
make baza-docs-sync
```

`baza-doctor` is local and non-networked. `baza-check-upstreams` uses GitHub
network access and should stay read-only.
