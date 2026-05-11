#!/usr/bin/env python3
"""Generate dist/manifest.json + dist/stats.json from the corpus subdirectories.

Inputs (live filesystem state):
  - The five top-level corpus subdirectories (ewd, m-web-server, mgsql,
    ydbocto-aux, ydbtest), each containing `.m` source from one upstream.
  - The subdir → upstream → license mapping table below, kept in sync
    with the human-readable summary in `LICENSES.md`.

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

# Subdir → (upstream URL, SPDX-ish license identifier).
#
# Kept in sync with the table in LICENSES.md. When refreshing a subdir
# snapshot from upstream, update this table if the upstream's license
# changes.
#
# `LicenseRef-mixed-per-component` is used for `ewd/`, whose components
# carry different licenses (see ewd/ewdMgr/COPYING, ewd/iwd/jqt/LICENSE.txt,
# embedded headers in the _*.m files). SPDX permits LicenseRef-* for
# non-standard / composite identifiers.
SUBDIR_LICENSES: dict[str, tuple[str, str]] = {
    "ewd": (
        "https://github.com/robtweed/EWD",
        "LicenseRef-mixed-per-component",
    ),
    "m-web-server": (
        "https://github.com/shabiel/M-Web-Server",
        "Apache-2.0",
    ),
    "mgsql": (
        "https://github.com/chrisemunt/mgsql",
        "Apache-2.0",
    ),
    "ydbocto-aux": (
        "https://github.com/YottaDB/YDBOcto",
        "AGPL-3.0",
    ),
    "ydbtest": (
        "https://github.com/YottaDB/YDBTest",
        "AGPL-3.0",
    ),
}

SCHEMA_VERSION = "1"


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


def build_manifest(root: Path) -> list[dict]:
    """Build the per-subdir manifest array."""
    entries: list[dict] = []
    for name in sorted(SUBDIR_LICENSES):
        upstream, license_id = SUBDIR_LICENSES[name]
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
    args = parser.parse_args(argv[1:])

    manifest_entries = build_manifest(args.root)
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
