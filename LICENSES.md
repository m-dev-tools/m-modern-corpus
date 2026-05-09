# Licenses and provenance

This repository is a **snapshot collection** of M (MUMPS) source code
from active open-source projects. Nothing here is original work. Each
subdirectory carries its own license terms from its upstream, reproduced
unchanged in per-subdirectory `LICENSE` / `COPYING` / `NOTICE` files.

The table below is a summary; the per-subdirectory files are
authoritative.

| Subdirectory | Upstream | License |
|---|---|---|
| `ewd/`           | <https://github.com/robtweed/EWD>      | Mixed per-component — see `ewd/ewdMgr/COPYING`, `ewd/iwd/jqt/LICENSE.txt`, embedded headers in `ewd/_*.m` |
| `mgsql/`         | <https://github.com/chrisemunt/mgsql>  | Apache-2.0 (`mgsql/LICENSE`) |
| `m-web-server/`  | <https://github.com/shabiel/M-Web-Server> | Apache-2.0 (`m-web-server/LICENSE`) |
| `ydbocto-aux/`   | <https://github.com/YottaDB/YDBOcto>   | AGPL-3.0 (`ydbocto-aux/COPYING`) plus YottaDB notices (`ydbocto-aux/LICENSE`) |
| `ydbtest/`       | <https://github.com/YottaDB/YDBTest>   | AGPL-3.0 (`ydbtest/COPYING`) plus YottaDB notices (`ydbtest/LICENSE`) |

## Snapshot policy

Snapshots are reproduced verbatim. They are **not auto-synced** as
the upstream projects evolve. To refresh a snapshot, delete the
subdirectory and re-clone from the upstream URL above:

```bash
rm -rf <subdir>
git clone <upstream-url> <subdir>
rm -rf <subdir>/.git    # snapshot semantics — see README
```

## Acquisition

The original snapshots were acquired by cloning each upstream URL and
then removing the inner `.git/` directories so each subdirectory is a
plain set of files rather than a nested git repo. This matches the
repository's "snapshot collection" framing in the README.

The repository as a whole carries no umbrella license — its content
is governed entirely by the per-subdirectory licenses cited above.
