#!/usr/bin/env bash
# No tracked text file starts with a UTF-8 BOM or contains stray control characters.
set -uo pipefail
mal=0
while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  case "$f" in *.png|*.jpg|*.jpeg|*.gif|*.ico|*.webp|*.woff|*.woff2|*.ttf|*.otf|*.pdf|*.zip|*.gz|*.onnx|*.wasm|*.jar|*.keystore|*.apk|*.aab) continue ;; esac
  if [ "$(head -c 3 "$f" | od -An -tx1 | tr -d ' \n')" = "efbbbf" ]; then
    echo "✗ $f empieza con BOM"
    mal=1
  fi
  if ! LC_ALL=C tr -d '\000-\010\013\014\016-\037' <"$f" | cmp -s - "$f"; then
    echo "✗ $f tiene caracteres de control"
    mal=1
  fi
done < <(git ls-files -z)
exit "$mal"
