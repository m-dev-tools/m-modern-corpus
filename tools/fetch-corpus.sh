#!/usr/bin/env bash
# tools/fetch-corpus.sh — idempotent corpus discovery & download.
#
# Single entrypoint for "what M source belongs in this corpus and where it
# came from upstream." The subdir → upstream mapping lives in
# tools/sources.tsv (shared with tools/gen-manifest.py).
#
# Snapshot semantics
# ------------------
# Each subdir is a verbatim copy of its upstream default-branch HEAD at
# fetch time, with `.git/` stripped so the subdir is plain files rather
# than a nested repo. The corpus is NOT auto-synced — refreshes are
# deliberate operations recorded in dist/sources.lock.json.
#
# Idempotency
# -----------
#   * Default invocation (or `status`) prints state and changes nothing.
#   * `fetch` clones only subdirs that are missing; re-runs are no-ops.
#   * `refresh` deliberately re-clones one or all subdirs.
#   * `verify` re-fetches each upstream into a tmp dir and diffs against
#     the working tree, exit 1 on drift. Read-only on the working tree.
#
# Atomicity
# ---------
# Each clone happens in a `.fetch-corpus-*` tmp dir inside the repo, and
# is only swapped into place on success. A failed/aborted run leaves the
# existing subdir intact and an obvious leftover tmp dir to clean.
#
# Usage
# -----
#   tools/fetch-corpus.sh [status]               # report state (default)
#   tools/fetch-corpus.sh fetch                  # clone missing subdirs
#   tools/fetch-corpus.sh refresh <subdir>       # re-clone one subdir
#   tools/fetch-corpus.sh refresh --all          # re-clone every subdir
#   tools/fetch-corpus.sh verify [<subdir>...]   # diff working tree vs upstream
#   tools/fetch-corpus.sh list                   # print the sources table
#
# Dependencies: bash 5, git, python3 (for JSON lock-file maintenance).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCES_TSV="$ROOT_DIR/tools/sources.tsv"
LOCK_FILE="$ROOT_DIR/dist/sources.lock.json"

# Parallel arrays populated by load_sources.
SUBDIRS=()
URLS=()
LICENSES=()
DESCS=()

# Parallel arrays of "what we fetched this run" — fed to the lockfile.
FETCHED_SUBDIRS=()
FETCHED_URLS=()
FETCHED_SHAS=()

# ---- colour helpers (no-op when stdout isn't a TTY) -------------------

if [ -t 1 ]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi

die() { printf "%sERROR:%s %s\n" "$C_RED" "$C_RESET" "$*" >&2; exit 2; }
note() { printf "%s%s%s\n" "$C_DIM" "$*" "$C_RESET" >&2; }

# ---- sources.tsv loader ----------------------------------------------

load_sources() {
  [ -f "$SOURCES_TSV" ] || die "missing $SOURCES_TSV"
  local lineno=0 subdir url license desc
  while IFS=$'\t' read -r subdir url license desc || [ -n "${subdir:-}" ]; do
    lineno=$((lineno + 1))
    # Skip blanks and comments.
    case "$subdir" in
      ""|"#"*) continue ;;
    esac
    [ -n "${url:-}" ]     || die "$SOURCES_TSV:$lineno: missing upstream URL for '$subdir'"
    [ -n "${license:-}" ] || die "$SOURCES_TSV:$lineno: missing license for '$subdir'"
    SUBDIRS+=("$subdir")
    URLS+=("$url")
    LICENSES+=("$license")
    DESCS+=("${desc:-}")
  done < "$SOURCES_TSV"
  [ "${#SUBDIRS[@]}" -gt 0 ] || die "$SOURCES_TSV declared zero sources"
}

# ---- discovery -------------------------------------------------------

# Return 0 if <subdir> is "present" (exists, non-empty).
is_present() {
  local target="$ROOT_DIR/$1"
  [ -d "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null || true)" ]
}

# Look up an array index by subdir name. Echoes the index, returns 1 if
# not found.
index_of() {
  local needle="$1" i
  for i in "${!SUBDIRS[@]}"; do
    if [ "${SUBDIRS[$i]}" = "$needle" ]; then
      echo "$i"
      return 0
    fi
  done
  return 1
}

# ---- the work-horse: clone + strip, atomically ----------------------

