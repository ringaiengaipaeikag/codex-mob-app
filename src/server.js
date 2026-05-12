import http from "node:http";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { inspectBaza, runBazaAction, runBazaPreflight } from "./baza.js";
import { createProject, findProject, loadProjects, publicProject, serverConfig } from "./config.js";
import { probeCodex } from "./codexAppServer.js";
import { listProjectHistory, listProjectThreadTurns, readProjectThread } from "./historyManager.js";
import { listZedRecentProjects, syncZedRecentProjects } from "./zedProjects.js";
import {
  ensureRuntimeForSession,
  interruptTurn,
  resolveServerRequest,
  setApprovalMode,
  startTurn,
  stopRuntime,
  subscribe
} from "./sessionManager.js";
import {
  createSession,
  ensureRuntimeDir,
  getSession,
  getSessionByThread,
  listSessions,
  markSessionStale,
  updateSession
} from "./store.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC_DIR = path.resolve(__dirname, "..", "public");
const config = serverConfig();

validateSafeBinding(config);
await ensureRuntimeDir();

const server = http.createServer(async (request, response) => {
  try {
    logRequest(request);
    if (request.url.startsWith("/api/")) {
      await handleApi(request, response);
      return;
    }
    await serveStatic(request, response);
  } catch (error) {
    sendJson(response, 500, {
      error: "internal_error",
      message: error.message
    });
  }
});

server.listen(config.port, config.host, () => {
  const authNote = config.token ? "token auth enabled" : "token auth disabled";
  console.log(`zed-mob-gateway listening on http://${config.host}:${config.port} (${authNote})`);
});

