#!/usr/bin/env bash
# Every tracked .env.example only lists names: no values (comments and empty values are fine).
set -uo pipefail
mal=0
while IFS= read -r f; do
  n=0
  while IFS= read -r linea || [ -n "$linea" ]; do
    n=$((n + 1))
    linea="${linea%$'\r'}"
    case "$linea" in ''|'#'*) continue ;; esac
    valor="${linea#*=}"
    if [ "$valor" != "$linea" ] && [ -n "$valor" ]; then
      echo "✗ $f:$n tiene un valor (${linea%%=*}). En .env.example solo van los nombres."
      mal=1
    fi
  done <"$f"
done < <(git ls-files | grep -E '(^|/)\.env\.example$')
exit "$mal"
