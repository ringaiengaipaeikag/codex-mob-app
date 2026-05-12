#!/usr/bin/env python3
"""Analyze sanitized CDP JavaScript coverage for a BAZA web capture run."""

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path
from urllib.parse import urlparse


CATEGORY_RULES = [
    ("cloudflare", re.compile(r"(cloudflare|cdn-cgi|cf_chl|cf_clearance|turnstile)", re.I)),
    ("datadome", re.compile(r"(datadome|geo\.datadome\.co|captcha-delivery)", re.I)),
    ("akamai", re.compile(r"(akamai|_abck|ak_bmsc|bm_sz|sec-cpt|sensor_data)", re.I)),
    ("recaptcha", re.compile(r"(recaptcha|grecaptcha|gstatic\.com/recaptcha)", re.I)),
    ("hcaptcha", re.compile(r"(hcaptcha|h-captcha)", re.I)),
    ("arkose", re.compile(r"(arkose|funcaptcha|arkoselabs|enforcement\.)", re.I)),
    ("perimeterx", re.compile(r"(perimeterx|px-captcha|_px|pxvid)", re.I)),
    ("kasada", re.compile(r"(kasada|kpsdk|x-kpsdk)", re.I)),
    ("fingerprint", re.compile(r"(fingerprint|fpjs|visitorid|canvas|webgl|navigator)", re.I)),
    ("trustev-threatmetrix", re.compile(r"(trustev|threatmetrix|transunion|tmx|fpe)", re.I)),
    ("application", re.compile(r"(\.js|\.mjs|\.cjs)(\?|$)", re.I)),
]


def read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError) as exc:
        return {"_error": str(exc)}


def safe_url(raw):
    try:
        parsed = urlparse(raw or "")
    except ValueError:
        return str(raw or "")
    if not parsed.scheme or not parsed.netloc:
        return raw or "generated/eval script"
    out = f"{parsed.scheme}://{parsed.netloc}{parsed.path or '/'}"
    if parsed.query:
        out += "?[REDACTED_QUERY]"
    return out


def categories_for(url):
    return [name for name, pattern in CATEGORY_RULES if pattern.search(url or "")]


def merge_intervals(intervals):
    normalized = sorted((max(0, int(start)), max(0, int(end))) for start, end in intervals if end > start)
    if not normalized:
        return []
    merged = [list(normalized[0])]
    for start, end in normalized[1:]:
        last = merged[-1]
        if start <= last[1]:
            last[1] = max(last[1], end)
        else:
            merged.append([start, end])
    return [(start, end) for start, end in merged]


def interval_size(intervals):
    return sum(end - start for start, end in intervals)


def script_coverage(script):
    all_ranges = []
    covered_ranges = []
    high_calls = []
    for fn in script.get("functions") or []:
        fn_name = fn.get("functionName") or "(anonymous)"
        fn_calls = 0
        fn_offsets = []
        for item in fn.get("ranges") or []:
            start = int(item.get("startOffset") or 0)
            end = int(item.get("endOffset") or 0)
            count = int(item.get("count") or 0)
            all_ranges.append((start, end))
            if count > 0:
                covered_ranges.append((start, end))
                fn_calls += count
                fn_offsets.append({"start": start, "end": end, "count": count})
        if fn_calls > 10:
            high_calls.append({
                "function": fn_name,
                "calls": fn_calls,
                "ranges": fn_offsets[:8],
            })
    total_bytes = interval_size(merge_intervals(all_ranges))
    covered_bytes = interval_size(merge_intervals(covered_ranges))
    pct = round((covered_bytes / total_bytes * 100.0), 2) if total_bytes else 0.0
    return total_bytes, covered_bytes, pct, sorted(high_calls, key=lambda item: item["calls"], reverse=True)


def extract_scripts(raw):
    if isinstance(raw, list):
        return raw
    if isinstance(raw, dict):
        if isinstance(raw.get("result"), list):
            return raw["result"]
        if isinstance(raw.get("coverage"), list):
            return raw["coverage"]
    return []


