#!/usr/bin/env python3
"""Analyze sanitized script inventory and optional local JS sources."""

import argparse
import json
import re
import sys
from collections import Counter
from collections import defaultdict
from pathlib import Path
from urllib.parse import urlparse


SCRIPT_RULES = [
    ("captcha", re.compile(r"(recaptcha|hcaptcha|turnstile|captcha|funcaptcha|arkose|geetest)", re.I)),
    ("anti-abuse", re.compile(r"(datadome|perimeterx|akamai|_abck|bm_sz|cloudflare|kasada|awswaf|challenge)", re.I)),
    ("fingerprint", re.compile(r"(fingerprint|canvas|webgl|navigator|userAgent|hardwareConcurrency|deviceMemory|fonts)", re.I)),
    ("auth-token", re.compile(r"(token|csrf|nonce|jwt|authorization|session|oauth|openid)", re.I)),
    ("crypto", re.compile(r"(crypto\.subtle|SHA-256|HMAC|encrypt|decrypt|digest|TextEncoder)", re.I)),
    ("network", re.compile(r"(fetch\(|XMLHttpRequest|sendBeacon|WebSocket|EventSource)", re.I)),
    ("storage", re.compile(r"(localStorage|sessionStorage|document\.cookie|indexedDB)", re.I)),
    ("dynamic-code", re.compile(r"(eval\(|new Function|import\(|setTimeout\([^,]+,|setInterval\([^,]+,)", re.I)),
    ("wasm", re.compile(r"(WebAssembly|\.wasm\b|instantiateStreaming)", re.I)),
    ("obfuscation", re.compile(r"(_0x[0-9a-f]{3,}|\\x[0-9a-f]{2}|atob\(|String\.fromCharCode)", re.I)),
]


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
            rows.append({"url": "", "hash": "", "unparseable": True})
    return rows


def safe_url(raw):
    try:
        parsed = urlparse(raw or "")
    except ValueError:
        return str(raw or "")
    if not parsed.scheme or not parsed.netloc:
        return raw or ""
    path = parsed.path or "/"
    out = f"{parsed.scheme}://{parsed.netloc}{path}"
    if parsed.query:
        out += "?[REDACTED_QUERY]"
    return out


def categories_for_text(text):
    return [name for name, pattern in SCRIPT_RULES if pattern.search(text or "")]


def source_files(source_dir):
    if not source_dir or not source_dir.exists():
        return []
    candidates = []
    for suffix in ("*.js", "*.mjs", "*.cjs", "*.ts", "*.tsx", "*.jsx"):
        candidates.extend(source_dir.rglob(suffix))
    return sorted(path for path in candidates if path.is_file())


def analyze(run_dir, source_dir=None, max_file_bytes=500000):
    scripts = read_ndjson(run_dir / "scripts.ndjson")
    script_items = []
    category_counts = Counter()

    for row in scripts:
        url = safe_url(row.get("url") or "")
        categories = categories_for_text(url)
        for category in categories:
            category_counts[category] += 1
        script_items.append({
            "url": url or "generated/eval script",
            "hash": row.get("hash", ""),
            "script_id": row.get("scriptId", ""),
            "start_line": row.get("startLine"),
            "end_line": row.get("endLine"),
            "categories": categories,
        })

    source_summary = []
    for file_path in source_files(source_dir):
        try:
            raw = file_path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        truncated = len(raw.encode("utf-8", errors="ignore")) > max_file_bytes
        text = raw[:max_file_bytes]
        categories = categories_for_text(text)
        match_counts = {}
        for name, pattern in SCRIPT_RULES:
            matches = pattern.findall(text)
            if matches:
                match_counts[name] = len(matches)
                category_counts[name] += 1
        if categories or match_counts:
            source_summary.append({
                "path": str(file_path.relative_to(source_dir)),
                "bytes_scanned": min(len(raw.encode("utf-8", errors="ignore")), max_file_bytes),
                "truncated": truncated,
                "categories": categories,
                "match_counts": match_counts,
            })

    return {
        "schema": "baza-script-analysis-v1",
        "run_dir": str(run_dir),
        "source_dir": str(source_dir) if source_dir else "",
        "script_inventory_count": len(script_items),
        "source_file_matches": len(source_summary),
        "category_counts": dict(sorted(category_counts.items())),
        "scripts": script_items,
        "source_summary": source_summary,
    }


def write_outputs(run_dir, result):
    (run_dir / "script-analysis.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    lines = [
        "# Script Analysis",
        "",
        f"- Script inventory entries: {result['script_inventory_count']}",
        f"- Source file matches: {result['source_file_matches']}",
        "",
        "## Categories",
        "",
    ]
    if result["category_counts"]:
        for category, count in result["category_counts"].items():
            lines.append(f"- `{category}`: {count}")
    else:
        lines.append("- No configured script patterns matched.")
    lines.extend([
        "",
        "## Notable Script Inventory",
        "",
    ])
    notable = [item for item in result["scripts"] if item["categories"]]
    if notable:
        for item in notable[:80]:
            lines.append(f"- `{item['url']}` categories={','.join(item['categories'])}")
    else:
        lines.append("- No notable script URLs detected.")
    if result["source_summary"]:
        lines.extend(["", "## Source Matches", ""])
        for item in result["source_summary"][:80]:
            lines.append(f"- `{item['path']}` categories={','.join(item['categories'])}")
    lines.extend([
        "",
        "## Boundary",
        "",
        "This report records pattern categories and counts only. Do not paste raw third-party script source, tokens, CAPTCHA payloads, or credentials into project docs.",
        "",
    ])
    (run_dir / "script-analysis.md").write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_dir", help="capture run directory")
    parser.add_argument("--source-dir", help="optional local directory with authorized JS sources")
    parser.add_argument("--json", action="store_true", help="print JSON summary")
    args = parser.parse_args()

    run_dir = Path(args.run_dir).expanduser().resolve()
    if not run_dir.is_dir():
        print(f"FAIL run_dir is not a directory: {run_dir}")
        return 2
    source_dir = Path(args.source_dir).expanduser().resolve() if args.source_dir else None
    if source_dir and not source_dir.is_dir():
        print(f"FAIL source-dir is not a directory: {source_dir}")
        return 2
    result = analyze(run_dir, source_dir)
    write_outputs(run_dir, result)
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"script_inventory_count: {result['script_inventory_count']}")
        print(f"source_file_matches: {result['source_file_matches']}")
        print(f"analysis: {run_dir / 'script-analysis.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
