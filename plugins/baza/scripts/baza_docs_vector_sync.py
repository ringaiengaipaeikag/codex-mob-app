#!/usr/bin/env python3
"""Build a local vector index for sanitized BAZA project documentation."""

import argparse
import hashlib
import json
import math
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime
from datetime import timezone
from pathlib import Path


STOP_WORDS = {
    "the", "and", "for", "with", "this", "that", "from", "into", "when", "then",
    "что", "как", "для", "или", "это", "при", "если", "без", "под", "над",
}

SECRET_REGEXES = [
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(r"\b\d{3}-\d{2}-\d{4}\b"),
    re.compile(r"(?i)\b(api[_-]?key|password|passwd|secret|token)\b\s*[:=]\s*[\"']?[A-Za-z0-9_./+=-]{12,}"),
    re.compile(r"(?i)\bbearer\s+[A-Za-z0-9_./+=-]{20,}"),
]

CHUNKER_VERSION = "baza-docs-chunker-v2"


def slugify(value):
    value = re.sub(r"[^a-z0-9]+", "-", value.strip().lower())
    return value.strip("-") or "project"


def derive_category(root, docs_dir):
    status = docs_dir / "status.md"
    if not status.exists():
        status = root / "docs" / "status.md"
    if not status.exists():
        return ""
    text = status.read_text(encoding="utf-8", errors="replace")
    matches = re.findall(r"\bproject-[a-z0-9][a-z0-9-]*\b", text)
    matches = [item for item in matches if item not in {"project-bootstrap"}]
    return matches[-1] if matches else ""


def source_name(relative_path):
    no_ext = re.sub(r"\.md$", "", str(relative_path), flags=re.I)
    if no_ext == "README":
        return "readme"
    if no_ext == "architecture":
        return "architecture"
    parts = Path(no_ext).parts
    base = parts[-1]
    directory = parts[0] if len(parts) > 1 else ""
    prefixes = {
        "agents": "agents",
        "api": "api",
        "bugs": "bug",
        "decisions": "decision",
        "experiments": "experiment",
        "modules": "module",
        "runbooks": "runbook",
        "setup": "setup",
        "source-dossiers": "source-dossier",
    }
    return "-".join(item for item in [prefixes.get(directory, ""), base] if item).replace(" ", "-")


def section_slug(text, fallback):
    value = re.sub(r"[^\w]+", "-", text.strip().lower(), flags=re.UNICODE).strip("-")
    return value or f"section-{fallback}"


def walk_markdown(docs_dir):
    if not docs_dir.exists():
        return []
    return sorted(path for path in docs_dir.rglob("*.md") if path.is_file())


