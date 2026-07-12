extends Node
## Releases presentation-owned static resources before ResourceServer teardown. Static caches are
## deliberate frame-time optimizations, but every owner must also participate in deterministic exit.

const CACHE_OWNERS: Array[Script] = [
	preload("res://presentation/overworld/overworld_tileset.gd"),
	preload("res://presentation/overworld/overworld_ambience.gd"),
	preload("res://presentation/overworld/npc_figures.gd"),
	preload("res://presentation/overworld/overworld_structures.gd"),
	preload("res://presentation/overworld/overworld_tokens.gd"),
	preload("res://presentation/overworld/quest_markers.gd"),
	preload("res://presentation/creature/living_plate.gd"),
	preload("res://presentation/lab/lab_bench_view.gd"),
]


func _exit_tree() -> void:
	for owner in CACHE_OWNERS:
		if owner.has_method("clear_runtime_cache"):
			owner.call("clear_runtime_cache")
