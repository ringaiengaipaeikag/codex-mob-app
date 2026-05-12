#!/usr/bin/env python3
"""Run a local BAZA health check without printing secrets."""

import argparse
import json
import re
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path


GLOBAL_SOURCE = Path.home() / ".codex" / "baza"

REQUIRED_FILES = [
    "AGENTS.md",
    "docs/status.md",
    "docs/agents/baza.md",
    ".codex/config.toml",
    "Makefile",
    "plugins/baza/baza-manifest.toml",
    "plugins/baza/docs/orchestration-policy.md",
    "plugins/baza/docs/best-practices-policy.md",
    "plugins/baza/docs/capture-evidence-graph.md",
    "plugins/baza/docs/js-runtime-analysis.md",
    "plugins/baza/docs/vector-memory-policy.md",
    "plugins/baza/docs/web-protection-analysis.md",
    "plugins/baza/docs/tls-fingerprint-tooling.md",
    "plugins/baza/docs/official-sources.md",
    "plugins/baza/docs/source-dossiers/web-protection-providers.md",
    "plugins/baza/docs/source-dossiers/tls-fingerprint-tooling.md",
    "plugins/baza/docs/source-dossiers/openai-codex.md",
    "plugins/baza/docs/source-dossiers/zed.md",
    "plugins/baza/docs/source-dossiers/zed-codex-acp.md",
    "plugins/baza/docs/source-dossiers/playwright.md",
    "plugins/baza/docs/source-dossiers/mitmproxy.md",
    "plugins/baza/scripts/baza_refresh_projection.py",
    "plugins/baza/scripts/baza_doctor.py",
    "plugins/baza/scripts/baza_docs_sync.py",
    "plugins/baza/scripts/baza_docs_health.py",
    "plugins/baza/scripts/baza_docs_vector_sync.py",
    "plugins/baza/scripts/baza_docs_search.py",
    "plugins/baza/scripts/context_hub_import_project_docs.js",
    "plugins/baza/scripts/context_hub_maintenance.js",
    "plugins/baza/scripts/baza_check_official_sources.py",
    "plugins/baza/scripts/web_capture/analyze_coverage.py",
    "plugins/baza/skills/baza-official-docs/SKILL.md",
    "plugins/baza/skills/baza-source-dossier/SKILL.md",
    "plugins/baza/skills/baza-docs-search/SKILL.md",
    "plugins/baza/skills/baza-bootstrap/SKILL.md",
    "plugins/baza/skills/baza-docs-sync/SKILL.md",
    "plugins/baza/skills/baza-orchestration/SKILL.md",
    "plugins/baza/skills/web-traffic-capture/SKILL.md",
    "plugins/baza/skills/http-traffic-analysis/SKILL.md",
    "plugins/baza/skills/js-runtime-analysis/SKILL.md",
    "plugins/baza/skills/js-coverage-analysis/SKILL.md",
    "plugins/baza/skills/tls-fingerprint-research/SKILL.md",
    "plugins/baza/skills/tls-fingerprint/SKILL.md",
    "plugins/baza/skills/captcha-protection-analysis/SKILL.md",
    "plugins/baza/skills/bot-detection-analysis/SKILL.md",
    "plugins/baza/skills/cloudflare-analysis/SKILL.md",
    "plugins/baza/skills/datadome-analysis/SKILL.md",
    "plugins/baza/skills/trustev-fingerprint/SKILL.md",
    "plugins/baza/skills/akamai-bypass/SKILL.md",
    "plugins/baza/skills/recaptcha-solve/SKILL.md",
    "plugins/baza/skills/tps-browser-harvester/SKILL.md",
    "plugins/baza/upstreams/registry.toml",
    "plugins/baza/official-sources/registry.toml",
]

