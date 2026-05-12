import fs from "node:fs/promises";
import path from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { projectRoot } from "./config.js";

const execFileAsync = promisify(execFile);

const REQUIRED_FILES = [
  "AGENTS.md",
  "docs/status.md",
  "docs/agents/baza.md",
  "plugins/baza",
  "Makefile"
];

export async function inspectBaza(project) {
  const files = await Promise.all(
    REQUIRED_FILES.map(async (relativePath) => {
      const absolutePath = path.join(project.path, relativePath);
      try {
        await fs.access(absolutePath);
        return { path: relativePath, ok: true };
      } catch {
        return { path: relativePath, ok: false };
      }
    })
  );

  const missing = files.filter((file) => !file.ok).map((file) => file.path);

  return {
    ok: missing.length === 0,
    missing,
    files,
    contextHubCategory: project.contextHubCategory
  };
}

export async function runBazaPreflight(project, options = {}) {
  const startedAt = new Date().toISOString();
  const inspection = await inspectBaza(project);
  const commands = [];

  commands.push(await runMake(project.path, "baza-doctor"));
  commands.push(await runMake(project.path, "baza-audit"));

  if (options.syncDocs) {
    commands.push(await runMake(project.path, "baza-docs-sync"));
  }

  const commandFailures = commands.filter((command) => command.exitCode !== 0);
  const blocking = !inspection.ok || commandFailures.length > 0;

  return {
    startedAt,
    finishedAt: new Date().toISOString(),
    ok: !blocking,
    blocking,
    inspection,
    commands
  };
}

export async function runBazaAction(project) {
  const startedAt = new Date().toISOString();
  const before = await inspectBaza(project);
  const commands = [];
  const mode = before.ok ? "refresh" : "init";

  if (mode === "init") {
    commands.push(await runBazaInit(project));
  } else {
    commands.push(await runMake(project.path, "baza-refresh-projection"));
  }

  commands.push(await runMake(project.path, "baza-doctor"));
  commands.push(await runMake(project.path, "baza-audit"));
  commands.push(await runMake(project.path, "baza-docs-sync"));

  const after = await inspectBaza(project);
  const commandFailures = commands.filter((command) => command.exitCode !== 0);
  const blocking = !after.ok || commandFailures.length > 0;

  return {
    startedAt,
    finishedAt: new Date().toISOString(),
    mode,
    ok: !blocking,
    blocking,
    before,
    after,
    commands
  };
}

async function runBazaInit(project) {
  const script = path.join(projectRoot(), "plugins", "baza", "scripts", "baza_init.py");
  return runCommand({
    label: "baza-init",
    command: "python3",
    args: [
      script,
      "--root",
      project.path,
      "--name",
      project.name,
      "--category",
      project.contextHubCategory,
      "--profile",
      "mobile-app"
    ],
    cwd: projectRoot(),
    timeout: 120000
  });
}

async function runMake(cwd, target) {
  return runCommand({
    label: target,
    command: "make",
    args: [target],
    cwd,
    timeout: 120000
  });
}

async function runCommand({ label, command, args, cwd, timeout }) {
  const startedAt = new Date().toISOString();
  try {
    const result = await execFileAsync(command, args, {
      cwd,
      timeout,
      maxBuffer: 1024 * 1024 * 4
    });

    return {
      target: label,
      ok: true,
      exitCode: 0,
      startedAt,
      finishedAt: new Date().toISOString(),
      stdout: result.stdout,
      stderr: result.stderr,
      warnings: collectWarnings(result.stdout, result.stderr)
    };
  } catch (error) {
    return {
      target: label,
      ok: false,
      exitCode: typeof error.code === "number" ? error.code : 1,
      startedAt,
      finishedAt: new Date().toISOString(),
      stdout: error.stdout || "",
      stderr: error.stderr || error.message || "",
      warnings: collectWarnings(error.stdout || "", error.stderr || "")
    };
  }
}

function collectWarnings(stdout, stderr) {
  return `${stdout}\n${stderr}`
    .split(/\r?\n/)
    .filter((line) => /\bwarn/i.test(line))
    .slice(0, 50);
}
