const state = {
  projects: [],
  sessions: [],
  historyThreads: [],
  historyNextCursor: "",
  activeHistoryThreadId: "",
  historyLoading: false,
  historyError: "",
  recentProjects: [],
  projectSearch: "",
  selectedProject: null,
  bazaOk: false,
  bazaMissing: [],
  activeSessionId: localStorage.getItem("zedMobActiveSessionId") || "",
  token: new URLSearchParams(window.location.search).get("token") || localStorage.getItem("zedMobToken") || "",
  build: "20260523-1845",
  activeEvents: null,
  subscribedSessionId: "",
  streamConnected: false,
  lastEventSeq: 0,
  backgroundStreamPaused: false,
  eventRetryTimer: null,
  eventRetryDelay: 1000,
  reconnecting: false,
  foregroundTimer: null,
  currentAssistant: null,
  localUserEcho: null,
  threadMessages: [],
  historyLoadedThreadId: "",
  historyOlderCursor: "",
  historyTurnsLoading: false,
  resumingThreadId: "",
  resumingThreadPromise: null,
  historyExpanded: false,
  visibleHistoryLimit: 10,
  sending: false,
  turnActive: false,
  activeTurnStartedAt: 0,
  lastStreamEventAt: 0,
  lastAssistantOutputAt: 0,
  lastMonitorNoticeAt: 0,
  approvalMode: localStorage.getItem("zedMobApprovalMode") === "alwaysAllow" ? "alwaysAllow" : "ask",
  attachments: [],
  chatFocus: false,
  chatFocusSuppressed: false,
  chatFocusObserver: null
};

const nodes = {
  sessionPanel: document.querySelector(".session-panel"),
  connectionLine: document.querySelector("#connectionLine"),
  projectList: document.querySelector("#projectList"),
  projectPickerButton: document.querySelector("#projectPickerButton"),
  refreshProjects: document.querySelector("#refreshProjects"),
  jumpChatButton: document.querySelector("#jumpChatButton"),
  newSessionButton: document.querySelector("#newSessionButton"),
  preflightButton: document.querySelector("#preflightButton"),
  historyButton: document.querySelector("#historyButton"),
  chatButton: document.querySelector("#chatButton"),
  statusButton: document.querySelector("#statusButton"),
  probeButton: document.querySelector("#probeButton"),
  sessionList: document.querySelector("#sessionList"),
  historyList: document.querySelector("#historyList"),
  historySheet: document.querySelector("#historySheet"),
  historySheetBackdrop: document.querySelector("#historySheetBackdrop"),
  historySheetClose: document.querySelector("#historySheetClose"),
  historyNewSessionButton: document.querySelector("#historyNewSessionButton"),
  historySheetList: document.querySelector("#historySheetList"),
  historySheetMeta: document.querySelector("#historySheetMeta"),
  refreshHistoryButton: document.querySelector("#refreshHistoryButton"),
  historyLoadMoreButton: document.querySelector("#historyLoadMoreButton"),
  currentChatTitle: document.querySelector("#currentChatTitle"),
  currentChatMeta: document.querySelector("#currentChatMeta"),
  projectSheet: document.querySelector("#projectSheet"),
  projectSheetBackdrop: document.querySelector("#projectSheetBackdrop"),
  projectSheetClose: document.querySelector("#projectSheetClose"),
  projectSheetList: document.querySelector("#projectSheetList"),
  projectSheetMeta: document.querySelector("#projectSheetMeta"),
  projectSearch: document.querySelector("#projectSearch"),
  syncZedProjectsButton: document.querySelector("#syncZedProjectsButton"),
  newProjectForm: document.querySelector("#newProjectForm"),
  newProjectName: document.querySelector("#newProjectName"),
  projectTitle: document.querySelector("#projectTitle"),
  sessionTitle: document.querySelector("#sessionTitle"),
  chatScreen: document.querySelector(".chat-screen"),
  backButton: document.querySelector("#backButton"),
  exitChatFocusButton: document.querySelector("#exitChatFocusButton"),
  stopButton: document.querySelector("#stopButton"),
  bazaStatus: document.querySelector("#bazaStatus"),
  sessionStatus: document.querySelector("#sessionStatus"),
  approvalModeButton: document.querySelector("#approvalModeButton"),
  chatMessages: document.querySelector("#chatMessages"),
  attachmentTray: document.querySelector("#attachmentTray"),
  attachButton: document.querySelector("#attachButton"),
  imageInput: document.querySelector("#imageInput"),
  messageInput: document.querySelector("#messageInput"),
  sendButton: document.querySelector("#sendButton"),
  interruptButton: document.querySelector("#interruptButton"),
  output: document.querySelector("#output")
};

const SUPPORTED_IMAGE_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
  "image/heic",
  "image/heif",
  "image/heic-sequence",
  "image/heif-sequence"
]);
const SUPPORTED_IMAGE_EXTENSIONS = new Set(["jpg", "jpeg", "png", "webp", "gif", "heic", "heif"]);

nodes.refreshProjects.addEventListener("click", () => runAction(refreshAppState));
nodes.jumpChatButton.addEventListener("click", () => jumpToComposer({ focus: false }));
nodes.projectPickerButton.addEventListener("click", () => runAction(openProjectSheet));
nodes.projectTitle.addEventListener("click", () => runAction(openProjectSheet));
nodes.newSessionButton.addEventListener("click", () => runAction(createSession));
nodes.preflightButton.addEventListener("click", () => runAction(runBazaAction));
nodes.bazaStatus.addEventListener("click", () => runAction(runBazaAction));
nodes.approvalModeButton.addEventListener("click", () => runAction(toggleApprovalMode));
nodes.historyButton.addEventListener("click", () => runAction(openHistorySheet));
nodes.chatButton.addEventListener("click", () => jumpToComposer({ focus: false }));
nodes.statusButton.addEventListener("click", () => runAction(loadStatus));
nodes.probeButton.addEventListener("click", () => runAction(probeCodex));
nodes.refreshHistoryButton.addEventListener("click", () => runAction(() => loadHistory({ reset: true })));
nodes.historyLoadMoreButton.addEventListener("click", () => runAction(() => loadHistory({ cursor: state.historyNextCursor })));
nodes.historySheetBackdrop.addEventListener("click", closeHistorySheet);
nodes.historySheetClose?.addEventListener("click", closeHistorySheet);
nodes.historyNewSessionButton.addEventListener("click", () => runAction(createSessionFromHistoryDrawer));
nodes.projectSheetBackdrop.addEventListener("click", closeProjectSheet);
nodes.projectSheetClose.addEventListener("click", closeProjectSheet);
nodes.syncZedProjectsButton.addEventListener("click", () => runAction(syncZedProjects));
nodes.projectSearch.addEventListener("input", () => {
  state.projectSearch = nodes.projectSearch.value;
  renderProjectSheet();
});
nodes.newProjectForm.addEventListener("submit", (event) => {
  event.preventDefault();
  runAction(createProjectFromSheet);
});
nodes.sendButton.addEventListener("click", () => runAction(sendTurn));
nodes.interruptButton.addEventListener("click", () => runAction(interruptTurn));
nodes.stopButton.addEventListener("click", () => runAction(stopSession));
nodes.backButton.addEventListener("click", () => exitChatFocus({ scrollToPanel: false }));
nodes.exitChatFocusButton.addEventListener("click", () => runAction(openHistorySheet));
nodes.attachButton.addEventListener("click", () => nodes.imageInput.click());
nodes.imageInput.addEventListener("change", () => runAction(addSelectedImages));
nodes.messageInput.addEventListener("input", autoResizeComposer);
nodes.messageInput.addEventListener("keydown", (event) => {
  if (event.key === "Enter" && !event.shiftKey) {
    event.preventDefault();
    runAction(sendTurn);
  }
});
nodes.messageInput.addEventListener("paste", pastePlainText);
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "hidden") {
    pauseSessionStreamForBackground();
    return;
  }
  scheduleForegroundReconnect({ force: state.backgroundStreamPaused });
});
window.addEventListener("pagehide", pauseSessionStreamForBackground);
window.addEventListener("pageshow", scheduleForegroundReconnect);
window.addEventListener("focus", scheduleForegroundReconnect);
window.addEventListener("online", scheduleForegroundReconnect);
window.addEventListener("resize", syncViewportHeight);
window.visualViewport?.addEventListener("resize", syncViewportHeight);
window.visualViewport?.addEventListener("scroll", syncViewportHeight);

if (state.token) {
  localStorage.setItem("zedMobToken", state.token);
}

writeOutput(`build ${state.build}`);
syncViewportHeight();
setupChatFocusObserver();
updateInterruptControl();
renderApprovalMode();
autoResizeComposer();
runAction(loadProjects);
window.setInterval(() => {
  if (!state.selectedProject || state.historyLoading || document.visibilityState === "hidden") {
    return;
  }
  runAction(loadProjectInbox);
}, 10000);
window.setInterval(updateTurnMonitor, 1000);

async function refreshAppState() {
  nodes.refreshProjects.disabled = true;
  nodes.refreshProjects.classList.add("refreshing");
  nodes.refreshProjects.textContent = "…";
  nodes.connectionLine.textContent = `refreshing · build ${state.build}`;
  try {
    await loadProjects();
    if (state.selectedProject) {
      const results = await Promise.allSettled([
        loadStatus(),
        loadProjectInbox()
      ]);
      const failure = results.find((result) => result.status === "rejected");
      if (failure) {
        throw failure.reason;
      }
      if (state.activeSessionId && (!state.activeEvents || !state.streamConnected)) {
        await reconnectSessionStream({ foreground: true });
      }
    }
    if (!nodes.projectSheet.hidden) {
      await loadRecentProjects();
    }
    nodes.connectionLine.textContent = `refreshed · build ${state.build}`;
    window.setTimeout(() => {
      if (nodes.connectionLine.textContent.startsWith("refreshed")) {
        nodes.connectionLine.textContent = `online · build ${state.build}`;
      }
    }, 1400);
  } finally {
    nodes.refreshProjects.disabled = false;
    nodes.refreshProjects.classList.remove("refreshing");
    nodes.refreshProjects.textContent = "↻";
  }
}

