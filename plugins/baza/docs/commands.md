# BAZA Commands

## Apply BAZA

```bash
python3 $HOME/.codex/baza/scripts/baza_init.py --root /path/to/project --category project-my-project
```

Optional:

```bash
python3 $HOME/.codex/baza/scripts/baza_init.py --root /path/to/project --name "Project Name" --category project-my-project
```

With a project profile:

```bash
python3 $HOME/.codex/baza/scripts/baza_init.py \
  --root /path/to/project \
  --name "Project Name" \
  --category project-my-project \
  --profile web-app
```

Use `--force` only when intentionally replacing generated BAZA files.

## Project Doctor

From an adopted project:

```bash
make baza-doctor
```

Equivalent direct command:

```bash
python3 plugins/baza/scripts/baza_doctor.py --root .
```

`baza-doctor` is a local, non-networked check for required BAZA files, Make
targets, projection metadata, key-file drift against the global BAZA source,
project `.codex/config.toml` BAZA skill wiring, and local tool availability.
Use `--json` for machine-readable output and `--strict` when warnings should
fail the run.

## Project Audit

From an adopted project:

```bash
make baza-audit
```

## Project Docs Sync

From an adopted project:

```bash
make baza-docs-sync
```

This syncs sanitized project docs into that project's own context-hub category.

For normal documentation updates, prefer:

```bash
make baza-docs-index
```

That runs Mongo sync and local vector index refresh together.

## Project Docs Health

Check whether local Markdown docs, context-hub Mongo, and the optional local
vector index are aligned:

```bash
make baza-docs-health
```

Direct command:

```bash
python3 plugins/baza/scripts/baza_docs_health.py --root .
```

`baza-docs-health` reports stale hashes, missing manifests, count mismatches,
duplicate chunk paths, missing support indexes, and stale vector indexes.

Create or refresh context-hub support indexes:

```bash
make baza-docs-maintenance
```

## Project Docs Vector Sync

Build or refresh the optional local vector index:

```bash
make baza-docs-vector-sync
```

Direct command:

```bash
python3 plugins/baza/scripts/baza_docs_vector_sync.py --root .
```

Default backend is dependency-free `local-hash`. For local semantic embeddings
through Ollama:

```bash
BAZA_VECTOR_BACKEND=ollama BAZA_VECTOR_MODEL=bge-m3 make baza-docs-vector-sync
```

Generated index path:

```text
.baza/docs-vector/<project-category>/index.json
```

Search the local index:

```bash
make baza-docs-search QUERY="reverse engineering capture policy"
```

Direct command:

```bash
python3 plugins/baza/scripts/baza_docs_search.py --root . --query "reverse engineering capture policy"
```

Run Mongo docs sync and vector sync together:

```bash
make baza-docs-index
```

## Register A Project Module

```bash
make baza-register-module MODULE=service-name ENTRY=src/service.py
```

The generated module doc is a starting point. Fill it in, update
`docs/status.md` if needed, then run `make baza-docs-sync`.

## Check BAZA Upstreams

From an adopted project:

```bash
python3 plugins/baza/scripts/baza_check_upstreams.py
```

From the global BAZA source:

```bash
python3 $HOME/.codex/baza/scripts/baza_check_upstreams.py
```

Use `--strict` for scheduled checks that should fail when a pinned repository
has drifted.

For authenticated read-only GitHub checks, export `GITHUB_TOKEN`, `GH_TOKEN`,
or `GITHUB_PERSONAL_ACCESS_TOKEN`. Do not print or commit the token.

## Check Official Sources

From an adopted project:

```bash
make baza-check-official-sources
```

From the global BAZA source:

```bash
python3 $HOME/.codex/baza/scripts/baza_check_official_sources.py
```

Offline dossier coverage check:

```bash
python3 $HOME/.codex/baza/scripts/baza_check_official_sources.py --offline
```

This checks `official-sources/registry.toml` against
`docs/source-dossiers/`. The network mode also verifies that official docs and
repository URLs are reachable. Use `--strict` for scheduled checks that should
fail when a dossier is missing.

## Refresh Project BAZA Projection

For existing projects after the global BAZA module changes:

```bash
make baza-refresh-projection
```

Equivalent direct command:

```bash
python3 plugins/baza/scripts/baza_refresh_projection.py --root .
```

This updates `plugins/baza` from `$HOME/.codex/baza`, removes stale
projection files that no longer exist in the global source, and appends newly
added BAZA skill entries to an existing `.codex/config.toml`. It also appends
the docs vector Make targets when missing. It does not replace
project-specific `AGENTS.md`, `docs/status.md`, `docs/agents/baza.md`,
`.codex/config.toml`, or other application files.

If `make baza-doctor` still warns that `codex-config:baza-skills` is missing,
rerun the conservative init command without `--force`:

```bash
python3 $HOME/.codex/baza/scripts/baza_init.py --root . --category project-my-project --profile generic
```

