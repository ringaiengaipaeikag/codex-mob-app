# Zed Mob Gateway

Local mobile web gateway for controlling Codex sessions from an iPhone or other
mobile browser while Codex runs on the laptop in allowlisted project folders.

This repository has two first-class parts:

- **Zed Mob Gateway app**: the local Node.js service and mobile PWA that expose
  a phone-friendly Codex control plane.
- **BAZA project module**: the committed `plugins/baza/` projection that gives
  the project repeatable Codex guardrails, MCP-first research routing, docs
  sync, audits, and contributor workflow checks.

The runtime is intentionally local-first:

- Node.js backend with no npm runtime dependencies
- static mobile PWA in `public/`
- Codex App Server integration over stdio
- project allowlist instead of arbitrary phone-side path selection
- BAZA preflight before mobile-controlled agent work
- optional bearer token auth for the gateway API

## Repository Map

```text
src/                    Node.js gateway backend
public/                 mobile PWA frontend
config/                 project allowlist example; local allowlist is ignored
docs/modules/           module docs for the app and BAZA projection
docs/architecture/      architecture decisions and roadmap
ios/                    SwiftUI prototype/reference client
plugins/baza/           BAZA project-local projection
.github/                CI, issue templates, and PR template
```

Start with:

- `docs/modules/zed-mob-gateway.md` for the app runtime and API.
- `docs/modules/baza-projection.md` for the BAZA module in this repository.
- `docs/contributing/public-repo.md` for public contributor hygiene.

## Requirements

- Node.js 20+
- Codex CLI with `codex app-server`
- BAZA projection already present in this repository

## Setup

Create a local project allowlist:

```bash
cp config/projects.example.json config/projects.json
```

Edit `config/projects.json` with absolute paths to the projects that the mobile
gateway may control. This file is ignored by git because it contains local
machine paths.

Run a syntax check:

```bash
npm run check
```

Start the local gateway:

```bash
npm run dev
```

Default URL:

```text
http://127.0.0.1:8787
```

For iPhone LAN access, bind explicitly and set a token:

```bash
ZED_MOB_HOST=0.0.0.0 ZED_MOB_TOKEN=<token> npm run dev
```

Open the gateway from the phone with:

```text
http://<laptop-lan-ip>:8787/?token=<token>
```

Do not expose this service to the public internet.

## Configuration

Environment variables:

- `ZED_MOB_HOST`: host to bind, default `127.0.0.1`
- `ZED_MOB_PORT`: port to bind, default `8787`
- `ZED_MOB_TOKEN`: optional bearer token, required for LAN binding
- `ZED_MOB_PROJECTS`: optional path to the project allowlist JSON
- `ZED_MOB_PROJECTS_ROOT`: optional root for newly created projects
- `ZED_MOB_DATA_DIR`: optional runtime state directory

Local runtime state is written to `.zed-mob/` and is ignored by git.

## Useful Commands

```bash
npm run check
npm run dev
make app-check
make app-dev
make baza-audit
make baza-docs-sync
```

## BAZA Module

BAZA is not application business logic. It is a reusable Codex project bootstrap
layer, committed here as `plugins/baza/` so contributors can run the same local
checks as the maintainer. In this repository it provides:

- MCP-first research and project-scoped docs routing
- BAZA doctor/audit checks before mobile-controlled Codex work
- sanitized docs sync into the `project-zed-mob-app` context-hub category
- best-practices and security guardrails for contributor work
- reusable skills, source dossiers, profiles, and project bootstrap scripts

Generated BAZA state is ignored by git; the committed module is the reusable
projection, not local indexes or runtime metadata.

## Repository Hygiene

Files intentionally excluded from git:

- `.zed-mob/` runtime state, sessions, uploads, and protocol cache
- `config/projects.json` local allowlist paths
- `.baza/docs-vector/` generated local vector index
- captures, logs, browser profiles, and trace artifacts
- Xcode user state and generated archives

Sanitized architecture and module documentation lives in `docs/`.

## Contributing

Public contribution guidance is in `CONTRIBUTING.md`. Security boundaries and
private reporting guidance are in `SECURITY.md`.

BAZA is intentionally committed under `plugins/baza/` so contributors can run
the same local audit commands. Generated BAZA indexes and projection metadata
are ignored by git.

## License

MIT. See `LICENSE`.
