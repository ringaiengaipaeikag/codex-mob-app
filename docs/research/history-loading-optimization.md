# History Loading Optimization Research

Last updated: 2026-05-03

## Problem

Opening a historical Codex/Zed chat from the mobile UI can feel slow. The target
UX is:

```text
tap chat row -> enter chat immediately -> show latest messages near composer -> prepare agent runtime in background
```

The user should not wait for full history, BAZA preflight, or Codex runtime
startup before seeing the recent transcript.

## Current Findings

Local measurements against `http://127.0.0.1:8787`:

- `GET /api/projects`: about 0.24s.
- `GET /api/projects/norm1-csv/chats?limit=60`: about 1.52s, 30 KB.
- `GET /api/projects/norm1-csv/chats/:threadId/turns?limit=6&direction=desc`:
  about 1.17s, 44 KB for the active long chat.
- `POST /api/sessions/:sessionId/start` for the same linked session: about
  4.33s.

The current UI already requests newest turns first with
`thread/turns/list&direction=desc`, but the perceived latency can still be high
because:

- `src/historyManager.js` starts and initializes a fresh `codex app-server`
  client for every history list and every turns page.
- Chat selection can also start or resume the local runtime, which runs BAZA
  preflight (`baza-doctor` and `baza-audit`) before the runtime is ready.
- History list payloads can include very long `title` and `preview` fields. One
  observed thread had about 2.8 KB in both `title` and `preview`, which is too
  large for a compact mobile drawer row.
- The phone may issue repeated project inbox refreshes while the user is opening
  history.

## Recommendation

Do not load the whole remaining history in the background by default. Very long
threads can waste bandwidth and block mobile rendering. Instead:

1. Show the latest 8-10 normalized messages immediately.
2. Preload at most one older page while the UI is idle.
3. Load older pages only when the user taps `Show earlier message(s)` or scrolls
   to the top.
4. Prepare the Codex runtime separately from transcript viewing.

## Proposed Architecture

### 1. Split View From Runtime Activation

Selecting a chat should be read-first:

```text
tap row
-> close history drawer
-> enter chat focus
-> render cached tail if available
-> GET latest messages
-> POST resume/start in background
-> enable composer when runtime is ready
```

The transcript should not wait for `POST /resume`, `/start`, or BAZA preflight.
If the runtime is still preparing, show a small `connecting` status pill and
keep the composer disabled or queue the draft locally.

### 2. Add Tail Endpoint Or Tighten Current Turns Endpoint

The gateway should expose a transcript-tail contract:

```http
GET /api/projects/:projectId/chats/:threadId/tail?messages=10
```

It should return:

```json
{
  "thread": { "id": "...", "title": "...", "updatedAt": "..." },
  "messages": [],
  "olderCursor": "..."
}
```

Unlike the current `limit=6` turns page, this should target message count, not
turn count. It can internally fetch turns until it has enough user/agent
messages, capped by a small maximum.

### 3. Cache History Metadata And Tail Pages

Add stale-while-revalidate cache in the gateway:

- thread list cache per `projectId`, TTL 10-30 seconds;
- tail cache per `projectId + threadId + updatedAt + messageLimit`;
- in-memory first, optional `.zed-mob/history-cache.json` later.

The mobile UI can render stale cached data immediately and refresh silently.
When fresh data arrives, replace only if the user is still viewing the same
thread.

### 4. Pool Codex History Clients

`withHistoryClient()` currently starts and stops a `codex app-server` process for
each history operation. Replace it with a small per-project history client pool:

- key by project id/path;
- initialize once;
- idle timeout 30-120 seconds;
- restart on app-server failure;
- stop all clients on gateway shutdown.

This should reduce the baseline `thread/list` and `thread/turns/list` latency.

### 5. Trim History Drawer Payload

For `GET /chats`, return compact fields:

- `title`: clamp to 120-160 characters;
- `preview`: omit by default or clamp to 160-240 characters;
- keep full text only in transcript endpoints.

Drawer rows only need a title, status/source, and relative time.

### 6. De-duplicate And Cancel Requests

On the client:

- use `AbortController` when switching chats quickly;
- ignore stale responses by `threadId`;
- do not run periodic `loadProjectInbox` while a history selection is in
  progress;
- avoid calling `loadHistory({ reset: true })` immediately after every resume
  on the critical path.

## Implementation Order

1. Trim `/chats` list payload and reduce UI list limit from 60 to 20 initially.
2. Add cached `tail` loading and render cached latest messages before runtime
   activation.
3. Move `/resume` and `/start` into background activation; composer becomes
   available only after runtime is ready.
4. Add per-project Codex history client pool.
5. Add one-page idle prefetch for older messages.
6. Add performance timings to diagnostics so slow phases are visible on mobile.

## Success Criteria

- Tapping a history row shows latest transcript content in under 1 second when
  cache is warm.
- Cold tail load should target under 2 seconds on LAN.
- Runtime preparation may continue separately, but the UI should not look blank
  while it runs.
- No full-history payload should be sent to the phone unless the user explicitly
  asks for older history.