def analyze(run_dir):
    coverage_path = run_dir / "js-coverage.json"
    raw = read_json(coverage_path)
    if isinstance(raw, dict) and "_error" in raw:
        return {
            "schema": "baza-js-coverage-analysis-v1",
            "run_dir": str(run_dir),
            "error": raw["_error"],
            "scripts": [],
            "category_counts": {},
            "summary": {},
        }

    scripts = []
    category_counts = Counter()
    totals = {"script_count": 0, "total_bytes": 0, "covered_bytes": 0}

    for script in extract_scripts(raw):
        url = safe_url(script.get("url") or "")
        total, covered, pct, high_calls = script_coverage(script)
        categories = categories_for(url)
        for category in categories:
            category_counts[category] += 1
        totals["script_count"] += 1
        totals["total_bytes"] += total
        totals["covered_bytes"] += covered
        scripts.append({
            "url": url,
            "script_id": script.get("scriptId", ""),
            "total_bytes": total,
            "covered_bytes": covered,
            "coverage_pct": pct,
            "function_count": len(script.get("functions") or []),
            "categories": categories,
            "high_call_functions": high_calls[:12],
        })

    overall_pct = (
        round(totals["covered_bytes"] / totals["total_bytes"] * 100.0, 2)
        if totals["total_bytes"]
        else 0.0
    )
    scripts.sort(key=lambda item: (item["categories"] == [], -item["covered_bytes"], item["url"]))
    return {
        "schema": "baza-js-coverage-analysis-v1",
        "run_dir": str(run_dir),
        "source": str(coverage_path),
        "error": raw.get("error", "") if isinstance(raw, dict) else "",
        "summary": {
            **totals,
            "overall_coverage_pct": overall_pct,
        },
        "category_counts": dict(sorted(category_counts.items())),
        "scripts": scripts,
    }


def write_outputs(run_dir, result):
    (run_dir / "js-coverage-analysis.json").write_text(
        json.dumps(result, indent=2) + "\n",
        encoding="utf-8",
    )
    lines = [
        "# JS Coverage Analysis",
        "",
        f"- Scripts: {result.get('summary', {}).get('script_count', 0)}",
        f"- Total bytes: {result.get('summary', {}).get('total_bytes', 0)}",
        f"- Covered bytes: {result.get('summary', {}).get('covered_bytes', 0)}",
        f"- Overall coverage: {result.get('summary', {}).get('overall_coverage_pct', 0)}%",
        "",
        "## Categories",
        "",
    ]
    if result.get("category_counts"):
        for category, count in result["category_counts"].items():
            lines.append(f"- `{category}`: {count}")
    else:
        lines.append("- No configured coverage categories matched.")

    lines.extend(["", "## Notable Scripts", ""])
    notable = [item for item in result.get("scripts", []) if item.get("categories")]
    if not notable:
        notable = result.get("scripts", [])[:20]
    if notable:
        for item in notable[:80]:
            categories = ",".join(item.get("categories") or ["uncategorized"])
            lines.append(
                f"- `{item['url']}` coverage={item['coverage_pct']}% "
                f"covered={item['covered_bytes']}/{item['total_bytes']} categories={categories}"
            )
    else:
        lines.append("- No coverage scripts available.")

    high_call_rows = []
    for item in result.get("scripts", []):
        for fn in item.get("high_call_functions") or []:
            high_call_rows.append((fn["calls"], item["url"], fn["function"]))
    high_call_rows.sort(reverse=True)
    if high_call_rows:
        lines.extend(["", "## High-Call Functions", ""])
        for calls, url, function in high_call_rows[:40]:
            lines.append(f"- `{url}` `{function}` calls={calls}")

    lines.extend([
        "",
        "## Boundary",
        "",
        "This report uses coverage offsets, percentages, categories, and call counts only. Do not paste raw third-party source, token values, CAPTCHA payloads, cookies, or credentials into project docs.",
        "",
    ])
    (run_dir / "js-coverage-analysis.md").write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_dir", help="capture run directory")
    parser.add_argument("--json", action="store_true", help="print JSON summary")
    args = parser.parse_args()

    run_dir = Path(args.run_dir).expanduser().resolve()
    if not run_dir.is_dir():
        print(f"FAIL run_dir is not a directory: {run_dir}")
        return 2
    result = analyze(run_dir)
    if result.get("error") and not result.get("scripts"):
        print(f"WARN {result['error']}")
    write_outputs(run_dir, result)
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        summary = result.get("summary", {})
        print(f"scripts: {summary.get('script_count', 0)}")
        print(f"overall_coverage_pct: {summary.get('overall_coverage_pct', 0)}")
        print(f"analysis: {run_dir / 'js-coverage-analysis.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
