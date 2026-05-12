# Mobile Codex Gateway

Last updated: 2026-05-05

## Decision

Build a project-local mobile web gateway for iPhone control of Codex sessions
running on the laptop.

Zed remains the desktop IDE. The mobile client does not control Zed directly.
Instead, it controls Codex sessions that run in the same project directories and
use the same local project context:

- `~/.codex/config.toml`
- project `AGENTS.md`
- project `.codex/config.toml` when present
- BAZA projection and project docs
- MCP routes and project-scoped context-hub category
- local git working tree and files

The recommended architecture is:

```text
iPhone PWA / mobile browser
        |
        | HTTPS or LAN HTTP + authenticated WebSocket/SSE
        v
local zed-mob-gateway on the laptop
        |
        | stdio or loopback JSON-RPC
        v
Codex app-server / Codex runtime
        |
        v
selected project + AGENTS.md + BAZA + MCP + git + files
```

## Research Summary

### OpenAI Codex

Primary source:

- https://github.com/openai/codex
- https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md

Codex provides `codex app-server`, a JSON-RPC 2.0 app server intended for rich
interfaces. It exposes thread/session operations, turn streaming, interrupts,
file operations, command execution, skills, hooks, auth, and related agent
events.

Relevant methods include:

- `initialize`
- `thread/list`
- `thread/start`
- `thread/resume`
- `thread/read`
- `turn/start`
- `turn/steer`
- `turn/interrupt`
- `fs/readFile`
- `fs/writeFile`
- `fs/readDirectory`
- `command/exec`
- `skills/list`
- `hooks/list`

Codex app-server supports transports including stdio, websocket, unix sockets,
and local app-server control. The websocket transport is marked experimental and
unsupported. Non-loopback websocket exposure needs explicit authentication and
should not be used as the first production boundary.

Decision impact: use Codex app-server as the agent core, but keep it behind our
own local gateway instead of exposing raw Codex websocket directly to the LAN.

### Zed and ACP

Primary sources:

- https://zed.dev/docs/ai/external-agents
- https://github.com/zed-industries/codex-acp

Zed supports external agents through ACP. For Codex, Zed runs Codex through the
`codex-acp` adapter and presents it in the Agent Panel. This is useful for the
desktop editor workflow, but current public docs describe the integration as a
UI-based editor feature, not as a stable headless Zed server API for mobile
clients.

Decision impact: do not build the mobile product on "headless Zed". Reuse the
same project files and Codex/BAZA/MCP configuration, but connect the mobile UI
to Codex through our own gateway.

### Existing GitHub Projects

Researched candidates:

- Yep Anywhere: https://github.com/kzahel/yepanywhere
- CloudCLI / claudecodeui: https://github.com/siteboon/claudecodeui
- Companion: https://github.com/The-Vibe-Company/companion
- Agmente: https://github.com/rebornix/Agmente
- OpenClaw: https://github.com/openclaw/openclaw

Findings:

- Yep Anywhere is the closest UX reference for this project: it is
  mobile-first, self-hosted, supports Codex, keeps agent processes owned by the
  laptop/server, shows a multi-session dashboard, and focuses on phone
  supervision rather than terminal streaming.
- CloudCLI has a ready mobile web UI and supports Codex, projects, sessions,
  shell, git, and file views. It is useful for quick local validation, but it is
  broader than this project and uses AGPL licensing.
- Companion is a useful reference for a web UI and Codex app-server adapter. It
  is MIT-licensed, but its security and approval behavior must be audited before
  reuse.
- Agmente is relevant for native iOS workflows because it supports ACP and
  Codex app-server protocol, but still requires a safe server/gateway on the
  laptop.
- OpenClaw is a broader assistant gateway. It may be too large for the focused
  "iPhone controls Codex on laptop" workflow.

Decision impact: copy the UX pattern, not the whole product. The immediate UI
direction is an inbox/session list plus a full-screen chat view with hidden
diagnostics. Keep the project architecture focused on a local Codex Mobile
Gateway with BAZA enforcement.

### Local iOS Design Prototype

