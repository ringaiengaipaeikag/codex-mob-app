# Public Repository Guide

Last updated: 2026-05-12

## Goal

Make the repository understandable and safe for outside contributors without
requiring access to the maintainer's local machine, Codex history, or runtime
state.

The public repository has two first-class surfaces:

- the Zed Mob Gateway application (`src/`, `public/`, `config/`, `ios/`)
- the BAZA project module (`plugins/baza/`, `AGENTS.md`, `.codex/`, BAZA docs
  and Make targets)

## Public Contributor Entry Points

- `README.md`: project purpose, setup, local/LAN launch, configuration, hygiene.
- `CONTRIBUTING.md`: development flow, checks, PR expectations, public repo
  hygiene.
- `SECURITY.md`: supported security boundary and private reporting guidance.
- `CODE_OF_CONDUCT.md`: lightweight participation rules.
- `.github/workflows/ci.yml`: syntax and BAZA audit checks.
- `.github/ISSUE_TEMPLATE/`: structured bug and feature reports.
- `.github/pull_request_template.md`: verification checklist.
- `docs/modules/baza-projection.md`: BAZA module purpose, boundaries, and
  contributor commands.

## BAZA in the Public Repo

`plugins/baza/` is committed as a project-local projection so contributors can
run the same BAZA checks as the maintainer:

```bash
make baza-audit
make baza-doctor
```

Generated BAZA state is ignored:

- `.baza/docs-vector/`
- `plugins/baza/.baza/`
- `plugins/baza/.baza-projection.json`

This keeps the reusable guardrails available while excluding local generated
indexes and machine-specific metadata.

BAZA's own canonical documentation belongs to the `project-baza` context-hub
category. This application repository documents only the local adoption state,
public contributor workflow, and how the gateway enforces BAZA preflight.

## Local Files That Must Stay Private

- `config/projects.json`
- `.zed-mob/`
- `.env*`
- Xcode `xcuserdata/`
- capture artifacts such as HAR, pcap, traces, browser profiles, and TLS key
  logs
- uploaded mobile images and local Codex session state

## Publication Checklist

Before the first public push:

```bash
npm run check
make baza-audit
make baza-docs-sync
git status --short --ignored
git add --dry-run .
git grep -n -I --untracked --exclude-standard -E '(/Users/|/Volumes/|sk-[A-Za-z0-9]|ghp_[A-Za-z0-9])' -- .
```

False positives are acceptable only when they are clearly public URLs or generic
documentation. Real local paths, credentials, runtime data, and generated
artifacts must not be committed.

## Publishing Status

Published repository:

```text
https://github.com/ringaiengaipaeikag/codex-mob-app
```

CI runs `npm run check` and `make baza-audit` on pushes and pull requests.