async function loadProjects() {
  nodes.connectionLine.textContent = `online · build ${state.build}`;
  const data = await api("/api/projects");
  state.projects = data.projects;
  if (state.selectedProject) {
    const selected = state.projects.find((project) => (
      project.id === state.selectedProject.id ||
      project.path === state.selectedProject.path
    ));
    if (selected) {
      state.selectedProject = selected;
      nodes.projectTitle.textContent = selected.name;
    }
  }
  renderProjects();
  renderProjectSheet();

  if (!state.selectedProject && state.projects[0]) {
    selectProject(state.projects[0]);
  }
}

function renderProjects() {
  nodes.projectList.innerHTML = "";
  const project = state.selectedProject || state.projects[0] || null;
  nodes.projectPickerButton.innerHTML = [
    `<strong>${escapeHtml(project?.name || "No project")}</strong>`,
    `<span class="project-path">${escapeHtml(project?.path || "Select project")}</span>`
  ].join("");
}

function selectProject(project) {
  if (state.activeEvents) {
    state.activeEvents.close();
    state.activeEvents = null;
    state.subscribedSessionId = "";
  }
  clearEventRetry();
  state.streamConnected = false;
  state.selectedProject = project;
  state.sessions = [];
  state.historyThreads = [];
  state.historyNextCursor = "";
  state.activeHistoryThreadId = "";
  state.historyError = "";
  state.activeSessionId = localStorage.getItem("zedMobActiveSessionId") || "";
  state.threadMessages = [];
  state.historyLoadedThreadId = "";
  state.historyOlderCursor = "";
  state.historyTurnsLoading = false;
  state.resumingThreadId = "";
  state.resumingThreadPromise = null;
  state.lastEventSeq = 0;
  clearAttachments();
  setTurnActive(false);
  state.bazaOk = false;
  state.bazaMissing = [];
  nodes.projectTitle.textContent = project.name;
  updateActiveSessionHeader();
  resetChat("Select or create a session.");
  renderProjects();
  renderHistory();
  renderProjectSheet();
  closeProjectSheet();
  runAction(loadStatus);
  runAction(() => loadProjectInbox({ restoreActive: Boolean(state.activeSessionId) }));
}

async function openProjectSheet() {
  nodes.projectSheet.hidden = false;
  nodes.projectSearch.value = state.projectSearch;
  renderProjectSheet();
  if (!state.recentProjects.length) {
    await loadRecentProjects();
  }
}

function closeProjectSheet() {
  nodes.projectSheet.hidden = true;
}

async function loadRecentProjects() {
  const data = await api("/api/projects/recent?limit=80");
  state.recentProjects = data.projects || [];
  renderProjectSheet();
}

function renderProjectSheet() {
  nodes.projectSheetList.innerHTML = "";
  const query = state.projectSearch.trim().toLowerCase();
  const configured = state.projects.map((project) => ({ ...project, source: "mobile" }));
  const configuredPaths = new Set(configured.map((project) => project.path));
  const combined = configured.concat(
    state.recentProjects.filter((project) => !configuredPaths.has(project.path))
  );
  const filtered = combined.filter((project) => {
    if (!query) return true;
    return `${project.name} ${project.path}`.toLowerCase().includes(query);
  });

  nodes.projectSheetMeta.textContent = `${filtered.length} project(s)`;
  for (const project of filtered) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `project-card ${state.selectedProject?.path === project.path ? "active" : ""}`;
    const source = project.source === "zed" ? "zed recent" : "mobile";
    button.innerHTML = [
      `<strong>${escapeHtml(project.name)}</strong>`,
      `<span class="project-path">${escapeHtml(source)} · ${escapeHtml(project.path)}</span>`
    ].join("");
    button.addEventListener("click", () => runAction(() => selectOrImportProject(project)));
    nodes.projectSheetList.append(button);
  }

  if (!filtered.length) {
    const empty = document.createElement("div");
    empty.className = "session-card history-state";
    empty.textContent = "No projects found.";
    nodes.projectSheetList.append(empty);
  }
}

async function selectOrImportProject(project) {
  const existing = state.projects.find((item) => item.path === project.path || item.id === project.id);
  if (existing) {
    selectProject(existing);
    return;
  }
  const result = await api("/api/projects/sync-zed", {
    method: "POST",
    body: { limit: 100 }
  });
  state.projects = result.projects;
  const imported = state.projects.find((item) => item.path === project.path);
  if (imported) {
    selectProject(imported);
    return;
  }
  renderProjectSheet();
  throw new Error("project_outside_trusted_root");
}

async function syncZedProjects() {
  nodes.syncZedProjectsButton.disabled = true;
  nodes.syncZedProjectsButton.textContent = "Syncing...";
  try {
    const data = await api("/api/projects/sync-zed", {
      method: "POST",
      body: { limit: 100 }
    });
    state.projects = data.projects;
    await loadRecentProjects();
    renderProjects();
    renderProjectSheet();
    writeOutput(JSON.stringify(data, null, 2));
  } finally {
    nodes.syncZedProjectsButton.disabled = false;
    nodes.syncZedProjectsButton.textContent = "Sync Zed Projects";
  }
}

async function createProjectFromSheet() {
  const name = nodes.newProjectName.value.trim();
  if (!name) {
    throw new Error("Project name is required");
  }
  const data = await api("/api/projects", {
    method: "POST",
    body: { name }
  });
  state.projects = data.projects;
  nodes.newProjectName.value = "";
  selectProject(data.project);
  writeOutput(JSON.stringify(data, null, 2));
  await runBazaAction({
    message: "Project created. BAZA is preparing it now."
  });
}

async function loadProjectInbox(options = {}) {
  await loadSessions();
  await loadHistory({ reset: true });
  if (options.restoreActive && state.activeSessionId && !state.activeEvents) {
    await activateSession(state.activeSessionId, { focus: false });
  }
}

async function loadStatus() {
  if (!state.selectedProject) return;
  const data = await api(`/api/projects/${encodeURIComponent(state.selectedProject.id)}/status`);
  state.bazaOk = Boolean(data.baza.ok);
  state.bazaMissing = data.baza.missing || [];
  nodes.bazaStatus.textContent = data.baza.ok ? "BAZA OK" : "BAZA missing files";
  writeOutput(JSON.stringify(data, null, 2));
}

async function runPreflight(syncDocs) {
  if (!state.selectedProject) return;
  nodes.bazaStatus.textContent = syncDocs ? "BAZA sync..." : "BAZA checking...";
  const data = await api(`/api/projects/${encodeURIComponent(state.selectedProject.id)}/preflight`, {
    method: "POST",
    body: { syncDocs }
  });
  nodes.bazaStatus.textContent = data.preflight.ok ? "BAZA preflight OK" : "BAZA preflight failed";
  writeOutput(JSON.stringify(data, null, 2));
}

async function runBazaAction(options = {}) {
  if (!state.selectedProject) return;
  nodes.preflightButton.disabled = true;
  nodes.preflightButton.textContent = "BAZA running...";
  nodes.bazaStatus.textContent = "BAZA running...";
  removeNoticeMessages("baza-required");
  addSystemMessage(options.message || "BAZA is preparing this project...", {
    pending: true,
    noticeKey: "baza-running"
  });
  try {
    const data = await api(`/api/projects/${encodeURIComponent(state.selectedProject.id)}/baza`, {
      method: "POST"
    });
    removePendingMessages();
    state.bazaOk = Boolean(data.baza.ok);
    state.bazaMissing = data.baza.after?.missing || data.baza.before?.missing || [];
    nodes.bazaStatus.textContent = data.baza.ok ? "BAZA synced" : "BAZA failed";
    addSystemMessage(data.baza.ok ? "BAZA ready." : "BAZA finished with blocking checks.", {
      noticeKey: "baza-result"
    });
    await loadStatus();
    await loadProjectInbox();
    writeOutput(JSON.stringify(data, null, 2));
  } finally {
    nodes.preflightButton.disabled = false;
    nodes.preflightButton.textContent = "BAZA";
  }
}

async function probeCodex() {
  if (!state.selectedProject) return;
  const data = await api(`/api/projects/${encodeURIComponent(state.selectedProject.id)}/codex-probe`, {
    method: "POST"
  });
  writeOutput(JSON.stringify(data, null, 2));
}

async function loadSessions() {
  if (!state.selectedProject) return;
  const data = await api(`/api/sessions?projectId=${encodeURIComponent(state.selectedProject.id)}`);
  state.sessions = data.sessions;

  const activeSession = state.sessions.find((session) => session.id === state.activeSessionId);
  if (!activeSession || activeSession.status === "stale") {
    state.activeSessionId = "";
    localStorage.removeItem("zedMobActiveSessionId");
  }
  if (state.activeSessionId) {
    localStorage.setItem("zedMobActiveSessionId", state.activeSessionId);
  }
  if (activeSession) {
    const serverMode = activeSession.approvalMode || "ask";
    if (serverMode === "alwaysAllow" && state.approvalMode !== "alwaysAllow") {
      state.approvalMode = "alwaysAllow";
      localStorage.setItem("zedMobApprovalMode", state.approvalMode);
    }
    const active = Boolean(activeSession.activeTurnId) || ["running", "interrupting"].includes(activeSession.status);
    if (active && !state.turnActive) {
      const updatedAt = Date.parse(activeSession.updatedAt || "");
      setTurnActive(true, {
        startedAt: Number.isNaN(updatedAt) ? Date.now() : updatedAt
      });
    }
    if (!active && state.turnActive) {
      setTurnActive(false);
    }
  }

  renderSessions();
  renderHistory();
  renderApprovalMode();
  updateActiveSessionHeader();
}

