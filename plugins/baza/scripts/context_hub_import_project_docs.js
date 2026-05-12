// Generic BAZA context-hub importer for sanitized Markdown docs.
// Usage: mongosh --quiet "$MONGO_URI" plugins/baza/scripts/context_hub_import_project_docs.js

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const ROOT = process.env.PROJECT_ROOT || process.cwd();
const DOCS_DIR = process.env.PROJECT_DOCS_DIR || path.join(ROOT, "docs");
const SCHEMA_VERSION = "baza-context-hub-docs-v2";
const CHUNKER_VERSION = "baza-docs-chunker-v2";

function detectCategory() {
  if (process.env.PROJECT_DOCS_CATEGORY) return process.env.PROJECT_DOCS_CATEGORY;
  const status = path.join(DOCS_DIR, "status.md");
  if (!fs.existsSync(status)) return "project-unknown";
  const text = fs.readFileSync(status, "utf8");
  const matches = [...text.matchAll(/\bproject-[a-z0-9][a-z0-9-]*\b/g)]
    .map((item) => item[0])
    .filter((item) => item !== "project-bootstrap");
  return matches[matches.length - 1] || "project-unknown";
}

const CATEGORY = detectCategory();

function sourceName(relativePath) {
  const noExt = relativePath.replace(/\.md$/i, "");
  if (noExt === "README") return "readme";
  if (noExt === "architecture") return "architecture";
  const parts = noExt.split(path.sep);
  const base = parts[parts.length - 1];
  const dir = parts.length > 1 ? parts[0] : "";
  const prefixes = {
    agents: "agents",
    api: "api",
    bugs: "bug",
    decisions: "decision",
    experiments: "experiment",
    modules: "module",
    runbooks: "runbook",
    setup: "setup",
    "source-dossiers": "source-dossier",
  };
  return [prefixes[dir], base].filter(Boolean).join("-").replace(/[^A-Za-z0-9_-]+/g, "-");
}

function slug(text, fallback) {
  const value = text
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^\p{Letter}\p{Number}]+/gu, "-")
    .replace(/^-+|-+$/g, "");
  return value || `section-${fallback}`;
}

function walkMarkdown(dir) {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      out.push(...walkMarkdown(full));
    } else if (entry.isFile() && entry.name.endsWith(".md")) {
      out.push(full);
    }
  }
  return out.sort();
}

function sha256(text) {
  return crypto.createHash("sha256").update(text).digest("hex");
}

function hashDocs(files) {
  const h = crypto.createHash("sha256");
  for (const file of files) {
    const relative = path.relative(DOCS_DIR, file).split(path.sep).join("/");
    h.update(relative);
    h.update("\0");
    h.update(fs.readFileSync(file));
    h.update("\0");
  }
  return h.digest("hex");
}

function approxTokens(text) {
  const words = text.match(/[\p{Letter}\p{Number}_-]+/gu) || [];
  return Math.max(1, words.length);
}

function keywords(text) {
  const stop = new Set([
    "the", "and", "for", "with", "this", "that", "from", "into", "when", "then",
    "что", "как", "для", "или", "это", "при", "если", "без", "под",
  ]);
  const counts = new Map();
  for (const raw of text.toLowerCase().match(/[\p{Letter}\p{Number}_-]{3,}/gu) || []) {
    if (stop.has(raw)) continue;
    counts.set(raw, (counts.get(raw) || 0) + 1);
  }
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, 20)
    .map(([word]) => word);
}

function links(text) {
  const found = new Set();
  const re = /\[[^\]]+\]\(([^)]+)\)/g;
  let match;
  while ((match = re.exec(text))) {
    const target = match[1].trim();
    if (target && !target.startsWith("http")) found.add(target);
  }
  return [...found];
}

