#!/usr/bin/env python3
"""Generate dist/manifest.json + dist/stats.json from the corpus subdirectories.

Inputs (live filesystem state):
  - The top-level corpus subdirectories, each containing `.m` source from
    one upstream.
  - tools/sources.tsv — the subdir → upstream URL → license mapping
    (shared with tools/fetch-corpus.sh; single source of truth).
  - LICENSES.md — the human-readable mirror of sources.tsv.

Outputs:
  - dist/manifest.json — array of {name, upstream, license, routine_count, loc}
    entries, sorted by name.
  - dist/stats.json — aggregate counts (routines / LOC / per-license breakdown
    / subdir count) plus `generated_from` provenance.

Determinism:
  - sorted subdirs, sorted JSON keys, fixed 2-space indent, trailing newline.
  - Running twice on an unchanged corpus must produce byte-identical output.
  - CI's `make check-manifest` gates on this.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCHEMA_VERSION = "1"


def load_sources(sources_tsv: Path) -> dict[str, tuple[str, str]]:
    """Parse tools/sources.tsv → {subdir: (upstream_url, license_spdx)}.

    The TSV is the shared source of truth with tools/fetch-corpus.sh.
    Comment lines (`#…`) and blanks are skipped. Columns are:
    subdir<TAB>upstream_clone_url<TAB>license_spdx<TAB>description.
    """
    out: dict[str, tuple[str, str]] = {}
    for lineno, raw in enumerate(sources_tsv.read_text().splitlines(), start=1):
        line = raw.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            print(
                f"ERROR: {sources_tsv}:{lineno}: expected ≥3 TAB-separated "
                f"columns, got {len(parts)}",
                file=sys.stderr,
            )
            sys.exit(2)
        subdir, url, license_spdx = parts[0], parts[1], parts[2]
        out[subdir] = (url, license_spdx)
    return out


def count_subdir(root: Path, name: str) -> tuple[int, int]:
    """Return (routine_count, loc) for `.m` files under root/name."""
    routines = sorted((root / name).rglob("*.m"))
    routine_count = len(routines)
    loc = 0
    for path in routines:
        try:
            with path.open("rb") as f:
                loc += sum(1 for _ in f)
        except OSError as exc:
            print(f"WARN: could not read {path}: {exc}", file=sys.stderr)
    return routine_count, loc


def build_manifest(root: Path, sources: dict[str, tuple[str, str]]) -> list[dict]:
    """Build the per-subdir manifest array."""
    entries: list[dict] = []
    for name in sorted(sources):
        upstream, license_id = sources[name]
        if not (root / name).is_dir():
            print(
                f"ERROR: declared subdir {name!r} not present at {root / name}",
                file=sys.stderr,
            )
            sys.exit(1)
        routine_count, loc = count_subdir(root, name)
        entries.append(
            {
                "name": name,
                "upstream": upstream,
                "license": license_id,
                "routine_count": routine_count,
                "loc": loc,
            }
        )
    return entries


def build_stats(manifest: list[dict]) -> dict:
    """Aggregate the manifest into corpus-level stats."""
    total_routines = sum(e["routine_count"] for e in manifest)
    total_loc = sum(e["loc"] for e in manifest)

    by_license: dict[str, dict[str, int]] = {}
    for entry in manifest:
        bucket = by_license.setdefault(
            entry["license"], {"routine_count": 0, "loc": 0, "subdir_count": 0}
        )
        bucket["routine_count"] += entry["routine_count"]
        bucket["loc"] += entry["loc"]
        bucket["subdir_count"] += 1

    return {
        "schema_version": SCHEMA_VERSION,
        "subdir_count": len(manifest),
        "total_routines": total_routines,
        "total_loc": total_loc,
        "license_breakdown": dict(sorted(by_license.items())),
        "generated_from": "tools/gen-manifest.py over corpus subdirectories",
    }


def write_json(path: Path, payload) -> None:
    """Deterministic JSON write — sorted keys, 2-space indent, trailing newline."""
    path.parent.mkdir(parents=True, exist_ok=True)
    body = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    path.write_text(body, encoding="utf-8")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Repo root (defaults to the parent of tools/).",
    )
    parser.add_argument(
        "--sources",
        type=Path,
        default=None,
        help="Path to sources.tsv (defaults to <root>/tools/sources.tsv).",
    )
    args = parser.parse_args(argv[1:])

    sources_tsv = args.sources or (args.root / "tools" / "sources.tsv")
    if not sources_tsv.is_file():
        print(f"ERROR: sources table not found at {sources_tsv}", file=sys.stderr)
        return 2
    sources = load_sources(sources_tsv)

    manifest_entries = build_manifest(args.root, sources)
    manifest_payload = {
        "schema_version": SCHEMA_VERSION,
        "subdirs": manifest_entries,
    }
    stats_payload = build_stats(manifest_entries)

    dist = args.root / "dist"
    write_json(dist / "manifest.json", manifest_payload)
    write_json(dist / "stats.json", stats_payload)

    print(
        f"wrote dist/manifest.json ({len(manifest_entries)} subdirs, "
        f"{stats_payload['total_routines']} routines, "
        f"{stats_payload['total_loc']} LOC)"
    )
    print(f"wrote dist/stats.json")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
