#!/usr/bin/env bash
# Do not edit: this file comes from unho-hq/ci (plantilla/check.sh).
# Runs the shared Unho checks at the version that check.conf names.
#   ./check.sh            full (what promotion to production needs)
#   ./check.sh --rapido   fast (what a PR needs)
# Exit codes: 0 all green · 1 the code is wrong · 2 the CI is misconfigured.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if [ -n "${UNHO_CI_LOCAL:-}" ]; then
  exec bash "$UNHO_CI_LOCAL/bin/check" "$@"
fi

version="$(sed -n 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*//p' check.conf 2>/dev/null | head -1 | tr -d '\r')"
if [ -z "$version" ]; then
  echo "✗ check.conf no dice qué version del CI usar (version = v1)"
  exit 2
fi
cache="${UNHO_CI_CACHE:-$HOME/.cache/unho-ci}/$version"

if [ -d "$cache/.git" ]; then
  # Moving tag (v1): refresh it, but keep working offline with the cached copy.
  git -C "$cache" fetch -q --depth 1 origin "+refs/tags/$version:refs/tags/$version" 2>/dev/null &&
    git -C "$cache" checkout -q --force "tags/$version" 2>/dev/null || true
else
  mkdir -p "$(dirname "$cache")"
  if ! git clone -q --depth 1 --branch "$version" https://github.com/unho-hq/ci.git "$cache"; then
    echo "✗ No se pudo bajar unho-hq/ci $version"
    exit 2
  fi
fi
exec bash "$cache/bin/check" "$@"
