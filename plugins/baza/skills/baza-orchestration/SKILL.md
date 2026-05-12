---
name: baza-orchestration
description: Use when planning how Codex should coordinate main thread work, subagents, MCP-first research, skills, review, and documentation updates in a BAZA-enabled project.
---

# BAZA Orchestration

Use `plugins/baza/docs/orchestration-policy.md` as the durable policy.

## Core Rules

- Main thread owns planning, architecture, integration, and final answer.
- Delegate only concrete, bounded side tasks that can run in parallel.
- Keep immediate blocking work in the main thread.
- Use MCP-first research before generic web search.
- For GitHub, OpenAI/Codex, third-party docs, and project docs, use the
  dedicated MCP route first.
- For project docs, use category-scoped context-hub first, then
  `baza-docs-search` when hybrid/semantic retrieval is useful.
- For authorized web action, endpoint, HAR, CDP, JavaScript runtime, or
  mitmproxy capture, use the `web-traffic-capture` skill and its pipeline docs.
- When orchestration rules or project workflow changes, update project docs and
  sync them.

## Documentation Rule

New modules, agents, skills, MCP routes, APIs, database flows, and major
workflows require sanitized docs updates before the task is complete.
