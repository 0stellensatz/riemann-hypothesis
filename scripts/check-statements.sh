#!/usr/bin/env bash
# Text-level checks that the Comparator challenge matches the submission's statements.
# Comparator does the real Expr-level comparison; this catches drift early and cheaply.
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "FAIL: $*" >&2; [ -n "${GITHUB_ACTIONS:-}" ] && echo "::error::$*"; exit 1; }

# 1. The challenge and the submission's statement file import Mathlib and nothing else.
for f in src/Challenge.lean src/Statements.lean; do
  imports=$(grep -E '^\s*import\s' "$f" | tr -s ' ')
  [ "$imports" = "import Mathlib" ] || fail "$f imports something other than Mathlib: $imports"
done
echo "ok: Challenge.lean and Statements.lean import only Mathlib"

# 2. The four definitions are byte-identical.
defs() { sed -n '/^def /,/^$/p' "$1" | sed '/^$/d'; }
diff <(defs src/Statements.lean) <(defs src/Challenge.lean) >/dev/null \
  || { diff <(defs src/Statements.lean) <(defs src/Challenge.lean) >&2 || true; fail "definitions differ from src/Statements.lean"; }
echo "ok: $(defs src/Challenge.lean | grep -c '^def ') definitions identical to src/Statements.lean"

# 3. Main states the same theorem names and types as the challenge, and the config lists them.
sig() { grep -E '^theorem ' "$1" | sed -E 's/^theorem ([^ ]+) : (.*) :=.*/\1 : \2/' | LC_ALL=C sort; }
diff <(sig src/Main.lean) <(sig src/Challenge.lean) >/dev/null \
  || { diff <(sig src/Main.lean) <(sig src/Challenge.lean) >&2 || true; fail "theorem signatures differ between Main.lean and Challenge.lean"; }
cfg=$(python3 -I -c 'import json,sys; print("\n".join(sorted(json.load(open(sys.argv[1]))["theorem_names"])))' comparator/config.json)
[ "$cfg" = "$(sig src/Main.lean | cut -d' ' -f1 | LC_ALL=C sort)" ] || fail "comparator/config.json theorem_names do not match Main.lean"
echo "ok: Main.lean and Challenge.lean state the same 5 theorems, all listed in comparator/config.json"
sig src/Main.lean | sed 's/^/     /'
