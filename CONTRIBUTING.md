# Contributing

Thanks for helping improve Zed Mob Gateway. This project is a local-first mobile
control surface for Codex sessions, so contributions should keep security and
operator control explicit.

## Start Here

1. Read `README.md`.
2. Copy `config/projects.example.json` to `config/projects.json`.
3. Add one local project path to `config/projects.json`.
4. Run:

```bash
npm run check
make baza-audit
```

5. Start the gateway:

```bash
npm run dev
```

Default local URL:

```text
http://127.0.0.1:8787
```

For phone access on the LAN, always set a token:

```bash
ZED_MOB_HOST=0.0.0.0 ZED_MOB_TOKEN=<token> npm run dev
```

## Project Shape

- `src/`: Node.js gateway backend.
- `public/`: mobile PWA frontend.
- `config/projects.example.json`: example allowlist config.
- `config/projects.json`: local allowlist, ignored by git.
- `docs/`: sanitized project documentation.
- `ios/`: SwiftUI prototype/reference client.
- `plugins/baza/`: project-local BAZA projection used for Codex workflow,
  documentation sync, audits, and contributor guardrails.

## Development Rules

- Keep the gateway local-first. Do not expose raw Codex app-server to the LAN or
  internet.
- Do not add arbitrary phone-side filesystem browsing outside allowlisted
  project paths.
- Do not commit local runtime state, uploaded images, logs, captures, browser
  profiles, credentials, or generated indexes.
- Keep `config/projects.json` local. Add example shapes to
  `config/projects.example.json` instead.
- Update `docs/` when changing architecture, APIs, workflows, security behavior,
  BAZA behavior, or contributor setup.
- After doc changes, run `make baza-docs-sync` when local context-hub is
  available. If it is not available, mention that in the PR.

## Checks

Run these before opening a PR:

```bash
npm run check
make baza-audit
```

For documentation changes:

```bash
make baza-docs-sync
```

The GitHub CI workflow runs `npm run check` and `make baza-audit`.

## Pull Requests

Keep PRs focused. Include:

- what changed
- why it changed
- how it was verified
- screenshots or screen recordings for UI changes when useful
- any BAZA/docs sync blocker

## Public Repo Hygiene

Before pushing a branch, check what will be committed:

```bash
git status --short --ignored
git add --dry-run .
git grep -n -I --untracked --exclude-standard -E '(/Users/|/Volumes/|sk-[A-Za-z0-9]|ghp_[A-Za-z0-9])' -- .
```

The grep can produce false positives in docs and URLs, but real local paths and
tokens must be removed or ignored.
