class_name QuestTrackerFacade
extends RefCounted
## Thin facade over the vendored **Questify** quest-system addon (ADR-017). This is
## the ONLY place that touches `QuestResource`/`QuestNode`/`Questify` autoload types;
## QuestService (application) only ever sees plain Strings / Dictionaries.
##
## Questify is Resource-driven and graph-based. Rather than ship authored `.tres`
## quest graphs (editor-only, brittle headless), we build a minimal linear graph in
## code from a data-only quest definition: Start -> [objective per step] -> End. The
## addon then owns the objective bookkeeping (active/completed propagation + signals)
## and JSON-friendly (de)serialization. The addon computes NO gameplay outcomes; it
## is a pure objective/state tracker.
##
## NOTE: nothing here writes run state or gates anything — that is QuestService's job.
## This facade is purely "which objective of which quest is active/done".

const QuestResourceScript := preload("res://addons/questify/scripts/model/quest_resource.gd")
const QuestStartScript := preload("res://addons/questify/scripts/model/quest_start.gd")
const QuestObjectiveScript := preload("res://addons/questify/scripts/model/quest_objective.gd")
const QuestEndScript := preload("res://addons/questify/scripts/model/quest_end.gd")
const QuestEdgeScript := preload("res://addons/questify/scripts/model/quest_edge.gd")

# quest_id -> QuestResource instance currently tracked by the addon.
var _quests: Dictionary = {}
# quest_id -> ordered Array[String] of step ids (objective node ids).
var _step_ids: Dictionary = {}


## Registers + starts a quest in the addon from a data-only definition:
##   { "id": String, "name": String, "description": String,
##     "steps": [ { "id": String, "description": String }, ... ] }
func start_quest(definition: Dictionary) -> void:
	var quest_id: String = str(definition.get("id", ""))
	if quest_id == "" or _quests.has(quest_id):
		return
	var quest: Resource = _build_graph(definition)
	var instance: Resource = quest.instantiate()
	_quests[quest_id] = instance
	_get_manager().start_quest(instance)


func is_active(quest_id: String) -> bool:
	var quest: Resource = _quests.get(quest_id, null)
	if quest == null:
		return false
	return quest.started and not quest.completed


func is_completed(quest_id: String) -> bool:
	var quest: Resource = _quests.get(quest_id, null)
	if quest == null:
		return false
	return quest.completed


## Marks a single objective (step) complete + advances the addon's bookkeeping.
## Returns true if this completion finished the whole quest.
func complete_step(quest_id: String, step_id: String) -> bool:
	var quest: Resource = _quests.get(quest_id, null)
	if quest == null:
		return false
	for node in quest.nodes:
		if node is QuestObjectiveScript and node.id == step_id:
			node.completed = true
	_get_manager().update_quests()
	return quest.completed


## Forces the whole quest complete (used when a quest is satisfied wholesale).
func complete_quest(quest_id: String) -> void:
	var quest: Resource = _quests.get(quest_id, null)
	if quest == null:
		return
	for node in quest.nodes:
		if node is QuestObjectiveScript:
			node.completed = true
	_get_manager().update_quests()
	if not quest.completed:
		quest.complete_quest()


## The ordered list of currently-active step ids for a quest (usually 0 or 1).
func active_step_ids(quest_id: String) -> Array:
	var out: Array = []
	var quest: Resource = _quests.get(quest_id, null)
	if quest == null:
		return out
	for objective in quest.get_active_objectives():
		out.append(objective.id)
	return out


func completed_step_ids(quest_id: String) -> Array:
	var out: Array = []
	var quest: Resource = _quests.get(quest_id, null)
	if quest == null:
		return out
	for node in quest.nodes:
		if node is QuestObjectiveScript and node.completed:
			out.append(node.id)
	return out


func tracked_quest_ids() -> Array:
	return _quests.keys()


# --- persistence: serialize through the addon, store as JSON data (ADR-012) --- #


## Returns a data-only dictionary: quest_id -> Questify's serialized quest dict.
func serialize() -> Dictionary:
	var out: Dictionary = {}
	for quest_id in _quests:
		out[quest_id] = _quests[quest_id].serialize()
	return out


## Rebuilds tracker state from a save. `definitions` is quest_id -> definition so we
## can reconstruct the graph shape, then the addon restores completion via deserialize.
func deserialize(saved: Dictionary, definitions: Dictionary) -> void:
	_quests.clear()
	_step_ids.clear()
	var manager: Node = _get_manager()
	if manager == null:
		return
	manager.clear()
	# Questify.set_quests expects a typed Array[QuestResource]; build one so the typed
	# assignment in the addon succeeds.
	var restored: Array[QuestResource] = []
	for quest_id in saved:
		var definition: Dictionary = definitions.get(quest_id, {})
		if definition.is_empty():
			continue
		var quest: Resource = _build_graph(definition)
		var instance: Resource = quest.instantiate()
		instance.deserialize(saved[quest_id])
		_quests[quest_id] = instance
		restored.append(instance)
	manager.set_quests(restored)


# --- internal: build a linear Questify graph from data --- #


func _build_graph(definition: Dictionary) -> Resource:
	var quest: Resource = QuestResourceScript.new()
	var nodes: Array = []
	var edges: Array = []

	var start: Resource = QuestStartScript.new()
	start.id = "%s::start" % str(definition.get("id", "quest"))
	start.name = str(definition.get("name", definition.get("id", "Quest")))
	start.description = str(definition.get("description", ""))
	nodes.append(start)

	var step_ids: Array = []
	var previous: Resource = start
	var steps: Array = definition.get("steps", [])
	for step in steps:
		var objective: Resource = QuestObjectiveScript.new()
		objective.id = str(step.get("id", ""))
		objective.description = str(step.get("description", ""))
		step_ids.append(objective.id)
		nodes.append(objective)
		edges.append(_edge(previous, objective))
		previous = objective

	var end_node: Resource = QuestEndScript.new()
	end_node.id = "%s::end" % str(definition.get("id", "quest"))
	nodes.append(end_node)
	edges.append(_edge(previous, end_node))

	var typed_nodes: Array[QuestNode] = []
	typed_nodes.assign(nodes)
	var typed_edges: Array[QuestEdge] = []
	typed_edges.assign(edges)
	quest.nodes = typed_nodes
	quest.edges = typed_edges
	_step_ids[str(definition.get("id", ""))] = step_ids
	return quest


func _edge(from_node: Resource, to_node: Resource) -> Resource:
	var edge: Resource = QuestEdgeScript.new()
	edge.from = from_node
	edge.to = to_node
	edge.edge_type = QuestEdgeScript.EdgeType.NORMAL
	return edge


func _get_manager() -> Node:
	# The Questify autoload (registered in project.godot).
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.has_node("Questify"):
		return tree.root.get_node("Questify")
	return null
