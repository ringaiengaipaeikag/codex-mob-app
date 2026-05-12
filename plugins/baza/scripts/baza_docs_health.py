#!/usr/bin/env python3
"""Check BAZA project documentation freshness across Markdown, Mongo, and vector index."""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from baza_docs_vector_sync import CHUNKER_VERSION
from baza_docs_vector_sync import contains_secret_like
from baza_docs_vector_sync import chunks_for
from baza_docs_vector_sync import derive_category
from baza_docs_vector_sync import docs_hash
from baza_docs_vector_sync import walk_markdown


def local_snapshot(root, docs_dir, category):
    docs = walk_markdown(docs_dir)
    chunks = []
    secret_like = 0
    duplicate_paths = {}
    for file_path in docs:
        for chunk in chunks_for(file_path, docs_dir, category):
            chunks.append(chunk)
            if contains_secret_like(chunk["content"]):
                secret_like += 1
            duplicate_paths[chunk["path"]] = duplicate_paths.get(chunk["path"], 0) + 1
    return {
        "root": str(root),
        "docs_dir": str(docs_dir),
        "category": category,
        "docs_hash": docs_hash(docs_dir) if docs else "",
        "source_count": len(docs),
        "chunk_count": len(chunks),
        "safe_chunk_count": len(chunks) - secret_like,
        "secret_like_chunks": secret_like,
        "duplicate_path_groups": sum(1 for count in duplicate_paths.values() if count > 1),
    }


def parse_marked_json(output, marker):
    for line in reversed(output.splitlines()):
        if line.startswith(marker):
            return json.loads(line[len(marker):])
    raise RuntimeError("mongosh output did not include health JSON marker")


def mongo_snapshot(mongo_uri, category):
    marker = "__BAZA_DOCS_HEALTH__"
    js = f"""
const category = {json.dumps(category)};
const manifest = db.doc_manifests.findOne({{_id: category}}) || db.doc_manifests.findOne({{category}});
const duplicatePathGroups = db.doc_chunks.aggregate([
  {{$match: {{category}}}},
  {{$group: {{_id: "$path", count: {{$sum: 1}}}}}},
  {{$match: {{count: {{$gt: 1}}}}}},
  {{$count: "n"}}
]).toArray()[0]?.n || 0;
const result = {{
  mongoVersion: db.version(),
  collections: db.getCollectionNames().sort(),
  manifest,
  sourceCount: db.doc_sources.countDocuments({{category}}),
  chunkCount: db.doc_chunks.countDocuments({{category}}),
  duplicatePathGroups,
  sourceIndexes: db.doc_sources.getIndexes().map((item) => item.name).sort(),
  chunkIndexes: db.doc_chunks.getIndexes().map((item) => item.name).sort(),
  manifestIndexes: db.doc_manifests.getIndexes().map((item) => item.name).sort(),
}};
print("{marker}" + JSON.stringify(result));
"""
    if not shutil.which("mongosh"):
        raise RuntimeError("mongosh not found")
    result = subprocess.run(
        ["mongosh", "--quiet", mongo_uri, "--eval", js],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stdout.strip() or f"mongosh exited with {result.returncode}")
    return parse_marked_json(result.stdout, marker)


def vector_snapshot(root, category):
    path = root / ".baza" / "docs-vector" / category / "index.json"
    if not path.exists():
        return {"exists": False, "path": str(path)}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return {"exists": True, "path": str(path), "invalid": str(exc)}
    return {
        "exists": True,
        "path": str(path),
        "schema": data.get("schema", ""),
        "docs_hash": data.get("docs_hash", ""),
        "chunker_version": data.get("chunker_version", ""),
        "chunk_count": data.get("chunk_count", 0),
        "backend": data.get("embedding_backend", ""),
        "model": data.get("embedding_model", ""),
        "created_at": data.get("created_at", ""),
    }


