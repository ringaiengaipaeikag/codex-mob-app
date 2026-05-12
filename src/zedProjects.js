import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { addProject, loadProjects, projectForPath, serverConfig } from "./config.js";

const execFileAsync = promisify(execFile);
const DEFAULT_ZED_DB = path.join(os.homedir(), "Library", "Application Support", "Zed", "db", "0-stable", "db.sqlite");

export async function listZedRecentProjects({ limit = 50 } = {}) {
  const dbPath = process.env.ZED_MOB_ZED_DB || DEFAULT_ZED_DB;
  try {
    await fs.access(dbPath);
  } catch {
    return {
      ok: false,
      error: "zed_db_not_found",
      dbPath,
      projects: []
    };
  }

  const rows = await queryZedWorkspaces(dbPath, boundedLimit(limit));
  const seen = new Set();
  const projects = [];
  for (const row of rows) {
    const paths = parseWorkspacePaths(row.paths);
    for (const candidatePath of paths) {
      const projectPath = path.resolve(candidatePath);
      if (seen.has(projectPath)) {
        continue;
      }
      if (!await isDirectory(projectPath)) {
        continue;
      }
      seen.add(projectPath);
      projects.push({
        ...projectForPath(projectPath),
        source: "zed",
        updatedAt: timestampToIso(row.timestamp),
        workspaceId: row.workspace_id
      });
    }
  }

  return {
    ok: true,
    dbPath,
    projects
  };
}

export async function syncZedRecentProjects({ limit = 50 } = {}) {
  const recent = await listZedRecentProjects({ limit });
  if (!recent.ok) {
    return {
      ...recent,
      added: [],
      projects: await loadProjects()
    };
  }

  const added = [];
  const trustedRoots = recent.ok ? await listZedTrustedRoots(recent.dbPath) : [];
  for (const project of recent.projects) {
    if (!isUnderTrustedRoot(project.path, trustedRoots)) {
      continue;
    }
    const result = await addProject(project);
    if (result.added) {
      added.push(result.project);
    }
  }

  return {
    ok: true,
    dbPath: recent.dbPath,
    added,
    projects: await loadProjects()
  };
}

async function listZedTrustedRoots(dbPath) {
  try {
    const result = await execFileAsync("sqlite3", [
      "-json",
      dbPath,
      "select absolute_path from trusted_worktrees where absolute_path is not null and trim(absolute_path) <> ''"
    ], {
      timeout: 15000,
      maxBuffer: 1024 * 1024
    });
    return JSON.parse(result.stdout || "[]")
      .map((row) => row.absolute_path)
      .filter(Boolean);
  } catch {
    return [];
  }
}

function isUnderTrustedRoot(candidatePath, zedTrustedRoots = []) {
  const trustedRoots = [
    serverConfig().projectsRoot,
    ...zedTrustedRoots,
    ...String(process.env.ZED_MOB_PROJECT_TRUST_ROOTS || "")
      .split(path.delimiter)
      .map((item) => item.trim())
      .filter(Boolean)
  ].map((item) => path.resolve(item));

  const candidate = path.resolve(candidatePath);
  return trustedRoots.some((root) => {
    const relative = path.relative(root, candidate);
    return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
  });
}

async function queryZedWorkspaces(dbPath, limit) {
  const query = [
    "select workspace_id, paths, paths_order, timestamp",
    "from workspaces",
    "where paths is not null and trim(paths) <> ''",
    "order by datetime(timestamp) desc",
    `limit ${limit}`
  ].join(" ");
  const result = await execFileAsync("sqlite3", ["-json", dbPath, query], {
    timeout: 15000,
    maxBuffer: 1024 * 1024
  });
  return JSON.parse(result.stdout || "[]");
}

function parseWorkspacePaths(value) {
  const text = String(value || "").trim();
  if (!text) {
    return [];
  }
  if (text.startsWith("[")) {
    try {
      const parsed = JSON.parse(text);
      if (Array.isArray(parsed)) {
        return parsed.map(String).filter(Boolean);
      }
    } catch {
      return [];
    }
  }
  return text
    .split(/\r?\n|\0/)
    .map((item) => item.trim())
    .filter(Boolean);
}

async function isDirectory(candidatePath) {
  try {
    const stat = await fs.stat(candidatePath);
    return stat.isDirectory();
  } catch {
    return false;
  }
}

function timestampToIso(value) {
  const date = value ? new Date(`${value}Z`) : null;
  return date && Number.isFinite(date.getTime()) ? date.toISOString() : "";
}

function boundedLimit(value) {
  const parsed = Number.parseInt(String(value || ""), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return 50;
  }
  return Math.min(parsed, 100);
}
