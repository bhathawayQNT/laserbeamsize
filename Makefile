PACKAGE         := laserbeamsize

# -------- venv config --------
PY_VERSION      ?= 3.11
VENV            ?= .venv
PY              := /opt/homebrew/opt/python@$(PY_VERSION)/bin/python$(PY_VERSION)
PYTHON          := $(VENV)/bin/python
PIP             := $(VENV)/bin/pip
REQUIREMENTS    ?= requirements-dev.txt

REPO            := scottprahl/laserbeamsize
SITE_BASE_URL   := /laserbeamsize/
BUILD_APPS      := lab
DOCS_DIR        := docs
LITE_DIR        := lite
HTML_DIR        := $(DOCS_DIR)/_build/html
DOIT_DB         := .jupyterlite.doit.db

BASE_URL        := /lite/laserbeamsize/
HOST            := 127.0.0.1
PORT            := 8000

PYTEST          := $(VENV)/bin/pytest
PYLINT          := $(VENV)/bin/pylint
SPHINX          := $(VENV)/bin/sphinx-build
RUFF            := $(VENV)/bin/ruff
BLACK           := $(VENV)/bin/black
PYROMA          := $(PYTHON) -m pyroma
RSTCHECK        := $(PYTHON) -m rstcheck
YAMLLINT        := $(PYTHON) -m yamllint

PYTEST_OPTS     := -q
SPHINX_OPTS     := -T -E -b html -d $(DOCS_DIR)/_build/doctrees -D language=en
NOTEBOOK_RUN    := $(PYTEST) --verbose tests/all_test_notebooks.py

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

.PHONY: help
help:
	@echo "Build Targets:"
	@echo "  dist           - Build sdist+wheel locally"
	@echo "  venv           - Create/provision the virtual environment ($(VENV))"
	@echo "  freeze         - Snapshot venv packages to requirements.lock.txt"
	@echo "  html           - Build Sphinx HTML documentation"
	@echo "  test           - Run pytest"
	@echo "Packaging Targets:"
	@echo "  lint           - Run pylint and yamllint"
	@echo "  rcheck         - Release checks (ruff, tests, docs, manifest, pyroma, notebooks)"
	@echo "  manifest-check - Validate MANIFEST"
	@echo "  note-check     - Validate jupyter notebooks"
	@echo "  rst-check      - Validate all RST files"
	@echo "  ruff-check     - Lint all .py and .ipynb files"
	@echo "  pyroma-check   - Validate overall packaging"
	@echo "JupyterLite Targets:"
	@echo "  run            - Clean lite, build, and serve locally"
	@echo "  lite           - Build JupyterLite site into $(LITE_DIR)"
	@echo "  lite-serve     - Serve $(LITE_DIR) at http://$(HOST):$(PORT)"
	@echo "Clean Targets:"
	@echo "  clean          - Remove build caches and docs output"
	@echo "  lite-clean     - Remove JupyterLite outputs"
	@echo "  realclean      - clean + remove $(VENV)"

# venv bootstrap (runs once, or when requirements change)
$(VENV)/.ready: Makefile $(REQUIREMENTS)
	@echo ">> Ensuring venv at $(VENV) using $(PY)"
	@if [ ! -x "$(PY)" ]; then \
		echo "❌ Homebrew Python $(PY_VERSION) not found at $(PY)"; \
		echo "   Try: brew install python@$(PY_VERSION)"; \
		exit 1; \
	fi
	@if [ ! -d "$(VENV)" ]; then \
		"$(PY)" -m venv "$(VENV)"; \
	fi
	@$(PIP) -q install --upgrade pip wheel
	@echo ">> Installing dev requirements from $(REQUIREMENTS)"
	@$(PIP) -q install -r "$(REQUIREMENTS)"
	@touch "$(VENV)/.ready"
	@echo "✅ venv ready"

.PHONY: venv
venv: $(VENV)/.ready
	@:

