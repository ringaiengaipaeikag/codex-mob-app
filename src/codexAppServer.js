import { spawn } from "node:child_process";

export class CodexAppServerClient {
  constructor({ cwd, command = "codex", args = ["app-server", "--listen", "stdio://"] }) {
    this.cwd = cwd;
    this.command = command;
    this.args = args;
    this.child = null;
    this.nextId = 1;
    this.pending = new Map();
    this.buffer = "";
    this.events = [];
    this.startError = null;
    this.listeners = new Set();
  }

  start() {
    if (this.child) {
      return;
    }

    this.child = spawn(this.command, this.args, {
      cwd: this.cwd,
      stdio: ["pipe", "pipe", "pipe"]
    });

    this.child.on("error", (error) => {
      this.startError = error;
      for (const [, pending] of this.pending) {
        pending.reject(error);
      }
      this.pending.clear();
      this.child = null;
    });
    this.child.stdout.setEncoding("utf8");
    this.child.stdout.on("data", (chunk) => this.handleStdout(chunk));
    this.child.stderr.setEncoding("utf8");
    this.child.stderr.on("data", (chunk) => {
      this.emit({ type: "stderr", text: chunk, at: new Date().toISOString() });
    });
    this.child.on("exit", (code, signal) => {
      for (const [, pending] of this.pending) {
        pending.reject(new Error(`codex app-server exited with code ${code} signal ${signal || ""}`));
      }
      this.pending.clear();
      this.child = null;
    });
  }

  async request(method, params = {}) {
    this.start();
    if (this.startError) {
      throw this.startError;
    }
    const id = this.nextId++;
    const payload = {
      jsonrpc: "2.0",
      id,
      method,
      params
    };

    const response = new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
    });

    this.child.stdin.write(`${JSON.stringify(payload)}\n`);
    return response;
  }

  respond(id, result = {}) {
    this.start();
    if (this.startError) {
      throw this.startError;
    }
    this.child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, result })}\n`);
  }

  respondError(id, { code = -32000, message = "Request rejected" } = {}) {
    this.start();
    if (this.startError) {
      throw this.startError;
    }
    this.child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, error: { code, message } })}\n`);
  }

  onEvent(listener) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  async stop() {
    if (!this.child) {
      return;
    }
    this.child.kill("SIGTERM");
  }

  handleStdout(chunk) {
    this.buffer += chunk;
    let newlineIndex = this.buffer.indexOf("\n");
    while (newlineIndex >= 0) {
      const line = this.buffer.slice(0, newlineIndex).trim();
      this.buffer = this.buffer.slice(newlineIndex + 1);
      if (line) {
        this.handleLine(line);
      }
      newlineIndex = this.buffer.indexOf("\n");
    }
  }

  handleLine(line) {
    let message;
    try {
      message = JSON.parse(line);
    } catch {
      this.emit({ type: "raw", text: line, at: new Date().toISOString() });
      return;
    }

    if (message.id && this.pending.has(message.id)) {
      const pending = this.pending.get(message.id);
      this.pending.delete(message.id);
      if (message.error) {
        pending.reject(new Error(message.error.message || "Codex JSON-RPC error"));
      } else {
        pending.resolve(message.result);
      }
      return;
    }

    this.emit({ type: "event", message, at: new Date().toISOString() });
  }

  emit(event) {
    this.events.push(event);
    for (const listener of this.listeners) {
      listener(event);
    }
  }

  async initialize() {
    return this.request("initialize", {
      clientInfo: {
        name: "zed-mob-gateway",
        title: "Zed Mob Gateway",
        version: "0.1.0"
      },
      capabilities: {
        experimentalApi: true
      }
    });
  }

  async startThread({ cwd, title }) {
    return this.request("thread/start", {
      cwd,
      approvalPolicy: "on-request",
      approvalsReviewer: "user",
      sandbox: "workspace-write",
      persistExtendedHistory: true,
      developerInstructions: title ? `Mobile session: ${title}` : null
    });
  }

  async resumeThread({ threadId, cwd, excludeTurns = false }) {
    return this.request("thread/resume", {
      threadId,
      cwd,
      approvalPolicy: "on-request",
      approvalsReviewer: "user",
      sandbox: "workspace-write",
      persistExtendedHistory: true,
      excludeTurns
    });
  }

  async listThreads({
    cursor = null,
    limit = 50,
    searchTerm = null,
    cwd = null,
    archived = false,
    sortDirection = "desc",
    sortKey = "updated_at",
    sourceKinds = null,
    useStateDbOnly = false
  } = {}) {
    return this.request("thread/list", {
      cursor,
      limit,
      searchTerm,
      cwd,
      archived,
      sortDirection,
      sortKey,
      sourceKinds,
      useStateDbOnly
    });
  }

  async readThread({ threadId, includeTurns = true }) {
    return this.request("thread/read", {
      threadId,
      includeTurns
    });
  }

  async listThreadTurns({ threadId, cursor = null, limit = 50, sortDirection = "desc" }) {
    return this.request("thread/turns/list", {
      threadId,
      cursor,
      limit,
      sortDirection
    });
  }

  async startTurn({ threadId, input, text = "", cwd }) {
    return this.request("turn/start", {
      threadId,
      cwd,
      input: input || [
        {
          type: "text",
          text
        }
      ]
    });
  }

  async steerTurn({ threadId, turnId, input }) {
    return this.request("turn/steer", {
      threadId,
      expectedTurnId: turnId,
      input
    });
  }

  async interruptTurn({ threadId, turnId }) {
    return this.request("turn/interrupt", {
      threadId,
      turnId
    });
  }
}

export async function probeCodex(project) {
  const client = new CodexAppServerClient({ cwd: project.path });
  try {
    client.start();
    await wait(500);
    if (client.startError) {
      throw client.startError;
    }
    return {
      ok: true,
      transport: "stdio",
      events: client.events.slice(-10)
    };
  } catch (error) {
    return {
      ok: false,
      error: error.code === "ENOENT"
        ? "codex executable not found in PATH"
        : error.message
    };
  } finally {
    await client.stop();
  }
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
