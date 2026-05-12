#!/usr/bin/env python3
"""Create redacted copies of text artifacts from a BAZA web capture run."""

import argparse
import json
import re
import shutil
import sys
from pathlib import Path


TEXT_SUFFIXES = {".json", ".ndjson", ".md", ".txt", ".har", ".log"}
SKIP_SUFFIXES = {".zip", ".flows", ".pcap", ".pcapng", ".png", ".jpg", ".jpeg", ".webp", ".sqlite", ".db"}
SENSITIVE_KEY_RE = re.compile(r"(authorization|cookie|set-cookie|token|secret|password|passwd|api[-_]?key|csrf|session)", re.I)
SECRET_PATTERNS = [
    re.compile(r"(?i)(bearer\s+)[A-Za-z0-9._+/=-]{12,}"),
    re.compile(r"(?i)(authorization[\"'\s:=]+)[A-Za-z0-9._+/=-]{12,}"),
    re.compile(r"(?i)(api[-_]?key[\"'\s:=]+)[A-Za-z0-9._+/=-]{12,}"),
    re.compile(r"(?i)(token[\"'\s:=]+)[A-Za-z0-9._+/=-]{12,}"),
    re.compile(r"\b\d{3}-\d{2}-\d{4}\b"),
]


def redact_string(value):
    text = str(value)
    for pattern in SECRET_PATTERNS:
        if "bearer" in pattern.pattern.lower():
            text = pattern.sub(r"\1[REDACTED]", text)
        elif "\\b\\d{3}" in pattern.pattern:
            text = pattern.sub("[REDACTED-SSN]", text)
        else:
            text = pattern.sub(r"\1[REDACTED]", text)
    return text


def redact_json(value):
    if isinstance(value, dict):
        out = {}
        for key, item in value.items():
            key_text = str(key)
            sensitive = SENSITIVE_KEY_RE.search(key_text) and key_text not in {"authorization_confirmed"}
            out[key] = "[REDACTED]" if sensitive else redact_json(item)
        return out
    if isinstance(value, list):
        return [redact_json(item) for item in value]
    if isinstance(value, str):
        return redact_string(value)
    return value


def redact_text(text):
    try:
        parsed = json.loads(text)
        return json.dumps(redact_json(parsed), indent=2, ensure_ascii=False) + "\n"
    except json.JSONDecodeError:
        pass

    lines = []
    for line in text.splitlines():
        if line.strip().startswith("{"):
            try:
                lines.append(json.dumps(redact_json(json.loads(line)), ensure_ascii=False))
                continue
            except json.JSONDecodeError:
                pass
        lines.append(redact_string(line))
    return "\n".join(lines) + ("\n" if text.endswith("\n") else "")


def iter_files(run_dir):
    for path in sorted(run_dir.rglob("*")):
        if not path.is_file():
            continue
        if "redacted" in path.relative_to(run_dir).parts:
            continue
        yield path


def redact_run(run_dir, out_dir, in_place=False):
    copied = []
    skipped = []
    for src in iter_files(run_dir):
        rel = src.relative_to(run_dir)
        if src.suffix.lower() in SKIP_SUFFIXES:
            skipped.append(str(rel))
            continue
        if src.suffix.lower() not in TEXT_SUFFIXES:
            skipped.append(str(rel))
            continue

        text = src.read_text(encoding="utf-8", errors="replace")
        redacted = redact_text(text)
        dst = src if in_place else out_dir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(redacted, encoding="utf-8")
        copied.append(str(rel))
    return copied, skipped


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_dir", help="capture run directory")
    parser.add_argument("--out-dir", help="redacted output directory; default <run_dir>/redacted")
    parser.add_argument("--in-place", action="store_true", help="modify text artifacts in place")
    parser.add_argument("--json", action="store_true", help="print JSON")
    args = parser.parse_args()

    run_dir = Path(args.run_dir).expanduser().resolve()
    if not run_dir.is_dir():
        print(f"FAIL run_dir is not a directory: {run_dir}")
        return 2

    out_dir = Path(args.out_dir).expanduser().resolve() if args.out_dir else run_dir / "redacted"
    if not args.in_place:
        if out_dir.exists():
            shutil.rmtree(out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)

    copied, skipped = redact_run(run_dir, out_dir, args.in_place)
    result = {
        "ok": True,
        "run_dir": str(run_dir),
        "out_dir": str(out_dir),
        "in_place": args.in_place,
        "redacted_files": copied,
        "skipped_files": skipped,
    }
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"redacted_files: {len(copied)}")
        print(f"skipped_files: {len(skipped)}")
        if not args.in_place:
            print(f"out_dir: {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