async function toggleApprovalMode() {
  state.approvalMode = state.approvalMode === "alwaysAllow" ? "ask" : "alwaysAllow";
  localStorage.setItem("zedMobApprovalMode", state.approvalMode);
  renderApprovalMode();
  await syncApprovalMode();
  if (state.approvalMode === "alwaysAllow") {
    markAutoAllowedPendingApprovalCards();
  }
  addSystemMessage(state.approvalMode === "alwaysAllow"
    ? "Always allow is enabled for supported Codex permission requests in this mobile session."
    : "Always allow is disabled. Permission requests will wait for Allow or Deny.", {
    noticeKey: "approval-mode"
  });
}

async function syncApprovalMode() {
  renderApprovalMode();
  if (!state.activeSessionId) return null;
  let data;
  try {
    data = await api(`/api/sessions/${encodeURIComponent(state.activeSessionId)}/approval-mode`, {
      method: "POST",
      body: { mode: state.approvalMode }
    });
  } catch (error) {
    if (["not_found", "session_not_found"].includes(error.data?.error)) {
      addSystemMessage("Gateway backend needs a restart before Always allow can sync to the server runtime.", {
        noticeKey: "approval-mode"
      });
      writeOutput(JSON.stringify(error.data || { message: error.message }, null, 2));
      return null;
    }
    throw error;
  }
  if (data.approvalMode) {
    state.approvalMode = data.approvalMode;
    localStorage.setItem("zedMobApprovalMode", state.approvalMode);
    renderApprovalMode();
  }
  return data;
}

function renderApprovalMode() {
  const alwaysAllow = state.approvalMode === "alwaysAllow";
  nodes.approvalModeButton.textContent = alwaysAllow ? "Always allow" : "Allow: ask";
  nodes.approvalModeButton.classList.toggle("active", alwaysAllow);
  nodes.approvalModeButton.setAttribute("aria-pressed", alwaysAllow ? "true" : "false");
}

async function loadHistory({ reset = false, cursor = "" } = {}) {
  if (!state.selectedProject) return;
  state.historyLoading = true;
  state.historyError = "";
  renderHistory();
  const params = new URLSearchParams({ limit: "60" });
  if (cursor) {
    params.set("cursor", cursor);
  }
  try {
    const data = await api(`/api/projects/${encodeURIComponent(state.selectedProject.id)}/chats?${params.toString()}`);
    state.historyThreads = reset || !cursor
      ? data.threads
      : state.historyThreads.concat(data.threads);
    state.historyNextCursor = data.nextCursor || "";
  } catch (error) {
    state.historyError = error.message;
    throw error;
  } finally {
    state.historyLoading = false;
    renderHistory();
  }
}

async function openHistorySheet() {
  nodes.historySheet.hidden = false;
  await loadHistory({ reset: true });
}

function closeHistorySheet() {
  nodes.historySheet.hidden = true;
}

async function createSessionFromHistoryDrawer() {
  closeHistorySheet();
  await createSession();
}

function renderSessions() {
  nodes.sessionList.innerHTML = "";
}

function renderHistory() {
  nodes.historyList.innerHTML = "";
  nodes.historySheetList.innerHTML = "";
  const activeSession = state.sessions.find((session) => session.id === state.activeSessionId);
  const activeThreadId = activeSession?.codexThreadId || state.activeHistoryThreadId;
  const entries = unifiedChatEntries();
  updateCurrentChatCard(activeSession, entries, activeThreadId);
  nodes.historySheetMeta.textContent = state.selectedProject ? `${state.selectedProject.name} · ${entries.length} chat(s)` : "Project chats";

  if (state.historyLoading && !entries.length) {
    nodes.historySheetList.append(historyStateCard("Loading chats..."));
  }

  if (state.historyError) {
    nodes.historySheetList.append(historyStateCard(`Codex history unavailable: ${state.historyError}`));
  }

  if (!state.historyLoading && !state.historyError && !entries.length) {
    nodes.historySheetList.append(historyStateCard("No chats for this project."));
  }

  renderHistoryDrawerEntries(entries, activeThreadId);

  nodes.historyLoadMoreButton.hidden = !state.historyNextCursor;
}

function renderHistoryDrawerEntries(entries, activeThreadId) {
  let lastGroup = "";
  for (const entry of entries) {
    const group = historyDateGroup(entry.updatedAt);
    if (group !== lastGroup) {
      const heading = document.createElement("div");
      heading.className = "history-date-heading";
      heading.textContent = group;
      nodes.historySheetList.append(heading);
      lastGroup = group;
    }

    const button = document.createElement("button");
    button.type = "button";
    button.className = `drawer-chat-row ${entry.threadId === activeThreadId || entry.sessionId === state.activeSessionId ? "active" : ""}`;
    button.innerHTML = `<span>${escapeHtml(entry.title)}</span>`;
    button.addEventListener("click", () => runAction(() => openChatEntry(entry)));
    nodes.historySheetList.append(button);
  }
}

function historyDateGroup(updatedAt) {
  const date = updatedAt ? new Date(updatedAt) : null;
  if (!date || Number.isNaN(date.getTime())) {
    return "Older";
  }

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const target = new Date(date);
  target.setHours(0, 0, 0, 0);
  const diffDays = Math.floor((today.getTime() - target.getTime()) / 86400000);

  if (diffDays <= 0) return "Today";
  if (diffDays === 1) return "Yesterday";
  if (diffDays < 30) return "30 days";

  return date.toLocaleDateString([], { month: "short", year: "numeric" });
}

function updateCurrentChatCard(activeSession, entries, activeThreadId) {
  const activeEntry = entries.find((entry) => entry.threadId === activeThreadId || entry.sessionId === state.activeSessionId);
  const title = activeSession?.title || activeEntry?.title || "No active session";
  const meta = activeSession
    ? [activeSession.status, activeSession.codexThreadId ? "linked" : "", "ready"].filter(Boolean).join(" · ")
    : activeEntry?.meta || "Open history or start a new session";
  nodes.currentChatTitle.textContent = title;
  nodes.currentChatMeta.textContent = meta;
}

function unifiedChatEntries() {
  const sessionsByThread = new Map();
  const historyThreadIds = new Set();
  const entries = [];

  for (const session of state.sessions) {
    if (session.codexThreadId && session.status !== "stale" && !sessionsByThread.has(session.codexThreadId)) {
      sessionsByThread.set(session.codexThreadId, session);
    }
  }

  for (const thread of state.historyThreads) {
    historyThreadIds.add(thread.id);
    const session = sessionsByThread.get(thread.id) || null;
    const status = session?.status || thread.status;
    const source = thread.source || "codex";
    entries.push({
      kind: "thread",
      threadId: thread.id,
      sessionId: session?.id || thread.linkedSessionId || "",
      title: thread.title,
      updatedAt: thread.updatedAt,
      meta: [status, source, thread.gitBranch || "", formatRelativeTime(thread.updatedAt)].filter(Boolean).join(" · ")
    });
  }

  return entries.sort((left, right) => new Date(right.updatedAt || 0) - new Date(left.updatedAt || 0));
}

async function openChatEntry(entry) {
  closeHistorySheet();
  if (entry.sessionId) {
    await activateSession(entry.sessionId);
    return;
  }
  if (entry.threadId) {
    await resumeHistoryThread(entry.threadId);
  }
}

function historyStateCard(text) {
  const card = document.createElement("div");
  card.className = "session-card history-state";
  card.textContent = text;
  return card;
}

async function activateSession(sessionId, options = {}) {
  const session = state.sessions.find((item) => item.id === sessionId);
  const threadId = session?.codexThreadId || "";
  const previousSessionId = state.activeSessionId;
  state.activeSessionId = sessionId;
  state.activeHistoryThreadId = "";
  if (previousSessionId !== sessionId) {
    state.lastEventSeq = 0;
  }
  localStorage.setItem("zedMobActiveSessionId", sessionId);
  state.historyExpanded = false;
  state.threadMessages = [];
  state.historyLoadedThreadId = "";
  state.historyOlderCursor = "";
  renderSessions();
  renderHistory();
  updateActiveSessionHeader();
  resetChat("Preparing session...", {
    pending: true,
    noticeKey: "session-pending"
  });
  jumpToComposer({ focus: Boolean(options.focus) });
  const recentTurns = threadId
    ? loadRecentThreadMessages(threadId, {
      fallbackText: "History is empty."
    }).catch((error) => {
      addSystemMessage(`Recent history unavailable: ${error.message}`, {
        noticeKey: "history-tail-error"
      });
      writeOutput(JSON.stringify(error.data || { message: error.message }, null, 2));
    })
    : Promise.resolve();
  const data = await api(`/api/sessions/${encodeURIComponent(sessionId)}/start`, {
    method: "POST",
    body: { autoBaza: true }
  });
  await syncApprovalMode();
  removeNoticeMessages("session-pending");
  writeOutput(JSON.stringify(data, null, 2));
  await loadStatus();
  subscribeToSession(sessionId, { force: true });
  await recentTurns;
  jumpToComposer({ focus: Boolean(options.focus) });
}

async function createSession(options = {}) {
  if (!state.selectedProject) return;
  const focus = options.focus !== false;
  const shouldReset = options.reset !== false;
  if (shouldReset) {
    resetChat("Preparing project and creating session...", {
      pending: true,
      noticeKey: "session-pending"
    });
  }
  const data = await api("/api/sessions", {
    method: "POST",
    body: {
      projectId: state.selectedProject.id,
      title: `session-${new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`,
      autoBaza: true
    }
  });
  removePendingMessages();
  state.activeSessionId = data.session.id;
  state.lastEventSeq = 0;
  state.historyExpanded = false;
  state.threadMessages = [];
  localStorage.setItem("zedMobActiveSessionId", state.activeSessionId);
  await syncApprovalMode();
  await loadStatus();
  await loadSessions();
  await loadHistory({ reset: true });
  subscribeToSession(state.activeSessionId);
  jumpToComposer({ focus });
  return data.session;
}

