# Makefile for scottprahl/laserbeamsize
# Use "make help" to list available targets.

SHELL := /bin/bash

# --------------------------- Configuration -----------------------------------

PACKAGE      := laserbeamsize
DOCS_DIR     := docs
BUILD_DIR    := $(DOCS_DIR)/_build/html
NOTEBOOK_RUN := pytest --verbose tests/all_test_notebooks.py

PYTEST       := pytest
PYTEST_FLAGS := -q

SPHINXOPTS   := -T -E -b html -d $(DOCS_DIR)/_build/doctrees -D language=en

PY_SRC := \
	$(PACKAGE)/*.py \
	tests/*.py

YAML_FILES := \
	.github/workflows/citation.yaml \
	.github/workflows/pypi.yaml \
	.github/workflows/test.yaml

RST_FILES := \
	README.rst \
	CHANGELOG.rst \
	$(DOCS_DIR)/index.rst \
	$(DOCS_DIR)/changelog.rst \
	$(DOCS_DIR)/analysis.rst \
	$(DOCS_DIR)/background.rst \
	$(DOCS_DIR)/display.rst \
	$(DOCS_DIR)/image_tools.rst \
	$(DOCS_DIR)/m2_display.rst \
	$(DOCS_DIR)/m2_fit.rst \
	$(DOCS_DIR)/masks.rst

# ---- JupyterLite config ----
LITE_DIR      := lite
LITE_OUT      := $(LITE_DIR)/_output
LITE_CONTENTS := docs
LITE_APPS     := lab tree repl
LITE_WHEELS   := $(LITE_DIR)/wheels
PYODIDE_URL   := https://cdn.jsdelivr.net/pyodide/v0.26.2/full/

# ----------------------------- Targets ---------------------------------------

.PHONY: test html lint rstcheck rcheck clean help

help: ## Show this help message
	@echo "Available make targets:"
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_.-]+:.*## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

test: ## Run all unit tests using pytest
	$(PYTEST) $(PYTEST_FLAGS) tests

html: ## Build HTML documentation using Sphinx
	@mkdir -p $(BUILD_DIR)
	cd $(DOCS_DIR) && python -m sphinx $(SPHINXOPTS) . _build/html
	@command -v open >/dev/null 2>&1 && open $(BUILD_DIR)/index.html || true

lint: ## Run pylint and yamllint
	-@pylint $(PY_SRC)
	-@yamllint $(YAML_FILES)

rstcheck: ## Validate all RST files
	-@rstcheck README.rst
	-@rstcheck CHANGELOG.rst
	-@rstcheck $(DOCS_DIR)/index.rst
	-@rstcheck $(DOCS_DIR)/changelog.rst
	-@rstcheck --ignore-directives automodapi $(DOCS_DIR)/analysis.rst
	-@rstcheck --ignore-directives automodapi $(DOCS_DIR)/background.rst
	-@rstcheck --ignore-directives automodapi $(DOCS_DIR)/display.rst
	-@rstcheck --ignore-directives automodapi $(DOCS_DIR)/image_tools.rst
	-@rstcheck --ignore-directives automodapi $(DOCS_DIR)/m2_display.rst
	-@rstcheck --ignore-directives automodapi $(DOCS_DIR)/m2_fit.rst
	-@rstcheck --ignore-directives automodapi $(DOCS_DIR)/masks.rst

rcheck: ## Run full repo checks: linting, tests, docs, manifest, and quality
	$(MAKE) clean
	ruff check
	$(MAKE) test
	$(MAKE) lint
	$(MAKE) rstcheck
	@touch $(DOCS_DIR)/*.ipynb || true
	@touch $(DOCS_DIR)/*.rst   || true
	$(MAKE) html
	check-manifest
	pyroma -d .
	$(NOTEBOOK_RUN)

lite: ## Build a JupyterLite site (Pyodide) from docs with laserbeamsize bundled
	@mkdir -p "$(LITE_DIR)/wheels"
	@python -m build --wheel --outdir "$(LITE_DIR)/wheels"
	jupyter lite build \
		--lite-dir "$(LITE_DIR)" \
		--contents "$(LITE_CONTENTS)" \
		--output-dir "$(LITE_OUT)" \
		$(foreach app,$(LITE_APPS),--apps $(app) ) \
		--disable-addons '@jupyterlite/xeus-python-kernel'
	@if [ -f "$(LITE_DIR)/jupyter-lite.json" ]; then \
	  cp -f "$(LITE_DIR)/jupyter-lite.json" "$(LITE_OUT)/jupyter-lite.json"; \
	fi
	@echo "Done! Site at: $(LITE_OUT)"
	
lite-audit: ## Quick health check of the built JupyterLite site
	@set -e; \
	OUT="$(LITE_OUT)"; \
	echo "🔎 Auditing $$OUT"; \
	if [ ! -d "$$OUT" ]; then echo "❌ No output dir. Run: make lite"; exit 1; fi; \
	if [ ! -f "$$OUT/index.html" ]; then echo "❌ $$OUT/index.html missing"; exit 1; fi; \
	if [ ! -f "$$OUT/jupyter-lite.json" ]; then echo "❌ $$OUT/jupyter-lite.json missing (config not copied)"; exit 1; fi; \
	if ! grep -q 'pyodide-kernel-extension' "$$OUT/jupyter-lite.json"; then \
	  echo "❌ jupyter-lite.json missing federated_extensions for Pyodide kernel"; exit 1; fi; \
	echo "✅ index.html present"; \
	echo "✅ jupyter-lite.json present and contains pyodide kernel extension"; \
	echo "ℹ️  Next: make lite-serve and open the printed Lab URL with ?disableSW=1&reset"

lite-serve: ## Serve the JupyterLite site with cache-busting URLs
	@if [ ! -d "$(LITE_OUT)" ] || [ ! -f "$(LITE_OUT)/index.html" ]; then \
	  echo "JupyterLite site not found at $(LITE_OUT)"; \
	  echo "Run: make lite"; \
	  exit 1; \
	fi; \
	PORT="$${LITE_PORT:-8000}"; \
	while lsof -nP -iTCP:"$$PORT" -sTCP:LISTEN >/dev/null 2>&1; do \
	  PORT=$$((PORT+1)); \
	done; \
	BASE="http://127.0.0.1:$$PORT"; \
	LAB_URL="$$BASE/lab?disableSW=1&reset"; \
	TREE_URL="$$BASE/tree?disableSW=1&reset"; \
	REPL_URL="$$BASE/repl?disableSW=1&reset"; \
	echo "Serving: $(LITE_OUT)"; \
	echo "Port:    $$PORT   (override: make LITE_PORT=8010 lite-serve)"; \
	echo "Lab:     $$LAB_URL"; \
	echo "Tree:    $$TREE_URL"; \
	echo "REPL:    $$REPL_URL"; \
	if command -v open >/dev/null 2>&1; then (sleep 1; open "$$LAB_URL") & fi; \
	exec python3 -m http.server "$$PORT" --directory "$(LITE_OUT)"

clean: ## Remove cache, build artifacts, docs output, and JupyterLite build (but keep config)
	@echo "Cleaning caches, build artifacts, docs output, and lite site..."
	@find . -name '.DS_Store' -type f -delete
	@find . -name '__pycache__' -type d -prune -exec rm -rf {} +
	@find . -name '.ipynb_checkpoints' -type d -prune -exec rm -rf {} +
	@rm -rf \
		.eggs \
		.pytest_cache \
		.ruff_cache \
		.virtual_documents \
		dist \
		build \
		$(PACKAGE).egg-info \
		$(DOCS_DIR)/_build \
		$(DOCS_DIR)/api \
		$(LITE_DIR)/_output \
		$(LITE_DIR)/wheels

.PHONY: clean rcheck html notecheck pycheck doccheck test rstcheck help
.PHONY: lite lite-audit lite-serve
