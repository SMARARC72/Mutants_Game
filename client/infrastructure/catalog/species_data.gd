class_name SpeciesData
extends Resource
## SpeciesData (Cluster 2, D1) — a single creature-registry row as a typed, read-only Resource.
##
## INFRASTRUCTURE/catalog layer. Mirrors the `species` Postgres table contract EXACTLY
## (supabase/migrations/0001_init.sql) — pure static catalog data, NOTHING derived. No stats, no
## RNG, no computation. Runtime stats are produced by the oracle (`domain/stat_engine.gd`) from
## this data + a creature's genome; this Resource never touches the domain layer.
##
## Single source of truth = docs/creature_registry.csv. These Resources are generated at build
## time (tools/gen_species_db.mjs packs the CSV into res://catalog/species/species_db.tres) and
## read ONLY through the SpeciesCatalog facade — never directly by the rest of the game.
##
## Field/column reconciliation vs the registry CSV (which differs from the table):
##   - CSV `line`        -> `evolution_line` (renamed)
##   - CSV `acquisition` -> DROPPED (no such column in the species table)
##   - `signature_skill` -> not present in the CSV; defaults to "" (table column is nullable)

@export var id: String = ""
@export var name: String = ""
@export var batch: String = ""
@export var art_ref: String = ""
@export var species_class: String = ""  # `class` is a GDScript keyword; maps to species.class
@export var rank: String = ""
@export var tier: String = ""
@export var force_primary: String = ""
@export var force_secondary: String = ""
@export var role: String = ""
@export var evolution_line: String = ""
@export var stage: String = ""
@export var signature_skill: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export var description: String = ""
@export var status: String = ""
