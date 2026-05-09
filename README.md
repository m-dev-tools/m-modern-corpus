# m-modern-corpus

Snapshot collection of modern (non-VistA) M source from active open-source
projects. Used as the in-org default validation corpus for
[`m-cli`](https://github.com/m-dev-tools/m-cli) lint rules and
[`tree-sitter-m`](https://github.com/m-dev-tools/tree-sitter-m) parsing,
confirming that the toolchain doesn't break on idioms outside the VA legacy
style. Maintainers also run the same gates against a private VistA checkout
(via the `CORPUS=` Makefile override) for the full 39,330-routine baseline.

This project is **data only** — no code, no Makefile, no tests. It exists to
be consumed by sibling tooling.

## Subdirectories

| Path | Source |
|---|---|
| `ewd/` | EWD framework |
| `m-web-server/` | YottaDB Web Server (M code) |
| `mgsql/` | mgsql |
| `ydbocto-aux/` | YDBOcto auxiliary routines |
| `ydbtest/` | YDB regression test routines |

Roughly 4K routines total — the benchmark for the m-cli "default profile =
curated daily-lint subset" calibration (3.3 findings/routine).

## How it's used

From `~/projects/m-cli/`:

```bash
make lint-modern    # runs `m lint` over this corpus
```

Results inform rule profile defaults and confirm new lint rules don't
false-positive on modern non-VistA M code.

## Status

Maintenance mode. Snapshot only — not auto-synced as upstream projects
evolve. Re-sync periodically if the corpus drifts too far behind.

## Relationship to other projects

- **[m-cli](https://github.com/m-dev-tools/m-cli)** — primary consumer; uses
  this as the default validation gate for rules
  (`make lint-vista CORPUS=...` and similar gates default to this corpus
  via the in-org `CORPUS=` Makefile flag).
- **[tree-sitter-m](https://github.com/m-dev-tools/tree-sitter-m)** —
  secondary consumer; parses this corpus alongside VistA.
- **[m-standard](https://github.com/m-dev-tools/m-standard)** — evidence
  base for which language features are actually used in modern M projects.
- **vista-meta** *(separate VistA-specific repo, not in m-dev-tools)* —
  companion corpus covering VistA-legacy idioms; maintainers run the
  same gates against it via `CORPUS=$HOME/vista-meta/...` for the full
  39,330-routine baseline.
