#!/usr/bin/env python3
"""Build a sanitized evidence graph for a BAZA web capture run."""

import argparse
import hashlib
import json
import re
import sys
from collections import Counter
from collections import defaultdict
from pathlib import Path
from urllib.parse import urlparse


SENSITIVE_KEY_RE = re.compile(
    r"(authorization|cookie|set-cookie|token|secret|password|passwd|api[-_]?key|csrf|session)",
    re.I,
)

PROTECTION_PATTERNS = [
    ("recaptcha", re.compile(r"(recaptcha|grecaptcha|g-recaptcha|google\.com/recaptcha|gstatic\.com/recaptcha)", re.I)),
    ("hcaptcha", re.compile(r"(hcaptcha|h-captcha|js\.hcaptcha\.com|api\.hcaptcha\.com/siteverify)", re.I)),
    ("turnstile", re.compile(r"(turnstile|cf-turnstile|challenges\.cloudflare\.com/turnstile)", re.I)),
    ("cloudflare-challenge", re.compile(r"(cf_clearance|cf_chl|cdn-cgi/challenge-platform|cloudflare)", re.I)),
    ("arkose", re.compile(r"(arkose|funcaptcha|fc-token|arkoselabs|enforcement\.)", re.I)),
    ("datadome", re.compile(r"(datadome|dd_cookie|datadome\.co)", re.I)),
    ("akamai", re.compile(r"(_abck|bm_sz|bm_sv|sensor_data|sec-cpt|akamai|ak_bmsc)", re.I)),
    ("perimeterx", re.compile(r"(perimeterx|px-captcha|_px|pxvid|px3)", re.I)),
    ("aws-waf", re.compile(r"(awswaf|aws-waf|awswaf-token)", re.I)),
    ("kasada", re.compile(r"(kasada|x-kpsdk|kpsdk)", re.I)),
    ("geetest", re.compile(r"(geetest|gt-captcha)", re.I)),
    ("fingerprintjs", re.compile(r"(fingerprintjs|fpjs|visitorid)", re.I)),
]

TOKEN_KEY_RE = re.compile(r"(token|csrf|nonce|challenge|captcha|clearance|session|auth|jwt)", re.I)


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
            rows.append({"ts": "", "source": "raw", "event": "unparseable"})
    return rows


def stable_id(prefix, *parts):
    raw = "\n".join(str(part or "") for part in parts)
    digest = hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]
    return f"{prefix}:{digest}"


def safe_url(raw):
    try:
        parsed = urlparse(raw or "")
    except ValueError:
        return {"origin": "", "path": str(raw or ""), "redacted_url": str(raw or "")}
    if not parsed.scheme or not parsed.netloc:
        return {"origin": "", "path": raw or "", "redacted_url": raw or ""}
    path = parsed.path or "/"
    origin = f"{parsed.scheme}://{parsed.netloc}"
    redacted_url = f"{origin}{path}"
    if parsed.query:
        redacted_url += "?[REDACTED_QUERY]"
    return {"origin": origin, "path": path, "redacted_url": redacted_url}


def redact(value):
    if isinstance(value, dict):
        out = {}
        for key, item in value.items():
            key_text = str(key)
            if SENSITIVE_KEY_RE.search(key_text) and key_text != "authorization_confirmed":
                out[key] = "[REDACTED]"
            else:
                out[key] = redact(item)
        return out
    if isinstance(value, list):
        return [redact(item) for item in value]
    if isinstance(value, str):
        value = re.sub(r"(?i)bearer\s+[A-Za-z0-9._+/=-]{12,}", "Bearer [REDACTED]", value)
        value = re.sub(r"\b\d{3}-\d{2}-\d{4}\b", "[REDACTED-SSN]", value)
    return value


def detect_providers(value):
    text = json.dumps(value, ensure_ascii=False, sort_keys=True) if not isinstance(value, str) else value
    found = []
    for provider, pattern in PROTECTION_PATTERNS:
        if pattern.search(text):
            found.append(provider)
    return found


def first_stack_url(stack):
    if not isinstance(stack, dict):
        return ""
    frames = stack.get("callFrames") or []
    for frame in frames:
        url = frame.get("url") or ""
        if url:
            return url
    parent = stack.get("parent")
    if parent:
        return first_stack_url(parent)
    return ""