# fetch_one <subdir> <url>  — echoes the upstream HEAD sha on success.
fetch_one() {
  local subdir="$1" url="$2"
  local target="$ROOT_DIR/$subdir"
  local tmp
  tmp=$(mktemp -d "$ROOT_DIR/.fetch-corpus-${subdir}-XXXXXX")
  # Always clean tmp on exit from this function.
  # shellcheck disable=SC2064  # we intentionally capture $tmp now.
  trap "rm -rf '$tmp'" RETURN

  note "  cloning $url"
  if ! git clone --quiet --depth 1 "$url" "$tmp/payload" >&2; then
    printf "%sFAILED:%s git clone %s\n" "$C_RED" "$C_RESET" "$url" >&2
    return 1
  fi
  local sha
  sha=$(git -C "$tmp/payload" rev-parse HEAD)
  rm -rf "$tmp/payload/.git"

  # Swap into place — remove any prior subdir first.
  if [ -e "$target" ]; then
    rm -rf "$target"
  fi
  mv "$tmp/payload" "$target"

  echo "$sha"
}

record_fetched() {
  FETCHED_SUBDIRS+=("$1")
  FETCHED_URLS+=("$2")
  FETCHED_SHAS+=("$3")
}

# ---- lock-file write (delegates JSON to python3) --------------------

update_lock_file() {
  [ "${#FETCHED_SUBDIRS[@]}" -gt 0 ] || return 0

  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  mkdir -p "$(dirname "$LOCK_FILE")"

  # Build "subdir|url|sha" tuples and hand off to a small python helper.
  local args=() i
  for i in "${!FETCHED_SUBDIRS[@]}"; do
    args+=("${FETCHED_SUBDIRS[$i]}|${FETCHED_URLS[$i]}|${FETCHED_SHAS[$i]}")
  done

  python3 - "$LOCK_FILE" "$now" "${args[@]}" <<'PY'
import json, sys, pathlib
lock = pathlib.Path(sys.argv[1])
now = sys.argv[2]
updates = sys.argv[3:]

data = {}
if lock.exists():
    try:
        data = json.loads(lock.read_text())
    except json.JSONDecodeError:
        print(f"WARN: {lock} unparseable; rewriting from scratch.",
              file=sys.stderr)
        data = {}

sources = {e["subdir"]: e for e in data.get("sources", [])}
for line in updates:
    subdir, url, sha = line.split("|", 2)
    sources[subdir] = {
        "subdir":     subdir,
        "url":        url,
        "head_sha":   sha,
        "fetched_at": now,
    }
out = {
    "schema_version": "1",
    "generated_by":   "tools/fetch-corpus.sh",
    "sources":        sorted(sources.values(), key=lambda e: e["subdir"]),
}
lock.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")
print(f"  recorded {len(updates)} subdir(s) in {lock.relative_to(lock.parents[1])}")
PY
}

# ---- subcommands -----------------------------------------------------

cmd_list() {
  printf "%s%-16s %-50s %-32s %s%s\n" \
    "$C_BOLD" "subdir" "upstream" "license" "description" "$C_RESET"
  local i
  for i in "${!SUBDIRS[@]}"; do
    printf "%-16s %-50s %-32s %s\n" \
      "${SUBDIRS[$i]}" "${URLS[$i]}" "${LICENSES[$i]}" "${DESCS[$i]}"
  done
}

cmd_status() {
  local missing=0 present=0 i mark
  printf "%s%-16s %-10s %s%s\n" "$C_BOLD" "subdir" "state" "upstream" "$C_RESET"
  for i in "${!SUBDIRS[@]}"; do
    if is_present "${SUBDIRS[$i]}"; then
      mark="${C_GREEN}present${C_RESET}"
      present=$((present + 1))
    else
      mark="${C_YELLOW}missing${C_RESET}"
      missing=$((missing + 1))
    fi
    # Tweak: the colour codes consume width; use raw widths.
    printf "%-16s " "${SUBDIRS[$i]}"
    printf "%b" "$mark"
    # Pad to column.
    local pad=$((10 - 7))  # word "present"/"missing" is 7 chars.
    printf "%*s%s\n" $pad "" "${URLS[$i]}"
  done
  printf "\n%d present, %d missing (of %d total).\n" \
    "$present" "$missing" "${#SUBDIRS[@]}"
  if [ "$missing" -gt 0 ]; then
    printf "Run %stools/fetch-corpus.sh fetch%s to clone missing subdirs.\n" \
      "$C_BOLD" "$C_RESET"
  fi
}