SOURCE_REQUIRED_FILES = [
    "baza-manifest.toml",
    ".codex-plugin/plugin.json",
    "docs/status.md",
    "docs/official-sources.md",
    "docs/project-profiles.md",
    "docs/source-dossiers/openai-codex.md",
    "docs/source-dossiers/zed.md",
    "docs/source-dossiers/zed-codex-acp.md",
    "docs/source-dossiers/playwright.md",
    "docs/source-dossiers/mitmproxy.md",
    "docs/source-dossiers/tls-fingerprint-tooling.md",
    "docs/source-dossiers/web-protection-providers.md",
    "docs/orchestration-policy.md",
    "docs/best-practices-policy.md",
    "docs/capture-evidence-graph.md",
    "docs/js-runtime-analysis.md",
    "docs/vector-memory-policy.md",
    "docs/web-protection-analysis.md",
    "docs/tls-fingerprint-tooling.md",
    "skills/baza-official-docs/SKILL.md",
    "skills/baza-source-dossier/SKILL.md",
    "skills/baza-docs-search/SKILL.md",
    "skills/baza-bootstrap/SKILL.md",
    "skills/baza-docs-sync/SKILL.md",
    "skills/baza-orchestration/SKILL.md",
    "skills/web-traffic-capture/SKILL.md",
    "skills/http-traffic-analysis/SKILL.md",
    "skills/js-runtime-analysis/SKILL.md",
    "skills/js-coverage-analysis/SKILL.md",
    "skills/tls-fingerprint-research/SKILL.md",
    "skills/tls-fingerprint/SKILL.md",
    "skills/captcha-protection-analysis/SKILL.md",
    "skills/bot-detection-analysis/SKILL.md",
    "skills/cloudflare-analysis/SKILL.md",
    "skills/datadome-analysis/SKILL.md",
    "skills/trustev-fingerprint/SKILL.md",
    "skills/akamai-bypass/SKILL.md",
    "skills/recaptcha-solve/SKILL.md",
    "skills/tps-browser-harvester/SKILL.md",
    "scripts/baza_init.py",
    "scripts/baza_refresh_projection.py",
    "scripts/baza_doctor.py",
    "scripts/baza_docs_sync.py",
    "scripts/baza_docs_health.py",
    "scripts/baza_docs_vector_sync.py",
    "scripts/baza_docs_search.py",
    "scripts/context_hub_import_project_docs.js",
    "scripts/context_hub_maintenance.js",
    "scripts/baza_check_official_sources.py",
    "scripts/web_capture/analyze_scripts.py",
    "scripts/web_capture/analyze_coverage.py",
    "scripts/web_capture/build_evidence_graph.py",
    "scripts/web_capture/diff_capture_runs.py",
    "scripts/web_capture/record_playwright_cdp.mjs",
    "scripts/web_capture/summarize_capture.py",
    "scripts/web_capture/verify_artifacts.py",
    "scripts/web_capture/js_runtime_observer.js",
    "upstreams/registry.toml",
    "official-sources/registry.toml",
    "profiles/generic.toml",
]

MAKE_TARGETS = [
    "baza-doctor",
    "baza-audit",
    "baza-docs-sync",
    "baza-register-module",
    "baza-docs-vector-sync",
    "baza-docs-search",
    "baza-docs-index",
    "baza-docs-health",
    "baza-docs-maintenance",
    "baza-check-upstreams",
    "baza-check-official-sources",
    "baza-refresh-projection",
]

