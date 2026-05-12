#!/usr/bin/env python3
"""Check registered BAZA upstream repositories for release or branch drift."""

import argparse
import json
import os
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


def github_get(path, token):
    req = urllib.request.Request(
        f"https://api.github.com{path}",
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "baza-upstream-checker",
        },
    )
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=20) as response:
        return json.loads(response.read().decode("utf-8"))


def github_token():
    return (
        os.environ.get("GITHUB_TOKEN")
        or os.environ.get("GH_TOKEN")
        or os.environ.get("GITHUB_PERSONAL_ACCESS_TOKEN")
    )


def format_github_error(exc):
    message = str(exc)
    if isinstance(exc, urllib.error.HTTPError) and exc.code == 403 and "rate limit" in message.lower():
        return (
            f"{message}; set GITHUB_TOKEN, GH_TOKEN, or "
            "GITHUB_PERSONAL_ACCESS_TOKEN for authenticated checks"
        )
    return message


def check_github(repo, token):
    owner = repo["owner"]
    name = repo["repo"]
    result = {
        "id": repo["id"],
        "url": repo["url"],
        "provider": "github",
        "updates": [],
        "warnings": [],
        "errors": [],
        "current": {},
        "pinned": {
            "release": repo.get("pinned_release", ""),
            "default_branch": repo.get("pinned_default_branch", ""),
            "default_branch_sha": repo.get("pinned_default_branch_sha", ""),
        },
    }

    try:
        meta = github_get(f"/repos/{owner}/{name}", token)
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as exc:
        result["errors"].append(f"repo metadata unavailable: {format_github_error(exc)}")
        return result

    default_branch = meta.get("default_branch", "")
    result["current"]["stars"] = meta.get("stargazers_count")
    result["current"]["forks"] = meta.get("forks_count")
    result["current"]["default_branch"] = default_branch
    result["current"]["open_issues"] = meta.get("open_issues_count")

    if repo.get("check_release", False):
        try:
            latest = github_get(f"/repos/{owner}/{name}/releases/latest", token)
            latest_tag = latest.get("tag_name", "")
            result["current"]["latest_release"] = latest_tag
            pinned = repo.get("pinned_release", "")
            if pinned and latest_tag and latest_tag != pinned:
                result["updates"].append(f"release drift: pinned {pinned}, latest {latest_tag}")
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                result["warnings"].append("no latest release found")
            else:
                result["errors"].append(f"latest release unavailable: {format_github_error(exc)}")
        except (urllib.error.URLError, TimeoutError) as exc:
            result["errors"].append(f"latest release unavailable: {format_github_error(exc)}")

    if repo.get("check_default_branch", False):
        branch = repo.get("pinned_default_branch") or default_branch
        if branch:
            try:
                commit = github_get(f"/repos/{owner}/{name}/commits/{branch}", token)
                sha = commit.get("sha", "")
                result["current"]["default_branch_sha"] = sha
                pinned_sha = repo.get("pinned_default_branch_sha", "")
                if pinned_sha and sha and sha != pinned_sha:
                    result["updates"].append(
                        f"default branch drift: pinned {pinned_sha[:12]}, latest {sha[:12]}"
                    )
            except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as exc:
                result["errors"].append(f"default branch commit unavailable: {format_github_error(exc)}")

    return result


def check_repo(repo, token):
    provider = repo.get("provider", "")
    if provider == "github":
        return check_github(repo, token)
    return {
        "id": repo.get("id", ""),
        "url": repo.get("url", ""),
        "provider": provider,
        "updates": [],
        "warnings": [],
        "errors": [f"unsupported provider: {provider}"],
        "current": {},
        "pinned": {},
    }


def print_text(results):
    for item in results:
        status = "OK"
        if item["updates"]:
            status = "UPDATE"
        if item["errors"]:
            status = "ERROR"
        print(f"{status} {item['id']} {item['url']}")
        current = item.get("current", {})
        if "latest_release" in current:
            print(f"  latest_release: {current['latest_release']}")
        if "default_branch" in current:
            print(f"  default_branch: {current['default_branch']}")
        if "default_branch_sha" in current:
            print(f"  default_branch_sha: {current['default_branch_sha']}")
        for message in item["updates"]:
            print(f"  UPDATE {message}")
        for message in item["warnings"]:
            print(f"  WARN {message}")
        for message in item["errors"]:
            print(f"  ERROR {message}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--registry",
        default=str(source_root() / "upstreams" / "registry.toml"),
        help="path to upstream registry",
    )
    parser.add_argument("--json", action="store_true", help="print JSON result")
    parser.add_argument("--strict", action="store_true", help="exit non-zero on drift")
    args = parser.parse_args()

    registry_path = Path(args.registry).expanduser().resolve()
    registry = load_registry(registry_path)
    repos = registry.get("repositories", [])
    token = github_token()
    results = [check_repo(repo, token) for repo in repos]

    if args.json:
        print(json.dumps({"registry": str(registry_path), "repositories": results}, indent=2))
    else:
        print_text(results)

    has_errors = any(item["errors"] for item in results)
    has_updates = any(item["updates"] for item in results)
    if has_errors:
        return 2
    if args.strict and has_updates:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