The repository also contains `ios/ACPChat`, a SwiftUI prototype for an ACP-style
iOS client. It is useful as a visual reference, but not as the current runtime
path.

Reusable UX patterns:

- `DesignSystem.swift`: dark neutral surfaces, indigo/cyan/pink accents,
  monospaced tags, compact spacing, and rounded controls
- `ChatView.swift`: full-height transcript, bottom composer, round send/stop
  controls, and mobile keyboard-friendly layout
- `MessageBubble.swift`: user bubbles aligned right, assistant bubbles aligned
  left, compact footer metadata, and collapsible tool receipts
- `SessionListView.swift`: session cards with a 4px active left bar and
  compact metadata
- `RootView.swift`: connection/status pill and persistent new-session action

Decision impact: port the visual language into the PWA, while keeping the
gateway network layer on HTTP/SSE and Codex app-server stdio.

Implementation note: mobile approval rendering is required for MCP-first BAZA
work. Codex can emit `mcpServer/elicitation/request` while waiting for approval
to call scoped `context_hub` tools. The gateway must surface that request in
the transcript and return `accept` or `decline` to Codex app-server; otherwise
the turn appears visually incomplete and eventually gets interrupted.

## Rejected Alternatives

### Headless Zed

Rejected as the primary architecture.

Reason: there is no clearly documented stable headless Zed API for mobile
project selection, Codex thread control, approvals, diffs, and file operations.
Zed is valuable as the desktop IDE and ACP client, but the mobile path should
talk to Codex directly through our own gateway.

### Raw terminal streaming

Rejected as the primary architecture.

Examples: SSH, tmux, ttyd, wetty, or a generic PTY wrapper around `codex`.

Reason: a terminal bridge can be built quickly, but mobile UX for approvals,
diffs, project selection, long agent output, and thread management is worse
than a protocol-aware UI. It also requires fragile terminal parsing.

### Exposing raw Codex app-server websocket to LAN

Rejected as the primary security boundary.

Reason: Codex websocket transport is experimental and unsupported. Non-loopback
exposure must be authenticated. The safer design is to keep Codex app-server on
stdio or loopback and expose only our own authenticated gateway.

### Claude-oriented products as core

Rejected.

Reason: this project will use the current Codex agent workflow, not Claude Code.
Multi-provider products can be used for research, but the core should be
Codex-specific and BAZA-aware.

## BAZA Requirements

BAZA is mandatory for mobile-controlled project work. The mobile gateway must
not treat BAZA as optional UI metadata. It must enforce BAZA as a preflight
layer before starting or resuming agent work.

For each selected project, the gateway should verify:

- the project is in an explicit allowlist
- `AGENTS.md` exists
- project `.codex/config.toml` exists when required by the project
- `plugins/baza` exists
- `docs/status.md` exists
- `docs/agents/baza.md` exists
- the active context-hub category matches the project category
- BAZA doctor/audit status is current enough for the requested action

Recommended preflight commands:

```bash
make baza-doctor
make baza-audit
make baza-docs-sync
```

`make baza-docs-sync` should run after sanitized documentation changes. It may
be skipped for read-only chat turns, but the UI must show whether docs sync is
current, stale, failed, or unknown.

Blocking BAZA failures should prevent creation of a new mobile-controlled
agent thread. Non-blocking warnings should be visible in the project screen.

## Security Requirements

The gateway must use secure local defaults:

- bind to LAN only after explicit user configuration
- require a token or paired-device credential
- support QR pairing for the iPhone
- avoid exposing raw Codex app-server to the LAN
- restrict projects to an allowlist of local paths
- never allow arbitrary path selection from the phone
- preserve Codex approval flows for risky operations
- log agent turns, approvals, interrupts, project selection, and preflight
  results
- never index or display secrets, credentials, local databases, raw captures,
  browser profiles, cookies, HAR files, or generated sensitive artifacts

Remote access outside the home LAN should be a later feature and should use a
private network layer such as Tailscale or WireGuard, or a protected tunnel with
strong access controls.