# Snapshot exact packages (useful for CI/repro)
.PHONY: freeze
freeze: $(VENV)/.ready
	@$(PIP) freeze > requirements.lock.txt
	@echo "📌 Wrote requirements.lock.txt"

.PHONY: dist
dist: $(VENV)/.ready ## [release] Build sdist and wheel (PEP 517)
	$(PYTHON) -m build
	
.PHONY: test
test: $(VENV)/.ready
	$(PYTEST) $(PYTEST_OPTS) tests

.PHONY: html
html: $(VENV)/.ready       ## Build HTML documentation using Sphinx
	@mkdir -p "$(HTML_DIR)"
	$(SPHINX) $(SPHINX_OPTS) "$(DOCS_DIR)" "$(HTML_DIR)"
	@command -v open >/dev/null 2>&1 && open "$(HTML_DIR)/index.html" || true

.PHONY: lint
lint: $(VENV)/.ready      ## Run pylint and yamllint
	-@$(PYLINT) $(PY_SRC)
	-@$(YAMLLINT) $(YAML_FILES)

.PHONY: rst-check
rst-check: $(VENV)/.ready    ## Validate all RST files
	-@$(RSTCHECK) README.rst
	-@$(RSTCHECK) CHANGELOG.rst
	-@$(RSTCHECK) $(DOCS_DIR)/index.rst
	-@$(RSTCHECK) $(DOCS_DIR)/changelog.rst
	-@$(RSTCHECK) --ignore-directives automodapi $(DOCS_DIR)/analysis.rst
	-@$(RSTCHECK) --ignore-directives automodapi $(DOCS_DIR)/background.rst
	-@$(RSTCHECK) --ignore-directives automodapi $(DOCS_DIR)/display.rst
	-@$(RSTCHECK) --ignore-directives automodapi $(DOCS_DIR)/image_tools.rst
	-@$(RSTCHECK) --ignore-directives automodapi $(DOCS_DIR)/m2_display.rst
	-@$(RSTCHECK) --ignore-directives automodapi $(DOCS_DIR)/m2_fit.rst

.PHONY: note-check
note-check: $(VENV)/.ready    ## Validate notebooks
	$(PYTEST) --verbose tests/all_test_notebooks.py
	@echo "✅ Notebook check complete"

# .PHONY: docs-touch
# docs-touch: $(VENV)/.ready    ## Touch docs only if files exist (avoids glob errors)
# 	@sh -c 'set -e; \
# 	  for p in $(DOCS_DIR)/*.ipynb $(DOCS_DIR)/*.rst; do \
# 	    [ -e "$$p" ] && touch "$$p"; \
# 	  done || true'

.PHONY: ruff-check
ruff-check: $(VENV)/.ready
	$(RUFF) check

.PHONY: manifest-check
manifest-check: $(VENV)/.ready
	check-manifest

.PHONY: pyroma-check
pyroma-check: $(VENV)/.ready
	$(PYROMA) -d .

.PHONY: rcheck
rcheck: realclean ruff-check test lint rst-check html manifest-check pyroma-check note-check lite dist
	@echo "✅ Release checks complete"

