---
# Machine-readable project descriptor — schema v1 (2026-05-05).
name: m-modern-corpus
kind: [data, corpus]
status: maintenance                        # static reference corpus
languages: [mumps]

runtime:
  needs: []                                # data only
  optional: []
  excludes: []

distribution:
  pypi: null
  github: null                             # local-only

location: ~/projects/m-modern-corpus

exposes:
  corpora:                                 # subdirectories of M source from modern OSS projects
    - "ewd/"                               # EWD-related
    - "m-web-server/"                      # M-Web-Server (YDB Web Server)
    - "mgsql/"                             # mgsql
    - "ydbocto-aux/"                       # YDBOcto auxiliary routines
    - "ydbtest/"                           # YDB test corpus
  formats_produced: []                     # consumed only

consumes:
  formats: []
  services: []

companions:
  - project: m-cli
    relation: "validation gate — `m lint` runs against this corpus to verify rules don't false-positive on modern non-VistA M code (4K+ routines)"
  - project: tree-sitter-m
    relation: "secondary parsing corpus alongside VistA — confirms grammar handles modern idioms"
  - project: m-standard
    relation: "evidence base for which language features are actually used in modern M projects"

incompatibilities:
  - "Snapshot only — not maintained as upstream evolves. Re-sync periodically if needed."
  - "Not a substitute for the VistA corpus (~40k routines at vista-meta/vista/vista-m-host/Packages); the two cover different idioms (legacy VA vs modern OSS)."

docs:
  primary: null                            # no README; structure is self-documenting
---

# m-modern-corpus

Snapshot collection of modern (non-VistA) M source from active open-source
projects. Used as a validation corpus alongside the VistA corpus (vista-meta's
`vista/vista-m-host/Packages/`) to confirm that m-cli rules and tree-sitter-m
parsing don't break on idioms outside the VA legacy style.

## Subdirectories

- `ewd/` — EWD framework
- `m-web-server/` — YottaDB Web Server (M code)
- `mgsql/` — mgsql
- `ydbocto-aux/` — YDBOcto auxiliary routines
- `ydbtest/` — YDB regression test routines

## How it's used

```bash
# From m-cli/
make lint-modern    # runs `m lint` over the corpus
```

Results inform rule profile defaults. The 4K-routine modern corpus is the
benchmark for "default profile = curated daily-lint subset" (3.3 findings/routine).

## Setup

This is a data repo — no install. Clone and it's ready:

```bash
git clone https://github.com/m-dev-tools/m-modern-corpus
```

Python 3 is the only dependency, used by `make manifest` to count routines
and regenerate `dist/*.json`. No virtualenv needed.

## Test

Not applicable — this repo carries no executable code. The "test" of the
corpus is performed by *consuming* tools (`m lint`, `tree-sitter-m`) running
against it. See those repos for their own CI.

## Build / generate

```bash
make manifest         # regenerate dist/manifest.json + dist/stats.json from corpus contents
```

The two committed `dist/*.json` artifacts are deterministic outputs of
`tools/gen-manifest.py` over the corpus subdirectories. Re-running `make
manifest` on an unchanged corpus must produce byte-identical files; CI's
`make check-manifest` gates on this.

## Verify

The `verification_commands` declared in `dist/repo.meta.json`:

```bash
make manifest          # regenerate
make check-manifest    # drift gate: regen + git diff --exit-code dist/
```

Plus the cross-repo guardrail:

```bash
make check-docs-prose  # docs/ holds only prose; this repo has no docs/ at all, so this is trivially green
```

## Guardrails

- **Do not hand-edit `dist/manifest.json` or `dist/stats.json`.** They are
  pipeline outputs of `tools/gen-manifest.py`; the CI drift gate will
  reject any direct edit.
- **Do not auto-sync from upstream.** Each subdirectory is a deliberate
  *snapshot* — refreshing it is a manual operation (see `LICENSES.md` §
  "Snapshot policy") with a corresponding new commit. Background sync
  daemons would break the snapshot semantic.
- **Do not bundle binaries.** The corpus is M source (`.m` files), prose,
  and per-subdir license artifacts only. Pre-built objects / docker
  images / wheels belong in their upstream repos, not here.
- **Per-subdir licenses are authoritative.** When in doubt about a file's
  redistribution status, defer to that subdirectory's `LICENSE` /
  `COPYING` / `NOTICE` — not to this repo's top-level `LICENSES.md` table,
  which is a summary only.
- **No tests live here.** If you need to test that consuming tools handle
  this corpus correctly, write that test *in the consuming tool's repo*
  (m-cli's `make lint-modern`, tree-sitter-m's parse harness, etc.).
