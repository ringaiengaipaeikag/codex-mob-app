# Zed Mob Gateway Module

Last updated: 2026-05-12

## Purpose

`zed-mob-gateway` is the local laptop service that exposes a mobile-first web UI
for controlling Codex work in allowlisted projects.

The module is intentionally Codex-specific and BAZA-aware. It does not depend on
Claude Code, headless Zed, or a third-party multi-agent UI.

## Runtime

Runtime stack:

- Node.js 20+
- no runtime npm dependencies
- static mobile PWA served from `public/`
- backend source in `src/`
- local project allowlist in `config/projects.json`
- local runtime state in `.zed-mob/`

`config/projects.json` contains machine-local absolute paths and is ignored by
git. Fresh clones can copy `config/projects.example.json` or start with an empty
allowlist; the gateway treats a missing local allowlist file as `{ "projects":
[] }`.

Runtime session metadata is stored in `.zed-mob/sessions.json`. Writes are
serialized and atomic via a temporary file plus rename, so concurrent Codex
status events cannot corrupt the JSON state file.

Codex/Zed chat history is not copied into `.zed-mob`. The gateway reads local
history through `codex app-server` and only stores a mobile session mapping to
the existing `codexThreadId` when a user resumes a historical thread.

Commands:

```bash
npm run check
npm run dev
make app-check
make app-dev
```

Default local URL:

```text
http://127.0.0.1:8787
```

Environment variables:

- `ZED_MOB_HOST`: host to bind, default `127.0.0.1`
- `ZED_MOB_PORT`: port to bind, default `8787`
- `ZED_MOB_TOKEN`: optional bearer token for API requests
- `ZED_MOB_PROJECTS`: optional path to a project allowlist JSON file
- `ZED_MOB_DATA_DIR`: optional runtime state directory

For iPhone LAN access, bind should be changed explicitly, for example:

```bash
ZED_MOB_HOST=0.0.0.0 ZED_MOB_TOKEN=<token> npm run dev
```

The browser can provide the token with `?token=<token>` on first load. The UI
stores the token in `localStorage` for later API calls.

The gateway refuses to start on a non-localhost bind without `ZED_MOB_TOKEN`.

## Implemented API

Health:

```http
GET /api/health
```

Projects:

```http
GET /api/projects
GET /api/projects/recent
POST /api/projects
POST /api/projects/sync-zed
GET /api/projects/:projectId/status
POST /api/projects/:projectId/preflight
POST /api/projects/:projectId/baza
POST /api/projects/:projectId/codex-probe
```

`GET /projects/recent` reads Zed recent projects from the local Zed SQLite
workspace database. `POST /projects/sync-zed` imports recent projects into the
gateway allowlist when they are under the configured projects root or a Zed
trusted worktree root. `POST /projects` creates a new folder under
`ZED_MOB_PROJECTS_ROOT` or the gateway's parent `projects` directory and adds it
to the allowlist. See `docs/modules/baza-projection.md` for the BAZA local
data-store model, including the context-hub documentation database, generated
vector index, and Zed project catalog import flow.

Chats:

```http
GET /api/projects/:projectId/chats
GET /api/projects/:projectId/chats/:threadId
GET /api/projects/:projectId/chats/:threadId/turns
POST /api/projects/:projectId/chats/:threadId/resume
```

`GET /chats` lists canonical local Codex threads whose recorded `cwd` is inside
the allowlisted project path. The gateway passes the project `cwd` to
app-server and asks for `cli`, `vscode`, `exec`, `appServer`, and `unknown`
source kinds so Zed, CLI, and mobile-created threads share one inbox. The list
response omits turn contents. `GET /chats/:threadId` reads the selected thread
with turns for full transcript preview. `GET /chats/:threadId/turns` validates
the thread's project path, reads a small paginated turn page from
`thread/turns/list`, and returns normalized message records instead of raw
turns so inline image data is not sent back to the browser. The mobile UI uses
`direction=desc&limit=6` to show the newest messages first, then loads earlier
turns on demand. `POST
/chats/:threadId/resume` validates the thread's project path, runs BAZA
preflight, creates or reuses local mobile runtime binding metadata, and calls
`thread/resume` through the existing Codex runtime path. When called with
`autoBaza: true`, it initializes or refreshes BAZA before retrying preflight.

