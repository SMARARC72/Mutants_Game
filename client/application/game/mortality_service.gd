extends RefCounted
## MortalityService (Wave 18 "Death With Weight") — the application-layer DEATH RULE. Given a
## finished battle result already folded onto the run (party_hp -> creature["hp"], Wave 3), it
## decides who is scarred and who is GONE, moves the dead out of run.party into the
## run.flags["graveyard"] memorial ledger, and credits their remains as Lab parts through the
## InventoryAdapter ("death funds creation").
##
## THE RULE (ADR-0020; measured via tools/balance_slice_check.py + the oracle death probe):
##   * A battle that was NOT lost (win / catch / stalemate / flee) never kills — every party
##     creature that hit 0 HP is dragged out by its coven at 1 HP, marked "scarred" (the MERCY
##     rule; deterministic, no roll). At current tuning a T3-elite win downs two of three
##     starters EVERY fight — deaths there would be cruelty, not weight.
##   * A LOST battle buries every party creature that ended at 0 HP — except the LAST LIGHT:
##     the active/lead creature survives at 1 HP, scarred, so a wipe never empties the party
##     (there is no recruit-from-zero path; an empty coven is a soft-lock, not a consequence).
##   * No re-softening (Dracula veto): the dead never return; there is no full-HP rebuild.
##
## HP / is_dead stay OUT of client/domain/ — this file reads engine-owned numbers off the
## result and computes NO combat math. Parts are picked deterministically (FNV-1a over the
## creature's identity tag — LOCAL hash, never a canonical stream) from splice_rules.json's
## wild-rank ingredient keys, so the same death always yields the same remains.

const SpliceRulesScript := preload("res://infrastructure/lab/splice_rules.gd")

## The run.flags key holding the memorial ledger (Array of memorial dicts, death order).
const GRAVEYARD_FLAG := "graveyard"
## Only wild-rank ingredient keys are harvestable from a fallen coven creature (a dead marsh
## sprout never yields a god_core). Data-driven off splice_rules.json ingredient_compat[*].rank.
const HARVEST_RANK := "wild"
## Fallback part table if the ruleset is unreadable (REAL splice_rules.json keys/types).
const FALLBACK_PARTS := {"claw": "organ", "horn": "organ"}

## item_key -> ingredient category, lazily read from splice_rules.json (wild-rank only).
static var _part_types: Dictionary = {}


## Apply the death rule to `run` after a battle result was folded onto the party. `spared_index`
## is the active/lead party index (the Last Light on a lost battle). Mutates run.party /
## run.flags and credits parts into `inventory`. Returns:
##   { "deaths": Array[memorial dicts appended to the graveyard], "scarred": Array[int] }
static func resolve(
	run: RunContext,
	result: Dictionary,
	spared_index: int,
	inventory: InventoryAdapter,
	catalog: SpeciesCatalog
) -> Dictionary:
	var out := {"deaths": [], "scarred": []}
	if run == null:
		return out
	var zeroed := _zeroed_indices(run.party)
	if zeroed.is_empty():
		return out
	var lost := _battle_was_lost(result)
	# MERCY rule: the battle was not lost — every downed creature is dragged out at 1 HP, scarred.
	if not lost:
		for idx: int in zeroed:
			_scar(run.party[idx] as Dictionary)
			(out["scarred"] as Array).append(idx)
		return out
	# LOST battle: the zeroed die — except the Last Light (the lead survives, scarred).
	var spared := clampi(spared_index, 0, run.party.size() - 1)
	var spared_creature: Variant = run.party[spared] if spared < run.party.size() else null
	var dead_indices: Array = []
	for idx: int in zeroed:
		if idx == spared:
			_scar(run.party[idx] as Dictionary)
			(out["scarred"] as Array).append(idx)
		else:
			dead_indices.append(idx)
	# Bury back-to-front so earlier indices stay valid while we remove.
	dead_indices.reverse()
	for idx: int in dead_indices:
		var creature: Dictionary = run.party[idx]
		var memorial := _bury(run, creature, result, inventory, catalog)
		(out["deaths"] as Array).append(memorial)
		run.party.remove_at(idx)
	(out["deaths"] as Array).reverse()  # report in party order, not removal order
	# The lead's index may have shifted left past the removals — re-aim the flag at the SAME dict.
	if spared_creature is Dictionary:
		for i in run.party.size():
			if is_same(run.party[i], spared_creature):
				run.flags["active_creature"] = i
				break
	return out


## The memorial ledger (run.flags["graveyard"]) — [] when absent / no run.
static func graveyard_of(run: RunContext) -> Array:
	if run == null:
		return []
	var raw: Variant = run.flags.get(GRAVEYARD_FLAG, [])
	return raw if raw is Array else []


# === internals ================================================================================ #


## Party indices whose folded end-of-battle HP is 0 (only entries that were IN the fight carry
## the key — auto/boss round-trips without party_hp fold nothing and kill nothing).
static func _zeroed_indices(party: Array) -> Array:
	var out: Array = []
	for i in party.size():
		var entry: Variant = party[i]
		if not (entry is Dictionary):
			continue
		var creature: Dictionary = entry
		if not creature.has("hp") or bool(creature.get("is_dead", false)):
			continue
		if int(creature.get("hp", 1)) <= 0:
			out.append(i)
	return out


