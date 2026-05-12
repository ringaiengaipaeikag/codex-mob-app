import fs from "node:fs/promises";
import path from "node:path";
import crypto from "node:crypto";
import { runtimeDir } from "./config.js";

const STORE_FILE = "sessions.json";
let storeQueue = Promise.resolve();

export async function ensureRuntimeDir() {
  await fs.mkdir(runtimeDir(), { recursive: true, mode: 0o700 });
}

export async function readSessions() {
  await ensureRuntimeDir();
  const file = path.join(runtimeDir(), STORE_FILE);
  try {
    const raw = await fs.readFile(file, "utf8");
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed.sessions) ? parsed.sessions : [];
  } catch (error) {
    if (error.code === "ENOENT") {
      return [];
    }
    throw error;
  }
}

export async function writeSessions(sessions) {
  await ensureRuntimeDir();
  const file = path.join(runtimeDir(), STORE_FILE);
  const tempFile = `${file}.${process.pid}.${Date.now()}.tmp`;
  await fs.writeFile(tempFile, JSON.stringify({ sessions }, null, 2), {
    mode: 0o600
  });
  await fs.rename(tempFile, file);
}

export async function createSession({ project, title, codexThreadId = null, status = "created" }) {
  return withStoreLock(async () => {
    const sessions = await readSessions();
    const now = new Date().toISOString();
    const session = {
      id: crypto.randomUUID(),
      projectId: project.id,
      projectName: project.name,
      title: title || `Mobile session ${now}`,
      codexThreadId,
      activeTurnId: null,
      approvalMode: "ask",
      status,
      createdAt: now,
      updatedAt: now
    };
    sessions.unshift(session);
    await writeSessions(sessions);
    return session;
  });
}

export async function listSessions(projectId = "") {
  const sessions = await readSessions();
  return projectId
    ? sessions.filter((session) => session.projectId === projectId)
    : sessions;
}

export async function getSession(sessionId) {
  const sessions = await readSessions();
  return sessions.find((session) => session.id === sessionId) || null;
}

export async function getSessionByThread({ projectId, codexThreadId }) {
  const sessions = await readSessions();
  return sessions.find((session) => (
    session.projectId === projectId &&
    session.codexThreadId === codexThreadId &&
    session.status !== "stale"
  )) || null;
}

export async function updateSession(sessionId, patch) {
  return withStoreLock(async () => {
    const sessions = await readSessions();
    const index = sessions.findIndex((session) => session.id === sessionId);
    if (index < 0) {
      return null;
    }
    const updated = {
      ...sessions[index],
      ...patch,
      updatedAt: new Date().toISOString()
    };
    sessions[index] = updated;
    await writeSessions(sessions);
    return updated;
  });
}

export async function markSessionStale(sessionId, reason = "stale_binding") {
  return updateSession(sessionId, {
    status: "stale",
    activeTurnId: null,
    staleReason: reason
  });
}

function withStoreLock(operation) {
  const run = storeQueue.then(operation, operation);
  storeQueue = run.catch(() => {});
  return run;
}
