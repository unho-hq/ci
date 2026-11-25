#!/usr/bin/env node
// Keeps the @unho/* packages of a repo up to date inside the same major (the 1.x promise:
// minors and patches never break). A new major (2.0) is never applied here: it is only reported.
//
// Usage (from the repo root): node actualizar-unho.mjs [--escribir]
//   without --escribir it only prints the plan; with it, it edits the package.json files
//   (only the version strings, so formatting is kept). Then `npm install` updates the lock.
// Versions come from `npm view <pkg> versions --json` (registry from the repo's .npmrc).
// Tests pass them in UNHO_VERSIONES='{"@unho/ui":["1.0.0","1.1.0"]}'.
// With GITHUB_OUTPUT set, writes `cambios` (true/false) and `mensaje` (the commit message).
import { appendFileSync, existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const SECCIONES = ["dependencies", "devDependencies", "optionalDependencies"];
const SEMVER = /^(\d+)\.(\d+)\.(\d+)$/;

export function comparar(a, b) {
  const x = a.match(SEMVER).slice(1).map(Number);
  const y = b.match(SEMVER).slice(1).map(Number);
  for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] - y[i];
  return 0;
}

/** The newest stable version with the same major, if newer; and the newest major, if higher. */
export function elegir(actual, disponibles) {
  const estables = disponibles.filter((v) => SEMVER.test(v)).sort(comparar);
  const mayor = Number(actual.split(".")[0]);
  const misma = estables.filter((v) => Number(v.split(".")[0]) === mayor && comparar(v, actual) > 0).at(-1) ?? null;
  const ultima = estables.at(-1);
  const otraMayor = ultima && Number(ultima.split(".")[0]) > mayor ? ultima : null;
  return { nueva: misma, otraMayor };
}

/** package.json files of the repo: the root and its npm workspaces ("dir" or "dir/*"). */
export function ficherosPaquete(raiz) {
  const raizPkg = join(raiz, "package.json");
  if (!existsSync(raizPkg)) return [];
  const lista = [raizPkg];
  const espacios = JSON.parse(readFileSync(raizPkg, "utf8")).workspaces ?? [];
  for (const patron of Array.isArray(espacios) ? espacios : (espacios.packages ?? [])) {
    const dirs = patron.endsWith("/*")
      ? readdirSync(join(raiz, patron.slice(0, -2)), { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => join(patron.slice(0, -2), d.name))
      : [patron];
    for (const d of dirs) if (existsSync(join(raiz, d, "package.json"))) lista.push(join(raiz, d, "package.json"));
  }
  return lista;
}

function versionesDelRegistro(nombre) {
  if (process.env.UNHO_VERSIONES) return JSON.parse(process.env.UNHO_VERSIONES)[nombre] ?? [];
  const salida = execFileSync("npm", ["view", nombre, "versions", "--json"], { encoding: "utf8", shell: process.platform === "win32" });
  const v = JSON.parse(salida);
  return Array.isArray(v) ? v : [v];
}

export function planear(raiz, versiones = versionesDelRegistro) {
  const cambios = [];
  const mayores = [];
  const cache = new Map();
  for (const fichero of ficherosPaquete(raiz)) {
    const pkg = JSON.parse(readFileSync(fichero, "utf8"));
    for (const seccion of SECCIONES) {
      for (const [nombre, rango] of Object.entries(pkg[seccion] ?? {})) {
        if (!nombre.startsWith("@unho/")) continue;
        const actual = String(rango).replace(/^[\^~=]/, "");
        if (!SEMVER.test(actual)) continue;
        if (!cache.has(nombre)) cache.set(nombre, versiones(nombre));
        const { nueva, otraMayor } = elegir(actual, cache.get(nombre));
        if (nueva) cambios.push({ fichero, nombre, de: String(rango), a: nueva });
        if (otraMayor && !mayores.some((m) => m.nombre === nombre)) mayores.push({ nombre, version: otraMayor });
      }
    }
  }
  return { cambios, mayores };
}

export function aplicar(cambios) {
  const porFichero = Map.groupBy(cambios, (c) => c.fichero);
  for (const [fichero, lista] of porFichero) {
    let texto = readFileSync(fichero, "utf8");
    for (const c of lista) {
      const viejo = new RegExp(`("${c.nombre.replace("/", "\\/")}"\\s*:\\s*)"${c.de.replace(/[.^~]/g, (x) => `\\${x}`)}"`);
      texto = texto.replace(viejo, `$1"${c.a}"`);
    }
    writeFileSync(fichero, texto);
  }
}

export function mensaje(cambios) {
  const unicos = [...new Map(cambios.map((c) => [c.nombre, c.a])).entries()];
  return `chore(deps): update ${unicos.map(([n, v]) => `${n} to ${v}`).join(", ")}`;
}

if (import.meta.url === `file://${process.argv[1].replace(/\\/g, "/").replace(/^(?=[A-Za-z]:)/, "/")}`) {
  const { cambios, mayores } = planear(process.cwd());
  for (const c of cambios) console.log(`↑ ${c.nombre} ${c.de} → ${c.a} (${c.fichero})`);
  for (const m of mayores) console.log(`! ${m.nombre} ${m.version} es una versión mayor: no se aplica sola (hace falta /poner-al-dia)`);
  if (cambios.length === 0) console.log("✓ @unho/* ya está al día.");
  if (process.argv.includes("--escribir") && cambios.length) aplicar(cambios);
  if (process.env.GITHUB_OUTPUT) {
    appendFileSync(process.env.GITHUB_OUTPUT, `cambios=${cambios.length > 0}\nmensaje=${cambios.length ? mensaje(cambios) : ""}\n`);
  }
}
