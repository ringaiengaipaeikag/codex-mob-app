import fs from "node:fs/promises";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const DEFAULT_CONFIG_PATH = path.join(ROOT, "config", "projects.json");
const DEFAULT_PROJECTS_ROOT = path.dirname(ROOT);

export function projectRoot() {
  return ROOT;
}

export function runtimeDir() {
  return process.env.ZED_MOB_DATA_DIR || path.join(ROOT, ".zed-mob");
}

export function serverConfig() {
  return {
    host: process.env.ZED_MOB_HOST || "127.0.0.1",
    port: Number.parseInt(process.env.ZED_MOB_PORT || "8787", 10),
    token: process.env.ZED_MOB_TOKEN || "",
    projectsConfigPath: process.env.ZED_MOB_PROJECTS || DEFAULT_CONFIG_PATH,
    projectsRoot: path.resolve(process.env.ZED_MOB_PROJECTS_ROOT || DEFAULT_PROJECTS_ROOT)
  };
}

export async function loadProjects(configPath = serverConfig().projectsConfigPath) {
  const parsed = await readProjectsConfig(configPath);
  return parsed.projects.map(normalizeProject);
}

export async function saveProjects(projects, configPath = serverConfig().projectsConfigPath) {
  const normalized = projects.map(normalizeProject);
  const file = path.resolve(configPath);
  await fs.mkdir(path.dirname(file), { recursive: true });
  const tempFile = `${file}.${process.pid}.${Date.now()}.tmp`;
  await fs.writeFile(tempFile, `${JSON.stringify({ projects: normalized }, null, 2)}\n`, {
    mode: 0o600
  });
  await fs.rename(tempFile, file);
  return normalized;
}

export async function addProject(project, configPath = serverConfig().projectsConfigPath) {
  const current = await loadProjects(configPath);
  const normalized = normalizeProject(project);
  const existing = current.find((item) => path.resolve(item.path) === normalized.path);
  if (existing) {
    return { project: existing, projects: current, added: false };
  }

  normalized.id = uniqueProjectId(normalized.id, current);
  const projects = await saveProjects([normalized, ...current], configPath);
  return { project: normalized, projects, added: true };
}

export async function createProject({ name, root = serverConfig().projectsRoot } = {}) {
  const projectName = String(name || "").trim();
  const folderName = safeFolderName(projectName);
  const projectsRoot = path.resolve(root);
  const projectPath = path.resolve(projectsRoot, folderName);
  const relative = path.relative(projectsRoot, projectPath);
  if (relative === "" || relative.startsWith("..") || path.isAbsolute(relative)) {
    throw new Error("project_path_outside_root");
  }

  await fs.mkdir(projectPath, { recursive: true });
  const result = await addProject(projectForPath(projectPath, projectName || folderName));
  return {
    ...result,
    projectsRoot
  };
}

export function projectForPath(projectPath, name = "") {
  const resolvedPath = path.resolve(projectPath);
  const projectName = String(name || path.basename(resolvedPath));
  return normalizeProject({
    id: projectId(projectName, resolvedPath),
    name: projectName,
    path: resolvedPath,
    contextHubCategory: contextHubCategory(projectName, resolvedPath)
  });
}

export function publicProject(project) {
  return {
    id: project.id,
    name: project.name,
    path: project.path,
    contextHubCategory: project.contextHubCategory
  };
}

export async function findProject(projectId) {
  const projects = await loadProjects();
  return projects.find((project) => project.id === projectId) || null;
}

export function contextHubCategory(name, projectPath = "") {
  return `project-${projectId(name, projectPath)}`;
}

export function projectId(name, projectPath = "") {
  const value = slug(name);
  if (value) {
    return value;
  }
  return `project-${hashPath(projectPath).slice(0, 10)}`;
}

export function slug(value) {
  return String(value)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

async function readProjectsConfig(configPath) {
  let raw;
  try {
    raw = await fs.readFile(configPath, "utf8");
  } catch (error) {
    if (error.code === "ENOENT") {
      return { projects: [] };
    }
    throw error;
  }
  const parsed = JSON.parse(raw);
  return {
    projects: Array.isArray(parsed.projects) ? parsed.projects : []
  };
}

function normalizeProject(project) {
  const resolvedPath = path.resolve(project.path);
  const name = String(project.name || path.basename(resolvedPath));
  const id = String(project.id || projectId(name, resolvedPath));
  return {
    id,
    name,
    path: resolvedPath,
    contextHubCategory: project.contextHubCategory
      ? String(project.contextHubCategory)
      : contextHubCategory(name, resolvedPath)
  };
}

function uniqueProjectId(baseId, projects) {
  const existingIds = new Set(projects.map((project) => project.id));
  if (!existingIds.has(baseId)) {
    return baseId;
  }
  for (let index = 2; index < 1000; index += 1) {
    const candidate = `${baseId}-${index}`;
    if (!existingIds.has(candidate)) {
      return candidate;
    }
  }
  return `${baseId}-${Date.now()}`;
}

function safeFolderName(value) {
  const folderName = String(value || "").trim().replace(/[/:\\\0]/g, " ").replace(/\s+/g, " ");
  if (!folderName || folderName === "." || folderName === "..") {
    throw new Error("invalid_project_name");
  }
  if (folderName.length > 90) {
    throw new Error("project_name_too_long");
  }
  return folderName;
}

function hashPath(value) {
  return crypto.createHash("sha1").update(String(value || "")).digest("hex");
}
