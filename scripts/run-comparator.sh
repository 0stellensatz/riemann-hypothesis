#!/usr/bin/env bash
# Full Comparator run. Needs Linux, a big machine, and hours: Comparator compiles all 175,187
# files of the solution inside its landrun sandbox.
#
# Run this from a FRESH clone. Comparator assumes the solution has never been compiled outside
# its sandbox, so this script refuses a tree whose project build outputs it did not produce.
#
#   scripts/run-comparator.sh
#   TOOLS=/some/dir scripts/run-comparator.sh      # reuse previously built tools
#
# Steps: preconditions -> mirror and statement checks -> build landrun, lean4export and
# comparator -> fetch pinned deps and Mathlib's official cache -> Comparator under systemd-run
# -> results/<UTC time>-<host>/ (commit that directory to publish the run).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
TOOLCHAIN=$(cat lean-toolchain)
TOOLS=${TOOLS:-$HOME/.cache/rh-lean-check-tools}
# The standalone Comparator repo is archived; `lake comparator` is in Lean core only from v4.35.0.
# v4.33.0 is its last tag for this Lean line, and lean4export has no v4.33.1 tag either.
COMPARATOR_REV=${COMPARATOR_REV:-v4.33.0}
LEAN4EXPORT_REV=${LEAN4EXPORT_REV:-v4.33.0}
LANDRUN_REV=${LANDRUN_REV:-origin/main}   # the Comparator README asks for landrun built from main
CONFIG=${CONFIG:-comparator/config.json}
OUT=${OUT:-$ROOT/results/$(date -u +%Y%m%dT%H%M%SZ)-$(hostname -s)}
mkdir -p "$OUT" "$TOOLS/bin" "$TOOLS/src"

log() { printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$*" | tee -a "$OUT/run.log" >&2; }
die() { log "ERROR: $*"; exit 1; }
START=$(date -u +%s)

# ---- 1. Preconditions
[ "$(uname -s)" = Linux ] || die "Linux only (landrun uses Landlock)"
[ "$(id -u)" -ne 0 ] || die "do not run as root (a Comparator README assumption)"
for c in git curl go elan lake python3 systemd-run; do command -v "$c" >/dev/null || die "missing: $c"; done
systemd-run --user --wait --pipe --collect --quiet /bin/true \
  || die "systemd-run --user is unavailable (over SSH you may need: loginctl enable-linger \$USER)"
PREBUILT=
if [ -e .lake/build/lib ] && [ ! -e .lake/.compiled-by-comparator ]; then
  # Escape hatch: PREBUILT_NOTE="how and where the outputs were built" accepts them and records it.
  [ -n "${PREBUILT_NOTE:-}" ] || die "project build outputs exist that Comparator did not produce; start from a fresh clone"
  PREBUILT=1
  log "WARNING: reusing build outputs that Comparator did not produce: $PREBUILT_NOTE"
fi
log "repo $(git rev-parse HEAD 2>/dev/null || echo unknown), toolchain $TOOLCHAIN, results in $OUT"

# ---- 2. Integrity of the mirror and of the challenge
scripts/verify-mirror.sh --offline 2>&1 | tee -a "$OUT/run.log"
scripts/check-statements.sh 2>&1 | tee -a "$OUT/run.log"

# ---- 3. Tools
clone_at() {  # clone_at URL REV DIR
  [ -d "$3/.git" ] || git clone -q "$1" "$3"
  git -C "$3" fetch -q --tags origin
  git -C "$3" checkout -q -f --detach "$2"
}
log "building landrun at $LANDRUN_REV"
clone_at https://github.com/Zouuup/landrun "$LANDRUN_REV" "$TOOLS/src/landrun"
(cd "$TOOLS/src/landrun" && go build -o "$TOOLS/bin/landrun" ./cmd/landrun) 2>&1 | tee -a "$OUT/run.log"

# Lean rejects .olean files written by a different Lean build, so lean4export (which reads the
# solution's .oleans) and comparator are built from their v4.33.0 sources with THIS project's
# toolchain. The override is recorded in tools.txt.
build_lean_tool() {  # build_lean_tool NAME URL REV
  local dir=$TOOLS/src/$1
  log "building $1 at $3 with toolchain $TOOLCHAIN"
  clone_at "$2" "$3" "$dir"
  echo "$TOOLCHAIN" > "$dir/lean-toolchain"
  (cd "$dir" && lake build "$1") 2>&1 | tail -5 | tee -a "$OUT/run.log"
  cp "$dir/.lake/build/bin/$1" "$TOOLS/bin/$1"
}
build_lean_tool lean4export https://github.com/leanprover/lean4export "$LEAN4EXPORT_REV"
build_lean_tool comparator https://github.com/leanprover/comparator "$COMPARATOR_REV"
{
  for t in landrun lean4export comparator; do
    echo "$t $(git -C "$TOOLS/src/$t" describe --tags --always 2>/dev/null) $(git -C "$TOOLS/src/$t" rev-parse HEAD)"
  done
  echo "lean4export and comparator built with toolchain override: $TOOLCHAIN"
  command -v nanoda_bin >/dev/null && echo "nanoda_bin $(command -v nanoda_bin)" || echo "nanoda_bin not found (independent-kernel pass skipped)"
} > "$OUT/tools.txt"

# ---- 4. Pinned dependencies and Mathlib's official build cache (network)
log "fetching pinned dependencies and Mathlib's official build cache"
lake exe cache get 2>&1 | tail -20 | tee "$OUT/cache-get.log"
python3 -I - lake-manifest.json <<'PY' 2>&1 | tee "$OUT/dependency-revs.txt"
import json, subprocess, sys
bad = 0
for p in json.load(open(sys.argv[1]))["packages"]:
    d = ".lake/packages/" + p["name"]
    head = subprocess.run(["git", "-C", d, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    dirty = subprocess.run(["git", "-C", d, "status", "--porcelain"], capture_output=True, text=True).stdout.strip()
    ok = head == p["rev"] and not dirty
    bad += not ok
    print(("ok   " if ok else "FAIL ") + f"{p['name']:16} {head[:12]} (pinned {p['rev'][:12]}){' DIRTY' if dirty else ''}")
sys.exit(1 if bad else 0)
PY

# ---- 5. Comparator, the way its README runs it (AF_UNIX blocked to guard a landrun hole fixed in Linux 7.1)
run_comparator() {  # run_comparator CONFIG LOGNAME
  local cmd=(lake env "$TOOLS/bin/comparator" "$1")
  [ -x /usr/bin/time ] && cmd=(/usr/bin/time -v -o "$OUT/$2.time.txt" "${cmd[@]}")
  log "running Comparator with $1 (log: $OUT/$2.log)"
  set +e
  systemd-run --user --wait --pipe --collect \
    --property=RestrictAddressFamilies=~AF_UNIX \
    -E PATH="$TOOLS/bin:$PATH" -E HOME="$HOME" \
    -E COMPARATOR_LANDRUN="$TOOLS/bin/landrun" \
    -E COMPARATOR_LEAN4EXPORT="$TOOLS/bin/lean4export" \
    ${NANODA:+-E COMPARATOR_NANODA="$NANODA"} \
    --working-directory "$ROOT" \
    -- /bin/bash -c 'exec "$@"' bash "${cmd[@]}" 2>&1 | tee "$OUT/$2.log"
  local rc=${PIPESTATUS[0]}
  set -e
  [ -n "$PREBUILT" ] || touch .lake/.compiled-by-comparator
  echo "$rc" > "$OUT/$2.exit"
  log "Comparator ($2) exit code $rc"
  return 0
}
C_START=$(date -u +%s)
run_comparator "$CONFIG" comparator
C_END=$(date -u +%s)

# Optional independent kernel: a second pass with nanoda, if nanoda_bin is available.
if NANODA=$(command -v nanoda_bin); then
  python3 -I -c 'import json,sys; c=json.load(open(sys.argv[1])); c["enable_nanoda"]=True; json.dump(c,open(sys.argv[2],"w"),indent=2)' \
    "$CONFIG" "$OUT/config.nanoda.json"
  run_comparator "$OUT/config.nanoda.json" comparator-nanoda
else
  unset NANODA
fi

# ---- 6. Record
{
  echo "host: $(hostname)"; uname -a; echo "cores: $(nproc)"; free -g | head -2
  systemctl --user --version 2>/dev/null | head -1
  echo "lean: $(lean --version)"; echo "lake: $(lake --version)"
} > "$OUT/environment.txt" 2>&1
(sha256sum lean-toolchain lake-manifest.json lakefile.toml src/Challenge.lean src/Main.lean src/Statements.lean "$CONFIG") > "$OUT/inputs.sha256"
cp "$CONFIG" "$OUT/config.json"
END=$(date -u +%s)
rc=$(cat "$OUT/comparator.exit")
{
  echo "# Comparator run $(basename "$OUT")"
  echo
  echo "- Result: **$([ "$rc" = 0 ] && echo PASS || echo "FAIL (exit $rc)")**"
  [ -e "$OUT/comparator-nanoda.exit" ] && echo "- nanoda pass: exit $(cat "$OUT/comparator-nanoda.exit")"
  [ -n "$PREBUILT" ] && echo "- **Not a fresh-clone run.** The solution was compiled before this run, outside Comparator's sandbox: $PREBUILT_NOTE"
  echo "- Repo commit: \`$(git rev-parse HEAD 2>/dev/null || echo unknown)\`"
  echo "- Toolchain: \`$TOOLCHAIN\`"
  echo "- Comparator wall time: $(( (C_END - C_START) / 60 )) min; whole script: $(( (END - START) / 60 )) min"
  [ -e "$OUT/comparator.time.txt" ] && grep -E 'Maximum resident|Elapsed' "$OUT/comparator.time.txt" | sed 's/^\s*/- /'
  echo
  echo "## Tools"; echo; sed 's/^/    /' "$OUT/tools.txt"
  echo; echo "## Dependency revisions"; echo; sed 's/^/    /' "$OUT/dependency-revs.txt"
  echo; echo "## Last 40 lines of Comparator output"; echo; tail -40 "$OUT/comparator.log" | sed 's/^/    /'
} > "$OUT/SUMMARY.md"
log "done: $OUT/SUMMARY.md"
exit "$rc"
