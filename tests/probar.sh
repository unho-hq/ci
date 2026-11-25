#!/usr/bin/env bash
# Tests for the shared checks: build throwaway repos and assert exit codes.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fallos=0
n=0

repo() { # new repo with one commit; $1 = name
  local d="$TMP/$1"
  mkdir -p "$d" && cd "$d" && git init -q -b main
  git config user.email prueba@example.com && git config user.name Prueba
  printf 'version = v1\nintegrados = sin-bom sin-secretos env-example autoria unho-yaml\n' >check.conf
  echo "# prueba" >README.md
  git add -A && git commit -q -m "chore: init"
}

espera() { # $1 = expected code, $2 = description, rest = command
  local esperado=$1 desc=$2
  shift 2
  n=$((n + 1))
  "$@" >"$TMP/salida.log" 2>&1
  local codigo=$?
  if [ "$codigo" = "$esperado" ]; then
    echo "ok $n - $desc"
  else
    echo "not ok $n - $desc (esperaba $esperado, salió $codigo)"
    sed 's/^/    /' "$TMP/salida.log" | tail -20
    fallos=$((fallos + 1))
  fi
}

check() { UNHO_CI_LOCAL="$RAIZ" UNHO_CI_BASE=none bash ./check.sh "$@"; }

# Green repo
repo verde
cp "$RAIZ/plantilla/check.sh" .
espera 0 "un repo limpio sale en verde" check --rapido

# Missing check.conf -> 2
mkdir -p "$TMP/sinconf" && cd "$TMP/sinconf" && git init -q -b main
espera 2 "sin check.conf es CI mal montado" bash "$RAIZ/bin/check"

# Unknown integrated check -> 2
repo desconocido
echo "integrados = no-existe" >check.conf
espera 2 "un check integrado que no existe es CI mal montado" bash "$RAIZ/bin/check"

# BOM
repo bom
printf '\xef\xbb\xbfhola\n' >con-bom.md && git add -A && git commit -q -m "docs: x"
espera 1 "un fichero con BOM falla" bash "$RAIZ/checks/sin-bom.sh"

# Control characters
repo control
printf 'a\x08b\n' >raro.txt && git add -A && git commit -q -m "docs: x"
espera 1 "un carácter de control falla" bash "$RAIZ/checks/sin-bom.sh"

# Secrets
repo env
echo "CLAVE=1" >.env && git add -f .env && git commit -q -m "chore: x"
espera 1 "un .env en git falla" bash "$RAIZ/checks/sin-secretos.sh"

repo token
printf 'const t = "%s";\n' "ghp_$(printf 'a%.0s' $(seq 36))" >a.ts && git add -A && git commit -q -m "feat: x"
espera 1 "un token de GitHub en el código falla" bash "$RAIZ/checks/sin-secretos.sh"

repo tokenignorado
printf 'const t = "%s"; // unho-ci: ignorar\n' "ghp_$(printf 'a%.0s' $(seq 36))" >a.ts && git add -A && git commit -q -m "feat: x"
espera 0 "un token falso marcado con «unho-ci: ignorar» pasa" bash "$RAIZ/checks/sin-secretos.sh"

repo referencia
mkdir -p documentacion-sistema && echo x >documentacion-sistema/a.md && git add -A && git commit -q -m "docs: x"
espera 1 "el material de la referencia en el repo falla" bash "$RAIZ/checks/sin-secretos.sh"

# .env.example
repo envejemplo
printf '# comentario\nCLAVE=\nOTRA=\n' >.env.example && git add -A && git commit -q -m "chore: x"
espera 0 ".env.example sin valores pasa" bash "$RAIZ/checks/env-example.sh"
printf 'CLAVE=secreto\n' >.env.example && git add -A && git commit -q -m "chore: x"
espera 1 ".env.example con un valor falla" bash "$RAIZ/checks/env-example.sh"

# Authorship
repo autoria
git commit -q --allow-empty -m "feat: x" -m "Co-Authored-By: Claude Opus <noreply@anthropic.com>"
espera 1 "un commit que nombra a Claude falla" env UNHO_CI_BASE=HEAD~1 bash "$RAIZ/checks/autoria.sh"
git commit -q --allow-empty -m "feat: y"
espera 0 "un commit normal pasa" env UNHO_CI_BASE=HEAD~1 bash "$RAIZ/checks/autoria.sh"