.PHONY: lite
lite: $(VENV)/.ready jupyter-lite.json
	@echo ">> Clearing doit cache (if present)"
	@/bin/rm -f "$(DOIT_DB)"
	@echo ">> Preparing notebook files"
	@/bin/rm -rf .lite-temp
	@mkdir -p .lite-temp
	@cp docs/*.ipynb .lite-temp/ 2>/dev/null || true
	@echo ">> Building JupyterLite $(LITE_DIR)/*.ipynb"
	$(PYTHON) -m jupyter lite build \
	  --apps lab \
	  --contents .lite-temp \
	  --output-dir "$(LITE_DIR)"
	@/bin/rm -rf .lite-temp
	cp jupyter-lite.json "$(LITE_DIR)/jupyter-lite.json"
	touch "$(LITE_DIR)/.nojekyll"
	@echo "ok" > "$(LITE_DIR)/.built"
	@echo "✅ Build complete -> $(LITE_DIR)"

.PHONY: run
run: lite-clean lite lite-serve

.PHONY: lite-serve
lite-serve: $(VENV)/.ready
	@test -f "$(LITE_DIR)/index.html" || { echo "❌ $(LITE_DIR)/index.html not found. Run: make lite"; exit 1; }
	@# Create a symlink so /lite/laserbeamsize/ maps to your built lite/
	@mkdir -p "$(LITE_DIR)"
	@[ -L "$(LITE_DIR)/laserbeamsize" ] || ( cd "$(LITE_DIR)" && ln -s . laserbeamsize )
	@echo ">> Serving repo root at http://$(HOST):$(PORT) (symlink: $(LITE_DIR)/laserbeamsize -> .)"
	@python3 -m http.server "$(PORT)" --bind "$(HOST)" --directory "$(PWD)" &
	@sleep 1
	@command -v open >/dev/null 2>&1 && open "http://$(HOST):$(PORT)/lite/laserbeamsize/" || true
	@wait

.PHONY: lite-clean
lite-clean:
	@echo ">> Cleaning output and staging dirs"
	@/bin/rm -rf "$(LITE_DIR)" .lite_contents
	@/bin/rm -f "$(DOIT_DB)"
	@if [ -d ".gh-pages" ]; then \
	    git worktree remove .gh-pages; \
	fi

# .PHONY: lite-deploy
# lite-deploy:
# 	@test -f "$(LITE_DIR)/index.html" || { echo "❌ $(LITE_DIR)/index.html not found. Run: make lite"; exit 1; }
# 	@echo ">> Deploying $(LITE_DIR)/ -> $(DEPLOY_USER)@$(DEPLOY_HOST):$(DEPLOY_PATH)"
# 	rsync $(RSYNC_OPTS) -e "$(RSYNC_SSH)" "$(LITE_DIR)/" "$(DEPLOY_USER)@$(DEPLOY_HOST):$(DEPLOY_PATH)"
# 	@echo ">> Opening $(DEPLOY_URL)"
# 	@command -v open >/dev/null 2>&1 && open "$(DEPLOY_URL)" || echo "Open: $(DEPLOY_URL)"

.PHONY: lite-deploy
lite-deploy: lite
	@echo ">> Publishing $(LITE_DIR) to github-pages"
	# Create or reuse a worktree for gh-pages branch
	@if ! git show-ref --verify --quiet refs/heads/gh-pages; then \
	    git switch --orphan gh-pages && \
	    git commit --allow-empty -m "Initial gh-pages commit" && \
	    git switch -; \
	fi
	@if [ ! -d ".gh-pages" ]; then \
	    git worktree add .gh-pages gh-pages; \
	fi
	# Copy the built site
	rm -rf .gh-pages/*
	cp -R $(LITE_DIR)/* .gh-pages/
	# Commit and push changes
	cd .gh-pages && \
	    git add -A && \
	    git commit -m "Deploy $$(date -u +'%Y-%m-%d %H:%M:%S UTC')" || true
	cd .gh-pages && git push origin gh-pages
	@echo "✅ Deployed to https://scottprahl.github.io/laserbeamsize/"

.PHONY: clean
clean: ## Remove cache, build artifacts, docs output, and JupyterLite build (but keep config)
	@echo "==> Cleaning build artifacts"	
	@find . -name '__pycache__' -type d -exec rm -rf {} +
	@find . -name '.DS_Store' -type f -delete
	@find . -name '.ipynb_checkpoints' -type d -prune -exec rm -rf {} +
	@rm -rf \
		.DS_store \
		.cache \
		.eggs \
		.pytest_cache \
		.ruff_cache \
		.virtual_documents \
		dist \
		build \
		$(PACKAGE).egg-info \
		$(DOCS_DIR)/_build \
		$(DOCS_DIR)/api \

.PHONY: realclean
realclean: lite-clean clean
	@/bin/rm -rf "$(VENV)"

