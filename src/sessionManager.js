import { CodexAppServerClient } from "./codexAppServer.js";
import { findProject } from "./config.js";
import { updateSession } from "./store.js";
import { saveImageAttachments } from "./uploads.js";

const runtimes = new Map();

export async function startRuntime({ session, project }) {
  if (runtimes.has(session.id)) {
    const runtime = runtimes.get(session.id);
    runtime.approvalMode = normalizeApprovalMode(session.approvalMode);
    return runtime;
  }

  const runtime = {
    sessionId: session.id,
    projectId: project.id,
    projectPath: project.path,
    client: new CodexAppServerClient({ cwd: project.path }),
    history: [],
    nextEventSeq: 1,
    pendingRequests: new Map(),
    subscribers: new Set(),
    threadId: session.codexThreadId || null,
    activeTurnId: session.activeTurnId || null,
    approvalMode: normalizeApprovalMode(session.approvalMode),
    initialized: false
  };

  runtime.client.onEvent((event) => recordEvent(runtime, event));
  runtime.client.start();

  try {
    const initialize = await runtime.client.initialize();
    recordEvent(runtime, {
      type: "gateway/initialized",
      result: initialize,
      at: new Date().toISOString()
    });

    if (runtime.threadId) {
      const threadResume = await runtime.client.resumeThread({
        threadId: runtime.threadId,
        cwd: project.path,
        excludeTurns: true
      });
      runtime.activeTurnId = null;
      const updated = await updateSession(session.id, {
        codexThreadId: threadResume.thread.id,
        status: "ready",
        activeTurnId: null
      });
      recordEvent(runtime, {
        type: "gateway/thread-resumed",
        thread: threadResume.thread,
        session: updated,
        at: new Date().toISOString()
      });
    } else {
      const threadStart = await runtime.client.startThread({
        cwd: project.path,
        title: session.title
      });
      runtime.threadId = threadStart.thread.id;
      runtime.activeTurnId = null;
      const updated = await updateSession(session.id, {
        codexThreadId: runtime.threadId,
        status: "ready",
        activeTurnId: null
      });
      recordEvent(runtime, {
        type: "gateway/thread-started",
        thread: threadStart.thread,
        session: updated,
        at: new Date().toISOString()
      });
    }
  } catch (error) {
    await runtime.client.stop();
    throw error;
  }

  runtime.initialized = true;
  runtimes.set(session.id, runtime);
  return runtime;
}

export async function ensureRuntimeForSession(session) {
  const project = await findProject(session.projectId);
  if (!project) {
    throw new Error("project_not_found");
  }
  return startRuntime({ session, project });
}

export async function startTurn({ session, text, attachments = [] }) {
  const project = await findProject(session.projectId);
  if (!project) {
    throw new Error("project_not_found");
  }
  const runtime = await startRuntime({ session, project });
  if (!runtime.threadId) {
    throw new Error("thread_not_ready");
  }
  const { input, savedAttachments } = await buildTurnInput({ session, text, attachments });

  recordEvent(runtime, {
    type: "gateway/user-message",
    text,
    attachments: savedAttachments.map(({ name, mimeType, size }) => ({ name, mimeType, size })),
    at: new Date().toISOString()
  });

  if (runtime.activeTurnId) {
    const result = await runtime.client.steerTurn({
      threadId: runtime.threadId,
      turnId: runtime.activeTurnId,
      input
    });
    recordEvent(runtime, {
      type: "gateway/turn-steered",
      result,
      at: new Date().toISOString()
    });
    return result;
  }

  const result = await runtime.client.startTurn({
    threadId: runtime.threadId,
    input,
    cwd: project.path
  });

  runtime.activeTurnId = result.turn?.id || runtime.activeTurnId;
  await updateSession(session.id, {
    status: "running",
    activeTurnId: runtime.activeTurnId
  });
  recordEvent(runtime, {
    type: "gateway/turn-started",
    result,
    at: new Date().toISOString()
  });

  return result;
}

async function buildTurnInput({ session, text, attachments }) {
  const savedAttachments = await saveImageAttachments({
    sessionId: session.id,
    attachments
  });
  const input = [];
  if (text) {
    input.push({ type: "text", text });
  }
  for (const attachment of savedAttachments) {
    input.push({ type: "localImage", path: attachment.path });
  }
  return { input, savedAttachments };
}

export async function interruptTurn({ session }) {
  const runtime = await ensureRuntimeForSession(session);
  if (!runtime.threadId || !runtime.activeTurnId) {
    throw new Error("no_active_turn");
  }
  const result = await runtime.client.interruptTurn({
    threadId: runtime.threadId,
    turnId: runtime.activeTurnId
  });
  await updateSession(session.id, { status: "interrupting" });
  recordEvent(runtime, {
    type: "gateway/turn-interrupt-requested",
    result,
    at: new Date().toISOString()
  });
  return result;
}

export async function resolveServerRequest({ session, requestId, action }) {
  const runtime = await ensureRuntimeForSession(session);
  const pending = runtime.pendingRequests.get(String(requestId));
  if (!pending) {
    throw new Error("pending_request_not_found");
  }

  const result = responseForServerRequest(pending, action);
  runtime.client.respond(pending.id, result);
  runtime.pendingRequests.delete(String(requestId));
  recordEvent(runtime, {
    type: "gateway/server-request-response",
    requestId: pending.id,
    method: pending.method,
    action,
    at: new Date().toISOString()
  });
  return { requestId: pending.id, method: pending.method, action };
}

