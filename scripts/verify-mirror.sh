#!/usr/bin/env bash
# Check that the mirrored submission is byte-identical to what alpo.ge published.
#
#   scripts/verify-mirror.sh            offline manifest check, then a check against the live tarball
#   scripts/verify-mirror.sh --offline  manifest check only
#
# The manifest (provenance/files.sha256) lists the sha256 of every file in the original tarball.
# The only files this repository adds to the submission's tree are listed in ADDED below, plus the
# block appended to lakefile.toml after its original bytes.
set -euo pipefail
cd "$(dirname "$0")/.."

TARBALL_SHA256=9631b4f020199e580ba86178cb56c6e9b09f690c2369a80dc4334aa93f49c7fc
PART_URL=https://alpo.ge/lean.tar.gz.part
ADDED=(src/Challenge.lean)
MARKER='# --- rh-lean-check: everything below this line was added for Comparator; it is not part of the submission ---'

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }
fail() { echo "FAIL: $*" >&2; [ -n "${GITHUB_ACTIONS:-}" ] && echo "::error::$*"; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# 1. Every submission file except lakefile.toml matches the manifest.
grep -v '  lakefile.toml$' provenance/files.sha256 > "$tmp/manifest"
if ! sha256 -c "$tmp/manifest" > "$tmp/check.out" 2>&1; then
  grep -v ': OK$' "$tmp/check.out" | head -20 >&2
  fail "files differ from provenance/files.sha256"
fi
echo "ok: $(wc -l < "$tmp/manifest" | tr -d ' ') files match the manifest"

# 2. lakefile.toml = original bytes + our marked block, and nothing else.
orig=provenance/lakefile.original.toml
want=$(awk '$2=="lakefile.toml"{print $1}' provenance/files.sha256)
[ "$(sha256 "$orig" | cut -c1-64)" = "$want" ] || fail "provenance/lakefile.original.toml does not match the manifest"
n=$(wc -c < "$orig" | tr -d ' ')
head -c "$n" lakefile.toml | cmp -s - "$orig" || fail "lakefile.toml does not start with the original lakefile bytes"
[ "$(tail -c +"$((n + 1))" lakefile.toml | head -1)" = "$MARKER" ] || fail "lakefile.toml has changes before the marker"
echo "ok: lakefile.toml is the original plus the marked Comparator block"

# 3. No files were added or removed apart from ADDED.
awk '{print $2}' provenance/files.sha256 | LC_ALL=C sort > "$tmp/expected"
{ find src -type f; ls lean-toolchain lake-manifest.json lakefile.toml; } | LC_ALL=C sort > "$tmp/actual"
extra=$(LC_ALL=C comm -13 "$tmp/expected" "$tmp/actual")
missing=$(LC_ALL=C comm -23 "$tmp/expected" "$tmp/actual")
[ -z "$missing" ] || fail "missing files: $(echo "$missing" | head -5 | tr '\n' ' ')"
[ "$extra" = "$(printf '%s\n' "${ADDED[@]}" | LC_ALL=C sort)" ] || fail "unexpected extra files: $(echo "$extra" | head -5 | tr '\n' ' ')"
echo "ok: the only added file is ${ADDED[*]}"

[ "${1:-}" = "--offline" ] && exit 0

# 4. The live tarball still has the recorded sha256, and its contents equal this tree.
echo "downloading the 14 parts from alpo.ge"
for i in $(seq -w 1 14); do
  if ! curl -fsSL --retry 3 -o "$tmp/part$i" "$PART_URL$i"; then
    msg="could not download part $i from alpo.ge; the offline checks above passed"
    echo "WARNING: $msg" >&2; [ -n "${GITHUB_ACTIONS:-}" ] && echo "::warning::$msg"
    [ -n "${REQUIRE_ONLINE:-}" ] && exit 1 || exit 0
  fi
done
cat "$tmp"/part* > "$tmp/lean.tar.gz"
got=$(sha256 "$tmp/lean.tar.gz" | cut -c1-64)
[ "$got" = "$TARBALL_SHA256" ] || fail "live tarball sha256 is $got, expected $TARBALL_SHA256 (the published archive changed)"
mkdir "$tmp/x" && tar xzf "$tmp/lean.tar.gz" -C "$tmp/x"
diff -r -q "$tmp/x/lean/src" src | grep -v '^Only in src: Challenge.lean$' > "$tmp/diff" || true
[ ! -s "$tmp/diff" ] || { head -20 "$tmp/diff" >&2; fail "tree differs from the live tarball"; }
for f in lean-toolchain lake-manifest.json; do cmp -s "$tmp/x/lean/$f" "$f" || fail "$f differs from the live tarball"; done
cmp -s "$tmp/x/lean/lakefile.toml" "$orig" || fail "lakefile.toml differs from the live tarball"
echo "ok: live tarball sha256 matches and its contents equal this tree"