# unho.yaml
repo yaml
printf 'version: 1\napp: personal\nnombre: Personal\nambito: empresas\ntipo: app\nmigracion: 3\n' >unho.yaml
espera 0 "un unho.yaml correcto pasa" bash "$RAIZ/checks/unho-yaml.sh"
printf 'version: 1\napp: Personal\nnombre: Personal\nambito: personal\ntipo: app\n' >unho.yaml
espera 1 "un unho.yaml con ámbito viejo y slug en mayúsculas falla" bash "$RAIZ/checks/unho-yaml.sh"

# Fast vs full and command checks
repo modos
printf 'version = v1\nintegrados = sin-bom\nrapido.uno = true\ncompleto.dos = exit 1\n' >check.conf
espera 0 "--rapido no corre los checks completos" bash "$RAIZ/bin/check" --rapido
espera 1 "el completo sí los corre y falla" bash "$RAIZ/bin/check"
printf 'version = v1\nrapido.lento = sleep 2\nrapido.otro = sleep 2\n' >check.conf
inicio=$(date +%s)
espera 0 "dos checks de 2 s" bash "$RAIZ/bin/check" --rapido
n=$((n + 1))
if [ $(($(date +%s) - inicio)) -lt 4 ]; then echo "ok $n - los checks corren en paralelo"; else echo "not ok $n - los checks no corren en paralelo"; fallos=$((fallos + 1)); fi

# The stub needs a version
repo sinversion
cp "$RAIZ/plantilla/check.sh" . && echo "integrados = sin-bom" >check.conf
espera 2 "el stub sin version es CI mal montado" bash ./check.sh

# Keeping @unho/* up to date (bin/actualizar-unho.mjs)
repo actualizar
mkdir -p web backend
printf '{
  "name": "x",
  "workspaces": ["backend", "web"]
}
' >package.json
printf '{
  "dependencies": {
    "@unho/core": "1.1.0",
    "hono": "4.0.0"
  }
}
' >backend/package.json
printf '{
  "dependencies": {
    "@unho/ui": "1.0.0",
    "react": "19.0.0"
  }
}
' >web/package.json
VERS='{"@unho/ui":["1.0.0","1.0.1","1.1.0","1.2.0-beta.1","2.0.0"],"@unho/core":["1.0.0","1.1.0"]}'
actualizar() { UNHO_VERSIONES="$VERS" node "$RAIZ/bin/actualizar-unho.mjs" "$@"; }
espera 0 "el plan sin --escribir no toca nada" actualizar
n=$((n + 1))
if grep -q '"@unho/ui": "1.0.0"' web/package.json; then echo "ok $n - sin --escribir los ficheros siguen igual"; else echo "not ok $n - sin --escribir ha cambiado web/package.json"; fallos=$((fallos + 1)); fi
salida="$(actualizar --escribir)"
n=$((n + 1))
if grep -q '"@unho/ui": "1.1.0"' web/package.json && grep -q '"react": "19.0.0"' web/package.json && grep -q '"@unho/core": "1.1.0"' backend/package.json; then
  echo "ok $n - sube @unho/ui a la última 1.x estable (ni beta ni 2.0) y no toca lo demás"
else
  echo "not ok $n - versiones mal escritas"; cat web/package.json backend/package.json; fallos=$((fallos + 1))
fi
n=$((n + 1))
if echo "$salida" | grep -q '@unho/ui 2.0.0 es una versión mayor'; then echo "ok $n - avisa de la 2.0 sin aplicarla"; else echo "not ok $n - no avisa de la versión mayor"; fallos=$((fallos + 1)); fi
out="$TMP/github_output"
: >"$out"
GITHUB_OUTPUT="$out" UNHO_VERSIONES="$VERS" node "$RAIZ/bin/actualizar-unho.mjs" >/dev/null
n=$((n + 1))
if grep -q '^cambios=false$' "$out"; then echo "ok $n - ya al día: cambios=false"; else echo "not ok $n - esperaba cambios=false"; cat "$out"; fallos=$((fallos + 1)); fi
printf '{
  "dependencies": {
    "@unho/ui": "^1.0.0"
  }
}
' >web/package.json
: >"$out"
GITHUB_OUTPUT="$out" UNHO_VERSIONES="$VERS" node "$RAIZ/bin/actualizar-unho.mjs" --escribir >/dev/null
n=$((n + 1))
if grep -q '^mensaje=chore(deps): update @unho/ui to 1.1.0$' "$out" && grep -q '"@unho/ui": "1.1.0"' web/package.json; then echo "ok $n - un rango ^ también se sube y el mensaje del commit sale bien"; else echo "not ok $n - rango ^ o mensaje mal"; cat "$out" web/package.json; fallos=$((fallos + 1)); fi

echo "1..$n"
if [ "$fallos" -gt 0 ]; then
  echo "# $fallos fallos"
  exit 1
fi
echo "# todo en verde"