def compact_stack(stack, limit=6):
    frames_out = []
    current = stack if isinstance(stack, dict) else {}
    while current and len(frames_out) < limit:
        for frame in current.get("callFrames") or []:
            if len(frames_out) >= limit:
                break
            frames_out.append({
                "url": safe_url(frame.get("url") or "")["redacted_url"],
                "function": frame.get("functionName") or "",
                "line": frame.get("lineNumber"),
                "column": frame.get("columnNumber"),
            })
        current = current.get("parent") or {}
    return frames_out


def endpoint_key(method, url):
    safe = safe_url(url)
    return method or "GET", safe["origin"], safe["path"]


def request_from_cdp(row):
    params = row.get("params") or {}
    request = params.get("request") or {}
    return {
        "ts": row.get("ts", ""),
        "source": "cdp",
        "event": "request",
        "request_id": params.get("requestId", ""),
        "url": request.get("url", ""),
        "method": request.get("method", ""),
        "resourceType": params.get("type", ""),
        "documentURL": params.get("documentURL", ""),
        "initiator": params.get("initiator") or {},
    }


def collect_requests(run_dir):
    playwright_requests = read_ndjson(run_dir / "requests.ndjson")
    cdp = read_ndjson(run_dir / "cdp-events.ndjson")
    cdp_requests = []
    for row in cdp:
        if row.get("method") == "Network.requestWillBeSent":
            cdp_requests.append(request_from_cdp(row))
    cdp_keys = {
        (item.get("method") or "", safe_url(item.get("url") or "")["redacted_url"])
        for item in cdp_requests
    }
    merged = list(cdp_requests)
    for item in playwright_requests:
        key = (item.get("method") or "", safe_url(item.get("url") or "")["redacted_url"])
        if key not in cdp_keys:
            merged.append(item)
    return merged


def collect_responses(run_dir):
    playwright_responses = read_ndjson(run_dir / "responses.ndjson")
    cdp = read_ndjson(run_dir / "cdp-events.ndjson")
    cdp_responses = []
    for row in cdp:
        if row.get("method") == "Network.responseReceived":
            params = row.get("params") or {}
            response = params.get("response") or {}
            cdp_responses.append({
                "ts": row.get("ts", ""),
                "source": "cdp",
                "event": "response",
                "request_id": params.get("requestId", ""),
                "url": response.get("url", ""),
                "status": response.get("status", ""),
                "statusText": response.get("statusText", ""),
            })
    cdp_keys = {
        safe_url(item.get("url") or "")["redacted_url"]
        for item in cdp_responses
    }
    merged = list(cdp_responses)
    for item in playwright_responses:
        key = safe_url(item.get("url") or "")["redacted_url"]
        if key not in cdp_keys:
            merged.append(item)
    return merged


def collect_coverage_scripts(run_dir):
    raw = read_json(run_dir / "js-coverage.json", {})
    if isinstance(raw, list):
        return raw
    if isinstance(raw, dict) and isinstance(raw.get("result"), list):
        return raw["result"]
    return []


def add_node(nodes, node):
    nodes.setdefault(node["id"], node)


def add_edge(edges, source, target, relation, evidence=None):
    if not source or not target or source == target:
        return
    item = {"source": source, "target": target, "relation": relation}
    if evidence:
        item["evidence"] = evidence
    edges.append(item)


