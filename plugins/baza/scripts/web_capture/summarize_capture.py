#!/usr/bin/env python3
"""Generate redacted endpoint and timeline summaries for a BAZA web capture run."""

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from urllib.parse import urlparse


SENSITIVE_KEY_RE = re.compile(r"(authorization|cookie|set-cookie|token|secret|password|passwd|api[-_]?key|csrf|session)", re.I)


def read_json(path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def read_ndjson(path):
    rows = []
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except FileNotFoundError:
        return rows
    for line in lines:
        if not line.strip():
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            rows.append({"ts": "", "source": "raw", "event": "unparseable", "text": "[UNPARSEABLE]"})
    return rows


def redact(value):
    if isinstance(value, dict):
        out = {}
        for key, item in value.items():
            key_text = str(key)
            sensitive = SENSITIVE_KEY_RE.search(key_text) and key_text not in {"authorization_confirmed"}
            out[key] = "[REDACTED]" if sensitive else redact(item)
        return out
    if isinstance(value, list):
        return [redact(item) for item in value]
    if isinstance(value, str):
        value = re.sub(r"(?i)bearer\s+[A-Za-z0-9._+/=-]{12,}", "Bearer [REDACTED]", value)
        value = re.sub(r"\b\d{3}-\d{2}-\d{4}\b", "[REDACTED-SSN]", value)
    return value


def safe_url(raw):
    parsed = urlparse(raw or "")
    if not parsed.scheme or not parsed.netloc:
        return {"origin": "", "path": raw or "", "redacted_url": raw or ""}
    path = parsed.path or "/"
    origin = f"{parsed.scheme}://{parsed.netloc}"
    redacted_url = f"{origin}{path}"
    if parsed.query:
        redacted_url += "?[REDACTED_QUERY]"
    return {"origin": origin, "path": path, "redacted_url": redacted_url}


def endpoint_key(method, url, status=""):
    safe = safe_url(url)
    return method or "GET", safe["origin"], safe["path"], str(status or "")


def request_from_cdp(row):
    params = row.get("params") or {}
    request = params.get("request") or {}
    return {
        "ts": row.get("ts", ""),
        "source": "cdp",
        "event": "request",
        "url": request.get("url", ""),
        "method": request.get("method", ""),
        "resourceType": params.get("type", ""),
    }


def response_from_cdp(row):
    params = row.get("params") or {}
    response = params.get("response") or {}
    return {
        "ts": row.get("ts", ""),
        "source": "cdp",
        "event": "response",
        "url": response.get("url", ""),
        "status": response.get("status", ""),
        "statusText": response.get("statusText", ""),
    }


def summarize(run_dir):
    manifest = read_json(run_dir / "manifest.json", {})
    requests = read_ndjson(run_dir / "requests.ndjson")
    responses = read_ndjson(run_dir / "responses.ndjson")
    cdp = read_ndjson(run_dir / "cdp-events.ndjson")
    console_rows = read_ndjson(run_dir / "console.ndjson")
    exceptions = read_ndjson(run_dir / "runtime-exceptions.ndjson")
    scripts = read_ndjson(run_dir / "scripts.ndjson")
    workers = read_ndjson(run_dir / "workers.ndjson")
    js_runtime = read_json(run_dir / "js-runtime-events.json", [])
    js_coverage = read_json(run_dir / "js-coverage.json", {})
    if not isinstance(js_runtime, list):
        js_runtime = []
    if isinstance(js_coverage, list):
        js_coverage_scripts = js_coverage
    elif isinstance(js_coverage, dict) and isinstance(js_coverage.get("result"), list):
        js_coverage_scripts = js_coverage["result"]
    else:
        js_coverage_scripts = []

    for row in cdp:
        method = row.get("method")
        if method == "Network.requestWillBeSent":
            requests.append(request_from_cdp(row))
        elif method == "Network.responseReceived":
            responses.append(response_from_cdp(row))

    response_status = {}
    for row in responses:
        url = row.get("url", "")
        if url:
            response_status[url] = row.get("status", "")

    endpoints = defaultdict(lambda: {"count": 0, "resource_types": set(), "examples": []})
    for row in requests:
        url = row.get("url", "")
        status = response_status.get(url, "")
        method, origin, path, status_text = endpoint_key(row.get("method", ""), url, status)
        item = endpoints[(method, origin, path, status_text)]
        item["count"] += 1
        if row.get("resourceType"):
            item["resource_types"].add(row.get("resourceType"))
        if len(item["examples"]) < 3:
            item["examples"].append(safe_url(url)["redacted_url"])

    endpoint_map = []
    for (method, origin, path, status), item in sorted(endpoints.items()):
        endpoint_map.append({
            "method": method,
            "origin": origin,
            "path": path,
            "status": status,
            "count": item["count"],
            "resource_types": sorted(item["resource_types"]),
            "examples": item["examples"],
        })

    timeline = []
    for label, rows in [
        ("request", requests),
        ("response", responses),
        ("console", console_rows),
        ("runtime-exception", exceptions),
        ("script", scripts),
        ("worker", workers),
        ("js-runtime", js_runtime),
    ]:
        for row in rows:
            redacted = redact(row)
            redacted.setdefault("event", label)
            timeline.append(redacted)
    timeline.sort(key=lambda item: item.get("ts", ""))

    js_runtime_types = defaultdict(int)
    for row in js_runtime:
        js_runtime_types[str(row.get("type", "unknown"))] += 1

    summary = {
        "manifest": redact(manifest),
        "counts": {
            "requests": len(requests),
            "responses": len(responses),
            "console": len(console_rows),
            "runtime_exceptions": len(exceptions),
            "scripts": len(scripts),
            "workers": len(workers),
            "js_runtime_events": len(js_runtime),
            "js_coverage_scripts": len(js_coverage_scripts),
            "endpoints": len(endpoint_map),
        },
        "endpoints": endpoint_map,
        "js_runtime_event_types": dict(sorted(js_runtime_types.items())),
    }
    return summary, timeline


def write_outputs(run_dir, summary, timeline):
    (run_dir / "endpoint-map.json").write_text(json.dumps(summary["endpoints"], indent=2), encoding="utf-8")
    with (run_dir / "timeline.ndjson").open("w", encoding="utf-8") as fh:
        for row in timeline:
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")

    lines = [
        "# Web Capture Redacted Summary",
        "",
        f"- Run id: `{summary['manifest'].get('run_id', 'unknown')}`",
        f"- Target origin: `{summary['manifest'].get('target_origin', 'unknown')}`",
        f"- Action: `{summary['manifest'].get('action_label', 'unknown')}`",
        f"- Capture depth: `{summary['manifest'].get('capture_depth', 'unknown')}`",
        f"- Requests: {summary['counts']['requests']}",
        f"- Responses: {summary['counts']['responses']}",
        f"- Console events: {summary['counts']['console']}",
        f"- Runtime exceptions: {summary['counts']['runtime_exceptions']}",
        f"- Scripts observed: {summary['counts']['scripts']}",
        f"- Worker targets observed: {summary['counts']['workers']}",
        f"- JS runtime observer events: {summary['counts']['js_runtime_events']}",
        f"- JS coverage scripts: {summary['counts']['js_coverage_scripts']}",
        "",
        "## Endpoints",
        "",
    ]
    if summary["endpoints"]:
        for item in summary["endpoints"]:
            status = f" -> {item['status']}" if item.get("status") else ""
            lines.append(f"- `{item['method']} {item['origin']}{item['path']}`{status} ({item['count']} observed)")
    else:
        lines.append("- No endpoint data available.")
    lines.extend([
        "",
        "## JS Runtime Signals",
        "",
    ])
    if summary["js_runtime_event_types"]:
        for event_type, count in summary["js_runtime_event_types"].items():
            lines.append(f"- `{event_type}`: {count}")
    else:
        lines.append("- No JS runtime observer events available.")
    lines.extend([
        "",
        "## Redaction",
        "",
        "This summary omits cookies, authorization headers, tokens, request bodies, response bodies, and query parameter values.",
        "",
    ])
    (run_dir / "redacted-summary.md").write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_dir", help="capture run directory")
    parser.add_argument("--json", action="store_true", help="print JSON summary")
    args = parser.parse_args()

    run_dir = Path(args.run_dir).expanduser().resolve()
    if not run_dir.is_dir():
        print(f"FAIL run_dir is not a directory: {run_dir}")
        return 2
    summary, timeline = summarize(run_dir)
    write_outputs(run_dir, summary, timeline)
    if args.json:
        print(json.dumps(summary, indent=2))
    else:
        print(f"endpoints: {summary['counts']['endpoints']}")
        print(f"timeline_events: {len(timeline)}")
        print(f"summary: {run_dir / 'redacted-summary.md'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
