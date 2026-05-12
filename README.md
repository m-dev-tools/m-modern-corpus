# m-modern-corpus

Snapshot collection of modern (non-VistA) M source from active open-source
projects. Used as a validation corpus alongside the VistA corpus
(`vista-meta/vista/vista-m-host/Packages/`) to confirm that
[`m-cli`](https://github.com/m-dev-tools/m-cli) lint rules and
[`tree-sitter-m`](https://github.com/m-dev-tools/tree-sitter-m) parsing don't
break on idioms outside the VA legacy style.

This project is **data-first** — its purpose is to be consumed by sibling
tooling. The only code is two small helpers under [tools/](tools/):
[`fetch-corpus.sh`](tools/fetch-corpus.sh) reproduces / refreshes the
snapshots from upstream, and [`gen-manifest.py`](tools/gen-manifest.py)
emits the discovery artifacts under [dist/](dist/). Both read the same
provenance table at [tools/sources.tsv](tools/sources.tsv).

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

From a sibling checkout of `m-cli` in the same workspace
(`~/m-dev-tools/m-cli/`):

```bash
make lint-modern    # runs `m lint` over this corpus
```

Results inform rule profile defaults and confirm new lint rules don't
false-positive on modern non-VistA M code.

## Build / verify

The repo ships two families of `make` targets. The first regenerates the
discovery artifacts — these are declared as the `verification_commands`
in [`dist/repo.meta.json`](dist/repo.meta.json):

```bash
make manifest         # regenerate dist/manifest.json + dist/stats.json
make check-manifest   # drift gate: regenerate, then `git diff --exit-code dist/`
```

The second family is for snapshot reproducibility — `tools/fetch-corpus.sh`
is the single entrypoint:

```bash
make corpus-status    # which subdirs are present vs missing
make corpus-list      # print the upstream provenance table (sources.tsv)
make corpus-fetch     # clone any missing subdirs (no-op when complete)
make corpus-verify    # diff each subdir vs upstream HEAD (drift report, read-only)
```

For a deliberate snapshot refresh, invoke the script directly:

```bash
tools/fetch-corpus.sh refresh <subdir>     # re-clone one
tools/fetch-corpus.sh refresh --all        # re-clone everything
```

Every fetch/refresh records `{upstream HEAD SHA, fetched_at}` per subdir
in [`dist/sources.lock.json`](dist/sources.lock.json) so the snapshot's
provenance is committed alongside the source. The `dist/*.json` files are
deterministic outputs of `tools/gen-manifest.py` — do not hand-edit them.
Python 3, bash 5, and `git` are the only dependencies.

## Status

Maintenance mode. Snapshot only — not auto-synced as upstream projects
evolve. Re-sync periodically if the corpus drifts too far behind.

## Relationship to other projects

- **m-cli** — primary consumer; uses this as a validation gate for rules.
- **tree-sitter-m** — secondary consumer; parses this corpus alongside VistA.
- **m-standard** — evidence base for which language features are actually
  used in modern M projects.
- **vista-meta** — companion corpus (VistA legacy) covering complementary idioms.
