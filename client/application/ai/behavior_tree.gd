class_name BehaviorTree
extends RefCounted
## BehaviorTree (ADR-016) — a tiny, SELF-CONTAINED, synchronous behaviour-tree kernel for battle
## action SELECTION. Pure GDScript (RefCounted; no Node/SceneTree/frame-tick), so one `tick(ctx)`
## resolves the whole tree in a single synchronous call inside the deterministic turn loop and runs
## headless with zero scene setup.
##
## WHY NOT Beehave (vendored) HERE: Beehave's BeehaveTree is a frame-ticked SceneTree Node
## (set_physics_process / actor_node_path / tick_rate) and ships NO HSM. A per-turn, synchronous,
## replay-deterministic `choose_action()` wants a value-type tree it can run to completion in one
## call. Same SELECTION semantics (Selector/Sequence/Condition/Action, SUCCESS/FAILURE), same
## Blackboard->RngService rule (ADR-016) — see application/ai/THIRD_PARTY note + the report.
##
## CONTRACT: a node's tick returns SUCCESS or FAILURE (no RUNNING — turns are atomic). An Action that
## SUCCEEDS writes its chosen Action dict into ctx.result and returns SUCCESS. `ctx` is the
## AiBlackboard; all randomness goes through ctx.rng (RngService). NO outcome math here — the tree
## only chooses; client/domain resolves.

enum Status { SUCCESS, FAILURE }


## Base node. Subclasses override `tick`.
class BtNode:
	extends RefCounted

	func tick(_ctx: AiBlackboard) -> int:
		return Status.FAILURE


## Selector (OR / fallback): ticks children in order; returns SUCCESS on the FIRST child that
## succeeds, FAILURE if all fail. Deterministic order = authored child order.
class Selector:
	extends BtNode
	var children: Array = []

	func _init(p_children: Array = []) -> void:
		children = p_children

	func add(child: BtNode) -> Selector:
		children.append(child)
		return self

	func tick(ctx: AiBlackboard) -> int:
		for c in children:
			if (c as BtNode).tick(ctx) == Status.SUCCESS:
				return Status.SUCCESS
		return Status.FAILURE


## Sequence (AND): ticks children in order; FAILURE on the first child that fails, SUCCESS if all
## succeed. Used to gate an Action behind a Condition (Condition then Action).
class Sequence:
	extends BtNode
	var children: Array = []

	func _init(p_children: Array = []) -> void:
		children = p_children

	func add(child: BtNode) -> Sequence:
		children.append(child)
		return self

	func tick(ctx: AiBlackboard) -> int:
		for c in children:
			if (c as BtNode).tick(ctx) == Status.FAILURE:
				return Status.FAILURE
		return Status.SUCCESS


## Condition leaf: wraps a predicate `Callable(ctx: AiBlackboard) -> bool`. SUCCESS when true.
## Pure guard — it reads the blackboard, never mutates ctx.result and never draws RNG to decide an
## outcome (a Condition may consult ctx.rng only to gate selection, e.g. a Rouse chance).
class Condition:
	extends BtNode
	var _predicate: Callable

	func _init(predicate: Callable) -> void:
		_predicate = predicate

	func tick(ctx: AiBlackboard) -> int:
		return Status.SUCCESS if bool(_predicate.call(ctx)) else Status.FAILURE


## Action leaf: wraps `Callable(ctx: AiBlackboard) -> Variant`. The callable returns a chosen Action
## dict (truthy) or null/empty to signal "I cannot act" (FAILURE, so the Selector falls through).
## On a truthy return it writes ctx.result and returns SUCCESS. This is the ONLY place a decision is
## committed; the controller reads ctx.result and hands it to the oracle.
class Action:
	extends BtNode
	var _chooser: Callable

	func _init(chooser: Callable) -> void:
		_chooser = chooser

	func tick(ctx: AiBlackboard) -> int:
		var chosen: Variant = _chooser.call(ctx)
		if chosen == null:
			return Status.FAILURE
		if chosen is Dictionary and (chosen as Dictionary).is_empty():
			return Status.FAILURE
		ctx.set_value("result", chosen)
		return Status.SUCCESS


## Inverter decorator: flips SUCCESS<->FAILURE of its single child (handy for "if NOT condition").
class Inverter:
	extends BtNode
	var child: BtNode

	func _init(p_child: BtNode) -> void:
		child = p_child

	func tick(ctx: AiBlackboard) -> int:
		return Status.FAILURE if child.tick(ctx) == Status.SUCCESS else Status.SUCCESS
