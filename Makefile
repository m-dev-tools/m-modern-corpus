# m-modern-corpus — data repo. No build, no tests. The only "build"
# here is regenerating the discovery artifacts in dist/ from the
# corpus contents, gated for drift on every push.

.PHONY: manifest check-manifest check-docs-prose help

help:
	@echo "Targets:"
	@echo "  manifest         regenerate dist/manifest.json + dist/stats.json"
	@echo "  check-manifest   regen + git diff (CI drift gate)"
	@echo "  check-docs-prose enforce docs/ is prose-only (cross-repo guardrail)"

# Regenerate the discovery artifacts from corpus contents.
manifest:
	python3 tools/gen-manifest.py

# Phase-0 drift gate: regenerate, then assert the working tree is clean.
# Same shape as m-stdlib's manifest-check and m-cli's check-manifest.
check-manifest: manifest
	@git diff --exit-code dist/ \
	  || { echo "ERROR: dist/ drift — run 'make manifest' and commit."; exit 1; }
	@echo "check-manifest: clean"

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
