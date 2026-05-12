#!/usr/bin/env python3
"""Check BAZA official source URLs and local source dossiers."""

import argparse
import json
import sys
import tomllib
import urllib.error
import urllib.request
from pathlib import Path


def source_root():
    return Path(__file__).resolve().parents[1]


def load_registry(path):
    with path.open("rb") as fh:
        return tomllib.load(fh)


def url_status(url, timeout):
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "baza-official-source-checker",
            "Accept": "text/html,application/json,*/*",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return {
                "ok": 200 <= response.status < 400,
                "status": response.status,
                "final_url": response.geturl(),
                "error": "",
            }
    except urllib.error.HTTPError as exc:
        return {"ok": False, "status": exc.code, "final_url": url, "error": str(exc)}
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        return {"ok": False, "status": None, "final_url": url, "error": str(exc)}


def check_source(item, root, timeout, offline):
    dossier = item.get("dossier", "")
    dossier_path = (root / dossier).resolve() if dossier else None
    result = {
        "id": item.get("id", ""),
        "title": item.get("title", ""),
        "kind": item.get("kind", ""),
        "url": item.get("url", ""),
        "dossier": str(dossier_path) if dossier_path else "",
        "mcp_route": item.get("mcp_route", ""),
        "warnings": [],
        "errors": [],
        "current": {},
    }

    if dossier_path:
        if dossier_path.exists():
            result["current"]["dossier"] = "present"
        else:
            result["warnings"].append(f"dossier missing: {dossier}")

    if offline:
        result["current"]["url_check"] = "skipped-offline"
        return result

    url = item.get("url", "")
    if not url:
        result["errors"].append("missing url")
        return result

    status = url_status(url, timeout)
    result["current"]["status"] = status.get("status")
    result["current"]["final_url"] = status.get("final_url")
    allowed_statuses = set(item.get("allowed_statuses", []))
    if not status["ok"] and status.get("status") in allowed_statuses:
        result["warnings"].append(f"url returned allowed status: {status.get('status')}")
    elif not status["ok"]:
        result["errors"].append(f"url unavailable: {status.get('error') or status.get('status')}")
    return result


def print_text(results, offline):
    mode = "offline" if offline else "network"
    print(f"BAZA official source check mode: {mode}")
    for item in results:
        status = "OK"
        if item["warnings"]:
            status = "WARN"
        if item["errors"]:
            status = "ERROR"
        print(f"{status} {item['id']} {item['url']}")
        if item.get("dossier"):
            print(f"  dossier: {item['dossier']}")
        if "status" in item.get("current", {}):
            print(f"  http_status: {item['current']['status']}")
        for message in item["warnings"]:
            print(f"  WARN {message}")
        for message in item["errors"]:
            print(f"  ERROR {message}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--registry",
        default=str(source_root() / "official-sources" / "registry.toml"),
        help="official sources registry",
    )
    parser.add_argument("--offline", action="store_true", help="check only local dossier coverage")
    parser.add_argument("--timeout", type=float, default=12.0, help="HTTP timeout in seconds")
    parser.add_argument("--json", action="store_true", help="print JSON result")
    parser.add_argument("--strict", action="store_true", help="exit non-zero on warnings")
    args = parser.parse_args()

    registry_path = Path(args.registry).expanduser().resolve()
    root = registry_path.parents[1]
    registry = load_registry(registry_path)
    results = [
        check_source(item, root, args.timeout, args.offline)
        for item in registry.get("sources", [])
    ]

    warnings = [item for item in results if item["warnings"]]
    errors = [item for item in results if item["errors"]]
    ok = not errors and not (args.strict and warnings)

    if args.json:
        print(json.dumps({
            "ok": ok,
            "registry": str(registry_path),
            "offline": args.offline,
            "warnings": warnings,
            "errors": errors,
            "sources": results,
        }, indent=2))
    else:
        print_text(results, args.offline)

    if errors:
        return 2
    if args.strict and warnings:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