async function previewHistoryThread(threadId) {
  if (!state.selectedProject) return;
  if (state.activeEvents) {
    state.activeEvents.close();
    state.activeEvents = null;
    state.subscribedSessionId = "";
  }
  clearEventRetry();
  state.streamConnected = false;
  state.lastEventSeq = 0;

  state.activeSessionId = "";
  state.activeHistoryThreadId = threadId;
  state.historyExpanded = false;
  state.threadMessages = [];
  state.historyLoadedThreadId = "";
  state.historyOlderCursor = "";
  renderSessions();
  renderHistory();
  resetChat("Loading history...", {
    pending: true,
    noticeKey: "history-pending"
  });
  jumpToComposer({ focus: false });

  const data = await api(`/api/projects/${encodeURIComponent(state.selectedProject.id)}/chats/${encodeURIComponent(threadId)}`);
  removePendingMessages();
  renderThreadHistory(data.thread, { fallbackText: "History is empty." });
  addHistoryResumeMessage(data.thread);
  nodes.sessionTitle.textContent = data.thread.title;
  nodes.sessionStatus.textContent = data.thread.linkedSessionId ? "linked history" : "history preview";
  writeOutput(JSON.stringify(data, null, 2));
  jumpToComposer({ focus: false });
}

async function resumeHistoryThread(threadId) {
  if (!state.selectedProject) return;
  if (state.activeEvents) {
    state.activeEvents.close();
    state.activeEvents = null;
    state.subscribedSessionId = "";
  }
  clearEventRetry();
  state.streamConnected = false;
  state.lastEventSeq = 0;
  state.activeSessionId = "";
  state.activeHistoryThreadId = threadId;
  state.historyExpanded = false;
  state.threadMessages = [];
  state.historyLoadedThreadId = "";
  state.historyOlderCursor = "";
  setTurnActive(false);
  resetChat("Loading recent messages...", {
    pending: true,
    noticeKey: "history-pending"
  });
  nodes.sessionTitle.textContent = "Loading chat";
  nodes.sessionStatus.textContent = "loading history";
  renderHistory();
  jumpToComposer({ focus: false });
  const recentTurns = loadRecentThreadMessages(threadId, {
    fallbackText: "History is empty."
  }).catch((error) => {
    addSystemMessage(`Recent history unavailable: ${error.message}`, {
      noticeKey: "history-tail-error"
    });
    writeOutput(JSON.stringify(error.data || { message: error.message }, null, 2));
  });
  const resumePromise = api(`/api/projects/${encodeURIComponent(state.selectedProject.id)}/chats/${encodeURIComponent(threadId)}/resume`, {
    method: "POST",
    body: { autoBaza: true }
  });
  state.resumingThreadId = threadId;
  state.resumingThreadPromise = resumePromise;
  try {
    const data = await resumePromise;
    removeNoticeMessages("session-pending");
    state.activeSessionId = data.session.id;
    state.lastEventSeq = 0;
    state.activeHistoryThreadId = "";
    state.historyExpanded = false;
    localStorage.setItem("zedMobActiveSessionId", state.activeSessionId);
    await syncApprovalMode();
    await loadStatus();
    await loadSessions();
    await loadHistory({ reset: true });
    subscribeToSession(state.activeSessionId);
    updateActiveSessionHeader();
    writeOutput(JSON.stringify(data, null, 2));
    await recentTurns;
  } finally {
    if (state.resumingThreadPromise === resumePromise) {
      state.resumingThreadId = "";
      state.resumingThreadPromise = null;
    }
  }
  jumpToComposer({ focus: false });
}

async function sendTurn() {
  if (state.sending) return;
  const text = composerText().trim();
  const attachments = state.attachments.map(({ name, type, size, dataUrl }) => ({
    name,
    type,
    size,
    dataUrl
  }));
  if (!text && !attachments.length) return;
  if (!state.activeSessionId && state.resumingThreadPromise) {
    addSystemMessage("Finishing chat load before sending...", {
      pending: true,
      noticeKey: "session-pending"
    });
    await state.resumingThreadPromise.catch(() => {});
    removeNoticeMessages("session-pending");
  }
  if (!state.activeSessionId && state.activeHistoryThreadId) {
    addSystemMessage("Wait for this chat to finish loading, then send again.", {
      noticeKey: "session-pending"
    });
    return;
  }

  const wasTurnActive = state.turnActive;
  state.sending = true;
  nodes.sendButton.disabled = true;
  nodes.attachButton.disabled = true;
  nodes.sendButton.textContent = "…";

  try {
    if (!state.activeSessionId) {
      await createSession({ focus: false });
    }
    setComposerText("");
    autoResizeComposer();
    const echoAttachments = state.attachments.map(({ id, name, type, size, previewUrl }) => ({
      id,
      name,
      type,
      size,
      previewUrl
    }));
    clearAttachments({ revoke: false });
    state.localUserEcho = {
      text,
      attachmentCount: echoAttachments.length
    };
    addChatMessage("user", text, "", { attachments: echoAttachments });
    addSystemMessage(wasTurnActive ? "Sending update..." : "Sending...", {
      pending: true,
      noticeKey: "sending"
    });
    ensureSessionStream(state.activeSessionId);
    const data = await api(`/api/sessions/${encodeURIComponent(state.activeSessionId)}/turn`, {
      method: "POST",
      body: { text, attachments }
    });
    setTurnActive(true);
    writeOutput(JSON.stringify(data, null, 2));
  } finally {
    state.sending = false;
    nodes.sendButton.disabled = false;
    nodes.attachButton.disabled = false;
    nodes.sendButton.textContent = "←";
  }
}

async function interruptTurn() {
  if (!state.activeSessionId || !state.turnActive) return;
  const data = await api(`/api/sessions/${encodeURIComponent(state.activeSessionId)}/interrupt`, {
    method: "POST"
  });
  setTurnActive(false);
  writeOutput(JSON.stringify(data, null, 2));
}

async function stopSession() {
  if (!state.activeSessionId) return;
  const data = await api(`/api/sessions/${encodeURIComponent(state.activeSessionId)}/stop`, {
    method: "POST"
  });
  if (state.activeEvents) {
    state.activeEvents.close();
    state.activeEvents = null;
    state.subscribedSessionId = "";
  }
  clearEventRetry();
  state.streamConnected = false;
  addSystemMessage("Runtime stopped.");
  await loadSessions();
  writeOutput(JSON.stringify(data, null, 2));
}

function subscribeToSession(sessionId, options = {}) {
  if (state.activeEvents && state.subscribedSessionId === sessionId && !options.force) {
    return;
  }
  clearEventRetry();
  if (state.activeEvents) {
    state.activeEvents.close();
  }
  const url = new URL(`/api/sessions/${encodeURIComponent(sessionId)}/events`, window.location.href);
  if (state.token) {
    url.searchParams.set("token", state.token);
  }
  if (state.lastEventSeq > 0) {
    url.searchParams.set("after", String(state.lastEventSeq));
  }

  state.activeEvents = new EventSource(url);
  state.subscribedSessionId = sessionId;
  state.streamConnected = false;
  state.activeEvents.onopen = () => {
    state.streamConnected = true;
    state.lastStreamEventAt = Date.now();
    state.eventRetryDelay = 1000;
    removeNoticeMessages("stream-disconnected");
    removeNoticeMessages("stream-reconnecting");
    nodes.connectionLine.textContent = `online · build ${state.build}`;
    state.backgroundStreamPaused = false;
    if (options.reconnect) {
      addSystemMessage("Stream reconnected.", {
        noticeKey: "stream-reconnected"
      });
    }
    updateTurnMonitor();
  };
  state.activeEvents.onmessage = (event) => {
    const payload = JSON.parse(event.data);
    state.lastStreamEventAt = Date.now();
    const seq = Number(payload.seq || event.lastEventId || 0);
    if (seq) {
      state.lastEventSeq = Math.max(state.lastEventSeq, seq);
    }
    handleGatewayEvent(payload);
  };
  state.activeEvents.onerror = () => {
    state.lastStreamEventAt = Date.now();
    handleStreamDisconnect(sessionId);
  };
}

function ensureSessionStream(sessionId) {
  if (state.activeEvents && state.subscribedSessionId === sessionId) return;
  subscribeToSession(sessionId);
}

function handleStreamDisconnect(sessionId) {
  if (state.subscribedSessionId && state.subscribedSessionId !== sessionId) {
    return;
  }
  state.streamConnected = false;
  nodes.connectionLine.textContent = `reconnecting · build ${state.build}`;
  state.activeEvents?.close();
  state.activeEvents = null;
  state.subscribedSessionId = "";
  addReconnectMessage();
  updateTurnMonitor();
  scheduleEventReconnect(sessionId);
}

function addReconnectMessage(message = "Stream disconnected. The agent can keep running on the laptop.") {
  removeNoticeMessages("stream-disconnected");
  const card = document.createElement("article");
  card.className = "message-card system";
  card.dataset.noticeKey = "stream-disconnected";
  card.innerHTML = [
    '<div class="message-stack">',
    '<div class="message-bubble">',
    '<div class="message-text"></div>',
    '<button type="button" class="history-button">Reconnect</button>',
    "</div>",
    "</div>"
  ].join("");
  setMessageText(card, message);
  card.querySelector("button").addEventListener("click", () => {
    runAction(() => reconnectSessionStream({ manual: true }));
  });
  insertChatCard(card, "bottom");
  followChat();
}