`/api/projects/:projectId/history` remains available as a compatibility alias
for `/chats`. New UI code should use `/chats`.

Sessions:

```http
GET /api/sessions?projectId=<projectId>
POST /api/sessions
```

`POST /api/sessions` creates local session metadata, runs BAZA preflight,
starts Codex app-server, creates a Codex thread, and stores `codexThreadId`.
When called with `autoBaza: true`, a new or partial project is prepared with
BAZA before the session is created.

Codex session runtime:

```http
GET /api/sessions/:sessionId/events
POST /api/sessions/:sessionId/start
POST /api/sessions/:sessionId/turn
POST /api/sessions/:sessionId/interrupt
POST /api/sessions/:sessionId/stop
```

`GET /events` is an SSE stream. `POST /turn` sends text input to Codex through
`turn/start` when no answer is active and through `turn/steer` when the current
Codex turn is still active. This lets the mobile browser submit clarifications
or course corrections while a long answer is running, matching the desktop
same-turn steering behavior when Codex accepts it. The endpoint also accepts an
`attachments` array with image data URLs from the mobile browser. The gateway
validates JPEG, PNG, WebP, GIF, HEIC, and HEIF files, saves up to four 8 MB
images per turn under
`.zed-mob/uploads/<session>/`, and sends them to Codex as `localImage` inputs.
PDF and arbitrary file inputs are not exposed in this endpoint because the
current Codex App Server user input schema documents text plus image inputs,
not generic files. If Codex reports that the active turn cannot accept same-turn
steering, the gateway returns a 409 `turn_already_active` response and the UI
keeps the active turn state visible. `POST /interrupt` calls `turn/interrupt` only for the
active turn. `POST /stop` terminates the local app-server process for that
session while preserving the stored Codex thread id. `POST /start` resumes or
starts the runtime only after BAZA preflight passes, and also accepts
`autoBaza: true`.

## BAZA Integration

Project status checks verify:

- `AGENTS.md`
- `docs/status.md`
- `docs/agents/baza.md`
- `plugins/baza`
- `Makefile`
- configured context-hub category

BAZA preflight runs:

```bash
make baza-doctor
make baza-audit
```

When requested with `syncDocs: true`, preflight also runs:

```bash
make baza-docs-sync
```

Preflight returns command output, warnings, exit codes, and a blocking status.
Blocking failures prevent the UI from creating or resuming mobile-controlled
agent runtime.

`POST /api/projects/:projectId/baza` is the user-facing BAZA action. For an
existing BAZA project it runs projection refresh, doctor, audit, and docs sync.
For a new or partial project it first runs `plugins/baza/scripts/baza_init.py`
from the gateway project and then runs doctor, audit, and docs sync.

Mobile session creation, session start, and history resume use the same BAZA
action automatically by passing `autoBaza: true`. If the automatic preparation
still leaves blocking checks, the server returns `baza_required` with the
preflight payload and any BAZA action output for diagnostics.

## Codex Integration

`src/codexAppServer.js` contains the JSON-RPC stdio client for:

```bash
codex app-server --listen stdio://
```

Implemented protocol methods:

- `initialize`
- `thread/start`
- `thread/resume`
- `thread/list`
- `thread/read`
- `thread/turns/list`
- `turn/start`
- `turn/steer`
- `turn/interrupt`

The official Codex App Server `turn/start` schema supports mixed user input
items. For this gateway the relevant mobile path is:

```json
[
  { "type": "text", "text": "Review this screenshot" },
  { "type": "localImage", "path": "/absolute/path/to/screenshot.png" }
]
```

Remote image URLs are also supported by Codex (`{ "type": "image", "url": ... }`),
but mobile uploads use `localImage` so the browser does not need to expose a
network-reachable file URL.

The gateway has been smoke-tested with:

```text
thread/start -> turn/start -> item/agentMessage/delta -> turn/completed
thread/resume -> turn/start -> item/agentMessage/delta -> turn/completed
thread/resume excludeTurns -> thread/turns/list desc page -> turn/start
active turn -> turn/steer for a same-turn mobile clarification
```

Current Codex CLI:

```text
codex-cli 0.128.0
```

