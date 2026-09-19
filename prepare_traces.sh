#!/usr/bin/env bash
#
# prepare_traces.sh -- inflate the compressed benchmark traces so the simulator's
# runner scripts find the plain trace_C*.trc.shared files they expect.
#
# This repository (FanosResearch/OctopusBMs) holds the Octopus benchmark traces. The
# SPLASH-2 traces are ~10 GB uncompressed -- far over GitHub's 100 MB per-file
# limit -- so they are stored as xz archives (trace_C*.trc.shared.xz); any
# archive that would itself exceed the limit is stored as split parts
# (trace_C*.trc.shared.xz.part-00, -01, ...). This script reassembles and
# decompresses them IN PLACE, idempotently: a plain trace that already exists is
# left alone, so it is safe (and cheap) to call before every run. The plain
# traces are git-ignored here; only the archives are tracked. EEMBC and TestBM
# traces are small and stored uncompressed (this script leaves them untouched).
#
# The Octopus simulator's get_benchmarks.sh clones this repo and calls this
# script automatically; you only need it by hand if you run the simulator binary
# on a SPLASH benchmark directly.
#
# Usage:  ./prepare_traces.sh [--force] [DIR ...]
#   --force   re-inflate even if the plain trace already exists
#   DIR       suite dir(s) to prepare (default: every suite in this repo)
#             e.g.  ./prepare_traces.sh splash
#
# Requires: xz (xz-utils on Linux; present in MSYS2/MinGW on Windows).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FORCE=0; DIRS=()
while [ $# -gt 0 ]; do case "$1" in
  --force) FORCE=1; shift;;
  -h|--help) sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0;;
  *) DIRS+=("$1"); shift;;
esac; done
[ ${#DIRS[@]} -eq 0 ] && DIRS=("$ROOT")

# xz: on a Windows dev box it may live in the MinGW bin and not be on PATH in a
# fresh shell; on Linux it is xz-utils. Fail loudly, not silently.
if ! command -v xz >/dev/null 2>&1; then
  MINGW="/c/Users/moham/AppData/Local/Microsoft/WinGet/Packages/BrechtSanders.WinLibs.POSIX.UCRT_Microsoft.Winget.Source_8wekyb3d8bbwe/mingw64/bin"
  [ -x "$MINGW/xz.exe" ] && export PATH="$MINGW:$PATH"
fi
command -v xz >/dev/null 2>&1 || { echo "ERROR: 'xz' not found. Install xz-utils (Linux) or MSYS2 xz (Windows)." >&2; exit 1; }

inflated=0; skipped=0; failed=0

# Inflate one logical archive. $1 = output plain-trace path; $2.. = archive
# piece(s) in order (a single .xz, or the split parts). Writes to a temp file
# and renames only on success, so an interrupted run never leaves a truncated
# trace that a later (idempotent) call would mistake for a finished one.
inflate(){
  local out="$1"; shift
  if [ "$FORCE" -eq 0 ] && [ -s "$out" ]; then skipped=$((skipped+1)); return 0; fi
  local tmp="$out.inflating.$$"
  if cat "$@" | xz -d -c > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
    mv -f "$tmp" "$out"; inflated=$((inflated+1)); echo "  inflated  ${out#$ROOT/}"
  else
    rm -f "$tmp"; failed=$((failed+1)); echo "  FAILED    ${out#$ROOT/}" >&2
  fi
}

for dir in "${DIRS[@]}"; do
  [ -d "$dir" ] || { echo "WARN: no such dir: $dir" >&2; continue; }
  # Whole archives: name.xz -> name
  while IFS= read -r -d '' arc; do
    inflate "${arc%.xz}" "$arc"
  done < <(find "$dir" -type f -name '*.trc.shared.xz' -print0)
  # Split archives: name.xz.part-00 (+ -01 ...) -> name. Parts concatenate in
  # lexical order, which the zero-padded numeric suffix guarantees.
  while IFS= read -r -d '' first; do
    base="${first%.part-00}"                      # name.xz
    parts=( "$base".part-* )
    inflate "${base%.xz}" "${parts[@]}"
  done < <(find "$dir" -type f -name '*.trc.shared.xz.part-00' -print0)
done

echo "prepare_traces: inflated=$inflated skipped(already present)=$skipped failed=$failed"
[ "$failed" -eq 0 ]