PROJECTION_KEY_FILES = [
    "baza-manifest.toml",
    "docs/best-practices-policy.md",
    "docs/capture-evidence-graph.md",
    "docs/js-runtime-analysis.md",
    "docs/vector-memory-policy.md",
    "docs/web-protection-analysis.md",
    "docs/tls-fingerprint-tooling.md",
    "docs/official-sources.md",
    "docs/source-dossiers/tls-fingerprint-tooling.md",
    "docs/source-dossiers/web-protection-providers.md",
    "docs/source-dossiers/openai-codex.md",
    "docs/source-dossiers/zed.md",
    "docs/source-dossiers/zed-codex-acp.md",
    "docs/source-dossiers/playwright.md",
    "docs/source-dossiers/mitmproxy.md",
    "official-sources/registry.toml",
    "scripts/baza_doctor.py",
    "scripts/baza_docs_sync.py",
    "scripts/baza_docs_health.py",
    "scripts/baza_docs_vector_sync.py",
    "scripts/baza_docs_search.py",
    "scripts/context_hub_import_project_docs.js",
    "scripts/context_hub_maintenance.js",
    "scripts/baza_check_official_sources.py",
    "scripts/baza_refresh_projection.py",
    "scripts/web_capture/analyze_scripts.py",
    "scripts/web_capture/analyze_coverage.py",
    "scripts/web_capture/build_evidence_graph.py",
    "scripts/web_capture/diff_capture_runs.py",
    "scripts/web_capture/record_playwright_cdp.mjs",
    "scripts/web_capture/summarize_capture.py",
    "scripts/web_capture/verify_artifacts.py",
    "scripts/web_capture/js_runtime_observer.js",
    "skills/baza-official-docs/SKILL.md",
    "skills/baza-source-dossier/SKILL.md",
    "skills/baza-docs-search/SKILL.md",
    "skills/baza-bootstrap/SKILL.md",
    "skills/baza-docs-sync/SKILL.md",
    "skills/baza-orchestration/SKILL.md",
    "skills/web-traffic-capture/SKILL.md",
    "skills/http-traffic-analysis/SKILL.md",
    "skills/js-runtime-analysis/SKILL.md",
    "skills/js-coverage-analysis/SKILL.md",
    "skills/tls-fingerprint-research/SKILL.md",
    "skills/tls-fingerprint/SKILL.md",
    "skills/captcha-protection-analysis/SKILL.md",
    "skills/bot-detection-analysis/SKILL.md",
    "skills/cloudflare-analysis/SKILL.md",
    "skills/datadome-analysis/SKILL.md",
    "skills/trustev-fingerprint/SKILL.md",
    "skills/akamai-bypass/SKILL.md",
    "skills/recaptcha-solve/SKILL.md",
    "skills/tps-browser-harvester/SKILL.md",
    "upstreams/registry.toml",
]

BAZA_SKILL_PATHS = [
    "../plugins/baza/skills/baza-official-docs",
    "../plugins/baza/skills/baza-source-dossier",
    "../plugins/baza/skills/baza-docs-search",
    "../plugins/baza/skills/baza-bootstrap",
    "../plugins/baza/skills/baza-docs-sync",
    "../plugins/baza/skills/baza-orchestration",
    "../plugins/baza/skills/web-traffic-capture",
    "../plugins/baza/skills/http-traffic-analysis",
    "../plugins/baza/skills/js-runtime-analysis",
    "../plugins/baza/skills/js-coverage-analysis",
    "../plugins/baza/skills/tls-fingerprint-research",
    "../plugins/baza/skills/tls-fingerprint",
    "../plugins/baza/skills/captcha-protection-analysis",
    "../plugins/baza/skills/bot-detection-analysis",
    "../plugins/baza/skills/cloudflare-analysis",
    "../plugins/baza/skills/datadome-analysis",
    "../plugins/baza/skills/trustev-fingerprint",
    "../plugins/baza/skills/akamai-bypass",
    "../plugins/baza/skills/recaptcha-solve",
    "../plugins/baza/skills/tps-browser-harvester",
]


def read_text(path):
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""


def load_toml(path):
    try:
        with path.open("rb") as fh:
            return tomllib.load(fh)
    except FileNotFoundError:
        return {}


def check(name, status, detail):
    return {"name": name, "status": status, "detail": detail}


def find_project_category(status_text):
    matches = re.findall(r"\bproject-[a-z0-9][a-z0-9-]*\b", status_text)
    matches = [item for item in matches if item not in {"project-bootstrap"}]
    return matches[-1] if matches else ""


