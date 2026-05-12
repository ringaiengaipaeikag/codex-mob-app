#!/usr/bin/env python3
"""Search a local BAZA docs vector index with hybrid lexical + vector ranking."""

import argparse
import json
import math
import os
import re
import sys
from pathlib import Path

from baza_docs_vector_sync import derive_category
from baza_docs_vector_sync import docs_hash
from baza_docs_vector_sync import embed_texts
from baza_docs_vector_sync import tokenize


def load_index(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise RuntimeError(f"missing vector index: {path}")
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"invalid vector index JSON: {exc}")


def cosine(left, right):
    if not left or not right or len(left) != len(right):
        return 0.0
    return sum(a * b for a, b in zip(left, right))


def lexical_score(query_terms, chunk):
    if not query_terms:
        return 0.0
    title = " ".join([chunk.get("title", ""), " ".join(chunk.get("headings") or [])]).lower()
    keywords = set(chunk.get("keywords") or [])
    content = chunk.get("content", "").lower()
    score = 0.0
    for term in query_terms:
        if term in keywords:
            score += 2.0
        if term in title:
            score += 2.0
        count = content.count(term)
        if count:
            score += min(3.0, 0.75 * count)
    return score / max(1.0, len(query_terms) * 3.5)


def snippet(content, query_terms, limit=280):
    text = re.sub(r"\s+", " ", content or "").strip()
    if len(text) <= limit:
        return text
    lower = text.lower()
    positions = [lower.find(term) for term in query_terms if lower.find(term) >= 0]
    start = max(0, min(positions) - 80) if positions else 0
    end = min(len(text), start + limit)
    prefix = "..." if start else ""
    suffix = "..." if end < len(text) else ""
    return f"{prefix}{text[start:end]}{suffix}"


def search(index, query, limit, vector_weight):
    backend = index.get("embedding_backend", "local-hash")
    model = index.get("embedding_model", "")
    dims = int(index.get("dimensions") or 384)
    _backend, _model, vectors = embed_texts(
        [query],
        backend,
        model if backend != "local-hash" else "",
        dims,
        os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434"),
        10.0,
    )
    query_vector = vectors[0]
    query_terms = tokenize(query)
    lexical_weight = 1.0 - vector_weight
    results = []
    for chunk in index.get("chunks") or []:
        vector_score = cosine(query_vector, chunk.get("vector") or [])
        lexical = lexical_score(query_terms, chunk)
        hybrid = (vector_weight * vector_score) + (lexical_weight * lexical)
        results.append({
            "score": hybrid,
            "vector_score": vector_score,
            "lexical_score": lexical,
            "category": chunk.get("category", ""),
            "path": chunk.get("path", ""),
            "title": chunk.get("title", ""),
            "headings": chunk.get("headings", []),
            "origin": chunk.get("origin", ""),
            "snippet": snippet(chunk.get("content", ""), query_terms),
        })
    results.sort(key=lambda item: item["score"], reverse=True)
    return results[:limit]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="project root")
    parser.add_argument("--category", default=os.environ.get("PROJECT_DOCS_CATEGORY", ""))
    parser.add_argument("--index", help="explicit index path")
    parser.add_argument("--query", required=True, help="search query")
    parser.add_argument("--limit", type=int, default=8)
    parser.add_argument("--vector-weight", type=float, default=0.65)
    parser.add_argument("--json", action="store_true", help="print machine-readable results")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    category = args.category or derive_category(root, root / "docs")
    if not category:
        print("FAIL category missing; pass --category or add project-<slug> to docs/status.md")
        return 2
    index_path = Path(args.index).expanduser().resolve() if args.index else root / ".baza" / "docs-vector" / category / "index.json"
    try:
        index = load_index(index_path)
        results = search(index, args.query, max(1, args.limit), min(1.0, max(0.0, args.vector_weight)))
    except Exception as exc:
        print(f"FAIL {exc}")
        return 1

    current_docs_hash = docs_hash(root / "docs") if (root / "docs").exists() else ""
    index_docs_hash = index.get("docs_hash", "")
    stale = bool(current_docs_hash and index_docs_hash and current_docs_hash != index_docs_hash)

    output = {
        "ok": True,
        "query": args.query,
        "category": index.get("category", category),
        "index": str(index_path),
        "backend": index.get("embedding_backend", ""),
        "model": index.get("embedding_model", ""),
        "stale": stale,
        "results": results,
    }
    if args.json:
        print(json.dumps(output, indent=2))
    else:
        print(f"query: {args.query}")
        print(f"category: {output['category']}")
        print(f"backend: {output['backend']} model: {output['model']}")
        if stale:
            print("WARN vector index is stale; run `make baza-docs-vector-sync`")
        for idx, item in enumerate(results, start=1):
            print(f"{idx}. score={item['score']:.4f} vector={item['vector_score']:.4f} lexical={item['lexical_score']:.4f}")
            print(f"   {item['path']} :: {item['title']}")
            print(f"   {item['snippet']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