## Mobile UI

The current PWA shell uses a chat-first layout for mobile use:

- unified project chat rail where Codex threads are the primary chat objects and
  local mobile runtime sessions are only continuation bindings
- full-height session screen with a compact header
- iOS-inspired Codex/user bubbles rendered directly in the main view
- bottom composer with round send and interrupt controls
- fixed bottom plaintext `contenteditable` composer in chat focus that expands
  while typing and avoids Safari's form-field assistant where possible
- image picker and attachment tray for local photo or screenshot uploads
- planned voice input is documented in `docs/research/speech-recognition.md`;
  the first supported scope is microphone recording, server transcription, and
  inserting text into the `Message` composer, not voice command control
- BAZA and session health badges above the transcript
- Codex permission request cards with allow/deny actions; supported
  `mcpServer/elicitation/request` and `item/commandExecution/requestApproval`
  prompts can also be auto-accepted by enabling `Always allow`
- collapsed history mode that shows the latest 12 messages by default
- bottom-anchored chat timeline with current messages next to the composer and
  older collapsed history above the current exchange
- diagnostics hidden in a drawer instead of replacing the chat
- runtime stop action hidden inside Dev Tools; the composer interrupt control is
  visible only while Codex has an active answer turn

The web UI intentionally borrows visual patterns from the local SwiftUI design
under `ios/ACPChat/Views`: `DesignSystem.swift`, `ChatView.swift`,
`MessageBubble.swift`, `SessionListView.swift`, and `RootView.swift`. The
network layer remains the project gateway HTTP/SSE API, not the ACP WebSocket
bridge from the native iOS prototype.

Current UI build:

```text
20260505-1840
```

The PWA supports:

- project picker with configured projects and Zed recent projects
- settings-page refresh action that re-reads configured projects, BAZA status,
  local session bindings, Codex/Zed chat history, and reconnects the active
  session stream when needed
- new local project folder creation under the configured projects root
- large BAZA action for project initialization or refresh
- diagnostics drawer actions for BAZA status, chat refresh, and Codex app-server probe
- left-side History drawer with the unified Codex/Zed chat list scoped to the
  selected project, compact date-grouped rows, and an in-drawer `+` button for
  starting a new chat; it closes by tapping the dimmed chat area
- two-page mobile navigation: Settings contains project controls and the `Chat`
  entry point; Chat is a full-screen conversation page with a compact header,
  a left top chat-history control, and a right top settings return arrow
- continue historical threads from the mobile UI by selecting a history row;
  selection closes the drawer immediately, switches to chat-focus, displays a
  pending loader, requests the newest turn page first, and remains
  bottom-aligned at the composer while the runtime resumes. Transcript rendering
  disables browser scroll anchoring and repeats bottom alignment across several
  layout frames so long collapsed histories open at the latest visible messages.
  Older turns are paginated behind the top `Show earlier message(s)` control.
- local session binding metadata creation
- token prompt and query-token storage
- Codex thread startup
- Codex thread resume
- text turn submission
- image attachment turn submission through Codex `localImage` for JPEG, PNG,
  WebP, GIF, HEIC, and HEIF
- turn interrupt
- Codex server request visibility and `mcpServer/elicitation/request` approval
  response
- per-session approval mode: `Allow: ask` waits for the mobile user, while
  `Always allow` persists on the gateway runtime and auto-accepts supported
  Codex permission requests even if the phone stream reconnects later
- runtime stop
- session list and active session selection
- SSE event rendering
- SSE heartbeats plus foreground/focus/online reconnect for mobile browser
  backgrounding; foreground reconnect closes stale browser streams and
  resubscribes with a sequence cursor so missed runtime events replay without
  duplicating already rendered deltas. Disconnected cards include a manual
  `Reconnect` action.
- visible client-side action errors in the transcript and diagnostics drawer
- automatic BAZA preparation before creating a session, resuming history, or
  sending the first message in a new project
- mobile chat page mode that locks the phone viewport to the active chat, hides
  developer tools while chatting, uses flat assistant message styling inspired
  by DeepSeek while preserving the project palette, and follows newly rendered
  messages automatically. The composer placeholder is `Message`, the send arrow
  points toward the input, and system notices omit the `SYSTEM` footer label.
