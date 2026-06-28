#!/usr/bin/env node
/**
 * gen_species_db.mjs — pack the single-sourced species catalog into a Godot text Resource
 * (Cluster 2, D2). ADR-006: ONE source, many consumers. This reads the already-generated
 * client/catalog/species.json (itself derived from docs/creature_registry.csv by gen_catalog.mjs)
 * and emits client/catalog/species/species_db.tres — a packed SpeciesDB holding one typed
 * SpeciesData sub-resource per row.
 *
 * Why a committed .tres (not the in-editor csv-data-importer)? Godot is not required in CI to
 * (re)import; a text .tres is a native, deterministic, diffable artifact that loads headlessly.
 * The csv-data-importer addon is vendored as the in-editor authoring path; this generator is the
 * build-time path that keeps the client Resources, the JSON bundle, and the Postgres seed in lock
 * step (the catalog-parity test enforces count + id-set equality across all three).
 *
 * Deterministic: stable ids, registry order, no timestamps. Run after gen_catalog.mjs.
 * Run: node tools/gen_catalog.mjs && node tools/gen_species_db.mjs
 */
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const CAT = join(ROOT, "client", "catalog");
const OUT_DIR = join(CAT, "species");
mkdirSync(OUT_DIR, { recursive: true });

// Stable resource UIDs/paths (mirror the committed .gd.uid files).
const DB_SCRIPT = "res://infrastructure/catalog/species_db.gd";
const DATA_SCRIPT = "res://infrastructure/catalog/species_data.gd";
const DB_SCRIPT_UID = "uid://bspeciesdb0aa"; // must match species_db.gd.uid
const DATA_SCRIPT_UID = "uid://cspeciesdat0a"; // must match species_data.gd.uid
const DB_UID = "uid://aspeciesdbres0"; // the packed resource's own stable uid

// JSON key -> .tres property name. `class` is a GDScript keyword, so species_data.gd exposes the
// species.class column as the export var `species_class`; the .tres property name follows the var.
const FIELDS = [
  ["id", "id"],
  ["name", "name"],
  ["batch", "batch"],
  ["art_ref", "art_ref"],
  ["class", "species_class"],
  ["rank", "rank"],
  ["tier", "tier"],
  ["force_primary", "force_primary"],
  ["force_secondary", "force_secondary"],
  ["role", "role"],
  ["evolution_line", "evolution_line"],
  ["stage", "stage"],
  ["signature_skill", "signature_skill"],
  ["description", "description"],
  ["status", "status"],
];

// Godot text-resource string escaping: backslash, double-quote, newline, tab, carriage return.
function gstr(v) {
  const s = v == null ? "" : String(v);
  return (
    '"' +
    s
      .replace(/\\/g, "\\\\")
      .replace(/"/g, '\\"')
      .replace(/\n/g, "\\n")
      .replace(/\r/g, "\\r")
      .replace(/\t/g, "\\t") +
    '"'
  );
}

function packedStringArray(arr) {
  if (!arr || arr.length === 0) return "PackedStringArray()";
  return "PackedStringArray(" + arr.map(gstr).join(", ") + ")";
}

// Deterministic sub-resource id from the row id (Godot ids must be [A-Za-z0-9_]).
function subId(id) {
  return "SpeciesData_" + String(id).replace(/[^A-Za-z0-9_]/g, "_");
}

const species = JSON.parse(readFileSync(join(CAT, "species.json"), "utf8")).species;

// load_steps = ext_resources (2) + sub_resources (one per species) + 1.
const loadSteps = 2 + species.length + 1;

let out = "";
out +=
  `[gd_resource type="Resource" script_class="SpeciesDB" load_steps=${loadSteps} ` +
  `format=3 uid="${DB_UID}"]\n\n`;
out += `[ext_resource type="Script" uid="${DB_SCRIPT_UID}" path="${DB_SCRIPT}" id="1_db"]\n`;
out += `[ext_resource type="Script" uid="${DATA_SCRIPT_UID}" path="${DATA_SCRIPT}" id="2_data"]\n\n`;

const subIds = [];
for (const s of species) {
  const sid = subId(s.id);
  subIds.push(sid);
  out += `[sub_resource type="Resource" id="${sid}"]\n`;
  out += `script = ExtResource("2_data")\n`;
  for (const [jsonKey, prop] of FIELDS) {
    out += `${prop} = ${gstr(s[jsonKey])}\n`;
  }
  out += `tags = ${packedStringArray(s.tags)}\n\n`;
}

out += `[resource]\n`;
out += `script = ExtResource("1_db")\n`;
const arrBody = subIds.map((id) => `SubResource("${id}")`).join(", ");
out += `species = Array[ExtResource("2_data")]([${arrBody}])\n`;

writeFileSync(join(OUT_DIR, "species_db.tres"), out);
console.log(`species_db.tres: ${species.length} SpeciesData sub-resources (load_steps=${loadSteps})`);