function chunksFor(filePath, source) {
  const text = fs.readFileSync(filePath, "utf8").replace(/\r\n/g, "\n");
  const lines = text.split("\n");
  const chunks = [];
  let order = 0;
  let seenHeading = false;
  let headings = [];
  let currentTitle = path.basename(filePath, ".md");
  let currentHeadings = [];
  let body = [];
  const slugCounts = new Map();

  function flush() {
    const content = body.join("\n").trim();
    const title = currentTitle.trim();
    if (!seenHeading && !content) return;
    if (!title && !content) return;
    const finalContent = content || title;
    const baseSlug = slug(title, order);
    const count = (slugCounts.get(baseSlug) || 0) + 1;
    slugCounts.set(baseSlug, count);
    const sectionSlug = count === 1 ? baseSlug : `${baseSlug}-${count}`;
    const chunkPath = `${CATEGORY}/${source}#${sectionSlug}`;
    const chunkId = `${CATEGORY}:${sha256(`${chunkPath}\n${finalContent}`).slice(0, 24)}`;
    chunks.push({
      _id: chunkId,
      chunkId,
      sourceId: `local:${CATEGORY}/${source}`,
      category: CATEGORY,
      path: chunkPath,
      title,
      headings: currentHeadings.length ? currentHeadings : [title],
      content: finalContent,
      tokens: approxTokens(finalContent),
      keywords: keywords(`${title}\n${finalContent}`),
      links: links(finalContent),
      order: order++,
    });
  }

  for (const line of lines) {
    const match = /^(#{1,6})\s+(.+?)\s*$/.exec(line);
    if (match) {
      flush();
      seenHeading = true;
      const level = match[1].length;
      currentTitle = match[2].replace(/`/g, "").trim();
      headings = headings.slice(0, level - 1);
      headings[level - 1] = currentTitle;
      currentHeadings = headings.filter(Boolean);
      body = [];
    } else {
      body.push(line);
    }
  }
  flush();
  return chunks;
}

if (CATEGORY === "project-unknown") {
  throw new Error("PROJECT_DOCS_CATEGORY is not set and no project category was found in docs/status.md");
}

const docs = walkMarkdown(DOCS_DIR);
if (!docs.length) {
  throw new Error(`No Markdown docs found: ${DOCS_DIR}`);
}

let insertedSources = 0;
let insertedChunks = 0;
let updatedSources = 0;
let deletedSources = 0;
let deletedChunks = 0;
let totalTokens = 0;
const sourceIds = [];
const docsHash = hashDocs(docs);
const syncedAt = new Date();

for (const file of docs) {
  const relative = path.relative(DOCS_DIR, file);
  const name = sourceName(relative);
  const sourceId = `local:${CATEGORY}/${name}`;
  sourceIds.push(sourceId);
  const chunks = chunksFor(file, name);
  const sourceDoc = {
    _id: sourceId,
    name,
    type: "local",
    origin: path.resolve(file),
    relativePath: relative.split(path.sep).join("/"),
    category: CATEGORY,
    schemaVersion: SCHEMA_VERSION,
    chunkerVersion: CHUNKER_VERSION,
    sourceHash: sha256(fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n")),
    lastIndexed: syncedAt,
    chunkCount: chunks.length,
    totalTokens: chunks.reduce((sum, chunk) => sum + chunk.tokens, 0),
    status: "indexed",
  };
  totalTokens += sourceDoc.totalTokens;
  const existing = db.doc_sources.findOne({ _id: sourceId });
  db.doc_sources.replaceOne({ _id: sourceId }, sourceDoc, { upsert: true });
  if (existing) {
    updatedSources += 1;
  } else {
    insertedSources += 1;
  }
  deletedChunks += db.doc_chunks.deleteMany({ sourceId }).deletedCount;
  if (chunks.length) db.doc_chunks.insertMany(chunks);
  insertedChunks += chunks.length;
}

const staleSources = db.doc_sources.find({
  category: CATEGORY,
  _id: { $nin: sourceIds },
}).toArray();
for (const source of staleSources) {
  deletedChunks += db.doc_chunks.deleteMany({ sourceId: source._id }).deletedCount;
}
deletedSources = db.doc_sources.deleteMany({
  category: CATEGORY,
  _id: { $nin: sourceIds },
}).deletedCount;

db.doc_manifests.replaceOne(
  { _id: CATEGORY },
  {
    _id: CATEGORY,
    category: CATEGORY,
    schemaVersion: SCHEMA_VERSION,
    chunkerVersion: CHUNKER_VERSION,
    docsDir: path.resolve(DOCS_DIR),
    docsHash,
    sourceCount: docs.length,
    chunkCount: insertedChunks,
    totalTokens,
    lastSyncedAt: syncedAt,
    status: "indexed",
  },
  { upsert: true }
);

printjson({
  category: CATEGORY,
  docsDir: path.resolve(DOCS_DIR),
  schemaVersion: SCHEMA_VERSION,
  chunkerVersion: CHUNKER_VERSION,
  docsHash,
  updatedSources,
  deletedSources,
  deletedChunks,
  insertedSources,
  insertedChunks,
});
