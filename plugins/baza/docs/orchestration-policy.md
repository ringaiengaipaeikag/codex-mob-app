# BAZA Orchestration Policy

BAZA includes orchestration rules because project productivity depends on how
Codex, subagents, skills, MCP servers, and project docs are combined.

## Roles

- Main thread: planning, architecture, tradeoffs, integration, and final answer.
- Worker subagent: bounded implementation work in a clear write scope.
- Explorer/docs researcher: read-only mapping, docs lookup, and source evidence.
- Reviewer: correctness, security, data safety, missing tests, and regressions.
- Project documentarian: documentation updates and context-hub hygiene.
- Documentation Search Operator: project-scoped context-hub lookup plus
  optional `baza-docs-search` hybrid retrieval before broad file search.
- Documentation Health Operator: use `baza-docs-health` when docs freshness,
  Mongo manifests, vector indexes, or category separation are in question.
- Web Capture Operator: explicit-use orchestration for authorized browser/CDP,
  HAR, mitmproxy, packet, JavaScript runtime, and endpoint capture workflows.
- HTTP Flow Analyst: explicit-use reconstruction of sanitized HAR/CDP/proxy
  evidence into endpoint, state, and request dependency maps.
- JS Coverage Analyst: explicit-use analysis of CDP coverage files to identify
  executed scripts, ranges, and high-call functions without raw source dumps.
- Web Protection Analyst: explicit-use observations-only analysis of
  CAPTCHA/protection signals, evidence graphs, run diffs, and provider
  documentation.

## Delegation

Use subagents only when the user explicitly asks for agents, delegation, or
parallel agent work, or when the active product surface explicitly enables that
workflow. Keep tightly coupled or immediate blocking work in the main thread.

Delegated coding work must have a bounded write scope. Delegated read-only work
must produce concrete file paths, source links, risks, or next actions.

## MCP-First Research

Use the most authoritative configured MCP before generic web search:

- GitHub work: GitHub MCP first.
- OpenAI/Codex/API work: OpenAI Developer Docs MCP first.
- Library/framework work: Context7 first.
- Project docs: context-hub scoped to the active project category only.
- Local docs vector search: use `baza-docs-search` when semantic/hybrid lookup
  is useful or exact context-hub search misses likely docs.
- Browser/DOM/network/CDP inspection: stealth-browser only for authorized or
  local targets.
- Web traffic capture: use the `web-traffic-capture` skill and
  `docs/web-traffic-capture-pipeline.md` before choosing tools.
- HTTP flow analysis: use `http-traffic-analysis` after capture or HAR import.
- JavaScript coverage: use `js-coverage-analysis` after `--js-coverage` runs.
- CAPTCHA/protection analysis: use `captcha-protection-analysis` and official
  provider docs before interpreting challenge or token-like signals.

Generic web search is fallback when no dedicated route exists or MCP evidence is
incomplete.

## Zed/Codex Caveats

Do not mention directories such as `.codex`, `.agents`, `docs`, or `scripts` as
Zed thread context. Mention concrete files or ask Codex to inspect directories
with shell search tools.

If a thread hits `context_window_exceeded`, start a fresh thread and rely on
`AGENTS.md`, `docs/status.md`, BAZA docs, and project docs instead of old chat
history.

## Documentation Coupling

Any new module, service, pipeline stage, agent, skill, MCP route, external
integration, database flow, API surface, or major workflow must update sanitized
project documentation and sync it into the project-scoped local documentation
database before the task is considered done.
