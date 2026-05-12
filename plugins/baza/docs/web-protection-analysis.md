# Web Protection Analysis

BAZA treats CAPTCHA and bot-protection research as explicit-use, authorized
observation work.

Allowed default goal:

```text
understand what happened, which provider participated, which scripts/endpoints
were involved, and where token-like browser state was created or sent
```

Disallowed default goal:

```text
solve CAPTCHA, bypass protections, harvest tokens, replay challenge payloads,
or automate protected endpoints outside confirmed authorization
```

## Skill

Use:

```text
plugins/baza/skills/captcha-protection-analysis/SKILL.md
plugins/baza/skills/bot-detection-analysis/SKILL.md
```

The skill builds on:

- `web-traffic-capture`,
- `http-traffic-analysis`,
- `js-runtime-analysis`,
- `js-coverage-analysis`,
- `capture-evidence-graph`,
- optional manual DevTools evidence.

## Provider Signals

The evidence graph currently detects sanitized signals for:

- Google reCAPTCHA,
- hCaptcha,
- Cloudflare Turnstile and challenge pages,
- Arkose Labs / FunCaptcha,
- DataDome,
- Akamai bot protection,
- PerimeterX / HUMAN,
- AWS WAF,
- Kasada,
- GeeTest,
- FingerprintJS.

Detection is pattern-based. Treat it as an observation, not proof of the full
protection stack. Confirm by script origins, iframe origins, endpoint sequence,
runtime event types, and official provider documentation.

## Analysis Questions

For each protected action, answer:

1. Which user action created the challenge or token-like state?
2. Which script, iframe, worker, or service worker was involved?
3. Which runtime APIs were used: network, storage, cookie, crypto, canvas,
   WebGL, FormData, WebSocket, or EventSource?
4. Which endpoint received token-like fields or challenge metadata?
5. Which provider pattern was observed?
6. What changed between a successful and failed run?
7. Which claims are direct evidence and which are inference?

## Recommended Pipeline

1. Record an authorized run with `--js-runtime-observer`.
2. Generate `redacted-summary.md`.
3. Build `evidence-graph.json` and `anti-abuse-observations.md`.
4. Run `analyze_scripts.py`.
5. Run `analyze_coverage.py` when JS coverage was captured.
6. Load guarded provider skills only when evidence matches:
   `cloudflare-analysis`, `datadome-analysis`, `trustev-fingerprint`,
   `akamai-bypass`, or `recaptcha-solve`.
7. Record a second run when behavior is ambiguous.
8. Run `diff_capture_runs.py`.
9. Write a sanitized project note or ADR only if the result changes project
   architecture, client choice, test strategy, or operational workflow.

## Manual DevTools Use

Use manual DevTools when:

- challenge timing is fragile,
- provider iframe state needs human observation,
- source maps expose readable application code,
- Performance recording is needed for script execution timing,
- a worker or generated script is hard to attribute from automated logs.

Manual exports are raw sensitive artifacts until redacted.

## Official References

Use the source dossier:

```text
plugins/baza/docs/source-dossiers/web-protection-providers.md
```

Keep provider documentation as context for terminology and expected lifecycle.
Do not copy provider bypass examples, third-party bypass snippets, or raw
challenge data into BAZA docs.

## Guarded Compatibility Skills

BAZA includes guarded skills for legacy/project names that may otherwise imply
operational bypass:

- `akamai-bypass` means Akamai observation and official-doc research only.
- `recaptcha-solve` means owned/test reCAPTCHA integration analysis only.
- `tps-browser-harvester` means a safety guard and authorized capture route,
  not third-party cookie harvesting or people-search automation.

These skills are included to make unsafe requests land on the right boundary,
not to make bypass workflows part of the global baseline.
