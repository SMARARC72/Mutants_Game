extends RefCounted
## LabLineage (Wave 15 extraction) — the Lab's creature_instance <-> bench-tuple DATA MAPPING,
## lifted verbatim from lab_screen.gd so the staged-table rebuild fits the file cap. PRESENTATION
## support, NO math (ADR-015): these helpers only reshape dictionaries — the oracle's numbers pass
## through cached, never recomputed, and the contamination guard still proves the cached block
## equals LabEngine on the same config+seed.


## Map a party creature_instance (by index) into the LabBench tuple [name, prim, sec, tier] by
## reading its species row through the catalog (mirrors MonFactory.from_creature). A spliced hybrid
## (species_id == "") resolves from the oracle identity cached at commit (stats_cached), so a
## committed hybrid is itself pickable/spliceable again. Returns [] if unresolvable.
static func creature_tuple(party: Array, party_index: int, catalog: SpeciesCatalog) -> Array:
	if party_index < 0 or party_index >= party.size():
		return []
	var entry: Variant = party[party_index]
	if not (entry is Dictionary):
		return []
	var creature: Dictionary = entry
	var species_id := str(creature.get("species_id", ""))
	if species_id == "":
		return _cached_tuple(creature)
	var species: SpeciesData = catalog.get_by_id(species_id) if catalog != null else null
	if species == null:
		return []
	var display_name := str(creature.get("nickname", ""))
	if display_name == "":
		display_name = species.name
	return [display_name, species.force_primary, species.force_secondary, species.tier]


## A spliced hybrid's LabBench tuple, from the prim/sec/tier the oracle reported at commit
## (stats_cached — cached verbatim, never recomputed). [] when the cache is absent/incomplete.
static func _cached_tuple(creature: Dictionary) -> Array:
	var cached_raw: Variant = creature.get("stats_cached", {})
	if not (cached_raw is Dictionary):
		return []
	var cached: Dictionary = cached_raw
	var prim := str(cached.get("prim", ""))
	var tier := str(cached.get("tier", ""))
	if prim == "" or tier == "":
		return []
	var display_name := str(creature.get("nickname", ""))
	if display_name == "":
		display_name = "Splice"
	return [display_name, prim, str(cached.get("sec", "")), tier]


## A compact, non-numeric provenance tag for a parent party creature (for lineage.parents).
## portrait_species carries the parent's OWN plate identity (its species, or — for a hybrid parent —
## its recorded dominant ancestor), so hybrid portraits survive recursive splices.
static func parent_tag(party: Array, party_index: int) -> Dictionary:
	if party_index < 0 or party_index >= party.size() or not (party[party_index] is Dictionary):
		return {}
	var entry: Dictionary = party[party_index]
	return {
		"species_id": str(entry.get("species_id", "")),
		"nickname": str(entry.get("nickname", "")),
		"portrait_species": PortraitUtil.portrait_species_of(entry),
	}


## Remove the sealed splice's PARENT creature_instances from the run's party (fuse: subject +
## donor; mutate: the host). Descending index order so the second erase is not shifted by the
## first. The caller then appends the hybrid — the newborn replaces its parents in the roster.
static func consume_parents(run: RunContext, parent_indices: Array) -> void:
	if run == null:
		return
	var indices := parent_indices.duplicate()
	indices.sort()
	indices.reverse()
	for idx in indices:
		var i := int(idx)
		if i >= 0 and i < run.party.size():
			run.party.remove_at(i)


## Shape the oracle's creature dict into a creature_instance (RunContext.party shape / the
## creature_instances column contract). The oracle's numbers are cached VERBATIM (stats_cached,
## entropy) — this never recomputes them. lineage.splice records provenance so the op is
## replayable. `parents` are parent_tag() dicts; `tuples` the parents' bench tuples (index-aligned).
static func to_creature_instance(
	creature: Dictionary,
	splice_config: Dictionary,
	op: String,
	op_id: String,
	parents: Array,
	tuples: Array
) -> Dictionary:
	return {
		"species_id": "",  # a spliced hybrid is not a catalog species — its forces live in lineage
		"nickname": str(creature.get("name", "Splice")),
		"genome": {},
		"expression": 1.0,
		"bond": 0,
		# The oracle's entropy ledger (a number it computed — cached, not recomputed here).
		"entropy": int(creature.get("entropy", 0)),
		"awakenings": 0,
		# The oracle's stat block, cached verbatim (the contamination guard proves equality vs the
		# engine on the same config+seed). prim/sec/tier/hp/bst are carried so the party entry is
		# usable without re-deriving a species row this hybrid does not have.
		"stats_cached":
		{
			"prim": str(creature.get("prim", "")),
			"sec": str(creature.get("sec", "")),
			"tier": str(creature.get("tier", "")),
			"hp": int(creature.get("hp", 0)),
			"bst": int(creature.get("bst", 0)),
			"stats": (creature.get("stats", {}) as Dictionary).duplicate(true),
		},
		"skills": [],
		"status_effects": {},
		"lineage":
		{
			"spliced": true,
			"op": op,
			"parents": parents,
			# Presentation provenance: which parent's plate represents this hybrid (dominant parent —
			# the one whose primary force carried into the blend; subject wins ties). Propagated
			# through hybrid-of-hybrid lineages so a deep splice still renders its founding line.
			"portrait_species": dominant_portrait_species(creature, parents, tuples),
			"splice_config": splice_config.duplicate(true),
			"rng_seed_tag": op_id,
			"taboo": bool(creature.get("taboo", false)),
		},
		"is_dead": false,
	}


## The DOMINANT parent's plate identity for a newborn hybrid: the parent whose primary force equals
## the oracle-blended prim (the face the blend kept), the subject on ties/absence. Falls through to
## any parent with a resolvable plate. Pure data pick — no numbers.
static func dominant_portrait_species(creature: Dictionary, parents: Array, tuples: Array) -> String:
	var hybrid_prim := str(creature.get("prim", ""))
	var ordered: Array = []
	# Prefer the parent whose primary force the blend kept (index-aligned with `parents`).
	for i in parents.size():
		var tuple: Array = tuples[i] if i < tuples.size() else []
		if tuple.size() >= 4 and str(tuple[1]) == hybrid_prim:
			ordered.append(parents[i])
	for parent in parents:
		if not ordered.has(parent):
			ordered.append(parent)
	for parent in ordered:
		if parent is Dictionary:
			var pid := str((parent as Dictionary).get("portrait_species", ""))
			if pid != "":
				return pid
	return ""
