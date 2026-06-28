#!/usr/bin/env node
/**
 * test_catalog_parity.mjs — CI schema-lint for the content pipeline (Cluster 2, D4/D6, ADR-006).
 *
 * Asserts, and FAILS (exit 1) on any mismatch:
 *   A. The registry CSV columns match the SpeciesData / `species`-table contract (after the
 *      documented reconciliation: line->evolution_line, acquisition dropped, signature_skill
 *      defaulted). No silent column drift in docs/creature_registry.csv.
 *   B. The client catalog bundle (client/catalog/species.json), the packed client Resource
 *      (client/catalog/species/species_db.tres) and the Postgres seed (supabase/seed.sql) agree
 *      EXACTLY on species count AND id-set. One source, no divergence between consumers.
 *
 * Pure Node (no deps). Run: node tools/test_catalog_parity.mjs
 */
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);
const ok = (msg) => console.log("  ok: " + msg);

// ---- minimal RFC-4180 CSV parser (quoted fields w/ commas + "" escapes) ----
function parseCSV(text) {
  const rows = [];
  let row = [], field = "", inQ = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQ) {
      if (c === '"') {
        if (text[i + 1] === '"') { field += '"'; i++; } else inQ = false;
      } else field += c;
    } else if (c === '"') inQ = true;
    else if (c === ",") { row.push(field); field = ""; }
    else if (c === "\n") { row.push(field); rows.push(row); row = []; field = ""; }
    else if (c === "\r") { /* skip */ }
    else field += c;
  }
  if (field.length || row.length) { row.push(field); rows.push(row); }
  return rows;
}

const setEq = (a, b) => a.size === b.size && [...a].every((x) => b.has(x));
const diff = (a, b) => [...a].filter((x) => !b.has(x));

// ===========================================================================
// A. CSV columns vs the SpeciesData / species-table contract
// ===========================================================================
console.log("A. registry CSV columns vs species-table contract");

// The CSV header the pipeline is built against (docs/creature_registry.csv).
const EXPECTED_CSV_COLS = [
  "id", "name", "batch", "rank", "class", "art_ref", "tier", "line", "stage",
  "force_primary", "force_secondary", "role", "acquisition", "tags", "description", "status",
];

// The species Postgres table contract (supabase/migrations/0001_init.sql) — the target schema.
const SPECIES_TABLE_COLS = [
  "id", "name", "batch", "art_ref", "class", "rank", "tier", "force_primary",
  "force_secondary", "role", "evolution_line", "stage", "signature_skill", "tags",
  "description", "status",
];

// Documented reconciliation between the two (Cluster 2 spec + ADR-006):
//   CSV `line`        -> table `evolution_line`
//   CSV `acquisition` -> dropped (no table column)
//   table `signature_skill` -> not in CSV (defaulted)
const CSV_TO_TABLE = { line: "evolution_line" };
const CSV_DROPPED = new Set(["acquisition"]);
const TABLE_NOT_IN_CSV = new Set(["signature_skill"]);

const csv = parseCSV(readFileSync(join(ROOT, "docs", "creature_registry.csv"), "utf8"));
const csvHeader = csv[0].map((h) => h.trim());

if (JSON.stringify(csvHeader) === JSON.stringify(EXPECTED_CSV_COLS)) {
  ok(`CSV header matches the expected ${EXPECTED_CSV_COLS.length} columns`);
} else {
  fail(
    "CSV header drifted from the expected contract.\n" +
      `    expected: ${EXPECTED_CSV_COLS.join(",")}\n` +
      `    actual:   ${csvHeader.join(",")}`
  );
}

// Map CSV columns through the reconciliation and confirm they cover the table contract.
const mappedFromCsv = new Set();
for (const col of csvHeader) {
  if (CSV_DROPPED.has(col)) continue;
  mappedFromCsv.add(CSV_TO_TABLE[col] ?? col);
}
for (const t of TABLE_NOT_IN_CSV) mappedFromCsv.add(t); // defaulted, not sourced from CSV

const tableSet = new Set(SPECIES_TABLE_COLS);
if (setEq(mappedFromCsv, tableSet)) {
  ok("CSV columns reconcile 1:1 onto the species-table contract");
} else {
  const missing = diff(tableSet, mappedFromCsv);
  const extra = diff(mappedFromCsv, tableSet);
  fail(
    "CSV->table reconciliation does not cover the species table.\n" +
      (missing.length ? `    table cols not produced: ${missing.join(", ")}\n` : "") +
      (extra.length ? `    produced cols not in table: ${extra.join(", ")}` : "")
  );
}

