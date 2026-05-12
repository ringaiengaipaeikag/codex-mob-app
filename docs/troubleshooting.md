# Troubleshooting

Last updated: 2026-05-12

## Gateway Does Not Start

Check Node.js:

```bash
node --version
npm run check
```

The server binds to `127.0.0.1:8787` by default. If the port is busy:

```bash
ZED_MOB_PORT=8797 npm run dev
```

For phone access on the LAN, bind explicitly and set a token:

```bash
ZED_MOB_HOST=0.0.0.0 ZED_MOB_TOKEN=<token> npm run dev
```

Do not expose the gateway to the public internet.

## No Projects Appear

Create a local allowlist:

```bash
cp config/projects.example.json config/projects.json
```

Edit `config/projects.json` with absolute paths. This file is ignored because
it contains local machine paths.

If importing from Zed recent workspaces, confirm Zed's SQLite database exists:

```text
~/Library/Application Support/Zed/db/0-stable/db.sqlite
```

Override the path if needed:

```bash
ZED_MOB_ZED_DB=/path/to/db.sqlite npm run dev
```

## BAZA Fails Preflight

Run:

```bash
make baza-doctor
make baza-audit
```

Common causes:

- missing `AGENTS.md`
- missing `docs/status.md`
- missing `docs/agents/baza.md`
- missing `plugins/baza`
- stale BAZA projection

Refresh the projection:

```bash
make baza-refresh-projection
```

## Docs Health Is Stale

After documentation changes:

```bash
make baza-docs-sync
make baza-docs-vector-sync
make baza-docs-health
```

If MongoDB/context-hub is unavailable, keep Markdown docs updated and mention
the sync blocker in the PR.

## GitHub Push Fails

GitHub no longer accepts account passwords for HTTPS git operations. Use a
GitHub token or a credential helper.

For this repository, a fine-grained token should be scoped to the repository and
include contents write access. If pushing workflow changes, it also needs
workflow write access.

Do not paste the token into issues, PRs, docs, screenshots, or shell history
you plan to share.

## Codex Runtime Is Missing

If the UI reports that Codex cannot be spawned, confirm the Codex CLI is
installed and available in the environment running the gateway:

```bash
codex --version
```

The gateway talks to:

```bash
codex app-server --listen stdio://
```

## iPhone Cannot Reach The Gateway

Check:

- laptop and phone are on the same network
- gateway was started with `ZED_MOB_HOST=0.0.0.0`
- firewall allows the selected port
- URL includes the token when `ZED_MOB_TOKEN` is set

Example:

```text
http://<laptop-lan-ip>:8787/?token=<token>
```
