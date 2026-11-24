#!/usr/bin/env bash
# If the repo has unho.yaml, its top-level fields are the ones the map (§13.2) asks for.
set -uo pipefail
f=unho.yaml
[ -f "$f" ] || exit 0
mal=0
valor() { sed -n "s/^$1:[[:space:]]*//p" "$f" | head -1 | sed 's/[[:space:]]*#.*$//' | tr -d '\r"'"'"; }
for clave in version app nombre ambito tipo; do
  if [ -z "$(valor "$clave")" ]; then
    echo "✗ unho.yaml: falta «$clave»"
    mal=1
  fi
done
case "$(valor ambito)" in ''|empresas|privado|interno|otro) ;; *) echo "✗ unho.yaml: ambito tiene que ser empresas, privado, interno u otro"; mal=1 ;; esac
case "$(valor tipo)" in ''|app|servicio|prueba) ;; *) echo "✗ unho.yaml: tipo tiene que ser app, servicio o prueba"; mal=1 ;; esac
m="$(valor migracion)"
case "$m" in ''|1|2|3) ;; *) echo "✗ unho.yaml: migracion tiene que ser 1, 2 o 3"; mal=1 ;; esac
if [[ ! "$(valor app)" =~ ^[a-z][a-z0-9-]*$ ]] && [ -n "$(valor app)" ]; then
  echo "✗ unho.yaml: app es el slug, en minúsculas y con guiones"
  mal=1
fi
exit "$mal"