def build_graph(run_dir):
    manifest = read_json(run_dir / "manifest.json", {})
    requests = collect_requests(run_dir)
    responses = collect_responses(run_dir)
    scripts = read_ndjson(run_dir / "scripts.ndjson")
    coverage_scripts = collect_coverage_scripts(run_dir)
    js_runtime = read_json(run_dir / "js-runtime-events.json", [])
    workers = read_ndjson(run_dir / "workers.ndjson")
    if not isinstance(js_runtime, list):
        js_runtime = []

    nodes = {}
    edges = []
    detections = defaultdict(lambda: {"count": 0, "evidence": []})

    action_id = stable_id("action", manifest.get("run_id", ""), manifest.get("action_label", ""))
    add_node(nodes, {
        "id": action_id,
        "type": "action",
        "label": manifest.get("action_label") or "web action capture",
        "run_id": manifest.get("run_id", ""),
        "target_origin": manifest.get("target_origin", ""),
    })

    script_by_url = {}
    for row in scripts:
        url = row.get("url") or ""
        safe = safe_url(url)
        label = safe["redacted_url"] or "generated/eval script"
        script_id = stable_id("script", label, row.get("hash", ""), row.get("scriptId", ""))
        script_by_url[url] = script_id
        add_node(nodes, {
            "id": script_id,
            "type": "script",
            "label": label,
            "url": label,
            "hash": row.get("hash", ""),
            "script_id": row.get("scriptId", ""),
        })
        for provider in detect_providers(label):
            provider_id = stable_id("protection", provider)
            add_node(nodes, {"id": provider_id, "type": "protection-provider", "label": provider})
            add_edge(edges, script_id, provider_id, "matches_provider_pattern")
            detections[provider]["count"] += 1
            detections[provider]["evidence"].append({"type": "script", "url": label})

    for row in coverage_scripts:
        url = row.get("url") or ""
        safe = safe_url(url)
        label = safe["redacted_url"] or "generated/eval script"
        if url in script_by_url:
            script_id = script_by_url[url]
        else:
            script_id = stable_id("script", label, row.get("scriptId", ""), "coverage")
            script_by_url[url] = script_id
            add_node(nodes, {
                "id": script_id,
                "type": "script",
                "label": label,
                "url": label,
                "hash": "",
                "script_id": row.get("scriptId", ""),
                "source": "js-coverage",
            })
        for provider in detect_providers(label):
            provider_id = stable_id("protection", provider)
            add_node(nodes, {"id": provider_id, "type": "protection-provider", "label": provider})
            add_edge(edges, script_id, provider_id, "coverage_matches_provider_pattern")
            detections[provider]["count"] += 1
            detections[provider]["evidence"].append({"type": "js-coverage", "url": label})

    response_status_by_url = {}
    for row in responses:
        if row.get("url"):
            response_status_by_url[row.get("url")] = row.get("status", "")

    endpoint_ids = {}
    initiators = []
    for row in requests:
        url = row.get("url") or ""
        method, origin, path = endpoint_key(row.get("method") or "", url)
        endpoint_id = stable_id("endpoint", method, origin, path)
        endpoint_ids[(method, origin, path)] = endpoint_id
        add_node(nodes, {
            "id": endpoint_id,
            "type": "endpoint",
            "label": f"{method} {origin}{path}",
            "method": method,
            "origin": origin,
            "path": path,
            "status": response_status_by_url.get(url, ""),
            "resource_type": row.get("resourceType", ""),
        })
        add_edge(edges, action_id, endpoint_id, "observed_request", {"ts": row.get("ts", "")})
        initiator = row.get("initiator") or {}
        initiator_url = first_stack_url(initiator.get("stack") or {}) or initiator.get("url", "")
        initiator_safe = safe_url(initiator_url)["redacted_url"]
        initiators.append({
            "endpoint": f"{method} {origin}{path}",
            "request_id": row.get("request_id", ""),
            "initiator_type": initiator.get("type", ""),
            "initiator_url": initiator_safe,
            "stack": compact_stack(initiator.get("stack") or {}),
        })
        if initiator_url:
            script_id = script_by_url.get(initiator_url) or stable_id("script", initiator_safe)
            add_node(nodes, {"id": script_id, "type": "script", "label": initiator_safe, "url": initiator_safe})
            add_edge(edges, script_id, endpoint_id, "initiated_request", {"initiator_type": initiator.get("type", "")})
        for provider in detect_providers(url):
            provider_id = stable_id("protection", provider)
            add_node(nodes, {"id": provider_id, "type": "protection-provider", "label": provider})
            add_edge(edges, endpoint_id, provider_id, "matches_provider_pattern")
            detections[provider]["count"] += 1
            detections[provider]["evidence"].append({"type": "endpoint", "endpoint": f"{method} {origin}{path}"})

    storage_summary = defaultdict(lambda: {"writes": 0, "removes": 0, "clears": 0, "token_like": False})
    js_event_types = Counter()
    for index, row in enumerate(js_runtime):
        event_type = str(row.get("type") or "unknown")
        data = row.get("data") if isinstance(row.get("data"), dict) else {}
        js_event_types[event_type] += 1
        event_id = stable_id("js", index, row.get("ts", ""), event_type, json.dumps(redact(data), sort_keys=True))
        add_node(nodes, {
            "id": event_id,
            "type": "js-runtime-event",
            "label": event_type,
            "event_type": event_type,
            "ts": row.get("ts", ""),
            "data": redact(data),
        })
        add_edge(edges, action_id, event_id, "observed_js_runtime_event", {"ts": row.get("ts", "")})
        event_url = data.get("url") or data.get("scriptUrl") or ""
        if event_url:
            safe = safe_url(event_url)
            method = data.get("method") or "GET"
            endpoint_id = stable_id("endpoint", method, safe["origin"], safe["path"])
            if endpoint_id in nodes:
                add_edge(edges, event_id, endpoint_id, "runtime_api_targets_endpoint")
        stack = data.get("stack")
        if isinstance(stack, list) and stack:
            frame_url = stack[0].get("url", "") if isinstance(stack[0], dict) else ""
            if frame_url:
                script_id = script_by_url.get(frame_url) or stable_id("script", safe_url(frame_url)["redacted_url"])
                add_node(nodes, {"id": script_id, "type": "script", "label": safe_url(frame_url)["redacted_url"], "url": safe_url(frame_url)["redacted_url"]})
                add_edge(edges, script_id, event_id, "stack_frame_for_event")
        key = data.get("key") or data.get("name") or data.get("cookie") or data.get("field") or ""
        event_type_lc = event_type.lower()
        if key and ("storage" in event_type_lc or "cookie" in event_type_lc or "formdata" in event_type_lc):
            class_name = "token-like-key" if TOKEN_KEY_RE.search(str(key)) else "state-key"
            storage_id = stable_id("state", class_name, key)
            add_node(nodes, {"id": storage_id, "type": "browser-state", "label": f"{class_name}:{key}", "key": key, "class": class_name})
            add_edge(edges, event_id, storage_id, "mutates_browser_state")
            summary = storage_summary[key]
            summary["token_like"] = summary["token_like"] or class_name == "token-like-key"
            if "clear" in event_type:
                summary["clears"] += 1
            elif "remove" in event_type:
                summary["removes"] += 1
            else:
                summary["writes"] += 1
        for provider in detect_providers(row):
            provider_id = stable_id("protection", provider)
            add_node(nodes, {"id": provider_id, "type": "protection-provider", "label": provider})
            add_edge(edges, event_id, provider_id, "matches_provider_pattern")
            detections[provider]["count"] += 1
            detections[provider]["evidence"].append({"type": "js-runtime-event", "event_type": event_type})

    for row in workers:
        url = row.get("url") or ""
        safe = safe_url(url)
        worker_id = stable_id("worker", row.get("type", ""), safe["redacted_url"], row.get("ts", ""))
        add_node(nodes, {
            "id": worker_id,
            "type": "worker-target",
            "label": f"{row.get('type', 'worker')} {safe['redacted_url']}",
            "url": safe["redacted_url"],
            "target_type": row.get("type", "worker"),
        })
        add_edge(edges, action_id, worker_id, "observed_worker_target")
        for provider in detect_providers(url):
            provider_id = stable_id("protection", provider)
            add_node(nodes, {"id": provider_id, "type": "protection-provider", "label": provider})
            add_edge(edges, worker_id, provider_id, "matches_provider_pattern")
            detections[provider]["count"] += 1
            detections[provider]["evidence"].append({"type": "worker", "url": safe["redacted_url"]})

    graph = {
        "schema": "baza-web-evidence-graph-v1",
        "run_dir": str(run_dir),
        "manifest": redact(manifest),
        "stats": {
            "nodes": len(nodes),
            "edges": len(edges),
            "requests": len(requests),
            "responses": len(responses),
            "scripts": len(scripts),
            "js_runtime_events": len(js_runtime),
            "workers": len(workers),
            "protection_providers": len(detections),
        },
        "js_runtime_event_types": dict(sorted(js_event_types.items())),
        "protection_detections": {
            provider: {
                "count": item["count"],
                "evidence": item["evidence"][:10],
            }
            for provider, item in sorted(detections.items())
        },
        "nodes": sorted(nodes.values(), key=lambda item: (item["type"], item["label"])),
        "edges": edges,
    }

    storage = {
        "schema": "baza-storage-summary-v1",
        "items": [
            {
                "key": key,
                "writes": item["writes"],
                "removes": item["removes"],
                "clears": item["clears"],
                "token_like": item["token_like"],
            }
            for key, item in sorted(storage_summary.items())
        ],
    }
    return graph, initiators, storage