cmd_fetch() {
  local i sha fetched=0 skipped=0
  for i in "${!SUBDIRS[@]}"; do
    if is_present "${SUBDIRS[$i]}"; then
      printf "%s—%s %s already present, skipping.\n" \
        "$C_DIM" "$C_RESET" "${SUBDIRS[$i]}"
      skipped=$((skipped + 1))
      continue
    fi
    printf "%s→%s fetching %s …\n" "$C_BOLD" "$C_RESET" "${SUBDIRS[$i]}"
    sha=$(fetch_one "${SUBDIRS[$i]}" "${URLS[$i]}") || exit $?
    record_fetched "${SUBDIRS[$i]}" "${URLS[$i]}" "$sha"
    printf "%s✓%s %s → %s\n" "$C_GREEN" "$C_RESET" "${SUBDIRS[$i]}" "${sha:0:12}"
    fetched=$((fetched + 1))
  done
  update_lock_file
  printf "\n%d fetched, %d already present.\n" "$fetched" "$skipped"
  if [ "$fetched" -gt 0 ]; then
    printf "Next: %smake manifest%s to refresh dist/ artifacts.\n" \
      "$C_BOLD" "$C_RESET"
  fi
}

cmd_refresh() {
  local target_subdirs=() arg i sha
  if [ "$#" -eq 0 ]; then
    die "refresh needs a subdir name or --all"
  fi
  if [ "$1" = "--all" ]; then
    target_subdirs=("${SUBDIRS[@]}")
  else
    for arg in "$@"; do
      if ! index_of "$arg" >/dev/null; then
        die "unknown subdir '$arg' (run 'tools/fetch-corpus.sh list')"
      fi
      target_subdirs+=("$arg")
    done
  fi

  for subdir in "${target_subdirs[@]}"; do
    i=$(index_of "$subdir")
    printf "%s↻%s refreshing %s …\n" "$C_BOLD" "$C_RESET" "$subdir"
    sha=$(fetch_one "$subdir" "${URLS[$i]}") || exit $?
    record_fetched "$subdir" "${URLS[$i]}" "$sha"
    printf "%s✓%s %s → %s\n" "$C_GREEN" "$C_RESET" "$subdir" "${sha:0:12}"
  done
  update_lock_file
  printf "\n%d refreshed.\n" "${#target_subdirs[@]}"
  printf "Next: %smake manifest%s and review changes before committing.\n" \
    "$C_BOLD" "$C_RESET"
}

cmd_verify() {
  local target_subdirs=() arg i tmp drift=0
  if [ "$#" -eq 0 ]; then
    target_subdirs=("${SUBDIRS[@]}")
  else
    for arg in "$@"; do
      if ! index_of "$arg" >/dev/null; then
        die "unknown subdir '$arg'"
      fi
      target_subdirs+=("$arg")
    done
  fi
  for subdir in "${target_subdirs[@]}"; do
    i=$(index_of "$subdir")
    if ! is_present "$subdir"; then
      printf "%s—%s %s not present locally, skipping verify.\n" \
        "$C_YELLOW" "$C_RESET" "$subdir"
      continue
    fi
    tmp=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN
    printf "%s?%s verifying %s vs %s\n" \
      "$C_BOLD" "$C_RESET" "$subdir" "${URLS[$i]}"
    if ! git clone --quiet --depth 1 "${URLS[$i]}" "$tmp/payload" >&2; then
      printf "%sFAILED:%s clone for verify %s\n" "$C_RED" "$C_RESET" "$subdir" >&2
      rm -rf "$tmp"
      drift=1
      continue
    fi
    rm -rf "$tmp/payload/.git"
    if diff -r --brief "$tmp/payload" "$ROOT_DIR/$subdir" >/dev/null; then
      printf "%s✓%s %s matches upstream HEAD.\n" "$C_GREEN" "$C_RESET" "$subdir"
    else
      printf "%s≠%s %s differs from upstream HEAD " "$C_YELLOW" "$C_RESET" "$subdir"
      printf "(expected for a frozen snapshot — run 'refresh %s' to update).\n" "$subdir"
      drift=1
    fi
    rm -rf "$tmp"
  done
  if [ "$drift" -ne 0 ]; then
    return 1
  fi
}

cmd_help() {
  sed -n '2,30p' "$0" | sed -e 's/^# \{0,1\}//' -e 's/^!.*//'
}

# ---- dispatch --------------------------------------------------------

main() {
  load_sources
  local cmd="${1:-status}"
  shift || true
  case "$cmd" in
    status|"")        cmd_status "$@" ;;
    list)             cmd_list "$@" ;;
    fetch|download)   cmd_fetch "$@" ;;
    refresh|update)   cmd_refresh "$@" ;;
    verify|check)     cmd_verify "$@" ;;
    help|-h|--help)   cmd_help ;;
    *)                die "unknown command: $cmd (try 'help')" ;;
  esac
}

main "$@"