async function handleApi(request, response) {
  if (!isAuthorized(request)) {
    sendJson(response, 401, { error: "unauthorized" });
    return;
  }

  const url = new URL(request.url, `http://${request.headers.host}`);

  if (request.method === "GET" && url.pathname === "/api/health") {
    sendJson(response, 200, {
      ok: true,
      service: "zed-mob-gateway",
      auth: Boolean(config.token),
      time: new Date().toISOString()
    });
    return;
  }

  if (request.method === "GET" && url.pathname === "/api/projects") {
    const projects = await loadProjects();
    sendJson(response, 200, { projects: projects.map(publicProject) });
    return;
  }

  if (request.method === "GET" && url.pathname === "/api/projects/recent") {
    const recent = await listZedRecentProjects({
      limit: url.searchParams.get("limit") || 50
    });
    sendJson(response, 200, {
      ...recent,
      projects: recent.projects.map(publicProjectWithSource)
    });
    return;
  }

  if (request.method === "POST" && url.pathname === "/api/projects/sync-zed") {
    const body = await readJson(request);
    const result = await syncZedRecentProjects({ limit: body.limit || 50 });
    sendJson(response, result.ok ? 200 : 404, {
      ...result,
      added: result.added.map(publicProject),
      projects: result.projects.map(publicProject)
    });
    return;
  }

  if (request.method === "POST" && url.pathname === "/api/projects") {
    const body = await readJson(request);
    const result = await createProject({ name: body.name });
    sendJson(response, 201, {
      project: publicProject(result.project),
      projects: result.projects.map(publicProject),
      added: result.added,
      projectsRoot: result.projectsRoot
    });
    return;
  }

  const historyMatch = url.pathname.match(/^\/api\/projects\/([^/]+)\/(?:history|chats)(?:\/([^/]+))?(?:\/([^/]+))?$/);
  if (historyMatch) {
    const project = await findProject(decodeURIComponent(historyMatch[1]));
    if (!project) {
      sendJson(response, 404, { error: "project_not_found" });
      return;
    }

    const threadId = historyMatch[2] ? decodeURIComponent(historyMatch[2]) : "";
    const action = historyMatch[3] ? decodeURIComponent(historyMatch[3]) : "";

    if (request.method === "GET" && !threadId) {
      const archivedParam = url.searchParams.get("archived");
      const history = await listProjectHistory({
        project,
        cursor: url.searchParams.get("cursor") || null,
        limit: url.searchParams.get("limit") || 50,
        searchTerm: url.searchParams.get("search") || "",
        archived: archivedParam === "true"
      });
      sendJson(response, 200, { project: publicProject(project), ...history });
      return;
    }

    if (request.method === "GET" && threadId && !action) {
      try {
        const history = await readProjectThread({ project, threadId, includeTurns: true });
        sendJson(response, 200, { project: publicProject(project), ...history });
      } catch (error) {
        if (error.message === "thread_not_in_project") {
          sendJson(response, 404, { error: "thread_not_found" });
          return;
        }
        throw error;
      }
      return;
    }

    if (request.method === "GET" && threadId && action === "turns") {
      try {
        const history = await listProjectThreadTurns({
          project,
          threadId,
          cursor: url.searchParams.get("cursor") || null,
          limit: url.searchParams.get("limit") || 6,
          sortDirection: url.searchParams.get("direction") || "desc"
        });
        sendJson(response, 200, { project: publicProject(project), ...history });
      } catch (error) {
        if (error.message === "thread_not_in_project") {
          sendJson(response, 404, { error: "thread_not_found" });
          return;
        }
        throw error;
      }
      return;
    }

    if (request.method === "POST" && threadId && action === "resume") {
      const body = await readJson(request);
      let history;
      try {
        history = await readProjectThread({ project, threadId, includeTurns: false });
      } catch (error) {
        if (error.message === "thread_not_in_project") {
          sendJson(response, 404, { error: "thread_not_found" });
          return;
        }
        throw error;
      }

      if (history.thread.status === "active") {
        sendJson(response, 409, { error: "thread_active", thread: history.thread });
        return;
      }

      const { preflight, bazaAction } = await ensureBazaReady(project, {
        autoBaza: Boolean(body.autoBaza)
      });
      if (!preflight.ok) {
        sendJson(response, 409, preflightFailurePayload(project, preflight, {
          thread: history.thread,
          bazaAction
        }));
        return;
      }

      let session = await getSessionByThread({ projectId: project.id, codexThreadId: threadId });
      if (!session) {
        session = await createSession({
          project,
          title: history.thread.title,
          codexThreadId: threadId,
          status: "created"
        });
      }

      let runtime;
      try {
        runtime = await ensureRuntimeForSession(session);
      } catch (error) {
        if (isMissingCodexThread(error)) {
          const staleSession = await markSessionStale(session.id, "codex_rollout_not_found");
          sendJson(response, 409, {
            error: "stale_binding",
            message: error.message,
            session: staleSession
          });
          return;
        }
        throw error;
      }
      const updated = await getSession(session.id);
      sendJson(response, 200, {
        session: updated,
        preflight,
        bazaAction,
        runtime: {
          threadId: runtime.threadId,
          initialized: runtime.initialized
        }
      });
      return;
    }
  }

  const projectMatch = url.pathname.match(/^\/api\/projects\/([^/]+)(?:\/([^/]+))?$/);
  if (projectMatch) {
    const project = await findProject(decodeURIComponent(projectMatch[1]));
    if (!project) {
      sendJson(response, 404, { error: "project_not_found" });
      return;
    }

    const action = projectMatch[2] || "";
    if (request.method === "GET" && action === "status") {
      sendJson(response, 200, {
        project: publicProject(project),
        baza: await inspectBaza(project)
      });
      return;
    }

    if (request.method === "POST" && action === "preflight") {
      const body = await readJson(request);
      const result = await runBazaPreflight(project, {
        syncDocs: Boolean(body.syncDocs)
      });
      sendJson(response, result.ok ? 200 : 409, { project: publicProject(project), preflight: result });
      return;
    }

    if (request.method === "POST" && action === "baza") {
      const result = await runBazaAction(project);
      sendJson(response, result.ok ? 200 : 409, {
        ...(result.ok ? {} : {
          error: "baza_failed",
          message: "BAZA action failed. Check diagnostics for command output."
        }),
        project: publicProject(project),
        baza: result
      });
      return;
    }

    if (request.method === "POST" && action === "codex-probe") {
      sendJson(response, 200, { project: publicProject(project), codex: await probeCodex(project) });
      return;
    }
  }

  if (request.method === "GET" && url.pathname === "/api/sessions") {
    sendJson(response, 200, { sessions: await listSessions(url.searchParams.get("projectId") || "") });
    return;
  }

  if (request.method === "POST" && url.pathname === "/api/sessions") {
    const body = await readJson(request);
    const project = await findProject(String(body.projectId || ""));
    if (!project) {
      sendJson(response, 404, { error: "project_not_found" });
      return;
    }
    const { preflight, bazaAction } = await ensureBazaReady(project, {
      autoBaza: Boolean(body.autoBaza)
    });
    if (!preflight.ok) {
      sendJson(response, 409, preflightFailurePayload(project, preflight, { bazaAction }));
      return;
    }

    const session = await createSession({ project, title: body.title });
    const runtime = await ensureRuntimeForSession(session);
    const readySession = await getSession(session.id);
    sendJson(response, 201, {
      session: readySession,
      preflight,
      bazaAction,
      runtime: {
        threadId: runtime.threadId,
        initialized: runtime.initialized
      }
    });
    return;
  }

  const requestMatch = url.pathname.match(/^\/api\/sessions\/([^/]+)\/requests\/([^/]+)$/);
  if (requestMatch) {
    const session = await getSession(decodeURIComponent(requestMatch[1]));
    if (!session) {
      sendJson(response, 404, { error: "session_not_found" });
      return;
    }
    if (request.method !== "POST") {
      sendJson(response, 405, { error: "method_not_allowed" });
      return;
    }
    try {
      const body = await readJson(request);
      const result = await resolveServerRequest({
        session,
        requestId: decodeURIComponent(requestMatch[2]),
        action: String(body.action || "decline")
      });
      sendJson(response, 202, { result });
    } catch (error) {
      if (error.message === "pending_request_not_found") {
        sendJson(response, 404, { error: "pending_request_not_found" });
        return;
      }
      if (error.message.startsWith("unsupported_server_request:")) {
        sendJson(response, 409, { error: "unsupported_server_request", message: error.message });
        return;
      }
      throw error;
    }
    return;
  }

  const sessionMatch = url.pathname.match(/^\/api\/sessions\/([^/]+)(?:\/([^/]+))?$/);
  if (sessionMatch) {
    const session = await getSession(decodeURIComponent(sessionMatch[1]));
    if (!session) {
      sendJson(response, 404, { error: "session_not_found" });
      return;
    }

    const action = sessionMatch[2] || "";
    if (request.method === "GET" && action === "events") {
      response.writeHead(200, {
        "content-type": "text/event-stream; charset=utf-8",
        "cache-control": "no-store",
        "x-accel-buffering": "no",
        connection: "keep-alive"
      });
      subscribe(session.id, response, {
        after: Number(url.searchParams.get("after") || request.headers["last-event-id"] || 0)
      });
      return;
    }

    if (request.method === "POST" && action === "turn") {
      const body = await readJson(request);
      const text = String(body.text || "").trim();
      const attachments = Array.isArray(body.attachments) ? body.attachments : [];
      if (!text && attachments.length === 0) {
        sendJson(response, 400, { error: "empty_turn" });
        return;
      }
      let result;
      try {
        result = await startTurn({ session, text, attachments });
      } catch (error) {
        if (error.message === "turn_already_active") {
          sendJson(response, 409, {
            error: "turn_already_active",
            message: "Codex is already answering in this chat and cannot accept an update right now."
          });
          return;
        }
        if (isTurnSteerError(error)) {
          sendJson(response, 409, {
            error: "turn_already_active",
            message: "Codex cannot accept an update for this active answer right now."
          });
          return;
        }
        if (isAttachmentError(error)) {
          sendJson(response, 400, attachmentErrorPayload(error));
          return;
        }
        throw error;
      }
      sendJson(response, 202, { result });
      return;
    }

    if (request.method === "POST" && action === "interrupt") {
      try {
        const result = await interruptTurn({ session });
        sendJson(response, 202, { result });
      } catch (error) {
        if (error.message === "no_active_turn") {
          sendJson(response, 409, { error: "no_active_turn" });
          return;
        }
        throw error;
      }
      return;
    }

    if (request.method === "POST" && action === "stop") {
      const stopped = await stopRuntime(session.id);
      const updated = await getSession(session.id);
      sendJson(response, 200, { stopped, session: updated });
      return;
    }

    if (request.method === "POST" && action === "approval-mode") {
      const body = await readJson(request);
      const mode = body.mode === "alwaysAllow" ? "alwaysAllow" : "ask";
      const updated = await setApprovalMode({ session, mode });
      sendJson(response, 200, {
        session: updated,
        approvalMode: updated.approvalMode || "ask"
      });
      return;
    }

    if (request.method === "POST" && action === "start") {
      const body = await readJson(request);
      const project = await findProject(session.projectId);
      if (!project) {
        sendJson(response, 404, { error: "project_not_found" });
        return;
      }
      const { preflight, bazaAction } = await ensureBazaReady(project, {
        autoBaza: Boolean(body.autoBaza)
      });
      if (!preflight.ok) {
        const failedSession = await updateSession(session.id, { status: "blocked" });
        sendJson(response, 409, preflightFailurePayload(project, preflight, {
          session: failedSession,
          bazaAction
        }));
        return;
      }
      let runtime;
      try {
        runtime = await ensureRuntimeForSession(session);
      } catch (error) {
        if (isMissingCodexThread(error)) {
          const staleSession = await markSessionStale(session.id, "codex_rollout_not_found");
          sendJson(response, 409, {
            error: "stale_binding",
            message: error.message,
            session: staleSession
          });
          return;
        }
        throw error;
      }
      const updated = await getSession(session.id);
      sendJson(response, 200, {
        session: updated,
        preflight,
        bazaAction,
        runtime: {
          threadId: runtime.threadId,
          initialized: runtime.initialized
        }
      });
      return;
    }
  }

  sendJson(response, 404, { error: "not_found" });
}

