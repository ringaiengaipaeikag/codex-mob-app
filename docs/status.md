# Project Status

Last updated: 2026-05-23

## Project

- Name: zed mob app
- Context-hub category: `project-zed-mob-app`
- BAZA version: 0.1.3
- BAZA profile: `mobile-app`
- Root instructions: `AGENTS.md`
- Project docs: `docs/`

## Current Architecture Decision

- Mobile direction: build a local Codex Mobile Gateway for iPhone access.
- Desktop role: keep Zed as the laptop IDE; do not depend on headless Zed.
- Agent role: run Codex on the laptop and expose a project-aware mobile web UI.
- BAZA role: enforce BAZA as a required preflight before mobile-controlled
  agent work.
- Research and implementation plan: `docs/architecture/mobile-codex-gateway.md`
- Implemented module docs: `docs/modules/zed-mob-gateway.md`

## Implementation Status

- Runtime: Node.js service with no npm runtime dependencies.
- Backend: project allowlist, Zed recent project discovery/import, new project
  folder creation, BAZA status, BAZA init/refresh action, BAZA preflight, docs
  sync trigger, local session metadata, Codex app-server probe, Codex thread
  startup, local Codex/Zed history list/read/resume, SSE events, text turn
  submission, BAZA-checked thread resume, turn interrupt, and runtime stop.
- Frontend: chat-first mobile PWA for project selection, project picker, BAZA
  action, History drawer, session creation/selection, Codex/Zed history
  continue, turn submission with image attachments, active-turn interrupt, and
  direct transcript rendering from SSE Codex events plus status-pill active-turn
  feedback for long-running answers.
- Current UI build: `20260523-1900`.
- Current local URL: `http://127.0.0.1:8787`
- LAN mode: run with `ZED_MOB_HOST=0.0.0.0` and `ZED_MOB_TOKEN=<token>`.
- Codex CLI: `codex-cli 0.128.0`
- Runtime smoke: `thread/start`, `turn/start`, SSE events, `agentMessage/delta`,
  and `turn/completed` verified locally.
- Resume smoke: `thread/resume`, `turn/start`, SSE events,
  `agentMessage/delta`, and `turn/completed` verified locally.
- Mobile send fix: repaired `.zed-mob/sessions.json`, changed session state
  writes to serialized atomic temp-file writes, and added visible UI errors for
  failed actions.
- Mobile UX fix: replaced the dashboard-first screen with a session chat view
  so sent text and streamed Codex replies appear in the visible phone viewport;
  diagnostics now live behind a drawer, and active mobile sessions scroll
  directly to the chat screen.
- iOS design import: ported visual patterns from `ios/ACPChat` into the PWA:
  dark design tokens, compact session cards, iMessage-like user/Codex bubbles,
  round send/interrupt buttons, and status pills.
- Mobile approval fix: Codex `*/request` events now render as approval cards in
  the chat instead of only in Dev Tools. Supported
  `mcpServer/elicitation/request` and `item/commandExecution/requestApproval`
  cards can be answered with allow or deny, and the `Always allow` status-pill
  mode persists on the active gateway runtime to auto-accept supported
  permission requests. Replayed approval cards are marked as expired when the
  gateway no longer has the pending callback, so stale history does not show
  live Allow/Deny controls. If the static mobile app is newer than the running
  backend process and `/approval-mode` is missing, the UI now reports that the
  gateway backend needs a restart instead of showing a raw `not_found` error.
- Mobile scroll fix: sending a prompt no longer reconnects SSE and replays the
  full transcript; the visible transcript is limited to the latest 10 messages
  with a button for older history, and a top arrow jumps to the composer.
- Codex history support: added project-scoped `thread/list`, `thread/read`, and
  chat resume endpoints; the PWA can continue existing local Zed/Codex threads
  from mobile.
- Chat order update: live and historical transcripts are bottom-anchored again,
  with current messages next to the composer and older collapsed history above
  the current exchange.