def check_health(root, mongo_uri, category):
    docs_dir = root / "docs"
    failures = []
    warnings = []
    if not docs_dir.exists():
        failures.append(f"docs directory missing: {docs_dir}")
        local = {}
    else:
        local = local_snapshot(root, docs_dir, category)
        if local["duplicate_path_groups"]:
            failures.append(f"local chunker produced duplicate paths: {local['duplicate_path_groups']}")
        if local["secret_like_chunks"]:
            warnings.append(f"local docs include {local['secret_like_chunks']} secret-like chunks; verify sanitization")

    try:
        mongo = mongo_snapshot(mongo_uri, category)
    except Exception as exc:
        mongo = {"error": str(exc)}
        failures.append(f"mongo health check failed: {exc}")

    manifest = mongo.get("manifest") or {}
    if mongo and not mongo.get("error"):
        if not manifest:
            failures.append("Mongo doc_manifests entry missing; run `make baza-docs-sync`")
        elif local:
            if manifest.get("docsHash") != local["docs_hash"]:
                failures.append("Mongo docsHash is stale; run `make baza-docs-sync`")
            if manifest.get("chunkerVersion") != CHUNKER_VERSION:
                warnings.append("Mongo chunkerVersion differs from local BAZA chunker")
            if int(manifest.get("sourceCount") or 0) != local["source_count"]:
                failures.append("Mongo manifest sourceCount differs from local docs")
            if int(manifest.get("chunkCount") or 0) != local["chunk_count"]:
                failures.append("Mongo manifest chunkCount differs from local chunker")
        if int(mongo.get("sourceCount") or 0) != int(manifest.get("sourceCount") or 0):
            failures.append("Mongo doc_sources count differs from manifest")
        if int(mongo.get("chunkCount") or 0) != int(manifest.get("chunkCount") or 0):
            failures.append("Mongo doc_chunks count differs from manifest")
        if int(mongo.get("duplicatePathGroups") or 0):
            failures.append(f"Mongo has duplicate chunk paths: {mongo['duplicatePathGroups']}")
        source_indexes = set(mongo.get("sourceIndexes") or [])
        chunk_indexes = set(mongo.get("chunkIndexes") or [])
        manifest_indexes = set(mongo.get("manifestIndexes") or [])
        for required in ["category_lastIndexed", "category_name"]:
            if required not in source_indexes:
                warnings.append(f"Mongo doc_sources index missing: {required}")
        for required in ["category_source_order", "category_path"]:
            if required not in chunk_indexes:
                warnings.append(f"Mongo doc_chunks index missing: {required}")
        if "category_unique" not in manifest_indexes:
            warnings.append("Mongo doc_manifests index missing: category_unique")

    vector = vector_snapshot(root, category)
    if not vector.get("exists"):
        warnings.append("local vector index missing; run `make baza-docs-vector-sync`")
    elif vector.get("invalid"):
        failures.append(f"local vector index invalid: {vector['invalid']}")
    elif local:
        if vector.get("docs_hash") != local["docs_hash"]:
            failures.append("local vector index docsHash is stale; run `make baza-docs-vector-sync`")
        if vector.get("chunker_version") != CHUNKER_VERSION:
            warnings.append("local vector index chunkerVersion differs from local BAZA chunker")
        if int(vector.get("chunk_count") or 0) != local["safe_chunk_count"]:
            warnings.append("local vector index chunk_count differs from safe local chunk count")

    ok = not failures
    return {
        "ok": ok,
        "category": category,
        "local": local,
        "mongo": mongo,
        "vector": vector,
        "failures": failures,
        "warnings": warnings,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="project root")
    parser.add_argument("--mongo-uri", default=os.environ.get("MONGO_URI", "mongodb://localhost:27017/context-hub"))
    parser.add_argument("--category", default=os.environ.get("PROJECT_DOCS_CATEGORY", ""))
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--strict", action="store_true", help="treat warnings as failures")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    category = args.category or derive_category(root, root / "docs")
    if not category:
        print("FAIL category missing; pass --category or add project-<slug> to docs/status.md")
        return 2
    if not re.fullmatch(r"project-[a-z0-9][a-z0-9-]*", category):
        print("FAIL category must look like project-<slug>")
        return 2

    result = check_health(root, args.mongo_uri, category)
    ok = result["ok"] and not (args.strict and result["warnings"])
    result["ok"] = ok

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"BAZA docs health root: {root}")
        print(f"category: {category}")
        print(f"local: {result['local'].get('source_count', 0)} sources / {result['local'].get('chunk_count', 0)} chunks")
        if result["mongo"].get("error"):
            print(f"mongo: error: {result['mongo']['error']}")
        else:
            print(f"mongo: {result['mongo'].get('sourceCount', 0)} sources / {result['mongo'].get('chunkCount', 0)} chunks")
        if result["vector"].get("exists"):
            print(f"vector: {result['vector'].get('chunk_count', 0)} chunks at {result['vector'].get('path')}")
        else:
            print(f"vector: missing at {result['vector'].get('path')}")
        for item in result["failures"]:
            print(f"FAIL {item}")
        for item in result["warnings"]:
            print(f"WARN {item}")
        if ok:
            print("OK BAZA docs health passed")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
