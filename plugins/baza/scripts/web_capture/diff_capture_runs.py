#!/usr/bin/env python3
"""Compare two sanitized BAZA web capture runs."""

import argparse
import json
import sys
from pathlib import Path

from build_evidence_graph import build_graph


def node_set(graph, node_type, key):
    values = set()
    for node in graph.get("nodes", []):
        if node.get("type") == node_type:
            value = node.get(key) or node.get("label")
            if value:
                values.add(value)
    return values


def event_types(graph):
    return set((graph.get("js_runtime_event_types") or {}).keys())


def providers(graph):
    return set((graph.get("protection_detections") or {}).keys())


def storage_keys(storage):
    return {item.get("key") for item in storage.get("items", []) if item.get("key")}


def compare(left_dir, right_dir):
    left_graph, _left_initiators, left_storage = build_graph(left_dir)
    right_graph, _right_initiators, right_storage = build_graph(right_dir)

    comparisons = {
        "endpoints": (
            node_set(left_graph, "endpoint", "label"),
            node_set(right_graph, "endpoint", "label"),
        ),
        "scripts": (
            node_set(left_graph, "script", "url"),
            node_set(right_graph, "script", "url"),
        ),
        "js_runtime_event_types": (
            event_types(left_graph),
            event_types(right_graph),
        ),
        "protection_providers": (
            providers(left_graph),
            providers(right_graph),
        ),
        "storage_keys": (
            storage_keys(left_storage),
            storage_keys(right_storage),
        ),
    }

    diff = {
        "schema": "baza-web-capture-diff-v1",
        "left": str(left_dir),
        "right": str(right_dir),
        "changes": {},
        "stats": {
            "left": left_graph.get("stats", {}),
            "right": right_graph.get("stats", {}),
        },
    }
    for name, (left, right) in comparisons.items():
        diff["changes"][name] = {
            "added": sorted(right - left),
            "removed": sorted(left - right),
            "unchanged": sorted(left & right),
            "left_count": len(left),
            "right_count": len(right),
        }
    return diff


def write_outputs(out_dir, diff):
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "capture-diff.json").write_text(json.dumps(diff, indent=2), encoding="utf-8")
    lines = [
        "# Web Capture Run Diff",
        "",
        f"- Left: `{diff['left']}`",
        f"- Right: `{diff['right']}`",
        "",
    ]
    for section, item in diff["changes"].items():
        lines.extend([
            f"## {section.replace('_', ' ').title()}",
            "",
            f"- Added: {len(item['added'])}",
            f"- Removed: {len(item['removed'])}",
            f"- Unchanged: {len(item['unchanged'])}",
        ])
        for label, values in [("Added", item["added"]), ("Removed", item["removed"])]:
            if values:
                lines.append("")
                lines.append(f"{label}:")
                for value in values[:50]:
                    lines.append(f"- `{value}`")
        lines.append("")
    lines.extend([
        "## Boundary",
        "",
        "This diff compares sanitized metadata only. Do not use it to replay tokens, solve CAPTCHA, or automate protected endpoints outside the authorized scope.",
        "",
    ])
    (out_dir / "capture-diff.md").write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("left_run_dir")
    parser.add_argument("right_run_dir")
    parser.add_argument("--out", help="output directory; default is right run dir")
    parser.add_argument("--json", action="store_true", help="print JSON diff")
    args = parser.parse_args()

    left_dir = Path(args.left_run_dir).expanduser().resolve()
    right_dir = Path(args.right_run_dir).expanduser().resolve()
    if not left_dir.is_dir():
        print(f"FAIL left run dir is not a directory: {left_dir}")
        return 2
    if not right_dir.is_dir():
        print(f"FAIL right run dir is not a directory: {right_dir}")
        return 2
    out_dir = Path(args.out).expanduser().resolve() if args.out else right_dir
    diff = compare(left_dir, right_dir)
    write_outputs(out_dir, diff)
    if args.json:
        print(json.dumps(diff, indent=2))
    else:
        print(f"diff: {out_dir / 'capture-diff.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
