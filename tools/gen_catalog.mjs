#!/usr/bin/env node
/**
 * gen_catalog.mjs — build the in-repo catalog bundle (ADR-006, D2). One source feeds
 * BOTH the client bundle (client/catalog/*.json) and the DB seed (via gen_seed.mjs).
 *
 *   species.json  <- docs/creature_registry.csv   (the 407-creature registry)
 *   gear.json     <- tools/balance_constants.json  (loot_engine GEAR — engine-faithful)
 *   skills.json   <- tools/balance_constants.json  (skill_engine SKILLS)
 *   factions.json <- authored (client/catalog/factions.json) — read for the manifest only
 *   version.json  <- generated manifest (counts + provenance)
 *
 * After the JSON bundle is written, this also packs the species into the Godot client Resource
 * (client/catalog/species/species_db.tres) via tools/gen_species_db.mjs (Cluster 2, D2) — one
 * source (the CSV) feeding the JSON bundle, the Postgres seed, AND the client catalog Resource.
 *
 * Deterministic (no timestamps) so re-running produces a stable, diffable result.
 * Run: node tools/gen_catalog.mjs
 */
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const CAT = join(ROOT, "client", "catalog");
mkdirSync(CAT, { recursive: true });

// ---- minimal RFC-4180 CSV parser (handles quoted fields w/ commas + "" escapes) ----
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

const nn = (s) => { const v = (s ?? "").trim(); return v === "" ? null : v; }; // "" -> null
const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");

// ---- species (from CSV) ---------------------------------------------------
const csv = parseCSV(readFileSync(join(ROOT, "docs", "creature_registry.csv"), "utf8"));
const header = csv[0];
const idx = Object.fromEntries(header.map((h, i) => [h.trim(), i]));
const species = [];
let skipped = 0;
for (let r = 1; r < csv.length; r++) {
  const row = csv[r];
  // A truly blank line (the parser yields [""]) is the only benign skip; ANY other column-count
  // mismatch is a malformed registry edit -> fail the build loudly (don't silently lose a row).
  if (!row || (row.length === 1 && row[0].trim() === "")) continue;
  if (row.length !== header.length) {
    const rid = idx.id != null ? (row[idx.id] ?? "").trim() : "";
    throw new Error(
      `gen_catalog: malformed CSV row ${r + 1} (id="${rid}") has ${row.length} columns, ` +
        `expected ${header.length}. Fix docs/creature_registry.csv.`
    );
  }
  const get = (k) => row[idx[k]];
  const force_primary = nn(get("force_primary"));
  if (!force_primary) { skipped++; continue; } // force_primary is NOT NULL + force CHECK
  const tagsRaw = nn(get("tags"));
  const tags = tagsRaw ? tagsRaw.split(";").map((t) => t.trim()).filter(Boolean) : null;
  species.push({
    id: get("id").trim(),
    name: nn(get("name")),
    batch: nn(get("batch")),
    art_ref: nn(get("art_ref")),
    class: nn(get("class")),
    rank: nn(get("rank")),
    tier: nn(get("tier")),
    force_primary,
    force_secondary: nn(get("force_secondary")),
    role: nn(get("role")),
    evolution_line: nn(get("line")),
    stage: nn(get("stage")),
    signature_skill: null, // not present in the registry CSV
    tags,
    description: nn(get("description")),
    status: nn(get("status")),
  });
}

// ---- gear + skills (from balance_constants.json) --------------------------
const balance = JSON.parse(readFileSync(join(ROOT, "tools", "balance_constants.json"), "utf8"));

const gear = Object.entries(balance.loot.gear).map(([name, g]) => {
  const { slot, rarity, force, ...effects } = g;
  return { id: slug(name), name, slot, rarity, force: force ?? null, effects };
});

const skills = Object.entries(balance.skill.library).map(([name, s]) => {
  const { force, verb, ap, ...effect } = s;
  return { id: slug(name), name, force, verb, ap, focus: null, effect };
});

// ---- factions (authored — read for the manifest) --------------------------
const factions = JSON.parse(readFileSync(join(CAT, "factions.json"), "utf8")).factions;

// ---- write bundle ---------------------------------------------------------
const J = (o) => JSON.stringify(o, null, 2) + "\n";
writeFileSync(join(CAT, "species.json"), J({ _source: "docs/creature_registry.csv", species }));
writeFileSync(join(CAT, "gear.json"), J({ _source: "tools/balance_constants.json (loot_engine.GEAR)", gear }));
writeFileSync(join(CAT, "skills.json"), J({ _source: "tools/balance_constants.json (skill_engine.SKILLS)", skills }));
writeFileSync(
  join(CAT, "version.json"),
  J({
    catalog_version: 1,
    counts: { species: species.length, gear: gear.length, skills: skills.length, factions: factions.length },
    sources: {
      species: "docs/creature_registry.csv",
      gear: "tools/balance_constants.json",
      skills: "tools/balance_constants.json",
      factions: "client/catalog/factions.json (authored from docs/Mutants_Game_Factions.md)",
    },
    notes: `${skipped} registry row(s) skipped (empty force_primary — NOT NULL + force CHECK).`,
  })
);

console.log(
  `catalog: species=${species.length} (skipped ${skipped}), gear=${gear.length}, skills=${skills.length}, factions=${factions.length}`
);

// ---- pack the client Godot Resource (Cluster 2, D2) -----------------------
// Same source, one more consumer: client/catalog/species/species_db.tres.
await import("./gen_species_db.mjs");
