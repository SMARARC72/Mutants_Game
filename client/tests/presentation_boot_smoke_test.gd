extends GdUnitTestSuite
## Wave 1 boot-smoke — every script under presentation/ must COMPILE and, when Node-based,
## INSTANTIATE. A script whose source no longer compiles (the Options `_get` native-virtual
## override crash) loads with can_instantiate() == false, so this suite catches a broken screen
## BEFORE a player ever opens it. FAST by design: load + bare instantiate + free — no scene
## trees, no _ready (instances are never added to the tree).

const ROOT := "res://presentation"


func test_every_presentation_script_compiles() -> void:
	var paths := _gd_paths(ROOT)
	# Sanity: the recursive walk actually found the presentation tree.
	assert_int(paths.size()).is_greater(10)
	for path in paths:
		var script: Script = load(path)
		(
			assert_object(script)
			. override_failure_message("script failed to LOAD: %s" % path)
			. is_not_null()
		)
		if script == null:
			continue
		(
			assert_bool(script.can_instantiate())
			. override_failure_message("script does not COMPILE: %s" % path)
			. is_true()
		)


func test_every_node_script_instantiates() -> void:
	for path in _gd_paths(ROOT):
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			continue  # the compile test above reports these
		var base := script.get_instance_base_type()
		if not ClassDB.is_parent_class(base, "Node"):
			continue  # RefCounted/Resource helpers may carry ctor args; compile check suffices
		var instance: Object = script.new()
		(
			assert_object(instance)
			. override_failure_message("Node script failed to INSTANTIATE: %s" % path)
			. is_not_null()
		)
		if instance is Node:
			(instance as Node).free()


## Recursively collect every .gd under `root` (res:// paths). DirAccess walk — tests cannot glob.
func _gd_paths(root: String) -> Array[String]:
	var out: Array[String] = []
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var dir_path: String = pending.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				if not entry.begins_with("."):
					pending.append(full)
			elif entry.ends_with(".gd"):
				out.append(full)
			entry = dir.get_next()
		dir.list_dir_end()
	out.sort()
	return out
