#!/usr/bin/env bash
# Commits are Izan's: none of the branch's commits may credit Claude as author.
set -uo pipefail
base="${UNHO_CI_BASE:-origin/main}"
if git rev-parse --verify -q "$base" >/dev/null; then
  rango="$base..HEAD"
else
  rango="HEAD~1..HEAD"
  git rev-parse --verify -q HEAD~1 >/dev/null || rango="HEAD"
fi
malos="$(git log --format='%h %s%n%b' "$rango" 2>/dev/null | grep -Ei 'Co-Authored-By:[[:space:]]*Claude|noreply@anthropic\.com|Generated with \[?Claude' || true)"
if [ -n "$malos" ]; then
  echo "✗ Hay commits que nombran a Claude como autor (los commits son de Izan):"
  echo "$malos"
  exit 1
fi
exit 0
