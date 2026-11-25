# ci

El CI común del ecosistema Unho (§12.6 del mapa). Todos los repos pasan los mismos checks, con el mismo `./check.sh`, en tu máquina y en el runner `pop-os`.

## Dos velocidades

| | Rápido (`./check.sh --rapido`) | Completo (`./check.sh`) |
|---|---|---|
| Cuándo | En cada PR | Tras fusionar, sobre `main`, en segundo plano |
| Qué | Los checks integrados + los `rapido.*` del repo | Todo lo anterior + los `completo.*` (build, e2e, migraciones…) |
| Frena | El merge (y con él el despliegue en desarrollo) | **Solo el paso a producción** |

Los checks corren **en paralelo**; un push nuevo a la misma rama cancela la ejecución vieja.

**Códigos de salida:** 0 todo verde · 1 el código tiene algo que arreglar · 2 el CI está mal montado.

## Checks integrados (`checks/`)

| Check | Falla si… |
|---|---|
| `sin-bom` | Un fichero de texto empieza con BOM o tiene caracteres de control |
| `sin-secretos` | Hay un `.env`, una clave o un certificado en git; un token con forma de secreto en el código (un ejemplo falso se marca con `unho-ci: ignorar`); o material de la referencia |
| `env-example` | Un `.env.example` tiene valores |
| `autoria` | Un commit de la rama nombra a Claude como autor |
| `unho-yaml` | `unho.yaml` no tiene `version`, `app`, `nombre`, `ambito`, `tipo` válidos |

## Cómo lo usa un repo

Copia los tres ficheros de `plantilla/` (la plantilla de apps ya los trae):

- `check.sh` en la raíz: **no se toca**. Baja este repo en la versión que diga `check.conf` (la tag `v1`, que se mueve con los arreglos) y lo guarda en `~/.cache/unho-ci/`. Sin red, usa la copia.
- `check.conf`: qué checks y qué comandos tiene ese repo.
- `.github/workflows/ci.yml`: llama a `.github/workflows/check.yml@v1` de aquí, que corre en `pop-os`.

```
version = v1
integrados = sin-bom sin-secretos env-example autoria unho-yaml
rapido.pruebas = pnpm test
completo.build = pnpm build
```

Para probar un cambio de este repo en otro sin publicarlo: `UNHO_CI_LOCAL=C:/Dev/unho-hq/ci ./check.sh`.

## Las apps se ponen al día solas (`@unho/*`)

`plantilla/actualizar-unho.yml` va en cada app como `.github/workflows/actualizar-unho.yml`. Cada hora (y cuando quieras desde Actions › «Actualizar @unho» › Run workflow) corre en `pop-os`:

1. `bin/actualizar-unho.mjs` mira en el registro de casa si hay una `@unho/core` o `@unho/ui` más nueva **de la misma versión mayor** (la promesa de la 1.x: nada rompe). Una 2.0 no se aplica nunca sola: solo avisa.
2. Si la hay: cambia `package.json` y el lock, y pasa el **CI completo**.
3. Todo verde → commit `chore(deps): update @unho/ui to 1.1.0` directo a `main` (con él, a desarrollo). Algo rojo → no toca `main`; deja la rama `unho/actualizar` con el cambio y el workflow en rojo.

GitHub (plan gratuito) no deja que los workflows abran PR en la organización, así que la puerta es el CI completo antes de subir, en lugar del CI de un PR. Ningún token extra: solo el del propio workflow.

## Este repo

Es **público**: así cualquier repo privado lo baja y llama a su workflow sin claves. No tiene secretos, solo los checks. Su propio CI corre en las máquinas de GitHub, nunca en `pop-os`.

- `bash tests/probar.sh`: 26 pruebas con repos de usar y tirar.
- Publicar: PR → merge → mover la tag `v1` (y crear `v1.x.y`).

**Pendiente (paso 6, con los paquetes):** la configuración compartida de Renovate.
