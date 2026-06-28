extends Control
## Sample grimoire screen (DoD) — proves the whole UX shell wires together.
##
## PRESENTATION layer. Renders a menu + panel + buttons in the ONE grimoire Theme (D6), fires a
## themed toast with sound (D7), runs the ritual transition (D8), and switches the G.U.I.D.E
## input context (D4) — the live demo behind the DoD acceptance lines. It only ever talks to the
## facades (ThemeService / Toast / Transition / InputService), never to an addon directly.

const Microcopy := preload("res://presentation/ui/toast/toast_microcopy.gd")
const Palette := preload("res://presentation/ui/theme/grimoire_palette.gd")
const InputActions := preload("res://infrastructure/input/input_actions.gd")

@onready var _toast_button: Button = %ToastButton
@onready var _transition_button: Button = %TransitionButton
@onready var _corruption_bar: ProgressBar = %CorruptionBar


func _ready() -> void:
	# D6: one Theme drives every Control under this screen.
	var theme_service := get_node_or_null("/root/ThemeService")
	if theme_service != null:
		theme_service.call("apply_to", self)

	# D4: this is a menu screen -> the Menu input context.
	var input_service := get_node_or_null("/root/InputService")
	if input_service != null:
		input_service.call("switch_context", InputActions.CTX_MENU)

	_corruption_bar.add_theme_stylebox_override("fill", _corruption_fill(0.65))
	_corruption_bar.value = 65.0

	if _toast_button != null:
		_toast_button.pressed.connect(_on_toast_pressed)
	if _transition_button != null:
		_transition_button.pressed.connect(_on_transition_pressed)


func _on_toast_pressed() -> void:
	# D7: a themed toast with funny-grim copy + sound.
	var toast := get_node_or_null("/root/Toast")
	if toast != null:
		toast.call("event", Microcopy.CAUGHT)


func _on_transition_pressed() -> void:
	# D8: run the ritual transition (here wrapping a trivial awaited beat; in-game it wraps the
	# overworld<->battle swap + threaded load).
	var transition := get_node_or_null("/root/Transition")
	if transition != null:
		await transition.call("ritual", Callable())
		var toast := get_node_or_null("/root/Toast")
		if toast != null:
			toast.call("event", Microcopy.AWAKEN)


func _corruption_fill(t: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.corruption_color(t)
	sb.set_corner_radius_all(4)
	return sb
