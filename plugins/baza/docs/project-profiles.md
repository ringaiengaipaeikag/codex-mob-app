# BAZA Project Profiles

Project profiles are lightweight BAZA adoption presets. They do not replace a
project's own `AGENTS.md` or documentation; they record which BAZA workflows
should be considered first for a project type.

Profiles live in:

```text
$HOME/.codex/baza/profiles
```

Use a profile during adoption:

```bash
python3 $HOME/.codex/baza/scripts/baza_init.py \
  --root /path/to/project \
  --category project-my-project \
  --profile web-app
```

## Available Profiles

- `generic`: default baseline when no project type is known.
- `web-app`: frontend/backend projects with browser testing, product docs,
  API routes, and visual/runtime verification.
- `mobile-app`: mobile clients, app-store style projects, native wrappers, and
  device/emulator workflows.
- `reverse-engineering`: explicit-use authorized API extraction, APK analysis,
  web traffic capture, HTTP flow analysis, JavaScript runtime and coverage
  capture, evidence graphs, CAPTCHA/protection observation, guarded provider
  analysis, TLS fingerprint research, and upstream tool tracking.
- `data-pipeline`: data ingestion, enrichment, exports, databases, operational
  runbooks, and sensitive artifact policy.
- `browser-research`: browser automation, screenshots, DOM/CDP inspection, and
  sanctioned web research workflows.

## Profile Rules

- Profile selection is metadata, not a permission grant.
- Profile selection complements, but does not replace, the BAZA skills enabled
  in project `.codex/config.toml`.
- `baza-docs-search` is recommended across profiles because every project
  benefits from scoped local documentation retrieval.
- Reusable official-source research should update `docs/source-dossiers/`
  regardless of profile.
- Sensitive workflows still require explicit authorization when BAZA or the
  project policy says so.
- Project-local docs remain the source of truth for project-specific choices.
- If a profile causes repeated manual steps, convert those steps into a BAZA
  skill, script, or docs template.

## Upgrade Direction

The next useful step is a profile apply command that can add profile-specific
docs templates without overwriting project files. Until then, profiles are used
for adoption metadata, doctor output, and operator routing.
