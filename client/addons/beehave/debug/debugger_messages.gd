class_name BeehaveDebuggerMessages


# LOCAL PATCH (Mutants W13, see addons/THIRD_PARTY.md): also require an ACTIVE debugger session.
# Upstream v2.9.2 only checks the editor feature, so every headless/CLI run (GdUnit, CI) spams
# "Can't send message. No active debugger" per tree registration and per tick.
static func can_send_message() -> bool:
	return not Engine.is_editor_hint() and OS.has_feature("editor") and EngineDebugger.is_active()


static func register_tree(beehave_tree: Dictionary) -> void:
	if can_send_message():
		EngineDebugger.send_message("beehave:register_tree", [beehave_tree])


static func unregister_tree(instance_id: int) -> void:
	if can_send_message():
		EngineDebugger.send_message("beehave:unregister_tree", [instance_id])


static func process_tick(instance_id: int, status: int, blackboard: Dictionary = {}) -> void:
	if can_send_message():
		EngineDebugger.send_message("beehave:process_tick", [instance_id, status, blackboard])

static func process_interrupt(instance_id: int, blackboard: Dictionary = {}) -> void:
	if can_send_message():
		EngineDebugger.send_message("beehave:process_interrupt", [instance_id, blackboard])

static func process_begin(instance_id: int, blackboard: Dictionary = {}) -> void:
	if can_send_message():
		EngineDebugger.send_message("beehave:process_begin", [instance_id, blackboard])


static func process_end(instance_id: int, blackboard: Dictionary = {}) -> void:
	if can_send_message():
		EngineDebugger.send_message("beehave:process_end", [instance_id, blackboard])
