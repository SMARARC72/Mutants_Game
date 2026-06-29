class_name KitFactory
extends RefCounted
## KitFactory (Phase 10 · Slice 0) — derives a creature's SKILL KIT (Array of skill ids) from its two
## forces, drawing from the force-grouped SkillEngine library (Constants.BALANCE["skill"]["library"]).
## APPLICATION/battle layer: this is a pure MAPPING POLICY (which skills a creature knows), NOT oracle
## math — the engine still owns every number (damage/heal/shield via SkillEngine). It composes no
## stats; it only chooses skill ids.
##
## Determinism: the same (prim, sec) ALWAYS yields the same kit (library iteration is insertion-ordered
## in GDScript), so a creature's loadout is stable across battles + saves. Single-sourced from the
## library, so adding a skill there flows through here automatically.
##
## Rule: a creature knows its PRIMARY force's full pool, then its SECONDARY force's pool (deduped). The
## primary's skills lead the ability bar (the home force first). A mono-force creature gets just the
## primary pool. Some force pairs (e.g. Cosmos+Eros) yield a pure-support kit with no damage verb — a
## legitimate role outcome (the design celebrates supports having a real job); a balanced party covers it.


static func _library() -> Dictionary:
	return Constants.BALANCE["skill"]["library"]


## The skill ids belonging to `force`, in the library's declaration (insertion) order — stable.
static func skills_of_force(force: String) -> Array:
	var out: Array = []
	var lib := _library()
	for skill_name in lib:
		if String((lib[skill_name] as Dictionary).get("force", "")) == force:
			out.append(skill_name)
	return out


## The kit for a (prim, sec) force pair: primary pool first, then the secondary's new skills (deduped;
## sec may equal/overlap prim). Empty forces are ignored.
static func kit_for(prim: String, sec: String) -> Array:
	var kit: Array = []
	for skill_name in skills_of_force(prim):
		if not kit.has(skill_name):
			kit.append(skill_name)
	if sec != "" and sec != prim:
		for skill_name in skills_of_force(sec):
			if not kit.has(skill_name):
				kit.append(skill_name)
	return kit