function isMissingCodexThread(error) {
  return String(error?.message || "").includes("no rollout found for thread id");
}

function validateSafeBinding(currentConfig) {
  const host = String(currentConfig.host || "").trim().toLowerCase();
  const loopbackHosts = new Set(["127.0.0.1", "localhost", "::1"]);
  const lanBind = host === "0.0.0.0" || host === "::" || !loopbackHosts.has(host);
  if (lanBind && !currentConfig.token) {
    throw new Error("ZED_MOB_TOKEN is required when binding outside localhost");
  }
}

function isAttachmentError(error) {
  return [
    "too_many_attachments",
    "unsupported_attachment_type",
    "attachment_too_large",
    "invalid_attachment_data"
  ].includes(error.message);
}

function isTurnSteerError(error) {
  const message = String(error?.message || "").toLowerCase();
  return message.includes("same-turn steering")
    || message.includes("cannot accept")
    || message.includes("expectedturnid");
}

function attachmentErrorPayload(error) {
  const messages = {
    too_many_attachments: "Attach up to 4 images per message.",
    unsupported_attachment_type: "Only JPEG, PNG, WebP, GIF, HEIC, and HEIF images are supported.",
    attachment_too_large: "Each image must be 8 MB or smaller.",
    invalid_attachment_data: "The uploaded image data could not be read."
  };
  return {
    error: error.message,
    message: messages[error.message] || "Invalid attachment."
  };
}