## True when the battle was LOST outright: not won, and not a flee (an escape is not a defeat).
static func _battle_was_lost(result: Dictionary) -> bool:
	if bool(result.get("player_won", false)):
		return false
	return str(result.get("winner", "")) != "fled"


## The mercy mark: dragged out at 1 HP, scarred (camp Rest clears the scar — GameController).
static func _scar(creature: Dictionary) -> void:
	creature["hp"] = 1
	creature["scarred"] = true


## Bury one creature: mark is_dead, shape its memorial, credit its remains, append to the ledger.
static func _bury(
	run: RunContext,
	creature: Dictionary,
	result: Dictionary,
	inventory: InventoryAdapter,
	catalog: SpeciesCatalog
) -> Dictionary:
	creature["is_dead"] = true
	var species_id := str(creature.get("species_id", ""))
	var tag := _identity_tag(creature)
	var parts := _credit_parts(tag, species_id, inventory)
	var memorial := {
		"name": _display_name(creature, catalog),
		"species_id": species_id,
		"sigil": tag,
		"force": _force_of(creature, catalog),
		"cause": _cause_of(result),
		"turn": int(result.get("turns", 0)),
		"region": str(run.world_state.get("active_region", "")),
		"parts": parts,
		"creature": creature.duplicate(true),
	}
	var graveyard: Array = graveyard_of(run)
	graveyard.append(memorial)
	run.flags[GRAVEYARD_FLAG] = graveyard
	return memorial


## Deterministically credit 1-2 wild-rank parts for a death (FNV-1a over the identity tag —
## the same death always yields the same remains). Returns the credited item_key list.
static func _credit_parts(tag: String, species_id: String, inventory: InventoryAdapter) -> Array:
	var granted: Array = []
	if inventory == null:
		return granted
	_ensure_part_types()
	var keys: Array = _part_types.keys()
	keys.sort()
	if keys.is_empty():
		return granted
	var h := _fnv1a_32("%s/%s" % [tag, species_id])
	var count := 1 + (h % 2)
	for i in count:
		var key := str(keys[((h >> (5 * i)) & 0xFFFF) % keys.size()])
		inventory.add(str(_part_types[key]), key, 1, {"source": "memorial"})
		granted.append(key)
	return granted


## Lazily read splice_rules.json's wild-rank ingredient keys -> categories (the harvest table).
static func _ensure_part_types() -> void:
	if not _part_types.is_empty():
		return
	var rules: SpliceRules = SpliceRulesScript.load_default()
	if rules != null:
		var compat: Variant = rules.data.get("ingredient_compat", {})
		if compat is Dictionary:
			for key: Variant in compat as Dictionary:
				var spec: Variant = (compat as Dictionary)[key]
				if spec is Dictionary and str((spec as Dictionary).get("rank", "")) == HARVEST_RANK:
					_part_types[str(key)] = str((spec as Dictionary).get("type", "organ"))
	if _part_types.is_empty():
		_part_types = FALLBACK_PARTS.duplicate()


## The creature's display name for the memorial: nickname, else species name, else a last rite.
static func _display_name(creature: Dictionary, catalog: SpeciesCatalog) -> String:
	var nickname := str(creature.get("nickname", ""))
	if nickname != "":
		return nickname
	if catalog != null:
		var species: SpeciesData = catalog.get_by_id(str(creature.get("species_id", "")))
		if species != null:
			return species.name
	return "The Nameless"


## The creature's identity tag (its one-of-one sigil seed): lineage.rng_seed_tag, else nickname
## (mirrors PortraitUtil.instance_tag_of — kept local, application never imports presentation).
static func _identity_tag(creature: Dictionary) -> String:
	var lineage: Variant = creature.get("lineage", {})
	if lineage is Dictionary:
		var tag := str((lineage as Dictionary).get("rng_seed_tag", ""))
		if tag != "":
			return tag
	return str(creature.get("nickname", ""))


## The species' primary force (the memorial sigil's accent), "" for hybrids/unknowns.
static func _force_of(creature: Dictionary, catalog: SpeciesCatalog) -> String:
	if catalog == null:
		return ""
	var species: SpeciesData = catalog.get_by_id(str(creature.get("species_id", "")))
	return species.force_primary if species != null else ""


## The memorial cause line, read off the result (never the word "fainted" — Dracula).
static func _cause_of(result: Dictionary) -> String:
	var foes: Array = result.get("enemy_survivors", []) as Array
	if not foes.is_empty():
		return "Felled by %s" % str(foes[0])
	return "Lost to the wilds"


## FNV-1a over UTF-8 bytes, 32-bit (mirrors SigilGen.fnv1a_32; kept local for layering).
static func _fnv1a_32(text: String) -> int:
	var h := 0x811C9DC5
	for b in text.to_utf8_buffer():
		h = ((h ^ int(b)) * 0x01000193) & 0xFFFFFFFF
	return h