def write_outputs(run_dir, graph, initiators, storage):
    (run_dir / "evidence-graph.json").write_text(json.dumps(graph, indent=2), encoding="utf-8")
    (run_dir / "initiators.json").write_text(json.dumps(initiators, indent=2), encoding="utf-8")
    (run_dir / "storage-summary.json").write_text(json.dumps(storage, indent=2), encoding="utf-8")

    lines = [
        "# Web Capture Evidence Graph",
        "",
        f"- Run id: `{graph['manifest'].get('run_id', 'unknown')}`",
        f"- Action: `{graph['manifest'].get('action_label', 'unknown')}`",
        f"- Nodes: {graph['stats']['nodes']}",
        f"- Edges: {graph['stats']['edges']}",
        f"- Requests: {graph['stats']['requests']}",
        f"- Scripts: {graph['stats']['scripts']}",
        f"- JS runtime events: {graph['stats']['js_runtime_events']}",
        f"- Worker targets: {graph['stats']['workers']}",
        "",
        "## Protection Signals",
        "",
    ]
    if graph["protection_detections"]:
        for provider, item in graph["protection_detections"].items():
            lines.append(f"- `{provider}`: {item['count']} sanitized signals")
    else:
        lines.append("- No protection-provider patterns detected.")
    lines.extend([
        "",
        "## JS Runtime Event Types",
        "",
    ])
    if graph["js_runtime_event_types"]:
        for event_type, count in graph["js_runtime_event_types"].items():
            lines.append(f"- `{event_type}`: {count}")
    else:
        lines.append("- No JS runtime observer events available.")
    lines.extend([
        "",
        "## Redaction",
        "",
        "This report is evidence-only. It omits raw tokens, cookies, request bodies, response bodies, and CAPTCHA payloads.",
        "",
    ])
    (run_dir / "evidence-graph.md").write_text("\n".join(lines), encoding="utf-8")

    observations = [
        "# Anti-Abuse Observations",
        "",
        "These are observations only, not bypass instructions.",
        "",
        "## Detected Providers",
        "",
    ]
    if graph["protection_detections"]:
        for provider, item in graph["protection_detections"].items():
            observations.append(f"- `{provider}`: {item['count']} signals")
    else:
        observations.append("- No known provider pattern detected.")
    observations.extend([
        "",
        "## State Keys",
        "",
    ])
    token_like = [item for item in storage["items"] if item["token_like"]]
    if token_like:
        for item in token_like:
            observations.append(f"- token-like key class: `{item['key']}` writes={item['writes']} removes={item['removes']} clears={item['clears']}")
    else:
        observations.append("- No token-like storage key names detected in sanitized runtime events.")
    observations.extend([
        "",
        "## Boundary",
        "",
        "Do not use this report to replay tokens, solve CAPTCHA, or automate protected endpoints outside the authorized scope.",
        "",
    ])
    (run_dir / "anti-abuse-observations.md").write_text("\n".join(observations), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_dir", help="capture run directory")
    parser.add_argument("--json", action="store_true", help="print JSON graph summary")
    args = parser.parse_args()

    run_dir = Path(args.run_dir).expanduser().resolve()
    if not run_dir.is_dir():
        print(f"FAIL run_dir is not a directory: {run_dir}")
        return 2
    graph, initiators, storage = build_graph(run_dir)
    write_outputs(run_dir, graph, initiators, storage)
    if args.json:
        print(json.dumps({
            "ok": True,
            "stats": graph["stats"],
            "protection_detections": graph["protection_detections"],
            "outputs": [
                "evidence-graph.json",
                "evidence-graph.md",
                "initiators.json",
                "storage-summary.json",
                "anti-abuse-observations.md",
            ],
        }, indent=2))
    else:
        print(f"nodes: {graph['stats']['nodes']}")
        print(f"edges: {graph['stats']['edges']}")
        print(f"protection_providers: {graph['stats']['protection_providers']}")
        print(f"graph: {run_dir / 'evidence-graph.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