async function ensureBazaReady(project, options = {}) {
  const autoBaza = Boolean(options.autoBaza);
  let bazaAction = null;

  if (autoBaza) {
    const inspection = await inspectBaza(project);
    if (!inspection.ok) {
      bazaAction = await runBazaAction(project);
    }
  }

  let preflight = await runBazaPreflight(project, { syncDocs: false });
  if (!preflight.ok && autoBaza && !bazaAction) {
    bazaAction = await runBazaAction(project);
    preflight = await runBazaPreflight(project, { syncDocs: false });
  }

  return { preflight, bazaAction };
}

function preflightFailurePayload(project, preflight, extra = {}) {
  const missing = preflight.inspection?.missing || [];
  const suffix = missing.length ? ` Missing: ${missing.join(", ")}.` : "";
  return {
    error: "baza_required",
    message: `BAZA is required for ${project.name}. Tap BAZA to initialize or sync this project.${suffix}`,
    project: publicProject(project),
    preflight,
    ...extra
  };
}

function publicProjectWithSource(project) {
  return {
    ...publicProject(project),
    source: project.source || "",
    updatedAt: project.updatedAt || "",
    workspaceId: project.workspaceId || ""
  };
}

async function serveStatic(request, response) {
  const url = new URL(request.url, `http://${request.headers.host}`);
  const pathname = url.pathname === "/" ? "/index.html" : url.pathname;
  const absolutePath = path.resolve(PUBLIC_DIR, `.${pathname}`);

  if (!absolutePath.startsWith(PUBLIC_DIR)) {
    response.writeHead(403);
    response.end("Forbidden");
    return;
  }

  try {
    const content = await fs.readFile(absolutePath);
    response.writeHead(200, {
      "content-type": contentType(absolutePath),
      "cache-control": "no-store"
    });
    response.end(content);
  } catch (error) {
    if (error.code === "ENOENT") {
      const index = await fs.readFile(path.join(PUBLIC_DIR, "index.html"));
      response.writeHead(200, { "content-type": "text/html; charset=utf-8" });
      response.end(index);
      return;
    }
    throw error;
  }
}

function isAuthorized(request) {
  if (!config.token) {
    return true;
  }
  const url = new URL(request.url, `http://${request.headers.host}`);
  if (url.searchParams.get("token") === config.token) {
    return true;
  }
  const header = request.headers.authorization || "";
  return header === `Bearer ${config.token}`;
}

async function readJson(request) {
  const chunks = [];
  for await (const chunk of request) {
    chunks.push(chunk);
  }
  if (!chunks.length) {
    return {};
  }
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store"
  });
  response.end(JSON.stringify(payload, null, 2));
}

function logRequest(request) {
  const url = new URL(request.url, `http://${request.headers.host}`);
  const safeUrl = `${url.pathname}${url.searchParams.has("token") ? "?token=<redacted>" : url.search}`;
  console.log(`${new Date().toISOString()} ${request.method} ${safeUrl}`);
}

function contentType(filePath) {
  if (filePath.endsWith(".html")) return "text/html; charset=utf-8";
  if (filePath.endsWith(".css")) return "text/css; charset=utf-8";
  if (filePath.endsWith(".js")) return "text/javascript; charset=utf-8";
  if (filePath.endsWith(".json")) return "application/json; charset=utf-8";
  if (filePath.endsWith(".svg")) return "image/svg+xml";
  return "application/octet-stream";
}