That appends the BAZA skill block to `.codex/config.toml` without replacing
the project's existing config. It also refreshes `plugins/baza` from the global
source when the projection already exists.

The same conservative init command also appends `BAZA Best Practices Rule` to
`AGENTS.md` when older projects do not have it.

## Best Practices Policy

BAZA's global best-practices policy is:

```text
plugins/baza/docs/best-practices-policy.md
```

For all adopted projects, implementation and project management should follow
official documentation, canonical repositories, local project conventions,
secure defaults, focused maintainable changes, appropriate verification, and
sanitized documentation updates.

## Web Traffic Capture Helpers

Check local dependencies:

```bash
python3 plugins/baza/scripts/web_capture/check_deps.py
```

Dry-run a capture plan without opening a browser:

```bash
node plugins/baza/scripts/web_capture/record_playwright_cdp.mjs \
  --authorized \
  --dry-run \
  --url http://127.0.0.1:3000 \
  --out .baza/web-re/example
```

Run browser/CDP capture after scope authorization:

```bash
node plugins/baza/scripts/web_capture/record_playwright_cdp.mjs \
  --authorized \
  --url http://127.0.0.1:3000 \
  --out .baza/web-re/example
```

Add sanitized JavaScript API provenance when the task asks how scripts trigger
requests, mutate storage/cookies, call crypto/encoding APIs, or form
token-like values:

```bash
node plugins/baza/scripts/web_capture/record_playwright_cdp.mjs \
  --authorized \
  --js-runtime-observer \
  --js-coverage \
  --url http://127.0.0.1:3000 \
  --out .baza/web-re/example
```

Add JS coverage only when you need executed script ranges and high-call
function evidence:

```bash
node plugins/baza/scripts/web_capture/record_playwright_cdp.mjs \
  --authorized \
  --js-coverage \
  --url http://127.0.0.1:3000 \
  --out .baza/web-re/example
```

Summarize, redact, and verify a run:

```bash
python3 plugins/baza/scripts/web_capture/summarize_capture.py .baza/web-re/example
python3 plugins/baza/scripts/web_capture/build_evidence_graph.py .baza/web-re/example
python3 plugins/baza/scripts/web_capture/analyze_scripts.py .baza/web-re/example
python3 plugins/baza/scripts/web_capture/analyze_coverage.py .baza/web-re/example
python3 plugins/baza/scripts/web_capture/redact_artifacts.py .baza/web-re/example
python3 plugins/baza/scripts/web_capture/verify_artifacts.py .baza/web-re/example --require-summary
```

Compare two authorized runs:

```bash
python3 plugins/baza/scripts/web_capture/diff_capture_runs.py \
  .baza/web-re/run-a \
  .baza/web-re/run-b \
  --out .baza/web-re/run-b
```

For dry-run plans:

```bash
python3 plugins/baza/scripts/web_capture/verify_artifacts.py .baza/web-re/example --allow-dry-run
```

Raw capture artifacts must stay ignored. Use:

```text
plugins/baza/templates/web-capture.gitignore
```

## CAPTCHA Protection Analysis

Use the explicit BAZA skill:

```text
plugins/baza/skills/captcha-protection-analysis/SKILL.md
plugins/baza/skills/bot-detection-analysis/SKILL.md
```

Reference:

```text
plugins/baza/docs/web-protection-analysis.md
plugins/baza/docs/capture-evidence-graph.md
plugins/baza/docs/source-dossiers/web-protection-providers.md
```

This workflow records observations only: provider signals, iframe/script
origins, endpoint sequence, token-like key names, and evidence/inference
separation. It must not solve CAPTCHA, replay tokens, or document bypass steps.

Guarded provider skills:

```text
plugins/baza/skills/cloudflare-analysis/SKILL.md
plugins/baza/skills/datadome-analysis/SKILL.md
plugins/baza/skills/trustev-fingerprint/SKILL.md
plugins/baza/skills/akamai-bypass/SKILL.md
plugins/baza/skills/recaptcha-solve/SKILL.md
plugins/baza/skills/tps-browser-harvester/SKILL.md
```

The guarded skills are routing boundaries, not permission to bypass, solve, or
harvest sessions.

## TLS Fingerprint Research

Use the explicit BAZA skill:

```text
plugins/baza/skills/tls-fingerprint-research/SKILL.md
plugins/baza/skills/tls-fingerprint/SKILL.md
```

Reference:

```text
plugins/baza/docs/tls-fingerprint-tooling.md
plugins/baza/docs/source-dossiers/tls-fingerprint-tooling.md
```

Track upstream drift with:

```bash
make baza-check-upstreams
```

## Sync BAZA Documentation

BAZA's own docs use category `project-baza`:

```bash
PROJECT_ROOT=$HOME/.codex/baza \
PROJECT_DOCS_DIR=$HOME/.codex/baza/docs \
PROJECT_DOCS_CATEGORY=project-baza \
mongosh --quiet mongodb://localhost:27017/context-hub \
  $HOME/.codex/baza/scripts/context_hub_import_project_docs.js
```
