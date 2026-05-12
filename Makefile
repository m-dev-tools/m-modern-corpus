# m-modern-corpus — data repo. No build, no tests. The only "build"
# here is regenerating the discovery artifacts in dist/ from the
# corpus contents, gated for drift on every push.

.PHONY: manifest check-manifest check-docs-prose \
        corpus-status corpus-fetch corpus-list corpus-verify help

help:
	@echo "Manifest / discovery:"
	@echo "  manifest         regenerate dist/manifest.json + dist/stats.json"
	@echo "  check-manifest   regen + git diff (CI drift gate)"
	@echo "  check-docs-prose enforce docs/ is prose-only (cross-repo guardrail)"
	@echo
	@echo "Corpus snapshots:"
	@echo "  corpus-status    show which subdirs are present vs missing"
	@echo "  corpus-list      print the upstream provenance table (sources.tsv)"
	@echo "  corpus-fetch     clone any missing subdirs (idempotent, no-op when complete)"
	@echo "  corpus-verify    diff each subdir vs upstream HEAD (drift report, read-only)"
	@echo
	@echo "  For deliberate snapshot refresh, invoke the script directly:"
	@echo "    tools/fetch-corpus.sh refresh <subdir>"
	@echo "    tools/fetch-corpus.sh refresh --all"

# Regenerate the discovery artifacts from corpus contents.
manifest:
	python3 tools/gen-manifest.py

# Phase-0 drift gate: regenerate, then assert the working tree is clean.
# Same shape as m-stdlib's manifest-check and m-cli's check-manifest.
check-manifest: manifest
	@git diff --exit-code dist/ \
	  || { echo "ERROR: dist/ drift — run 'make manifest' and commit."; exit 1; }
	@echo "check-manifest: clean"

# Corpus discovery / download — thin wrappers over tools/fetch-corpus.sh.
# The script is the source of truth; these targets exist so the repo's
# entry points are visible from `make help`.
corpus-status:
	@tools/fetch-corpus.sh status

corpus-list:
	@tools/fetch-corpus.sh list

corpus-fetch:
	@tools/fetch-corpus.sh fetch

corpus-verify:
	@tools/fetch-corpus.sh verify

# Guardrail: docs/ holds only human-readable prose. Non-prose artifacts
# (data, output, metadata, examples) belong elsewhere. Same target name
# as the tier-1 repos so a contributor finds it predictable.
check-docs-prose:
	@if [ ! -d docs ]; then echo "check-docs-prose: no docs/ directory ✓"; exit 0; fi; \
	violations=$$(find docs -type f \
	    ! -name '*.md' ! -name '*.markdown' \
	    ! -name '*.png' ! -name '*.jpg' ! -name '*.jpeg' \
	    ! -name '*.gif' ! -name '*.svg' ! -name '*.webp' \
	    ! -name '.gitkeep'); \
	if [ -n "$$violations" ]; then \
	  echo "ERROR: non-prose files under docs/ — move to a top-level domain dir:" >&2; \
	  echo "$$violations" >&2; \
	  exit 1; \
	fi; \
	echo "check-docs-prose: docs/ is prose-only ✓"
