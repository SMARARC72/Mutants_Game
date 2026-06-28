class_name SpeciesDB
extends Resource
## SpeciesDB (Cluster 2, D2) — the single packed catalog Resource holding every SpeciesData row.
##
## INFRASTRUCTURE/catalog layer. Generated from docs/creature_registry.csv at build time by
## tools/gen_species_db.mjs into res://catalog/species/species_db.tres, then read ONLY through the
## SpeciesCatalog facade. Pure static data — no derived/stat fields, no computation.

@export var species: Array[SpeciesData] = []