- Unified chat inbox: the History drawer now renders one `Chats` list. Codex/Zed
  threads are canonical, `thread/list` includes `cli`, `vscode`, `exec`,
  `appServer`, and `unknown` source kinds, and `.zed-mob` sessions are used only
  as runtime bindings. Orphan bindings that point at missing rollouts are marked
  stale instead of being shown as chats or retained as the active mobile session.
- UX refresh: the project name opens a project picker, Zed recent projects can
  be imported from the local Zed SQLite workspace database, new project folders
  can be created under the projects root, Status/Probe moved into diagnostics,
  and chat history opens from a `History` drawer instead of filling the main
  mobile screen.
- Settings refresh fix: the top-right refresh button now performs a visible
  app-state refresh instead of only re-reading the project allowlist. It updates
  configured projects, BAZA status, sessions, chat history, current chat state,
  and reconnects the active session stream if it is disconnected.
- Mobile error clarity: projects missing BAZA now return `baza_required` with a
  clear "Tap BAZA" message, and project switching clears stale active chat state
  before the next history list loads.
- History reliability fix: project chat lists now pass `cwd` to Codex
  app-server instead of listing global threads first and filtering afterward.
- New project session fix: mobile `New Session`, session start, history resume,
  and first message send now request `autoBaza`, so a project without BAZA is
  initialized or refreshed before Codex runtime startup. If BAZA still fails,
  the transcript shows one actionable BAZA card instead of repeated generic
  errors.
- New project BAZA fix: creating a project from the mobile project picker now
  immediately runs the BAZA action after the project is selected. The action
  initializes or refreshes the projection, runs doctor/audit, rebuilds the docs
  index, and runs docs health when the project exposes those Makefile targets.
- Mobile stale-turn fix: Codex `thread/status/changed: idle` now clears the
  stored `activeTurnId` as well as marking the mobile session ready, preventing
  the phone UI from treating a completed answer as still active after reconnect
  or server restart.
- Mobile Safari load fallback: the PWA script is served as a classic deferred
  script instead of an ES module because the app does not import modules. The
  HTML shell now exposes a visible connection-line diagnostic when `app.js`
  fails to load or throws during startup.
- Mobile overflow fix: chat, status pills, sheets, and system cards are clipped
  to the viewport to avoid horizontal scrolling on iPhone.
- Mobile two-page UX: the phone UI is now split into a settings page and a chat
  page. Settings exposes `New Session`, `BAZA`, `History`, and `Chat`; the chat
  page uses a DeepSeek-like full-screen layout with the project's dark palette,
  a compact header, a left top chat-history control, a right top settings return
  arrow, flat Codex text, and a compact bottom composer without
  reasoning/search/smiley controls.
- Mobile chat history drawer: the chat header's left `☰` button opens a
  left-side project chat drawer with date-grouped compact rows and an in-drawer
  `+` button for starting a new chat. The drawer closes by tapping the dimmed
  chat area rather than showing an extra close button.
- Mobile composer and attachments: the chat composer is fixed at the bottom of
  chat focus, grows with typed text, scrolls to the newest message after updates,
  uses a plaintext `contenteditable` input to avoid Safari's form-field
  assistant where possible, and can attach up to four local images. Supported
  upload formats are JPEG, PNG, WebP, GIF, HEIC, and HEIF. The gateway saves
  selected mobile images under `.zed-mob/uploads/` and sends them to Codex as
  `localImage` inputs through `turn/start`.
- Mobile composer label cleanup: the focused composer placeholder is `Message`,
  the send arrow points toward the input, and system notice cards no longer show
  a `SYSTEM` footer label.
- Mobile rich transcript rendering: chat text is still sanitized, but fenced
  Markdown code blocks now render as scrollable code panels with a copy button,
  and inline backtick code is styled for readability.
