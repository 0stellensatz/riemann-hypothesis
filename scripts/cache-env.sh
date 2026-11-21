#!/usr/bin/env bash
# Source this file before using stock `lake cache get` and `lake build`.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo 'Use: source scripts/cache-env.sh' >&2
  exit 1
fi

RH_CACHE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Public reads need no Cloudflare account or upload credential.
RH_CACHE_DEFAULT_URL='https://pub-884847f4b2f3414dafff28af7db8b7a3.r2.dev'
RIEMANN_CACHE_URL="${RIEMANN_CACHE_URL:-$RH_CACHE_DEFAULT_URL}"
RIEMANN_CACHE_URL="${RIEMANN_CACHE_URL%/}"
if [[ ! "$RIEMANN_CACHE_URL" =~ ^https://[a-zA-Z0-9./:_-]+$ ]]; then
  echo 'Set RIEMANN_CACHE_URL to the public cache HTTPS URL before sourcing this file.' >&2
  return 1
fi

mkdir -p "$RH_CACHE_ROOT/.lake"
export LAKE_CONFIG="$RH_CACHE_ROOT/.lake/public-cache.toml"
export LAKE_CACHE_DIR="${LAKE_CACHE_DIR:-$RH_CACHE_ROOT/.lake/cache}"
export LAKE_ARTIFACT_CACHE=true
export LAKE_RESTORE_ARTIFACTS=true
{
  printf 'cache.defaultService = "riemann-hypothesis"\n'
  printf '[[cache.service]]\nname = "riemann-hypothesis"\nkind = "s3"\n'
  printf 'artifactEndpoint = "%s/artifacts"\n' "$RIEMANN_CACHE_URL"
  printf 'revisionEndpoint = "%s/revisions"\n' "$RIEMANN_CACHE_URL"
} > "$LAKE_CONFIG"
unset RH_CACHE_ROOT RH_CACHE_DEFAULT_URL
