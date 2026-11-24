#!/usr/bin/env bash
# No secret files and no secret-looking values in tracked files.
set -uo pipefail
mal=0
while IFS= read -r f; do
  base="${f##*/}"
  case "$base" in
    .env.example) ;;
    .env|.env.*) echo "✗ $f: un .env con valores no va en git"; mal=1 ;;
    *.pem|*.key|*.p12|*.pfx|*.jks|*.keystore) echo "✗ $f: clave o certificado en git"; mal=1 ;;
    id_rsa|id_ed25519|id_ecdsa) echo "✗ $f: clave SSH en git"; mal=1 ;;
  esac
  case "$f" in *documentacion-sistema*) echo "✗ $f: material de la referencia, no puede estar en un repo"; mal=1 ;; esac
done < <(git ls-files)

patrones='-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{40,}|sk-(ant-|proj-)?[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|AGE-SECRET-KEY-1[0-9A-Z]{58}|xox[baprs]-[A-Za-z0-9-]{10,}'
encontrado="$(git grep -n -I -E -e "$patrones" -- ':!*.lock' ':!pnpm-lock.yaml' ':!package-lock.json' 2>/dev/null | grep -v 'unho-ci: ignorar' || true)"
if [ -n "$encontrado" ]; then
  echo "✗ Parece haber secretos en el código (si es un ejemplo falso, añade el comentario «unho-ci: ignorar» en esa línea):"
  echo "$encontrado" | cut -c1-160
  mal=1
fi
exit "$mal"