function scheduleEventReconnect(sessionId) {
  if (!sessionId || sessionId !== state.activeSessionId) return;
  clearEventRetry();
  const delay = state.eventRetryDelay;
  state.eventRetryDelay = Math.min(15000, Math.round(state.eventRetryDelay * 1.6));
  state.eventRetryTimer = window.setTimeout(() => {
    runAction(() => reconnectSessionStream());
  }, delay);
}

function clearEventRetry() {
  if (state.eventRetryTimer) {
    window.clearTimeout(state.eventRetryTimer);
    state.eventRetryTimer = null;
  }
}

function pauseSessionStreamForBackground() {
  if (!state.activeEvents) {
    return;
  }
  state.activeEvents.close();
  state.activeEvents = null;
  state.subscribedSessionId = "";
  state.streamConnected = false;
  state.backgroundStreamPaused = true;
  clearEventRetry();
  updateTurnMonitor();
}

function scheduleForegroundReconnect(options = {}) {
  if (state.foregroundTimer) {
    window.clearTimeout(state.foregroundTimer);
  }
  state.foregroundTimer = window.setTimeout(() => {
    if (!state.activeSessionId) {
      return;
    }
    if (options.force || state.backgroundStreamPaused || !state.activeEvents || !state.streamConnected) {
      runAction(() => reconnectSessionStream({ foreground: true }));
      return;
    }
    if (state.selectedProject) {
      runAction(loadProjectInbox);
    }
  }, 250);
}

async function reconnectSessionStream({ manual = false, foreground = false } = {}) {
  if (!state.activeSessionId || state.reconnecting) return;
  const sessionId = state.activeSessionId;
  clearEventRetry();
  state.reconnecting = true;
  removeNoticeMessages("stream-reconnected");
  if (manual) {
    addSystemMessage("Reconnecting stream...", {
      pending: true,
      noticeKey: "stream-reconnecting"
    });
  }
  try {
    const data = await api(`/api/sessions/${encodeURIComponent(sessionId)}/start`, {
      method: "POST",
      body: { autoBaza: true }
    });
    writeOutput(JSON.stringify(data, null, 2));
    await loadSessions();
    if (state.activeSessionId === sessionId) {
      subscribeToSession(sessionId, { reconnect: manual || foreground, force: true });
    }
  } catch (error) {
    addReconnectMessage(`Reconnect failed: ${error.message}`);
    scheduleEventReconnect(sessionId);
    writeOutput(JSON.stringify(error.data || { message: error.message }, null, 2));
  } finally {
    state.reconnecting = false;
    removeNoticeMessages("stream-reconnecting");
    updateTurnMonitor();
  }
}

function handleGatewayEvent(event) {
  writeOutput(JSON.stringify(event, null, 2));

  if (event.type === "gateway/thread-started" || event.type === "gateway/thread-resumed") {
    setTurnActive(false);
    if (event.thread?.turns?.length) {
      renderThreadHistory(event.thread);
    } else {
      removeNoticeMessages("session-pending");
      if (!nodes.chatMessages.children.length) {
        addSystemMessage("Session ready.");
      }
    }
    nodes.sessionStatus.textContent = event.type === "gateway/thread-resumed" ? "resumed" : "ready";
    return;
  }

  if (event.type === "gateway/user-message") {
    if (matchesLocalUserEcho(event)) {
      state.localUserEcho = null;
      removePendingMessages();
      return;
    }
    addChatMessage("user", event.text || "", "", {
      attachments: event.attachments || []
    });
    return;
  }

  if (event.type === "gateway/turn-started") {
    setTurnActive(true);
    state.lastAssistantOutputAt = 0;
    return;
  }

  if (event.type === "gateway/turn-steered") {
    setTurnActive(true);
    removePendingMessages();
    nodes.sessionStatus.textContent = "updated";
    updateTurnMonitor();
    return;
  }

  if (event.type === "gateway/turn-interrupt-requested") {
    nodes.sessionStatus.textContent = "interrupting";
    updateTurnMonitor();
    return;
  }

  const message = event.message;
  if (!message) return;

  if (message.method === "thread/status/changed") {
    const status = message.params.status.type;
    nodes.sessionStatus.textContent = status;
    setTurnActive(status === "active");
    return;
  }

  if (message.method === "turn/started") {
    setTurnActive(true);
    state.lastAssistantOutputAt = 0;
    return;
  }

  if (message.id !== undefined && isApprovalRequestEvent(message)) {
    addApprovalRequest(message, {
      autoApproved: Boolean(event.autoApproved),
      pending: event.pendingApproval !== false
    });
    nodes.sessionStatus.textContent = event.autoApproved
      ? "auto approved"
      : event.pendingApproval === false ? "approval expired" : "waiting approval";
    return;
  }

  if (message.method === "serverRequest/resolved") {
    markApprovalResolved(message.params.requestId, "resolved");
    return;
  }

  if (message.method === "item/agentMessage/delta") {
    state.lastAssistantOutputAt = Date.now();
    removePendingMessages();
    appendAssistantDelta(message.params.itemId, message.params.delta);
    updateTurnMonitor();
    return;
  }

  if (message.method === "item/completed" && message.params?.item?.type === "agentMessage") {
    state.lastAssistantOutputAt = Date.now();
    removePendingMessages();
    completeAssistant(message.params.item.id, message.params.item.text);
    updateTurnMonitor();
    return;
  }

  if (message.method === "turn/completed") {
    nodes.sessionStatus.textContent = "ready";
    setTurnActive(false);
  }
}

async function loadRecentThreadMessages(threadId, { fallbackText = "History is empty." } = {}) {
  if (!state.selectedProject || !threadId) return null;
  state.historyTurnsLoading = true;
  const projectId = state.selectedProject.id;
  const params = new URLSearchParams({
    limit: "6",
    direction: "desc"
  });
  try {
    const data = await api(`/api/projects/${encodeURIComponent(projectId)}/chats/${encodeURIComponent(threadId)}/turns?${params.toString()}`);
    if (!isCurrentThread(threadId, projectId)) {
      return data;
    }
    removeNoticeMessages("history-pending");
    state.historyLoadedThreadId = threadId;
    state.historyOlderCursor = data.nextCursor || "";
    state.historyExpanded = false;
    state.threadMessages = data.messages || turnsToMessages(data.turns || []);
    nodes.sessionTitle.textContent = data.thread.title;
    if (!state.activeSessionId) {
      nodes.sessionStatus.textContent = data.thread.linkedSessionId ? "linked history" : "history preview";
    }
    renderThreadMessages();
    if (!state.threadMessages.length) {
      addSystemMessage(fallbackText);
    }
    writeOutput(JSON.stringify(data, null, 2));
    return data;
  } finally {
    if (isCurrentThread(threadId, projectId)) {
      state.historyTurnsLoading = false;
      renderThreadMessages({ follow: false });
    }
  }
}

async function loadOlderThreadMessages() {
  if (!state.selectedProject || !state.historyLoadedThreadId || !state.historyOlderCursor || state.historyTurnsLoading) {
    return;
  }
  const threadId = state.historyLoadedThreadId;
  const projectId = state.selectedProject.id;
  const cursor = state.historyOlderCursor;
  state.historyTurnsLoading = true;
  renderThreadMessages({ follow: false });
  const params = new URLSearchParams({
    limit: "6",
    direction: "desc",
    cursor
  });
  try {
    const data = await api(`/api/projects/${encodeURIComponent(projectId)}/chats/${encodeURIComponent(threadId)}/turns?${params.toString()}`);
    if (!isCurrentThread(threadId, projectId)) {
      return;
    }
    state.historyOlderCursor = data.nextCursor || "";
    state.historyExpanded = true;
    state.threadMessages = (data.messages || turnsToMessages(data.turns || [])).concat(state.threadMessages);
    renderThreadMessages({ follow: false });
    writeOutput(JSON.stringify(data, null, 2));
  } finally {
    if (state.selectedProject?.id === projectId && state.historyLoadedThreadId === threadId) {
      state.historyTurnsLoading = false;
      renderThreadMessages({ follow: false });
    }
  }
}

function isCurrentThread(threadId, projectId = state.selectedProject?.id) {
  if (!threadId || state.selectedProject?.id !== projectId) {
    return false;
  }
  const activeSession = state.sessions.find((session) => session.id === state.activeSessionId);
  return state.activeHistoryThreadId === threadId
    || activeSession?.codexThreadId === threadId
    || state.historyLoadedThreadId === threadId;
}

