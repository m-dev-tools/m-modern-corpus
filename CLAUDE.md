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
