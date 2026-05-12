# BAZA Best Practices Policy

BAZA requires every adopted project to be managed and implemented according to
best practices for that project's actual stack, risk level, and existing
architecture.

This is a concrete operating rule, not a generic preference.

## Precedence

When deciding how to implement, refactor, configure, test, document, or operate
a project, use this order:

1. Official documentation, source dossiers, and canonical repositories for the
   exact tools, APIs, frameworks, and versions in use.
2. Existing project architecture, style, naming, test patterns, operational
   runbooks, and security boundaries.
3. Small, maintainable, reviewable changes with the least necessary blast
   radius.
4. Secure defaults: no secret exposure, no unsafe artifact indexing, no broad
   permissions, and no live external automation without explicit scope.
5. Verification appropriate to risk: static checks, focused tests, smoke tests,
   or documented blockers when verification cannot run.
6. Documentation updates when behavior, architecture, commands, integrations,
   or operational workflows change.

## Engineering Rules

- Prefer project-local patterns over new abstractions.
- Prefer official APIs and structured parsers over ad hoc string handling.
- Avoid broad rewrites unless they are required for the task and can be tested.
- Keep changes scoped to the requested behavior and nearby ownership boundary.
- Add tests or checks proportional to risk and blast radius.
- Preserve sensitive data boundaries and do not index or commit generated
  sensitive artifacts.
- Use source dossiers for reusable official-source research.
- Record durable tradeoffs in docs when a best-practice choice is ambiguous.

## Anti-Patterns

- Replacing existing project conventions with generic advice.
- Adding dependencies without clear workflow value.
- Making style-only rewrites during a functional task.
- Claiming "best practice" without official docs, repo evidence, or local
  project precedent.
- Treating warnings, failing checks, or missing verification as irrelevant.

## Project Adoption

Every BAZA-adopted project should include the `BAZA Best Practices Rule` in
`AGENTS.md`. Run the conservative init command without `--force` to append the
rule to older projects:

```bash
python3 $HOME/.codex/baza/scripts/baza_init.py --root . --category project-my-project --profile generic
```