def docs_hash(docs_dir):
    digest = hashlib.sha256()
    for path in walk_markdown(docs_dir):
        rel = path.relative_to(docs_dir).as_posix()
        digest.update(rel.encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def approx_tokens(text):
    return max(1, len(re.findall(r"[\w-]+", text, flags=re.UNICODE)))


def tokenize(text):
    return [
        item
        for item in re.findall(r"[\w-]{3,}", text.lower(), flags=re.UNICODE)
        if item not in STOP_WORDS
    ]


def keywords(text):
    counts = {}
    for item in tokenize(text):
        counts[item] = counts.get(item, 0) + 1
    return [
        item
        for item, _count in sorted(counts.items(), key=lambda pair: (-pair[1], pair[0]))[:20]
    ]


def links(text):
    found = set()
    for match in re.finditer(r"\[[^\]]+\]\(([^)]+)\)", text):
        target = match.group(1).strip()
        if target and not target.startswith("http"):
            found.add(target)
    return sorted(found)


def contains_secret_like(text):
    return any(pattern.search(text) for pattern in SECRET_REGEXES)


def chunks_for(file_path, docs_dir, category):
    text = file_path.read_text(encoding="utf-8", errors="replace").replace("\r\n", "\n")
    relative = file_path.relative_to(docs_dir)
    source = source_name(relative)
    chunks = []
    order = 0
    seen_heading = False
    headings = []
    current_title = file_path.stem
    current_headings = []
    body = []
    slug_counts = {}

    def flush():
        nonlocal order
        content = "\n".join(body).strip()
        title = current_title.strip()
        if not seen_heading and not content:
            return
        if not title and not content:
            return
        final_content = content or title
        base_slug = section_slug(title, order)
        slug_counts[base_slug] = slug_counts.get(base_slug, 0) + 1
        slug_value = base_slug if slug_counts[base_slug] == 1 else f"{base_slug}-{slug_counts[base_slug]}"
        path_value = f"{category}/{source}#{slug_value}"
        chunk_hash = hashlib.sha256(f"{path_value}\n{final_content}".encode("utf-8")).hexdigest()[:24]
        chunks.append({
            "chunk_id": f"{category}:{chunk_hash}",
            "source_id": f"local:{category}/{source}",
            "category": category,
            "source": source,
            "origin": str(file_path.resolve()),
            "path": path_value,
            "title": title,
            "headings": current_headings[:] if current_headings else [title],
            "content": final_content,
            "tokens": approx_tokens(final_content),
            "keywords": keywords(f"{title}\n{final_content}"),
            "links": links(final_content),
            "order": order,
        })
        order += 1

    for line in text.split("\n"):
        match = re.match(r"^(#{1,6})\s+(.+?)\s*$", line)
        if match:
            flush()
            seen_heading = True
            level = len(match.group(1))
            current_title = match.group(2).replace("`", "").strip()
            headings = headings[: level - 1]
            if len(headings) < level:
                headings.extend([""] * (level - len(headings)))
            headings[level - 1] = current_title
            current_headings = [item for item in headings if item]
            body = []
        else:
            body.append(line)
    flush()
    return chunks


def normalize(vec):
    norm = math.sqrt(sum(item * item for item in vec))
    if not norm:
        return vec
    return [item / norm for item in vec]


def local_hash_embedding(text, dims):
    vec = [0.0] * dims
    for token in tokenize(text):
        digest = hashlib.blake2b(token.encode("utf-8"), digest_size=8).digest()
        value = int.from_bytes(digest, "big")
        idx = value % dims
        sign = -1.0 if (value >> 63) else 1.0
        vec[idx] += sign
    return normalize(vec)


def ollama_request(url, payload, timeout):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def ollama_embeddings(texts, model, host, timeout):
    host = host.rstrip("/")
    try:
        result = ollama_request(f"{host}/api/embed", {"model": model, "input": texts}, timeout)
        embeddings = result.get("embeddings")
        if isinstance(embeddings, list) and len(embeddings) == len(texts):
            return embeddings
    except (OSError, urllib.error.URLError, urllib.error.HTTPError, TimeoutError, json.JSONDecodeError):
        pass

    embeddings = []
    for text in texts:
        result = ollama_request(f"{host}/api/embeddings", {"model": model, "prompt": text}, timeout)
        embedding = result.get("embedding")
        if not isinstance(embedding, list):
            raise RuntimeError("Ollama response did not include embedding")
        embeddings.append(embedding)
    return embeddings


def embed_texts(texts, backend, model, dims, ollama_host, timeout):
    if backend == "auto":
        if model:
            try:
                vectors = ollama_embeddings(texts, model, ollama_host, timeout)
                return "ollama", model, [normalize([float(x) for x in vec]) for vec in vectors]
            except Exception:
                pass
        backend = "local-hash"

    if backend == "ollama":
        selected_model = model or "nomic-embed-text"
        vectors = ollama_embeddings(texts, selected_model, ollama_host, timeout)
        return "ollama", selected_model, [normalize([float(x) for x in vec]) for vec in vectors]

    if backend == "local-hash":
        return "local-hash", f"local-hash-v1-{dims}", [local_hash_embedding(text, dims) for text in texts]

    raise RuntimeError(f"unsupported embedding backend: {backend}")


def batched(items, size):
    for idx in range(0, len(items), size):
        yield items[idx: idx + size]


def build_index(root, docs_dir, category, out_path, backend, model, dims, ollama_host, timeout, batch_size):
    docs = walk_markdown(docs_dir)
    if not docs:
        raise RuntimeError(f"no Markdown docs found: {docs_dir}")

    chunks = []
    skipped_secret_like = 0
    for file_path in docs:
        for chunk in chunks_for(file_path, docs_dir, category):
            if contains_secret_like(chunk["content"]):
                skipped_secret_like += 1
                continue
            chunks.append(chunk)

    if not chunks:
        raise RuntimeError("no safe chunks available for vector indexing")

    embedded_chunks = []
    selected_backend = backend
    selected_model = model
    dimensions = 0
    for batch in batched(chunks, batch_size):
        texts = [
            f"{chunk['title']}\n{' > '.join(chunk['headings'])}\n{chunk['content']}"
            for chunk in batch
        ]
        selected_backend, selected_model, vectors = embed_texts(
            texts,
            selected_backend,
            selected_model,
            dims,
            ollama_host,
            timeout,
        )
        for chunk, vector in zip(batch, vectors):
            dimensions = len(vector)
            embedded = dict(chunk)
            embedded["vector"] = vector
            embedded_chunks.append(embedded)

    index = {
        "schema": "baza-docs-vector-index-v1",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "root": str(root),
        "docs_dir": str(docs_dir),
        "category": category,
        "docs_hash": docs_hash(docs_dir),
        "chunker_version": CHUNKER_VERSION,
        "embedding_backend": selected_backend,
        "embedding_model": selected_model,
        "dimensions": dimensions,
        "chunk_count": len(embedded_chunks),
        "skipped_secret_like_chunks": skipped_secret_like,
        "chunks": embedded_chunks,
    }

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(index, indent=2) + "\n", encoding="utf-8")
    return index


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="project root")
    parser.add_argument("--docs-dir", help="sanitized Markdown docs directory")
    parser.add_argument("--category", default=os.environ.get("PROJECT_DOCS_CATEGORY", ""))
    parser.add_argument("--out", help="output index path")
    parser.add_argument("--backend", default=os.environ.get("BAZA_VECTOR_BACKEND", "local-hash"), choices=["auto", "local-hash", "ollama"])
    parser.add_argument("--model", default=os.environ.get("BAZA_VECTOR_MODEL", ""))
    parser.add_argument("--dims", type=int, default=int(os.environ.get("BAZA_VECTOR_DIMS", "384")))
    parser.add_argument("--ollama-host", default=os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434"))
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--json", action="store_true", help="print machine-readable summary")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    docs_dir = Path(args.docs_dir).expanduser().resolve() if args.docs_dir else root / "docs"
    category = args.category or derive_category(root, docs_dir)
    if not category:
        print("FAIL category missing; pass --category or add project-<slug> to docs/status.md")
        return 2
    if not re.fullmatch(r"project-[a-z0-9][a-z0-9-]*", category):
        print("FAIL category must look like project-<slug>")
        return 2
    out_path = Path(args.out).expanduser().resolve() if args.out else root / ".baza" / "docs-vector" / category / "index.json"

    try:
        index = build_index(
            root,
            docs_dir,
            category,
            out_path,
            args.backend,
            args.model,
            args.dims,
            args.ollama_host,
            args.timeout,
            max(1, args.batch_size),
        )
    except Exception as exc:
        print(f"FAIL {exc}")
        return 1

    summary = {
        "ok": True,
        "category": category,
        "index": str(out_path),
        "backend": index["embedding_backend"],
        "model": index["embedding_model"],
        "dimensions": index["dimensions"],
        "chunks": index["chunk_count"],
        "skipped_secret_like_chunks": index["skipped_secret_like_chunks"],
    }
    if args.json:
        print(json.dumps(summary, indent=2))
    else:
        for key, value in summary.items():
            print(f"{key}: {value}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
