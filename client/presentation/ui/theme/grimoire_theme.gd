class_name GrimoireTheme
extends RefCounted
## ThemeGen facade (D6) — authors the ONE grimoire `Theme` in code from `GrimoirePalette`.
##
## PRESENTATION layer. "ThemeGen" in this project means *theme-as-code*: the spec (D6) calls
## for the grimoire `Theme` authored in code from the 6-force palette + parchment/ink, so a
## single semantic-colour source drives every Control node. Building it here (vs hand-editing a
## .tres) means swapping a colour in `GrimoirePalette` re-themes the whole app — the D6
## acceptance test. This is the only place StyleBoxes/fonts are assembled.
##
## Colorblind-safe (design §5): colour is one channel; the consuming screens always pair it
## with the force/status icons under `client/assets/icons/**`. The Theme never relies on hue
## alone to convey state (focus = a brighter brass BORDER, not just a tint).

const P := preload("res://presentation/ui/theme/grimoire_palette.gd")

const CORNER := 5
const BORDER := 2
const PAD_X := 14
const PAD_Y := 8
const FONT_BODY := 18
const FONT_TITLE := 30
const FONT_SMALL := 14


## Build and return the grimoire Theme. Call once; cache via `ThemeService`.
static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_BODY

	_apply_panel(theme)
	_apply_button(theme)
	_apply_label(theme)
	_apply_line_edit(theme)
	_apply_progress(theme)
	_apply_check(theme)
	_apply_tab_and_scroll(theme)
	return theme


static func _box(bg: Color, border_col: Color, border_w: int = BORDER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(CORNER)
	sb.set_border_width_all(border_w)
	sb.border_color = border_col
	sb.content_margin_left = PAD_X
	sb.content_margin_right = PAD_X
	sb.content_margin_top = PAD_Y
	sb.content_margin_bottom = PAD_Y
	return sb


static func _apply_panel(theme: Theme) -> void:
	# Panels = raised ink with brass sigil-linework borders (design §2).
	var panel := _box(P.INK_PANEL, P.BRASS)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", _box(P.INK_PANEL, P.BRASS))
	# A parchment variant for "open grimoire page" surfaces.
	theme.set_stylebox("panel", "PopupPanel", _box(P.PARCHMENT, P.BRASS))


static func _apply_button(theme: Theme) -> void:
	# Buttons read state by BORDER brightness + fill, not hue alone (colorblind-safe).
	theme.set_stylebox("normal", "Button", _box(P.INK_PANEL, P.BRASS))
	theme.set_stylebox("hover", "Button", _box(P.INK_HOVER, P.BRASS_BRIGHT))
	theme.set_stylebox("pressed", "Button", _box(P.INK, P.BRASS_BRIGHT, BORDER + 1))
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), P.BRASS_BRIGHT, BORDER + 1))
	var disabled := _box(P.INK, P.TEXT_MUTED)
	disabled.bg_color.a = 0.6
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_color("font_color", "Button", P.TEXT_ON_INK)
	theme.set_color("font_hover_color", "Button", P.BRASS_BRIGHT)
	theme.set_color("font_pressed_color", "Button", P.COSMOS)
	theme.set_color("font_disabled_color", "Button", P.TEXT_MUTED)
	theme.set_font_size("font_size", "Button", FONT_BODY)


static func _apply_label(theme: Theme) -> void:
	theme.set_color("font_color", "Label", P.TEXT_ON_INK)
	theme.set_font_size("font_size", "Label", FONT_BODY)
	# Title variation (use via `theme_type_variation = "TitleLabel"`).
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_color("font_color", "TitleLabel", P.BRASS_BRIGHT)
	theme.set_font_size("font_size", "TitleLabel", FONT_TITLE)
	# Muted/secondary variation.
	theme.set_type_variation("MutedLabel", "Label")
	theme.set_color("font_color", "MutedLabel", P.TEXT_MUTED)
	theme.set_font_size("font_size", "MutedLabel", FONT_SMALL)


static func _apply_line_edit(theme: Theme) -> void:
	theme.set_stylebox("normal", "LineEdit", _box(P.INK, P.BRASS))
	theme.set_stylebox("focus", "LineEdit", _box(P.INK, P.BRASS_BRIGHT, BORDER + 1))
	theme.set_color("font_color", "LineEdit", P.TEXT_ON_INK)
	theme.set_color("font_placeholder_color", "LineEdit", P.TEXT_MUTED)
	theme.set_color("caret_color", "LineEdit", P.BRASS_BRIGHT)


static func _apply_progress(theme: Theme) -> void:
	# Used for HP / corruption / entropy readouts. Background ink, fill set per-bar in code
	# (e.g. force colour or `GrimoirePalette.corruption_color`).
	theme.set_stylebox("background", "ProgressBar", _box(P.INK, P.BRASS, 1))
	var fill := _box(P.EROS, P.BRASS_BRIGHT, 1)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_color("font_color", "ProgressBar", P.TEXT_ON_INK)


static func _apply_check(theme: Theme) -> void:
	theme.set_color("font_color", "CheckButton", P.TEXT_ON_INK)
	theme.set_color("font_color", "CheckBox", P.TEXT_ON_INK)
	theme.set_color("font_hover_color", "CheckButton", P.BRASS_BRIGHT)
	theme.set_color("font_hover_color", "CheckBox", P.BRASS_BRIGHT)


static func _apply_tab_and_scroll(theme: Theme) -> void:
	theme.set_stylebox("panel", "TabContainer", _box(P.INK_PANEL, P.BRASS))
	theme.set_color("font_selected_color", "TabContainer", P.BRASS_BRIGHT)
	theme.set_color("font_unselected_color", "TabContainer", P.TEXT_MUTED)