- safe rich rendering for chat text: fenced Markdown code blocks are rendered
  as scrollable code panels with a copy action, and inline backtick code is
  styled without allowing raw HTML from agent output.
- active-turn clarity without an overlay panel: when Codex is already answering,
  the session status pill shows elapsed runtime and stream state. Sending another
  message during a supported active turn steers the same answer through
  `turn/steer`; if Codex rejects same-turn steering, the UI keeps the active
  state visible and shows an actionable error. The previous standalone monitor
  panel was removed because it consumed a mobile grid row and could push the
  transcript and composer out of alignment when the iOS keyboard was open.

The previous dashboard-first UI made successful mobile sends look like no-ops
because Codex output was pushed into a lower `Output` panel. The current UI
renders sent user text immediately and streams Codex deltas as assistant
message cards. On mobile, Settings and Chat are separate pages rather than a
single long scroll. Selecting or loading an active session opens the Chat page,
and sending a turn reuses the current SSE subscription instead of reconnecting
and replaying the transcript, which prevents the phone viewport from jumping to
the top of the chat. The chat header keeps chat history on the left, the
settings return arrow on the right in the same flat icon style, and new-session
inside the left history drawer. If no session is active, sending the first
message creates a session and prepares BAZA first; repeated "create or select a
session" cards are no longer appended. Mobile CSS clips the chat, sheets, and
status rows to the viewport to avoid horizontal scrolling.

Device handoff is thread-based, not simultaneous multi-client editing. The same
Codex thread can be continued from desktop and then mobile by selecting it from
History, but the product should keep one active writer at a time. The mobile UI
blocks sends while it knows an answer turn is active, and the server rejects a
second mobile `turn/start` if the gateway runtime already has an active turn.
When a phone tab is backgrounded and Safari/Chrome drops SSE, the agent runtime
can continue on the laptop; returning to the tab or tapping `Reconnect`
revalidates `/api/sessions/:sessionId/start` and opens a fresh event stream for
the same session/thread. Each gateway event carries a monotonic `seq`; the
browser stores the last seen sequence and reconnects with `after=<seq>` so only
missed events are replayed. If the page is fully reopened, the saved active
session is restored when it still belongs to the current project.

History selection is optimized for perceived latency. The UI does not wait for
`thread/resume` to return a full `thread.turns` array. It opens chat-focus
immediately, calls `thread/turns/list` through the gateway to render the newest
turn page, then resumes the runtime with `excludeTurns: true`. This keeps large
desktop histories usable on mobile and avoids an empty transcript while the
runtime binding is being prepared.

The session rail now exposes a `History` button instead of an always-open chat
list. Rows are loaded from `thread/list`; selecting one resumes or opens the
linked runtime and scrolls to the latest messages plus the composer. Local
`.zed-mob` records are treated only as runtime bindings for Codex threads, not
as independent chat history. Stale bindings that point at missing rollouts are
marked `stale` and removed from the user-facing inbox and active-session
browser state.

When a project is missing BAZA files, session creation and history resume return
`baza_required` with a user-facing message instead of a generic request failure.
Switching projects clears the active mobile session and transcript immediately
so `Current Chat` cannot show stale data from the previous project while the new
history list is loading. History listing uses Codex app-server's project `cwd`
filter so older project-specific histories are not lost behind newer global
threads from other projects.

## Security Boundaries

Current defaults:

- bind to `127.0.0.1`
- project access only through `config/projects.json`
- Codex history is filtered by allowlisted project path before it is returned
  to the browser
- runtime state ignored by git
- optional bearer token auth
- bearer token required for non-localhost binding
- raw Codex app-server is not exposed to LAN

Before LAN use, run with an explicit token and bind host:

```bash
ZED_MOB_HOST=0.0.0.0 ZED_MOB_TOKEN=<token> npm run dev
```

Do not expose this service to the public internet.

## Next Implementation Steps

1. Render Codex tool calls and approvals.
2. Add QR pairing for iPhone token setup.
3. Add a macOS launchd service for everyday use.
4. Add a session cleanup/delete endpoint.
5. Add archive/unarchive and rename controls for Codex history.
6. Add structured chat transcript storage separate from raw SSE history when
   offline transcript caching becomes necessary.