// ===========================================================================
// B. client catalog (JSON) == client Resource (.tres) == Postgres seed
// ===========================================================================
console.log("B. client catalog == client Resource == Postgres seed (count + id-set)");

// --- B1. client bundle: client/catalog/species.json ---
const jsonSpecies = JSON.parse(
  readFileSync(join(ROOT, "client", "catalog", "species.json"), "utf8")
).species;
const jsonIds = new Set(jsonSpecies.map((s) => s.id));
if (jsonIds.size !== jsonSpecies.length) {
  fail(`species.json has duplicate ids (${jsonSpecies.length} rows, ${jsonIds.size} unique)`);
}

// --- B2. client Resource: client/catalog/species/species_db.tres ---
const tres = readFileSync(join(ROOT, "client", "catalog", "species", "species_db.tres"), "utf8");
// Each species row is a sub_resource with an `id = "..."` property line.
const tresIds = new Set();
const subBlocks = tres.split('[sub_resource type="Resource"').slice(1);
for (const block of subBlocks) {
  const m = block.match(/\bid = "((?:[^"\\]|\\.)*)"/);
  if (m) tresIds.add(m[1]);
}
// Also confirm the packed array references exactly that many sub-resources.
const arrMatch = tres.match(/species = Array\[ExtResource\("[^"]+"\)\]\(\[([\s\S]*?)\]\)/);
const arrCount = arrMatch
  ? (arrMatch[1].match(/SubResource\(/g) || []).length
  : -1;

// --- B3. Postgres seed: supabase/seed.sql (species insert block) ---
const seed = readFileSync(join(ROOT, "supabase", "seed.sql"), "utf8");
const startMarker = "insert into species (";
const start = seed.indexOf(startMarker);
const seedIds = new Set();
if (start === -1) {
  fail("seed.sql has no `insert into species (` block");
} else {
  // The species INSERT tuples run from `values` to the `on conflict` clause. (Do NOT split on
  // `;` — descriptions contain semicolons, e.g. 'Feral runed wolf; bleeds what it bites.')
  const valuesAt = seed.indexOf(" values", start);
  let end = seed.indexOf("on conflict", valuesAt);
  if (end === -1) end = seed.indexOf(";", valuesAt);
  const block = seed.slice(valuesAt, end);
  // Each tuple begins `('<id>', ...` at the start of a line.
  const re = /^\s*\('((?:[^'']|'')*)'/gm;
  let m;
  while ((m = re.exec(block)) !== null) seedIds.add(m[1].replace(/''/g, "'"));
}

// --- counts ---
console.log(
  `  counts: json=${jsonIds.size}, tres=${tresIds.size} (array refs=${arrCount}), seed=${seedIds.size}`
);

if (jsonIds.size === tresIds.size && tresIds.size === seedIds.size && jsonIds.size > 0) {
  ok(`all three sources report ${jsonIds.size} species`);
} else {
  fail(
    `species COUNT mismatch: json=${jsonIds.size}, tres=${tresIds.size}, seed=${seedIds.size}`
  );
}

if (arrCount !== tresIds.size) {
  fail(`.tres packed array (${arrCount}) != sub_resource count (${tresIds.size})`);
} else {
  ok(".tres packed array length matches its sub_resource count");
}

// --- id-set equality (pairwise) ---
function checkSet(nameA, a, nameB, b) {
  if (setEq(a, b)) {
    ok(`${nameA} id-set == ${nameB} id-set`);
    return;
  }
  const onlyA = diff(a, b).slice(0, 10);
  const onlyB = diff(b, a).slice(0, 10);
  fail(
    `${nameA} vs ${nameB} id-set divergence.\n` +
      (onlyA.length ? `    only in ${nameA}: ${onlyA.join(", ")}\n` : "") +
      (onlyB.length ? `    only in ${nameB}: ${onlyB.join(", ")}` : "")
  );
}
checkSet("json", jsonIds, "seed", seedIds);
checkSet("json", jsonIds, "tres", tresIds);

// ===========================================================================
console.log("");
if (failures.length) {
  console.error(`CATALOG PARITY: FAIL (${failures.length})`);
  for (const f of failures) console.error("  - " + f);
  process.exit(1);
}
console.log("CATALOG PARITY: PASS");
