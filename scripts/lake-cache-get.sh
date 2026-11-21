#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source scripts/cache-env.sh
exec lake cache get --repo leanprover-community/riemann-hypothesis "$@"
