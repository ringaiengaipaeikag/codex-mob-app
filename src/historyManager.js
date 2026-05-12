import path from "node:path";
import { CodexAppServerClient } from "./codexAppServer.js";
import { listSessions } from "./store.js";

const MAX_HISTORY_LIMIT = 100;
const MAX_TURN_PAGE_LIMIT = 20;
const PROJECT_CHAT_SOURCE_KINDS = ["cli", "vscode", "exec", "appServer", "unknown"];

export async function listProjectHistory({
  project,
  cursor = null,
  limit = 50,
  searchTerm = "",
  archived = false
}) {
  return withHistoryClient(project, async (client) => {
    const result = await client.listThreads({
      cursor,
      limit: boundedLimit(limit),
      searchTerm: searchTerm || null,
      cwd: project.path,
      archived,
      sortDirection: "desc",
      sortKey: "updated_at",
      sourceKinds: PROJECT_CHAT_SOURCE_KINDS,
      useStateDbOnly: false
    });
    const sessionsByThread = await sessionsByThreadId(project.id);
    const threads = (result.data || [])
      .filter((thread) => isPathInside(project.path, thread.cwd))
      .map((thread) => normalizeThread(thread, sessionsByThread));

    return {
      threads,
      nextCursor: result.nextCursor || null,
      backwardsCursor: result.backwardsCursor || null
    };
  });
}

export async function readProjectThread({ project, threadId, includeTurns = true }) {
  return withHistoryClient(project, async (client) => {
    const result = await client.readThread({ threadId, includeTurns });
    const thread = result.thread;
    if (!thread || !isPathInside(project.path, thread.cwd)) {
      throw new Error("thread_not_in_project");
    }
    const sessionsByThread = await sessionsByThreadId(project.id);
    return {
      thread: normalizeThread(thread, sessionsByThread, { includeTurns })
    };
  });
}

export async function listProjectThreadTurns({
  project,
  threadId,
  cursor = null,
  limit = 6,
  sortDirection = "desc"
}) {
  return withHistoryClient(project, async (client) => {
    const result = await client.readThread({ threadId, includeTurns: false });
    const thread = result.thread;
    if (!thread || !isPathInside(project.path, thread.cwd)) {
      throw new Error("thread_not_in_project");
    }

    const direction = normalizeSortDirection(sortDirection);
    const turns = await client.listThreadTurns({
      threadId,
      cursor,
      limit: boundedTurnLimit(limit),
      sortDirection: direction
    });
    const sessionsByThread = await sessionsByThreadId(project.id);
    const pageTurns = direction === "desc" ? (turns.data || []).slice().reverse() : turns.data || [];

    return {
      thread: normalizeThread(thread, sessionsByThread, { includeTurns: false }),
      messages: turnsToMessages(pageTurns),
      nextCursor: turns.nextCursor || null,
      backwardsCursor: turns.backwardsCursor || null,
      sortDirection: direction
    };
  });
}

async function withHistoryClient(project, operation) {
  const client = new CodexAppServerClient({ cwd: project.path });
  try {
    client.start();
    await client.initialize();
    return await operation(client);
  } finally {
    await client.stop();
  }
}

async function sessionsByThreadId(projectId) {
  const sessions = await listSessions(projectId);
  const byThread = new Map();
  for (const session of sessions) {
    if (session.codexThreadId && session.status !== "stale" && !byThread.has(session.codexThreadId)) {
      byThread.set(session.codexThreadId, session);
    }
  }
  return byThread;
}

function normalizeThread(thread, sessionsByThread, { includeTurns = false } = {}) {
  const linkedSession = sessionsByThread.get(thread.id) || null;
  const title = thread.name || thread.preview || `Thread ${String(thread.id).slice(0, 8)}`;
  const status = typeof thread.status === "string"
    ? thread.status
    : thread.status?.type || "unknown";

  return {
    id: thread.id,
    title,
    preview: thread.preview || "",
    cwd: thread.cwd,
    createdAt: unixSecondsToIso(thread.createdAt),
    updatedAt: unixSecondsToIso(thread.updatedAt),
    modelProvider: thread.modelProvider || "",
    source: sourceLabel(thread.source),
    status,
    cliVersion: thread.cliVersion || "",
    gitBranch: thread.gitInfo?.branch || "",
    linkedSessionId: linkedSession?.id || "",
    linkedSessionStatus: linkedSession?.status || "",
    turns: includeTurns ? thread.turns || [] : []
  };
}

function turnsToMessages(turns) {
  const messages = [];
  for (const turn of turns || []) {
    for (const item of turn.items || []) {
      if (item.type === "userMessage") {
        const content = Array.isArray(item.content) ? item.content : [];
        const text = content.map((part) => part.text || "").join("\n").trim() || String(item.text || "").trim();
        const attachments = content.map(userInputAttachment).filter(Boolean);
        if (text || attachments.length) {
          messages.push({ role: "user", text, attachments });
        }
      }
      if (item.type === "agentMessage" && item.text) {
        messages.push({ role: "codex", text: item.text });
      }
    }
  }
  return messages;
}

function userInputAttachment(part) {
  const type = part?.type || part?.kind || "";
  if (!["image", "localImage", "input_image"].includes(type)) {
    return null;
  }
  const pathValue = part.path || "";
  const url = part.url || part.image_url || "";
  const safeUrl = url.startsWith("data:") ? "" : url;
  const name = part.name
    || pathValue.split("/").pop()
    || safeUrl.split("/").pop()
    || "image";

  return {
    name,
    path: pathValue,
    url: safeUrl,
    mimeType: part.mimeType || part.mime_type || imageMimeFromDataUrl(url)
  };
}

function imageMimeFromDataUrl(value) {
  const match = String(value || "").match(/^data:([^;,]+)[;,]/);
  return match ? match[1] : "";
}

function sourceLabel(source) {
  if (!source) return "";
  if (typeof source === "string") return source;
  if (source.type) return source.type;
  const key = Object.keys(source)[0];
  return key || "";
}

function unixSecondsToIso(value) {
  const seconds = Number(value);
  if (!Number.isFinite(seconds) || seconds <= 0) {
    return "";
  }
  return new Date(seconds * 1000).toISOString();
}

function boundedLimit(value) {
  const parsed = Number.parseInt(String(value || ""), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return 50;
  }
  return Math.min(parsed, MAX_HISTORY_LIMIT);
}

function boundedTurnLimit(value) {
  const parsed = Number.parseInt(String(value || ""), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return 6;
  }
  return Math.min(parsed, MAX_TURN_PAGE_LIMIT);
}

function normalizeSortDirection(value) {
  return value === "asc" ? "asc" : "desc";
}

function isPathInside(rootPath, candidatePath) {
  if (!rootPath || !candidatePath) {
    return false;
  }
  const root = path.resolve(rootPath);
  const candidate = path.resolve(candidatePath);
  const relative = path.relative(root, candidate);
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}
