class_name Hsm
extends RefCounted
## Hsm (ADR-016) — a tiny, SELF-CONTAINED hierarchical state machine for the Succession invasion
## boss's phase logic (Opening -> Pressure -> Desperation -> Apotheosis), mirroring LimboAI's
## HSM/LimboState (_enter/_exit/_update). Pure GDScript (RefCounted; no Node/SceneTree).
##
## APPLICATION/ai layer. Each STATE is a phase that owns a BehaviorTree (the phase's move-selection
## logic). Transitions are BLACKBOARD-GATED: a transition's guard `Callable(ctx) -> bool` reads
## phase-gate values the controller wrote onto the AiBlackboard each turn (own HP%, turn count,
## squad losses, the entropy clock). On `update(ctx)` the HSM first evaluates the current state's
## outgoing transitions (in authored order) and switches if a guard passes, then ticks the (possibly
## new) state's BehaviorTree to SELECT a move. NO outcome math here.
##
## Determinism: transitions are pure reads of blackboard gates + authored order; any randomness in
## move selection inside a state's tree draws ONLY from ctx.rng (RngService). Same (seed, teams,
## gates) -> identical phase path -> identical decisions (TDD §6 replay).


## One HSM state = a named phase with a behaviour tree and outgoing transitions.
class State:
	extends RefCounted
	var name: String
	var tree: BehaviorTree.BtNode
	var _transitions: Array = []  # Array of {to: String, guard: Callable}
	var _on_enter: Callable

	func _init(p_name: String, p_tree: BehaviorTree.BtNode) -> void:
		name = p_name
		tree = p_tree

	## Add an outgoing transition: when `guard(ctx)` is true, switch to state `to`. Authored order
	## is the evaluation order (first satisfied guard wins) — keeps phase progression deterministic.
	func add_transition(to: String, guard: Callable) -> State:
		_transitions.append({"to": to, "guard": guard})
		return self

	## Optional enter hook (e.g. log the phase change). Pure side-effect; no RNG, no math.
	func set_on_enter(cb: Callable) -> State:
		_on_enter = cb
		return self

	## First transition whose guard passes, or "" if none. Pure blackboard read.
	func next_state(ctx: AiBlackboard) -> String:
		for t in _transitions:
			if bool((t["guard"] as Callable).call(ctx)):
				return str(t["to"])
		return ""


var _states: Dictionary = {}  # name -> State
var _current: String = ""
var _initial: String = ""


## Register a state. The first registered state is the initial state unless overridden by start().
func add_state(state: State) -> Hsm:
	_states[state.name] = state
	if _initial == "":
		_initial = state.name
	return self


func set_initial(name: String) -> Hsm:
	_initial = name
	return self


## The phase the HSM is currently in (after at least one update / explicit start()).
func current_state() -> String:
	return _current


## Enter the initial phase explicitly (fires its on_enter). Safe to call once before the first update.
func start(ctx: AiBlackboard) -> void:
	_current = _initial
	_fire_enter(_current, ctx)


## One decision step:
##   1. ensure we're in a state (lazy start on first call),
##   2. follow transitions until no guard fires (supports multi-step jumps in one update — e.g. a
##      sudden squad wipe that skips a phase), capped to avoid a cyclic-guard infinite loop,
##   3. tick the resolved state's tree to SELECT a move; write it onto ctx ("result").
## Returns the chosen Action dict (ctx "result"), or {} if the active tree could not select.
func update(ctx: AiBlackboard) -> Dictionary:
	if _current == "":
		start(ctx)
	# Resolve phase transitions (blackboard-gated). Cap iterations to states.size() so a misauthored
	# always-true guard cycle can never hang the turn loop.
	var hops := 0
	while hops < _states.size():
		var st := _states[_current] as State
		var nxt := st.next_state(ctx)
		if nxt == "" or nxt == _current or not _states.has(nxt):
			break
		_current = nxt
		_fire_enter(_current, ctx)
		hops += 1
	# Tick the active phase's tree to select a move.
	ctx.erase_value("result")
	var active := _states[_current] as State
	active.tree.tick(ctx)
	var res: Variant = ctx.get_value("result", {})
	return res if res is Dictionary else {}


func _fire_enter(name: String, ctx: AiBlackboard) -> void:
	var st := _states.get(name, null) as State
	if st != null and st._on_enter.is_valid():
		st._on_enter.call(ctx)
