// BAZA context-hub maintenance indexes.
// Usage: mongosh --quiet "$MONGO_URI" plugins/baza/scripts/context_hub_maintenance.js

db.doc_sources.createIndex(
  { category: 1, lastIndexed: -1 },
  { name: "category_lastIndexed" }
);

db.doc_sources.createIndex(
  { category: 1, name: 1 },
  { name: "category_name" }
);

db.doc_chunks.createIndex(
  { category: 1, sourceId: 1, order: 1 },
  { name: "category_source_order" }
);

db.doc_chunks.createIndex(
  { category: 1, path: 1 },
  { name: "category_path" }
);

db.doc_manifests.createIndex(
  { category: 1 },
  { name: "category_unique", unique: true }
);

db.doc_manifests.createIndex(
  { lastSyncedAt: -1 },
  { name: "lastSyncedAt_desc" }
);

printjson({
  ok: true,
  doc_sources: db.doc_sources.getIndexes().map((item) => item.name).sort(),
  doc_chunks: db.doc_chunks.getIndexes().map((item) => item.name).sort(),
  doc_manifests: db.doc_manifests.getIndexes().map((item) => item.name).sort(),
});