function renderThreadHistory(thread, { fallbackText = "Session ready." } = {}) {
  const messages = turnsToMessages(thread.turns || []);
  state.threadMessages = messages;
  state.historyLoadedThreadId = thread.id || "";
  state.historyOlderCursor = "";
  renderThreadMessages();
  if (!nodes.chatMessages.children.length) {
    addSystemMessage(fallbackText);
  }
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

function renderThreadMessages({ follow = true } = {}) {
  resetChat("");
  const hiddenCount = Math.max(0, state.threadMessages.length - state.visibleHistoryLimit);
  const visibleMessages = state.historyExpanded || hiddenCount === 0
    ? state.threadMessages
    : state.threadMessages.slice(hiddenCount);

  if (state.historyOlderCursor) {
    addHistoryCollapsedMessage(hiddenCount, {
      loading: state.historyTurnsLoading
    });
  } else if (hiddenCount > 0 && !state.historyExpanded) {
    addHistoryCollapsedMessage(hiddenCount);
  }

  for (const message of visibleMessages) {
    addChatMessage(message.role, message.text || "", "", {
      attachments: message.attachments || [],
      scroll: false
    });
  }

  if (follow) {
    followChat({ settle: true });
  }
}

function addHistoryCollapsedMessage(hiddenCount, options = {}) {
  const card = document.createElement("article");
  card.className = "message-card system history-card";
  const canLoadOlder = Boolean(state.historyOlderCursor);
  const label = canLoadOlder
    ? (options.loading ? "Loading earlier message(s)..." : "Show earlier message(s)")
    : `Show ${hiddenCount} earlier message(s)`;
  card.innerHTML = [
    '<div class="message-stack">',
    '<div class="message-bubble">',
    `<button type="button" class="history-button">${escapeHtml(label)}</button>`,
    "</div>",
    '<div class="message-footer"><span class="message-role">HISTORY</span></div>',
    "</div>"
  ].join("");
  card.querySelector(".history-button").addEventListener("click", () => {
    if (state.historyOlderCursor) {
      runAction(loadOlderThreadMessages);
      return;
    }
    state.historyExpanded = true;
    renderThreadMessages();
  });
  card.querySelector(".history-button").disabled = Boolean(options.loading);
  nodes.chatMessages.append(card);
}

function addHistoryResumeMessage(thread) {
  const card = document.createElement("article");
  card.className = "message-card system history-card";
  const label = thread.linkedSessionId ? "Open Linked Session" : "Continue";
  const meta = [
    thread.status,
    thread.modelProvider || "codex",
    thread.updatedAt ? formatRelativeTime(thread.updatedAt) : ""
  ].filter(Boolean).join(" · ");
  card.innerHTML = [
    '<div class="message-stack">',
    '<div class="message-bubble">',
    `<div class="message-text">${escapeHtml(meta)}</div>`,
    `<button type="button" class="history-button">${escapeHtml(label)}</button>`,
    "</div>",
    '<div class="message-footer"><span class="message-role">HISTORY</span></div>',
    "</div>"
  ].join("");
  card.querySelector(".history-button").addEventListener("click", () => {
    if (thread.linkedSessionId) {
      runAction(() => activateSession(thread.linkedSessionId));
      return;
    }
    runAction(() => resumeHistoryThread(thread.id));
  });
  nodes.chatMessages.append(card);
  followChat();
}

function addChatMessage(role, text, id = "", options = {}) {
  removeEmptyChat();
  const attachments = options.attachments || [];
  const card = document.createElement("article");
  card.className = `message-card ${role === "codex" ? "codex" : "user"}`;
  if (id) card.dataset.itemId = id;
  card.innerHTML = [
    '<div class="message-stack">',
    '<div class="message-bubble">',
    '<div class="message-text"></div>',
    renderMessageAttachments(attachments),
    "</div>",
    '<div class="message-footer">',
    `<span class="message-role">${role === "codex" ? "CODEX" : "USER"}</span>`,
    `<time>${formatClock(new Date())}</time>`,
    "</div>",
    "</div>"
  ].join("");
  setMessageText(card, text);
  insertChatCard(card, options.position || "bottom");
  if (options.scroll !== false) {
    followChat();
  }
  return card;
}

async function addSelectedImages() {
  const files = Array.from(nodes.imageInput.files || []);
  nodes.imageInput.value = "";
  if (!files.length) return;

  const availableSlots = 4 - state.attachments.length;
  if (files.length > availableSlots) {
    throw new Error("You can attach up to 4 images.");
  }

  for (const file of files) {
    if (!isSupportedImageFile(file)) {
      throw new Error("Supported image formats: JPEG, PNG, WebP, GIF, HEIC, HEIF.");
    }
    if (file.size > 8 * 1024 * 1024) {
      throw new Error("Image must be 8 MB or smaller.");
    }
  }

  const pending = await Promise.all(files.map(async (file) => ({
    id: window.crypto?.randomUUID ? window.crypto.randomUUID() : `${Date.now()}-${Math.random()}`,
    name: file.name || "image",
    type: file.type || mimeTypeFromName(file.name) || "image/*",
    size: file.size,
    dataUrl: await fileToDataUrl(file),
    previewUrl: URL.createObjectURL(file)
  })));
  state.attachments.push(...pending);
  renderAttachments();
  followChat({ focus: false });
}

function isSupportedImageFile(file) {
  const type = String(file.type || "").toLowerCase();
  if (SUPPORTED_IMAGE_TYPES.has(type)) return true;
  const extension = fileExtension(file.name);
  return SUPPORTED_IMAGE_EXTENSIONS.has(extension);
}

function mimeTypeFromName(name) {
  const extension = fileExtension(name);
  const byExtension = {
    jpg: "image/jpeg",
    jpeg: "image/jpeg",
    png: "image/png",
    webp: "image/webp",
    gif: "image/gif",
    heic: "image/heic",
    heif: "image/heif"
  };
  return byExtension[extension] || "";
}

function fileExtension(name) {
  const match = String(name || "").toLowerCase().match(/\.([a-z0-9]+)$/);
  return match ? match[1] : "";
}

function fileToDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.addEventListener("load", () => resolve(String(reader.result || "")));
    reader.addEventListener("error", () => reject(reader.error || new Error("Failed to read image.")));
    reader.readAsDataURL(file);
  });
}

function renderAttachments() {
  nodes.attachmentTray.innerHTML = "";
  nodes.attachmentTray.hidden = state.attachments.length === 0;
  for (const attachment of state.attachments) {
    const chip = document.createElement("div");
    chip.className = "attachment-chip";
    chip.innerHTML = [
      `<img src="${escapeAttr(attachment.previewUrl)}" alt="">`,
      '<div class="attachment-meta">',
      `<strong>${escapeHtml(attachment.name)}</strong>`,
      `<span>${escapeHtml(formatBytes(attachment.size))}</span>`,
      "</div>",
      `<button type="button" aria-label="Remove ${escapeAttr(attachment.name)}">×</button>`
    ].join("");
    chip.querySelector("button").addEventListener("click", () => removeAttachment(attachment.id));
    nodes.attachmentTray.append(chip);
  }
}

function clearAttachments({ revoke = true } = {}) {
  if (revoke) {
    for (const attachment of state.attachments) {
      if (attachment.previewUrl) {
        URL.revokeObjectURL(attachment.previewUrl);
      }
    }
  }
  state.attachments = [];
  renderAttachments();
}

function removeAttachment(id) {
  const attachment = state.attachments.find((item) => item.id === id);
  if (attachment?.previewUrl) {
    URL.revokeObjectURL(attachment.previewUrl);
  }
  state.attachments = state.attachments.filter((item) => item.id !== id);
  renderAttachments();
}

function renderMessageAttachments(attachments) {
  if (!attachments.length) return "";
  const items = attachments.map((attachment) => {
    const name = attachment.name || attachment.path?.split("/").pop() || "image";
    if (attachment.previewUrl) {
      return [
        '<figure class="message-attachment preview">',
        `<img src="${escapeAttr(attachment.previewUrl)}" alt="${escapeAttr(name)}">`,
        `<figcaption>${escapeHtml(name)}</figcaption>`,
        "</figure>"
      ].join("");
    }
    return [
      '<div class="message-attachment file">',
      '<span>IMG</span>',
      '<strong>',
      escapeHtml(name),
      attachment.size ? ` · ${escapeHtml(formatBytes(attachment.size))}` : "",
      "</strong>",
      "</div>"
    ].join("");
  });
  return `<div class="message-attachments">${items.join("")}</div>`;
}

function setMessageText(card, text) {
  card.__rawText = String(text || "");
  const textNode = card.querySelector(".message-text");
  if (!textNode) return;
  textNode.innerHTML = renderRichMessageText(card.__rawText);
  attachCodeCopyHandlers(card);
}

function renderRichMessageText(text) {
  const source = String(text || "");
  if (!source) return "";

  const blocks = [];
  const fencePattern = /```([a-zA-Z0-9_.+-]*)[ \t]*\n?([\s\S]*?)(```|$)/g;
  let index = 0;
  let match;
  while ((match = fencePattern.exec(source)) !== null) {
    if (match.index > index) {
      blocks.push(renderProseBlock(source.slice(index, match.index)));
    }
    blocks.push(renderCodeBlock(match[2], match[1]));
    index = match.index + match[0].length;
  }
  if (index < source.length) {
    blocks.push(renderProseBlock(source.slice(index)));
  }

  return blocks.join("");
}

function renderProseBlock(text) {
  if (!text) return "";
  const html = renderInlineMarkdown(text.trimEnd()).replaceAll("\n", "<br>");
  return html ? `<div class="message-prose">${html}</div>` : "";
}

