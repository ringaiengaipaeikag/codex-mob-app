#!/usr/bin/env python3
"""Check local dependencies for BAZA web traffic capture."""

import argparse
import json
import platform
import shutil
import subprocess
import sys
from pathlib import Path


MAC_CHROME_PATHS = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
]


def command_version(cmd, args=None):
    args = args or ["--version"]
    path = shutil.which(cmd)
    if not path:
        return {"name": cmd, "found": False, "path": "", "version": ""}
    try:
        proc = subprocess.run(
            [path] + args,
            text=True,
            capture_output=True,
            timeout=10,
            check=False,
        )
        output = (proc.stdout or proc.stderr or "").strip().splitlines()
        version = output[0] if output else ""
    except (OSError, subprocess.SubprocessError) as exc:
        version = f"version unavailable: {exc}"
    return {"name": cmd, "found": True, "path": path, "version": version}


def find_chrome():
    names = [
        "google-chrome",
        "google-chrome-stable",
        "chromium",
        "chromium-browser",
        "msedge",
    ]
    for name in names:
        path = shutil.which(name)
        if path:
            return {"name": "chrome", "found": True, "path": path, "version": command_version(path)["version"]}
    for item in MAC_CHROME_PATHS:
        path = Path(item)
        if path.exists():
            try:
                proc = subprocess.run(
                    [str(path), "--version"],
                    text=True,
                    capture_output=True,
                    timeout=10,
                    check=False,
                )
                version = (proc.stdout or proc.stderr or "").strip()
            except (OSError, subprocess.SubprocessError) as exc:
                version = f"version unavailable: {exc}"
            return {"name": "chrome", "found": True, "path": str(path), "version": version}
    return {"name": "chrome", "found": False, "path": "", "version": ""}


def playwright_module():
    node = shutil.which("node")
    if not node:
        return {"name": "node-playwright-module", "found": False, "version": "", "error": "node missing"}
    script = (
        "try {"
        " const pw = require('playwright');"
        " const pkg = require('playwright/package.json');"
        " console.log(pkg.version || 'installed');"
        "} catch (err) {"
        " console.error(err.message); process.exit(1);"
        "}"
    )
    proc = subprocess.run([node, "-e", script], text=True, capture_output=True, timeout=10, check=False)
    if proc.returncode != 0:
        return {
            "name": "node-playwright-module",
            "found": False,
            "version": "",
            "error": (proc.stderr or proc.stdout or "").strip(),
        }
    return {"name": "node-playwright-module", "found": True, "version": proc.stdout.strip(), "error": ""}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="print JSON")
    parser.add_argument("--strict", action="store_true", help="exit non-zero if live capture dependencies are missing")
    args = parser.parse_args()

    checks = {
        "platform": platform.platform(),
        "python": sys.version.split()[0],
        "node": command_version("node"),
        "npx": command_version("npx"),
        "chrome": find_chrome(),
        "mitmdump": command_version("mitmdump"),
        "tshark": command_version("tshark"),
        "playwright": playwright_module(),
    }

    required = ["node", "chrome", "playwright"]
    missing_required = [name for name in required if not checks[name]["found"]]
    optional_missing = [name for name in ["mitmdump", "tshark"] if not checks[name]["found"]]
    result = {
        "ready_for_live_browser_capture": not missing_required,
        "missing_required": missing_required,
        "missing_optional": optional_missing,
        "checks": checks,
    }

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"ready_for_live_browser_capture: {str(result['ready_for_live_browser_capture']).lower()}")
        for name, item in checks.items():
            if isinstance(item, dict) and "found" in item:
                status = "OK" if item["found"] else "MISSING"
                detail = item.get("version") or item.get("error") or item.get("path") or ""
                print(f"{status} {name}: {detail}")
        if optional_missing:
            print("optional_missing: " + ", ".join(optional_missing))

    if args.strict and missing_required:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