- Voice input research: documented speech-recognition options, official source
  links, HTTPS prerequisite for iPhone microphone capture, and the recommended
  MVP path of browser recording plus OpenAI transcription into the `Message`
  composer.
- History selection UX: selecting a row in the History drawer immediately closes
  the drawer, enters mobile chat focus, shows a pending loader in the transcript,
  and stays bottom-aligned at the latest messages plus composer while the thread
  is resumed or loaded.
- History bottom-follow fix: thread rendering now disables browser scroll
  anchoring for the transcript and repeats bottom alignment across several
  layout frames so long histories open at the latest messages, not at the first
  message in the visible collapsed segment.
- Fast history resume: selecting a History row now requests only the newest
  turn page with `thread/turns/list`, renders the latest messages first, and
  resumes the runtime with `thread/resume` `excludeTurns: true` so large desktop
  histories do not leave a blank mobile chat while the full thread is loading.
  The gateway normalizes that turn page into message records and strips inline
  image data from the response; earlier turns are loaded on demand from the top
  `Show earlier message(s)` control.
- Stop controls cleanup: the runtime stop action moved into Dev Tools as a
  diagnostic operation. The composer interrupt button is hidden unless Codex has
  an active turn, preventing accidental `no_active_turn` errors.
- Active-turn steering: mobile send now submits follow-up text or image input
  through Codex app-server `turn/steer` when an answer is already running,
  instead of blocking the composer until `turn/completed`.
- Mobile stream resilience: SSE now has server heartbeats, foreground/focus/online
  reconnect hooks, backoff reconnect, and an actionable `Reconnect` system card.
  Reconnect also revalidates the mobile session runtime with `/start`, so device
  handoff after a sleeping/backgrounded phone can resume the same Codex thread
  without starting a second parallel turn.
- Mobile foreground replay fix: when the browser is backgrounded, the client
  closes the stale EventSource and resubscribes on return with `after=<seq>`.
  Gateway events carry monotonic `seq` values so missed Codex deltas replay
  without duplicating already rendered text; a saved active session is restored
  after full page reopen when it still belongs to the selected project.
- Active-turn clarity rollback: the standalone active-turn monitor was removed
  from the chat grid after it caused mobile keyboard/layout collisions. Long
  turns still update the session status pill with elapsed time and stream state;
  the composer can steer supported active turns, and unsupported active-turn
  updates return a visible 409 message.
- Mobile header fix: chat-focus header height and icon rendering were stabilized
  after the active-turn monitor change so the history menu, title, and settings
  arrow are not clipped on iPhone.
- Mobile composer viewport fix: chat-focus now uses `visualViewport` height for
  the fixed chat page and restores the mobile grid rows to header, status,
  transcript, and composer so the Message field stays visible when the iOS
  keyboard opens.
- Environment fix: quoted global `github-research` skill descriptions in
  `$HOME/.codex/skills` and `$HOME/.agents/skills`; Codex app-server now
  starts without that YAML skill parse error.
- GitHub preparation: added a root README, ignored local allowlist/runtime and
  generated artifacts, added `config/projects.example.json`, made a missing
  local `config/projects.json` load as an empty allowlist, and enforced
  `ZED_MOB_TOKEN` when the gateway binds outside localhost.
- Public contributor preparation: added `CONTRIBUTING.md`, `SECURITY.md`,
  `CODE_OF_CONDUCT.md`, GitHub issue/PR templates, GitHub Actions CI, and
  `docs/contributing/public-repo.md`.
- Public repository license: added MIT `LICENSE` and linked it from
  `README.md`.
- BAZA public docs refresh: split the repository description into the Zed Mob
  Gateway app and the BAZA projection module, added
  `docs/modules/baza-projection.md`, and updated public contributor docs.
- BAZA local data-store docs: documented context-hub MongoDB for sanitized
  project docs, generated vector indexes, Zed SQLite project discovery, local
  project catalog import, and MCP server setup recommendations.