function renderInlineMarkdown(text) {
  const source = String(text || "");
  const parts = [];
  const inlineCodePattern = /`([^`\n]+)`/g;
  let index = 0;
  let match;
  while ((match = inlineCodePattern.exec(source)) !== null) {
    if (match.index > index) {
      parts.push(renderInlineProse(source.slice(index, match.index)));
    }
    parts.push(`<code class="inline-code">${escapeHtml(match[1])}</code>`);
    index = match.index + match[0].length;
  }
  if (index < source.length) {
    parts.push(renderInlineProse(source.slice(index)));
  }
  return parts.join("");
}

function renderInlineProse(text) {
  return escapeHtml(text).replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
}

function renderCodeBlock(code, language) {
  const label = String(language || "code").trim() || "code";
  return [
    '<div class="message-code-block">',
    '<div class="message-code-header">',
    `<span>${escapeHtml(label)}</span>`,
    '<button type="button" data-copy-code>Copy</button>',
    "</div>",
    `<pre><code>${escapeHtml(String(code || "").replace(/\n$/, ""))}</code></pre>`,
    "</div>"
  ].join("");
}

function attachCodeCopyHandlers(card) {
  for (const button of card.querySelectorAll("[data-copy-code]")) {
    button.addEventListener("click", async () => {
      const code = button.closest(".message-code-block")?.querySelector("code")?.textContent || "";
      try {
        await navigator.clipboard.writeText(code);
        button.textContent = "Copied";
        window.setTimeout(() => {
          button.textContent = "Copy";
        }, 900);
      } catch {
        button.textContent = "Copy failed";
        window.setTimeout(() => {
          button.textContent = "Copy";
        }, 1200);
      }
    });
  }
}

function userInputAttachment(part) {
  const type = part?.type || part?.kind || "";
  if (!["image", "localImage", "input_image"].includes(type)) {
    return null;
  }
  const path = part.path || "";
  const url = part.url || part.image_url || "";
  return {
    name: part.name || path.split("/").pop() || url.split("/").pop() || "image",
    path,
    url,
    mimeType: part.mimeType || part.mime_type || ""
  };
}

function matchesLocalUserEcho(event) {
  if (!state.localUserEcho) return false;
  const attachmentCount = Array.isArray(event.attachments) ? event.attachments.length : 0;
  return String(event.text || "") === state.localUserEcho.text
    && attachmentCount === state.localUserEcho.attachmentCount;
}

function setTurnActive(active, options = {}) {
  const nextActive = Boolean(active);
  if (nextActive && !state.turnActive) {
    state.activeTurnStartedAt = options.startedAt || Date.now();
    state.lastMonitorNoticeAt = 0;
  }
  if (!nextActive) {
    state.activeTurnStartedAt = 0;
    state.lastAssistantOutputAt = 0;
    state.lastMonitorNoticeAt = 0;
  }
  state.turnActive = nextActive;
  updateInterruptControl();
  updateTurnMonitor();
}

function updateInterruptControl() {
  const canInterrupt = Boolean(state.activeSessionId && state.turnActive);
  nodes.interruptButton.hidden = !canInterrupt;
  nodes.interruptButton.disabled = !canInterrupt;
}

function updateTurnMonitor() {
  if (!state.turnActive) {
    return;
  }
  const now = Date.now();
  const runningFor = state.activeTurnStartedAt ? formatDuration(now - state.activeTurnStartedAt) : "";
  const stream = state.streamConnected ? "" : "stream paused";
  nodes.sessionStatus.textContent = ["running", runningFor, stream].filter(Boolean).join(" · ");
}

function addTurnStatusMessage() {
  const now = Date.now();
  const runningFor = state.activeTurnStartedAt ? formatDuration(now - state.activeTurnStartedAt) : "unknown";
  const streamAgo = state.lastStreamEventAt ? `${formatDuration(now - state.lastStreamEventAt)} ago` : "no stream event yet";
  const outputAgo = state.lastAssistantOutputAt ? `${formatDuration(now - state.lastAssistantOutputAt)} ago` : "no visible output yet";
  const stream = state.streamConnected ? "connected" : state.reconnecting ? "reconnecting" : "disconnected";
  addSystemMessage(`Local run status: running ${runningFor}; stream ${stream}; last event ${streamAgo}; last output ${outputAgo}. You can send an update while the answer is running.`, {
    noticeKey: "turn-local-status"
  });
}

function formatDuration(ms) {
  const seconds = Math.max(0, Math.floor(ms / 1000));
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  const restSeconds = seconds % 60;
  if (minutes < 60) {
    return restSeconds ? `${minutes}m ${restSeconds}s` : `${minutes}m`;
  }
  const hours = Math.floor(minutes / 60);
  const restMinutes = minutes % 60;
  return restMinutes ? `${hours}h ${restMinutes}m` : `${hours}h`;
}

function autoResizeComposer() {
  const input = nodes.messageInput;
  input.style.height = "auto";
  const viewportHeight = window.visualViewport?.height || window.innerHeight;
  const maxHeight = Math.max(96, Math.round(viewportHeight * 0.34));
  const nextHeight = Math.min(input.scrollHeight, maxHeight);
  input.style.height = `${nextHeight}px`;
  input.style.overflowY = input.scrollHeight > maxHeight ? "auto" : "hidden";
  window.requestAnimationFrame(() => scrollChat());
}

function syncViewportHeight() {
  const viewport = window.visualViewport;
  const height = viewport?.height || window.innerHeight || document.documentElement.clientHeight;
  const offsetTop = viewport?.offsetTop || 0;
  const appHeight = Math.max(320, Math.round(height));
  document.documentElement.style.setProperty("--app-height", `${appHeight}px`);
  document.documentElement.style.setProperty("--app-top", `${Math.round(offsetTop)}px`);
  autoResizeComposer();
}

function composerText() {
  return nodes.messageInput.innerText.replace(/\u00a0/g, " ");
}

function setComposerText(value) {
  nodes.messageInput.textContent = value;
}

function pastePlainText(event) {
  const text = event.clipboardData?.getData("text/plain");
  if (!text) return;
  event.preventDefault();
  document.execCommand("insertText", false, text);
}

function addSystemMessage(text, options = {}) {
  removeEmptyChat();
  if (options.noticeKey) {
    removeNoticeMessages(options.noticeKey);
  }
  const card = document.createElement("article");
  card.className = "message-card system";
  if (options.pending) card.dataset.pending = "true";
  if (options.noticeKey) card.dataset.noticeKey = options.noticeKey;
  card.innerHTML = [
    '<div class="message-stack">',
    '<div class="message-bubble"><div class="message-text"></div></div>',
    "</div>"
  ].join("");
  setMessageText(card, text);
  insertChatCard(card, "bottom");
  followChat();
}

function addBazaRequiredMessage(data = {}) {
  removePendingMessages();
  removeNoticeMessages("baza-required");
  removeEmptyChat();

  const missing = data.preflight?.inspection?.missing || data.bazaAction?.after?.missing || state.bazaMissing || [];
  state.bazaOk = false;
  state.bazaMissing = missing;
  nodes.bazaStatus.textContent = "BAZA missing files";
  const message = data.message || bazaRequiredMessage();
  const details = missing.length ? `Missing: ${missing.join(", ")}` : "Run BAZA to initialize or sync this project.";
  const card = document.createElement("article");
  card.className = "message-card system baza-required-card";
  card.dataset.noticeKey = "baza-required";
  card.innerHTML = [
    '<div class="message-stack">',
    '<div class="message-bubble">',
    `<div class="message-text">${escapeHtml(message)}</div>`,
    `<div class="message-hint">${escapeHtml(details)}</div>`,
    '<button type="button" class="history-button">Run BAZA</button>',
    "</div>",
    "</div>"
  ].join("");
  card.querySelector(".history-button").addEventListener("click", () => runAction(runBazaAction));
  insertChatCard(card, "bottom");
  followChat();
}

function addApprovalRequest(message, options = {}) {
  const requestId = String(message.id);
  if (nodes.chatMessages.querySelector(`[data-request-id="${requestId}"]`)) return;

  removeEmptyChat();
  const params = message.params || {};
  const meta = params._meta || {};
  const supported = isSupportedApprovalRequest(message);
  const expired = options.pending === false && !options.autoApproved;
  const tool = meta.tool_description || params.message || params.reason || params.command || message.method || "Codex requests permission.";
  const payload = {
    method: message.method,
    server: params.serverName,
    message: params.message,
    reason: params.reason,
    command: params.command,
    cwd: params.cwd,
    proposedExecpolicyAmendment: params.proposedExecpolicyAmendment,
    tool: meta.tool_params_display || meta.tool_params || null,
    persist: meta.persist || null,
    supported
  };
  const title = options.autoApproved
    ? "Permission auto-allowed"
    : expired ? "Permission request expired" : "Permission request";
  const hint = expired
    ? "This request is no longer active on the gateway."
    : supported
    ? "Review the request, then allow or deny it."
    : "This request type is visible here, but must be handled from desktop Codex/Zed.";

  const card = document.createElement("article");
  card.className = "message-card system approval-card";
  if (options.autoApproved || expired) card.classList.add("resolved");
  if (!supported) card.classList.add("unsupported");
  card.dataset.requestId = requestId;
  card.dataset.method = message.method || "";
  card.innerHTML = [
    '<div class="message-stack">',
    '<div class="message-bubble">',
    `<div class="approval-title">${escapeHtml(title)}</div>`,
    `<div class="message-text">${escapeHtml(tool)}</div>`,
    `<div class="message-hint">${escapeHtml(hint)}</div>`,
    `<pre class="approval-payload">${escapeHtml(JSON.stringify(payload, null, 2))}</pre>`,
    '<div class="approval-actions">',
    options.autoApproved
      ? '<span>allowed automatically</span>'
      : expired
      ? '<span>expired</span>'
      : [
        `<button type="button" data-action="accept" ${supported ? "" : "disabled"}>Allow</button>`,
        `<button type="button" data-action="decline" ${supported ? "" : "disabled"}>Deny</button>`
      ].join(""),
    "</div>",
    "</div>",
    '<div class="message-footer"><span class="message-role">APPROVAL</span></div>',
    "</div>"
  ].join("");

  for (const button of card.querySelectorAll("[data-action]")) {
    button.addEventListener("click", () => runAction(() => resolveApproval(requestId, button.dataset.action)));
  }

  nodes.chatMessages.append(card);
  followChat();
}

function isSupportedApprovalRequest(message) {
  return isApprovalRequestEvent(message);
}

function isApprovalRequestEvent(message) {
  return [
    "mcpServer/elicitation/request",
    "item/commandExecution/requestApproval"
  ].includes(message?.method);
}

function markAutoAllowedPendingApprovalCards() {
  for (const card of nodes.chatMessages.querySelectorAll(".approval-card:not(.resolved)")) {
    if (!isAutoAllowedApprovalMethod(card.dataset.method)) {
      continue;
    }
    card.classList.add("resolved");
    const actions = card.querySelector(".approval-actions");
    if (actions) {
      actions.innerHTML = "<span>allowed automatically</span>";
    }
  }
}

function isAutoAllowedApprovalMethod(method) {
  return [
    "mcpServer/elicitation/request",
    "item/commandExecution/requestApproval"
  ].includes(method);
}

async function resolveApproval(requestId, action) {
  const card = nodes.chatMessages.querySelector(`[data-request-id="${requestId}"]`);
  if (card) {
    for (const button of card.querySelectorAll("button")) button.disabled = true;
    card.classList.add("resolving");
  }
  try {
    const data = await api(`/api/sessions/${encodeURIComponent(state.activeSessionId)}/requests/${encodeURIComponent(requestId)}`, {
      method: "POST",
      body: { action }
    });
    markApprovalResolved(requestId, action === "accept" ? "allowed" : "denied");
    writeOutput(JSON.stringify(data, null, 2));
  } catch (error) {
    if (["pending_request_not_found", "not_found"].includes(error.data?.error)) {
      markApprovalResolved(requestId, "expired");
      addSystemMessage("This permission request is no longer active on the gateway. Stop or reconnect the runtime, then retry from the updated gateway.", {
        noticeKey: "approval-expired"
      });
      writeOutput(JSON.stringify(error.data || { message: error.message }, null, 2));
      return;
    }
    throw error;
  }
}

function markApprovalResolved(requestId, label) {
  const card = nodes.chatMessages.querySelector(`[data-request-id="${String(requestId)}"]`);
  if (!card) return;
  card.classList.remove("resolving");
  card.classList.add("resolved");
  const actions = card.querySelector(".approval-actions");
  if (actions) {
    actions.innerHTML = `<span>${escapeHtml(label)}</span>`;
  }
}

function removePendingMessages() {
  for (const card of nodes.chatMessages.querySelectorAll("[data-pending='true']")) {
    card.remove();
  }
}

function removeNoticeMessages(noticeKey) {
  for (const card of nodes.chatMessages.querySelectorAll("[data-notice-key]")) {
    if (card.dataset.noticeKey === noticeKey) {
      card.remove();
    }
  }
}

function appendAssistantDelta(itemId, delta) {
  removeEmptyChat();
  let card = findMessageByItemId(itemId);
  if (!card) {
    card = addChatMessage("codex", "", itemId);
  }
  setMessageText(card, `${card.__rawText || ""}${delta}`);
  followChat();
}

function completeAssistant(itemId, text) {
  let card = findMessageByItemId(itemId);
  if (!card) {
    card = addChatMessage("codex", text, itemId);
  } else {
    setMessageText(card, text);
  }
  followChat();
}

function findMessageByItemId(itemId) {
  for (const card of nodes.chatMessages.querySelectorAll("[data-item-id]")) {
    if (card.dataset.itemId === itemId) return card;
  }
  return null;
}

function resetChat(systemText, options = {}) {
  nodes.chatMessages.innerHTML = "";
  if (systemText) addSystemMessage(systemText, options);
}

function removeEmptyChat() {
  const empty = nodes.chatMessages.querySelector(".empty-chat");
  if (empty) empty.remove();
}

function scrollChat() {
  const bottom = Math.max(0, nodes.chatMessages.scrollHeight - nodes.chatMessages.clientHeight);
  nodes.chatMessages.scrollTop = bottom;
  nodes.chatMessages.scrollLeft = 0;
  nodes.chatMessages.lastElementChild?.scrollIntoView({
    block: "end",
    inline: "nearest",
    behavior: "auto"
  });
}

function followChat({ focus = false, settle = false } = {}) {
  const apply = () => {
    scrollChat();
    if (!isMobileViewport()) {
      if (focus) {
        nodes.messageInput.focus({ preventScroll: true });
      }
      return;
    }
    if (!state.chatFocus) {
      nodes.chatScreen.scrollIntoView({ block: "end", behavior: "smooth" });
    }
    document.documentElement.scrollLeft = 0;
    document.body.scrollLeft = 0;
    if (focus) {
      nodes.messageInput.focus({ preventScroll: true });
    }
  };

  window.requestAnimationFrame(apply);
  for (const delay of settle ? [50, 140, 320, 700, 1100] : [80, 220]) {
    window.setTimeout(apply, delay);
  }
}

function insertChatCard(card, position = "bottom") {
  if (position === "top") {
    nodes.chatMessages.prepend(card);
    return;
  }
  nodes.chatMessages.append(card);
}

function updateActiveSessionHeader() {
  const session = state.sessions.find((item) => item.id === state.activeSessionId);
  nodes.sessionTitle.textContent = session?.title || "No session";
  if (state.turnActive) {
    updateTurnMonitor();
  } else {
    nodes.sessionStatus.textContent = session ? session.status : "No active session";
  }
}

function setupChatFocusObserver() {
  if (!("IntersectionObserver" in window)) {
    return;
  }

  state.chatFocusObserver = new IntersectionObserver((entries) => {
    const entry = entries[0];
    if (!entry || !isMobileViewport() || state.chatFocus || state.chatFocusSuppressed) {
      return;
    }
    if (entry.isIntersecting && entry.intersectionRatio >= 0.72) {
      enterChatFocus({ focus: false });
    }
  }, {
    threshold: [0, 0.55, 0.72, 0.9]
  });
  state.chatFocusObserver.observe(nodes.chatScreen);

  window.addEventListener("resize", () => {
    if (!isMobileViewport() && state.chatFocus) {
      exitChatFocus({ scrollToPanel: false });
    }
  });
}

function isMobileViewport() {
  return window.matchMedia("(max-width: 780px)").matches;
}

function enterChatFocus({ focus = false } = {}) {
  if (!isMobileViewport()) {
    followChat({ focus, settle: true });
    return;
  }

  state.chatFocus = true;
  document.body.classList.add("chat-focus");
  nodes.exitChatFocusButton.hidden = false;
  nodes.sessionPanel.setAttribute("aria-hidden", "true");
  followChat({ focus, settle: true });
}

function exitChatFocus(options = {}) {
  const scrollToPanel = options.scrollToPanel !== false;
  state.chatFocus = false;
  state.chatFocusSuppressed = true;
  document.body.classList.remove("chat-focus");
  nodes.exitChatFocusButton.hidden = true;
  nodes.sessionPanel.removeAttribute("aria-hidden");
  if (scrollToPanel) {
    nodes.sessionPanel.scrollIntoView({ block: "start", behavior: "smooth" });
  }
  window.setTimeout(() => {
    state.chatFocusSuppressed = false;
  }, 900);
}

function formatClock(date) {
  return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function formatRelativeTime(value) {
  const time = value ? new Date(value).getTime() : 0;
  if (!time) return "unknown";
  const diffSeconds = Math.max(1, Math.round((Date.now() - time) / 1000));
  if (diffSeconds < 60) return "now";
  const diffMinutes = Math.round(diffSeconds / 60);
  if (diffMinutes < 60) return `${diffMinutes}m ago`;
  const diffHours = Math.round(diffMinutes / 60);
  if (diffHours < 24) return `${diffHours}h ago`;
  const diffDays = Math.round(diffHours / 24);
  return `${diffDays}d ago`;
}

function formatBytes(value) {
  const bytes = Number(value || 0);
  if (bytes < 1024) return `${bytes} B`;
  const kilobytes = bytes / 1024;
  if (kilobytes < 1024) return `${kilobytes.toFixed(kilobytes >= 10 ? 0 : 1)} KB`;
  const megabytes = kilobytes / 1024;
  return `${megabytes.toFixed(megabytes >= 10 ? 0 : 1)} MB`;
}

function jumpToComposer({ focus = false } = {}) {
  window.requestAnimationFrame(() => {
    document.documentElement.scrollLeft = 0;
    document.body.scrollLeft = 0;
    if (window.matchMedia("(max-width: 780px)").matches) {
      enterChatFocus({ focus });
      return;
    }
    followChat({ focus });
  });
}

async function api(path, options = {}) {
  const init = {
    method: options.method || "GET",
    headers: { "content-type": "application/json" }
  };
  if (state.token) {
    init.headers.authorization = `Bearer ${state.token}`;
  }
  if (options.body) {
    init.body = JSON.stringify(options.body);
  }

  const response = await fetch(path, init);
  const data = await response.json();
  if (response.status === 401) {
    const token = window.prompt("Gateway token");
    if (token) {
      state.token = token;
      localStorage.setItem("zedMobToken", token);
      return api(path, options);
    }
  }
  if (!response.ok) {
    const error = new Error(data.message || data.error || "Request failed");
    error.data = data;
    throw error;
  }
  return data;
}

async function runAction(action) {
  try {
    await action();
  } catch (error) {
    handleActionError(error);
    writeOutput(JSON.stringify(error.data || { message: error.message }, null, 2));
  }
}

function handleActionError(error) {
  removePendingMessages();
  if (error.data?.error === "no_active_turn") {
    setTurnActive(false);
    addSystemMessage("No active answer to stop.", {
      noticeKey: "action-error"
    });
    return;
  }
  if (error.data?.error === "turn_already_active") {
    setTurnActive(true);
    updateTurnMonitor({ forceNotice: true });
    addSystemMessage("The current answer is still running and this turn cannot accept updates right now. Tap the stop button to interrupt it, or use Reconnect if the stream disconnected.", {
      noticeKey: "active-turn"
    });
    return;
  }
  if (error.data?.error === "baza_required") {
    addBazaRequiredMessage(error.data);
    return;
  }
  if (error.data?.error === "baza_failed") {
    state.bazaOk = false;
    state.bazaMissing = error.data.baza?.after?.missing || state.bazaMissing;
    nodes.bazaStatus.textContent = "BAZA failed";
    addSystemMessage(error.data.message || "BAZA action failed.", {
      noticeKey: "baza-result"
    });
    jumpToComposer({ focus: false });
    return;
  }
  addSystemMessage(`Error: ${error.message}`, {
    noticeKey: "action-error"
  });
  jumpToComposer({ focus: false });
}

function writeOutput(value) {
  nodes.output.textContent = value;
}

function bazaRequiredMessage() {
  const projectName = state.selectedProject?.name || "this project";
  const suffix = state.bazaMissing.length ? ` Missing: ${state.bazaMissing.join(", ")}.` : "";
  return `BAZA is required for ${projectName}. Run BAZA to initialize or sync this project.${suffix}`;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function escapeAttr(value) {
  return escapeHtml(value).replaceAll("'", "&#39;");
}