def is_source_root(root):
    return (root / "baza-manifest.toml").exists() and (root / "scripts/baza_init.py").exists()


def command_available(*names):
    for name in names:
        path = shutil.which(name)
        if path:
            return path
    return ""


def app_exists(*paths):
    for item in paths:
        path = Path(item)
        if path.exists():
            return str(path)
    return ""


def node_has_playwright(root):
    if not command_available("node"):
        return False
    try:
        result = subprocess.run(
            ["node", "-e", "require.resolve('playwright')"],
            cwd=root,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return result.returncode == 0


def compare_projection(root):
    dst = root / "plugins" / "baza"
    if not dst.exists():
        return [check("projection", "fail", "plugins/baza is missing")]
    if dst.resolve() == GLOBAL_SOURCE.resolve():
        return [check("projection", "ok", "running against global BAZA source")]
    if not GLOBAL_SOURCE.exists():
        return [check("projection", "skip", "global BAZA source is not available")]

    results = []
    for rel in PROJECTION_KEY_FILES:
        src_file = GLOBAL_SOURCE / rel
        dst_file = dst / rel
        if not dst_file.exists():
            results.append(check(f"projection:{rel}", "fail", "missing from project projection"))
            continue
        if not src_file.exists():
            results.append(check(f"projection:{rel}", "skip", "missing from global source"))
            continue
        if src_file.read_bytes() != dst_file.read_bytes():
            results.append(check(f"projection:{rel}", "warn", "differs from global source; run make baza-refresh-projection"))
        else:
            results.append(check(f"projection:{rel}", "ok", "matches global source"))
    return results


def run(root):
    checks = []

    if not root.exists() or not root.is_dir():
        return [check("project-root", "fail", f"not a directory: {root}")]

    source_mode = is_source_root(root)
    required_files = SOURCE_REQUIRED_FILES if source_mode else REQUIRED_FILES

    checks.append(check(
        "mode",
        "ok",
        "global BAZA source" if source_mode else "project BAZA projection",
    ))

    for rel in required_files:
        status = "ok" if (root / rel).exists() else "fail"
        detail = "present" if status == "ok" else "missing"
        checks.append(check(f"file:{rel}", status, detail))

    status_text = read_text(root / "docs/status.md")
    category = find_project_category(status_text)
    checks.append(check("context-hub-category", "ok" if category else "fail", category or "missing"))

    if not source_mode:
        agents_text = read_text(root / "AGENTS.md")
        if "BAZA Best Practices Rule" in agents_text:
            checks.append(check("agents:best-practices-rule", "ok", "present"))
        else:
            checks.append(check("agents:best-practices-rule", "warn", "missing BAZA Best Practices Rule"))

    manifest_path = root / "baza-manifest.toml" if source_mode else root / "plugins/baza/baza-manifest.toml"
    manifest = load_toml(manifest_path)
    checks.append(check("baza-version", "ok" if manifest.get("version") else "warn", str(manifest.get("version", "unknown"))))

    if source_mode:
        checks.append(check("projection", "ok", "global source; no project projection required"))
        checks.append(check("projection-metadata", "skip", "not required for global source"))
    else:
        projection_meta = root / "plugins/baza/.baza-projection.json"
        if projection_meta.exists():
            try:
                json.loads(read_text(projection_meta))
                checks.append(check("projection-metadata", "ok", str(projection_meta)))
            except json.JSONDecodeError as exc:
                checks.append(check("projection-metadata", "warn", f"invalid JSON: {exc}"))
        else:
            checks.append(check("projection-metadata", "warn", "missing; run make baza-refresh-projection"))

        checks.extend(compare_projection(root))

    if source_mode:
        checks.append(check("make-targets", "skip", "not required for global source"))
    else:
        makefile = read_text(root / "Makefile")
        for target in MAKE_TARGETS:
            status = "ok" if f"{target}:" in makefile else "warn"
            detail = "present" if status == "ok" else "missing"
            checks.append(check(f"make:{target}", status, detail))

        codex_config = read_text(root / ".codex/config.toml")
        if "BAZA skills" in codex_config and "baza-official-docs" in codex_config:
            checks.append(check("codex-config:baza-skills", "ok", "BAZA skills configured"))
        else:
            checks.append(check("codex-config:baza-skills", "warn", "missing BAZA skills block"))
        config_dir = root / ".codex"
        for rel in BAZA_SKILL_PATHS:
            skill_file = (config_dir / rel / "SKILL.md").resolve()
            checks.append(check(
                f"codex-config:skill-path:{rel}",
                "ok" if skill_file.exists() else "warn",
                "resolves to SKILL.md" if skill_file.exists() else f"missing {skill_file}",
            ))

    if source_mode:
        checks.append(check("gitignore:web-capture", "skip", "project gitignore is checked in projections"))
    else:
        gitignore = read_text(root / ".gitignore")
        if "BAZA web traffic capture artifacts" in gitignore:
            checks.append(check("gitignore:web-capture", "ok", "raw capture artifacts are ignored"))
        else:
            checks.append(check("gitignore:web-capture", "warn", "missing BAZA web capture ignore block"))
        if ".baza/docs-vector/" in gitignore:
            checks.append(check("gitignore:docs-vector", "ok", "generated docs vector index is ignored"))
        else:
            checks.append(check("gitignore:docs-vector", "warn", "missing .baza/docs-vector/ ignore rule"))

        vector_index = root / ".baza" / "docs-vector" / category / "index.json"
        if vector_index.exists():
            try:
                parsed = json.loads(read_text(vector_index))
                chunk_count = parsed.get("chunk_count", 0)
                checks.append(check("docs-vector:index", "ok", f"{chunk_count} chunks at {vector_index}"))
            except json.JSONDecodeError as exc:
                checks.append(check("docs-vector:index", "warn", f"invalid JSON: {exc}"))
        else:
            checks.append(check("docs-vector:index", "warn", "missing; run make baza-docs-vector-sync"))

    tools = {
        "python3": command_available("python3"),
        "git": command_available("git"),
        "node": command_available("node"),
        "npx": command_available("npx"),
        "mongosh": command_available("mongosh"),
        "codex": command_available("codex"),
        "zed": command_available("zed"),
        "mitmdump": command_available("mitmdump"),
        "tshark": command_available("tshark"),
    }
    for name, path in tools.items():
        status = "ok" if path else "warn"
        if name in {"python3", "git"} and not path:
            status = "fail"
        checks.append(check(f"tool:{name}", status, path or "not found"))

    chrome = command_available("google-chrome", "chromium", "chrome", "msedge") or app_exists(
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
        "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
    )
    checks.append(check("tool:browser", "ok" if chrome else "warn", chrome or "Chrome/Chromium/Edge not found"))

    playwright_available = node_has_playwright(root)
    checks.append(check(
        "node-module:playwright",
        "ok" if playwright_available else "warn",
        "available" if playwright_available else "not resolvable from project root",
    ))

    return checks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="project root")
    parser.add_argument("--json", action="store_true", help="print JSON result")
    parser.add_argument("--strict", action="store_true", help="treat warnings as failures")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    checks = run(root)
    failures = [item for item in checks if item["status"] == "fail"]
    warnings = [item for item in checks if item["status"] == "warn"]
    ok = not failures and not (args.strict and warnings)

    if args.json:
        print(json.dumps({
            "ok": ok,
            "root": str(root),
            "failures": failures,
            "warnings": warnings,
            "checks": checks,
        }, indent=2))
    else:
        print(f"BAZA doctor root: {root}")
        for item in checks:
            prefix = item["status"].upper()
            print(f"{prefix} {item['name']}: {item['detail']}")
        if ok:
            print("OK BAZA doctor checks completed")

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