- Public contributor UX docs: added setup docs for local databases and MCP,
  troubleshooting guidance, and sanitized screenshots for the mobile chat and
  project picker.

## MCP Research

Use MCP-first research. Source of truth:

```text
$HOME/.codex/mcp-first-routes.md
$HOME/.codex/mcp-first-routes.json
```

Active global MCP routes at bootstrap time:

- `context7` (skill `$mcp-research-policy`; scope `main-agent`)
  Smoke: resolve a common library ID and query a narrow docs topic
- `context_hub` (skill `$mcp-research-policy`; scope `main-agent`)
  Smoke: docs_search with the active project category when project docs exist
  Known limit: Requires the active project category from AGENTS.md or docs/status.md; context-hub is shared across projects.
- `github` (skill `$github-research`; scope `subagent-ok`)
  Smoke: read-only release or file lookup through GitHub MCP
  Known limit: Use github_operator only when subagents/delegation are explicitly requested.
- `openaiDeveloperDocs` (skill `$mcp-research-policy`; scope `main-agent`)
  Smoke: OpenAI docs MCP search/fetch for a stable docs page
- `stealth-browser` (skill `$browser-research`; scope `main-agent`; upstream `vibheksoni/stealth-browser-mcp`)
  Smoke: list_cdp_commands; local data: page spawn/navigate/evaluate/screenshot/close when browser execution is needed
  Known limit: Direct stealth-browser tool calls can hang inside browser_operator subagent; execute them in the main agent until that runtime issue is fixed.

Project docs: context-hub only with category `project-zed-mob-app`.

For project docs, use scoped `docs_search(category="project-zed-mob-app")`, then `docs_read` on exact project paths. Do not use context-hub summary tools that cannot scope by category.

## Documentation Hygiene

Do not index, print, commit, or expose secrets, generated artifacts, logs, credentials, cookies, local databases, exports, browser profiles, screenshots, HAR files, or other sensitive data.

## BAZA

- Status: enabled
- Local projection: `plugins/baza`
- Projection metadata: `plugins/baza/.baza-projection.json`
- Adoption notes: `docs/agents/baza.md`
- Current capabilities: MCP-first research, official source index, source dossiers, best-practices policy, orchestration policy, docs sync, upstream monitoring, reverse-engineering policy, and web traffic capture helpers
- Commands: `make baza-doctor`, `make baza-audit`, `make baza-docs-sync`,
  `make baza-docs-vector-sync`, `make baza-docs-search`, `make baza-docs-index`,
  `make baza-docs-health`, `make baza-docs-maintenance`,
  `make baza-register-module`, `make baza-check-upstreams`,
  `make baza-check-official-sources`, `make baza-refresh-projection`

Project work follows the BAZA Best Practices Rule in `AGENTS.md`: official
documentation and canonical repositories first, then local project conventions,
secure focused changes, appropriate verification, and sanitized docs updates.

## Bootstrap Checklist

- [x] Created project `AGENTS.md`
- [x] Created `docs/status.md`
- [x] Applied current BAZA projection
- [x] Added BAZA skills to `.codex/config.toml`
- [x] Added BAZA Best Practices Rule to `AGENTS.md`
- [x] Run `$HOME/.codex/bin/codex-mcp-audit` after opening the project in a fresh Codex/Zed session
- [ ] Verify `context7` route: resolve a common library ID and query a narrow docs topic
- [x] Verify `context_hub` route: docs_search with the active project category when project docs exist
- [ ] Verify `github` route: read-only release or file lookup through GitHub MCP
- [ ] Verify `openaiDeveloperDocs` route: OpenAI docs MCP search/fetch for a stable docs page
- [ ] Verify `stealth-browser` route: list_cdp_commands; local data: page spawn/navigate/evaluate/screenshot/close when browser execution is needed
- [x] Add sanitized project documentation under `docs/`
- [x] Import sanitized docs into context-hub category `project-zed-mob-app` when docs exist
- [x] Run a project smoke check when code exists
