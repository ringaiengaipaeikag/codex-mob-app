QUERY ?=
VECTOR_BACKEND ?= local-hash
VECTOR_MODEL ?=
PYTHON ?= python3
MONGO_URI ?= mongodb://localhost:27017/context-hub

BAZA ?= plugins/baza
ENTRY ?= path/to/file

.PHONY: baza-audit baza-docs-sync baza-docs-vector-sync baza-docs-index baza-docs-search baza-docs-health baza-docs-maintenance baza-register-module baza-check-upstreams app-check app-dev

baza-audit:
	$(PYTHON) $(BAZA)/scripts/baza_audit.py

baza-docs-sync:
	$(PYTHON) $(BAZA)/scripts/baza_docs_sync.py --mongo-uri "$(MONGO_URI)"

docs-import: baza-docs-sync

baza-docs-vector-sync:
	$(PYTHON) $(BAZA)/scripts/baza_docs_vector_sync.py --root .

baza-docs-index: baza-docs-vector-sync

baza-docs-search:
	@test -n "$(QUERY)" || (echo "Usage: make baza-docs-search QUERY='search text'" && exit 1)
	$(PYTHON) $(BAZA)/scripts/baza_docs_search.py --root . --query "$(QUERY)"

baza-docs-health:
	$(PYTHON) $(BAZA)/scripts/baza_docs_health.py --root . --mongo-uri "$(MONGO_URI)"

baza-docs-maintenance:
	mongosh --quiet "$(MONGO_URI)" $(BAZA)/scripts/context_hub_maintenance.js

baza-register-module:
	@test -n "$(MODULE)" || (echo "Usage: make baza-register-module MODULE=<name> [ENTRY=path/to/file]" && exit 1)
	$(PYTHON) $(BAZA)/scripts/baza_register_module.py "$(MODULE)" --entry "$(ENTRY)"

baza-check-upstreams:
	$(PYTHON) $(BAZA)/scripts/baza_check_upstreams.py

.PHONY: baza-refresh-projection

baza-refresh-projection:
	$(PYTHON) $(BAZA)/scripts/baza_refresh_projection.py --root .

.PHONY: baza-doctor

baza-doctor:
	$(PYTHON) $(BAZA)/scripts/baza_doctor.py --root .

.PHONY: baza-check-official-sources

baza-check-official-sources:
	$(PYTHON) $(BAZA)/scripts/baza_check_official_sources.py

app-check:
	npm run check

app-dev:
	npm run dev