export async function setApprovalMode({ session, mode }) {
  const approvalMode = normalizeApprovalMode(mode);
  const updated = await updateSession(session.id, { approvalMode });
  const runtime = runtimes.get(session.id);
  if (runtime) {
    runtime.approvalMode = approvalMode;
    if (approvalMode === "alwaysAllow") {
      for (const pending of Array.from(runtime.pendingRequests.values())) {
        maybeAutoApproveServerRequest(runtime, pending);
      }
    }
  }
  return updated;
}

export async function stopRuntime(sessionId) {
  const runtime = runtimes.get(sessionId);
  if (!runtime) {
    return false;
  }
  await runtime.client.stop();
  runtimes.delete(sessionId);
  await updateSession(sessionId, { status: "stopped", activeTurnId: null });
  return true;
}

export function subscribe(sessionId, response, options = {}) {
  const runtime = runtimes.get(sessionId);
  if (!runtime) {
    response.write(`event: error\ndata: ${JSON.stringify({ error: "runtime_not_started" })}\n\n`);
    response.end();
    return;
  }

  const after = Number(options.after || 0);
  const send = (event) => {
    const payload = eventForSubscriber(runtime, event);
    if (event.seq) {
      response.write(`id: ${event.seq}\n`);
    }
    response.write(`event: message\ndata: ${JSON.stringify(payload)}\n\n`);
  };
  const heartbeat = setInterval(() => {
    response.write(`: heartbeat ${Date.now()}\n\n`);
  }, 15000);

  for (const event of runtime.history) {
    if (event.seq && event.seq <= after) {
      continue;
    }
    send(event);
  }

  runtime.subscribers.add(send);
  response.on("close", () => {
    clearInterval(heartbeat);
    runtime.subscribers.delete(send);
  });
}

function recordEvent(runtime, event) {
  event.seq = runtime.nextEventSeq;
  runtime.nextEventSeq += 1;
  runtime.history.push(event);
  if (runtime.history.length > 500) {
    runtime.history.shift();
  }
  if (event.message?.method === "turn/completed") {
    runtime.activeTurnId = null;
    updateSession(runtime.sessionId, { status: "ready", activeTurnId: null }).catch(() => {});
  }
  if (event.message?.id !== undefined && isServerApprovalRequest(event.message)) {
    runtime.pendingRequests.set(String(event.message.id), event.message);
    event.autoApproved = maybeAutoApproveServerRequest(runtime, event.message);
    event.pendingApproval = runtime.pendingRequests.has(String(event.message.id));
  }
  if (event.message?.method === "serverRequest/resolved") {
    const requestId = event.message.params?.requestId;
    if (requestId !== undefined) {
      runtime.pendingRequests.delete(String(requestId));
    }
  }
  if (event.message?.method === "turn/started") {
    const turnId = event.message.params?.turn?.id;
    runtime.activeTurnId = turnId || runtime.activeTurnId;
    updateSession(runtime.sessionId, {
      status: "running",
      activeTurnId: runtime.activeTurnId
    }).catch(() => {});
  }
  if (event.message?.method === "thread/status/changed") {
    const status = event.message.params?.status?.type;
    if (status === "active") {
      updateSession(runtime.sessionId, { status: "running" }).catch(() => {});
    }
    if (status === "idle") {
      runtime.activeTurnId = null;
      updateSession(runtime.sessionId, { status: "ready", activeTurnId: null }).catch(() => {});
    }
  }
  for (const subscriber of runtime.subscribers) {
    subscriber(event);
  }
}

function eventForSubscriber(runtime, event) {
  if (event.message?.id !== undefined && isServerApprovalRequest(event.message)) {
    return {
      ...event,
      pendingApproval: runtime.pendingRequests.has(String(event.message.id))
    };
  }
  return event;
}

function normalizeApprovalMode(mode) {
  return mode === "alwaysAllow" ? "alwaysAllow" : "ask";
}

function maybeAutoApproveServerRequest(runtime, message) {
  if (runtime.approvalMode !== "alwaysAllow" || !isAutoApprovableServerRequest(message)) {
    return false;
  }
  const requestId = String(message.id);
  if (!runtime.pendingRequests.has(requestId)) {
    return false;
  }
  const result = responseForServerRequest(message, "accept");
  runtime.client.respond(message.id, result);
  runtime.pendingRequests.delete(requestId);
  return true;
}

function isAutoApprovableServerRequest(message) {
  if (!isServerApprovalRequest(message)) {
    return false;
  }
  return [
    "mcpServer/elicitation/request",
    "item/commandExecution/requestApproval"
  ].includes(message?.method);
}

function isServerApprovalRequest(message) {
  return [
    "mcpServer/elicitation/request",
    "item/commandExecution/requestApproval"
  ].includes(message?.method);
}

function responseForServerRequest(message, action) {
  if (message.method === "mcpServer/elicitation/request") {
    if (action === "accept") {
      return { action: "accept", content: {} };
    }
    if (action === "cancel") {
      return { action: "cancel", content: null };
    }
    return { action: "decline", content: null };
  }
  if (message.method === "item/commandExecution/requestApproval") {
    if (action === "accept") {
      return { decision: commandApprovalAcceptDecision(message) };
    }
    if (action === "cancel") {
      return { decision: "cancel" };
    }
    return { decision: "decline" };
  }
  throw new Error(`unsupported_server_request:${message.method}`);
}

function commandApprovalAcceptDecision(message) {
  const decisions = Array.isArray(message.params?.availableDecisions)
    ? message.params.availableDecisions
    : [];
  const amendment = decisions.find((decision) => (
    decision &&
    typeof decision === "object" &&
    decision.acceptWithExecpolicyAmendment
  ));
  return amendment || "accept";
}
