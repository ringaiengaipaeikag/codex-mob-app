#!/usr/bin/env python3
"""Verify a BAZA web capture run without printing sensitive artifact content."""

import argparse
import json
import re
import sys
from pathlib import Path


SECRET_PATTERNS = [
    re.compile(r"(?i)bearer\s+[A-Za-z0-9._+/=-]{12,}"),
    re.compile(r"(?i)authorization\s*[:=]\s*[A-Za-z0-9._+/=-]{12,}"),
    re.compile(r"(?i)api[-_]?key\s*[:=]\s*[A-Za-z0-9._+/=-]{12,}"),
    re.compile(r"\b\d{3}-\d{2}-\d{4}\b"),
]


def read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError) as exc:
        return {"_error": str(exc)}


def has_lines(path):
    try:
        return any(line.strip() for line in path.read_text(encoding="utf-8", errors="replace").splitlines())
    except FileNotFoundError:
        return False


def contains_secret_like(path):
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return False
    return any(pattern.search(text) for pattern in SECRET_PATTERNS)


def verify(run_dir, require_summary=False, allow_dry_run=False):
    failures = []
    warnings = []
    manifest_path = run_dir / "manifest.json"
    if not manifest_path.exists():
        failures.append("missing manifest.json")
        manifest = {}
    else:
        manifest = read_json(manifest_path)
        if "_error" in manifest:
            failures.append("manifest.json is not valid JSON")
        if manifest.get("authorization_confirmed") is not True:
            warnings.append("manifest does not explicitly mark authorization_confirmed=true")

    evidence_files = [
        "playwright-trace.zip",
        "network.har",
        "network.har.zip",
        "cdp-events.ndjson",
        "requests.ndjson",
        "responses.ndjson",
        "workers.ndjson",
        "js-runtime-events.json",
        "js-coverage.json",
        "endpoint-map.json",
        "timeline.ndjson",
        "evidence-graph.json",
        "initiators.json",
        "storage-summary.json",
        "anti-abuse-observations.md",
    ]
    present = [name for name in evidence_files if (run_dir / name).exists()]
    dry_run_ok = (
        allow_dry_run
        and manifest.get("status") == "dry-run"
        and (run_dir / "capture-plan.json").exists()
        and not require_summary
    )
    if not present and not dry_run_ok:
        failures.append("no capture evidence files found")

    for name in ["requests.ndjson", "responses.ndjson", "cdp-events.ndjson", "timeline.ndjson", "workers.ndjson"]:
        path = run_dir / name
        if path.exists() and not has_lines(path):
            warnings.append(f"{name} exists but has no events")

    summary_path = run_dir / "redacted-summary.md"
    if require_summary and not summary_path.exists():
        failures.append("missing redacted-summary.md")
    if summary_path.exists() and contains_secret_like(summary_path):
        failures.append("redacted-summary.md contains secret-like content")

    endpoint_map = run_dir / "endpoint-map.json"
    if require_summary and not endpoint_map.exists():
        failures.append("missing endpoint-map.json")
    if endpoint_map.exists():
        parsed = read_json(endpoint_map)
        if "_error" in parsed:
            failures.append("endpoint-map.json is not valid JSON")

    js_runtime = run_dir / "js-runtime-events.json"
    if js_runtime.exists():
        parsed = read_json(js_runtime)
        if "_error" in parsed:
            failures.append("js-runtime-events.json is not valid JSON")
        elif not isinstance(parsed, list):
            warnings.append("js-runtime-events.json is not a JSON array")

    for name in [
        "evidence-graph.json",
        "initiators.json",
        "storage-summary.json",
        "script-analysis.json",
        "js-coverage.json",
        "js-coverage-analysis.json",
        "capture-diff.json",
    ]:
        path = run_dir / name
        if path.exists() and "_error" in read_json(path):
            failures.append(f"{name} is not valid JSON")

    return {
        "ok": not failures,
        "run_dir": str(run_dir),
        "manifest_status": manifest.get("status", ""),
        "present_evidence": present,
        "dry_run_ok": dry_run_ok,
        "failures": failures,
        "warnings": warnings,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_dir", help="capture run directory")
    parser.add_argument("--require-summary", action="store_true", help="require redacted-summary.md and endpoint-map.json")
    parser.add_argument("--allow-dry-run", action="store_true", help="accept manifest status dry-run with capture-plan.json")
    parser.add_argument("--json", action="store_true", help="print JSON")
    args = parser.parse_args()

    run_dir = Path(args.run_dir).expanduser().resolve()
    if not run_dir.is_dir():
        print(f"FAIL run_dir is not a directory: {run_dir}")
        return 2
    result = verify(run_dir, args.require_summary, args.allow_dry_run)
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"ok: {str(result['ok']).lower()}")
        print(f"manifest_status: {result['manifest_status'] or 'unknown'}")
        print("present_evidence: " + (", ".join(result["present_evidence"]) or "none"))
        for item in result["failures"]:
            print(f"FAIL {item}")
        for item in result["warnings"]:
            print(f"WARN {item}")
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