## MVP Scope

The first usable version should include:

- local backend process on the laptop
- mobile-first PWA served by the backend
- authenticated iPhone access
- project picker backed by a path allowlist
- project status page with BAZA state
- new Codex thread
- resume existing Codex thread when supported reliably
- streaming chat output
- turn interrupt
- tool call and approval display
- basic session metadata persisted locally

Out of scope for MVP:

- native iOS app
- remote internet access
- direct Zed UI control
- full file explorer
- full git dashboard
- multi-provider agent support

## Implementation Plan

### Phase 0: Existing Solution Spike

Goal: validate assumptions and collect implementation patterns.

Tasks:

- run CloudCLI locally and test iPhone access over LAN
- run Companion locally and inspect Codex app-server behavior
- compare project selection, session recovery, approvals, and mobile UX
- record reusable patterns and security gaps

### Phase 1: Codex App-Server Protocol Spike

Goal: prove direct Codex control without Zed or a terminal parser.

Tasks:

- generate or inspect Codex app-server TypeScript schema
- start Codex app-server via stdio or loopback
- send `initialize`
- start a thread in a selected project
- send a turn through `turn/start`
- stream agent events to a local test client
- interrupt an active turn
- test thread resume/list behavior

### Phase 2: Local Gateway MVP

Goal: create the first project-specific mobile control plane.

Tasks:

- implement backend project allowlist
- implement Codex process/session manager
- implement JSON-RPC bridge
- persist session metadata in SQLite or a small local store
- implement auth token and device pairing
- expose WebSocket/SSE for mobile chat streaming
- add structured error reporting for BAZA preflight failures

### Phase 3: Mobile PWA

Goal: make the iPhone workflow usable.

Screens:

- project picker
- project status with BAZA health
- thread list
- chat view
- approvals view
- minimal settings view

### Phase 4: BAZA Integration

Goal: make BAZA state explicit and enforceable.

Tasks:

- run and parse `make baza-doctor`
- run and parse `make baza-audit`
- expose `make baza-docs-sync`
- show context-hub category and sync status
- block agent startup on severe BAZA errors
- surface warnings without hiding the chat workflow

### Phase 5: Hardening and Operations

Goal: make the service practical on a personal laptop.

Tasks:

- add macOS launchd service
- add LAN bind configuration
- add optional HTTPS
- add audit log viewer
- add idle session cleanup
- add laptop sleep handling guidance
- add backup/export for local session metadata

### Phase 6: Optional Enhancements

Potential additions:

- file and diff viewer
- git status and branch view
- reusable prompt/actions panel
- BAZA action buttons
- MCP route diagnostics
- Tailscale/WireGuard access profile
- native iOS client or Agmente-compatible server mode

## Open Questions

- Which Codex app-server transport is most stable locally for long-running
  sessions: stdio, unix socket, or loopback websocket?
- How reliably can current Codex app-server list and resume previous threads
  across process restarts?
- What exact event types must be rendered for high-quality mobile approvals and
  diffs?
- Should the backend use Node.js or Bun for the first version?
- Should session metadata be SQLite from day one or start with JSON files?
- Which BAZA warnings are blocking versus informational for mobile work?

## Current Recommendation

Build `zed-mob-gateway` as a focused Codex Mobile Gateway:

- Codex-specific
- BAZA-aware
- local-first
- iPhone PWA first
- no Claude Code dependency
- no headless Zed dependency
- no raw LAN exposure of Codex app-server

Use Zed on the laptop as the normal desktop editor. Use the mobile gateway as a
separate control surface for the same projects and Codex configuration.

## Implementation Notes

Initial implementation started on 2026-05-03.

Implemented foundation:

- Node.js backend with no runtime npm dependencies
- static mobile PWA shell
- allowlisted project registry
- BAZA status endpoint
- BAZA preflight endpoint
- optional docs sync through preflight
- local session metadata store
- initial Codex app-server stdio adapter
- Codex executable probe endpoint
- optional bearer token API auth

Module details are recorded in `docs/modules/zed-mob-gateway.md`.
