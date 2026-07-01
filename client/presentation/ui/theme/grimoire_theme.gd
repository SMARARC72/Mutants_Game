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
const FONT_TITLE := 34
const FONT_SMALL := 14

# The grimoire type pairing (client/assets/fonts, SIL OFL — see PROVENANCE.md there):
# Alegreya = the readable literary book-body; Cinzel = engraved Roman-capital titles.
# Loaded with load() (not preload) so a missing import degrades to the default font
# instead of breaking the script parse.
const FONT_BODY_PATH := "res://assets/fonts/Alegreya.ttf"
const FONT_TITLE_PATH := "res://assets/fonts/Cinzel.ttf"
const PARCHMENT_FRAME_PATH := "res://assets/ui/parchment_frame.png"


## Build and return the grimoire Theme. Call once; cache via `ThemeService`.
static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_BODY
	var body_font: Resource = load(FONT_BODY_PATH)
	if body_font is Font:
		theme.default_font = body_font as Font

	_apply_panel(theme)
	_apply_button(theme)
	_apply_label(theme)
	_apply_line_edit(theme)
	_apply_progress(theme)
	_apply_check(theme)
	_apply_tab_and_scroll(theme)
	_apply_surface_variations(theme)
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
	# Title variation (use via `theme_type_variation = "TitleLabel"`) — engraved Cinzel capitals.
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_color("font_color", "TitleLabel", P.BRASS_BRIGHT)
	theme.set_font_size("font_size", "TitleLabel", FONT_TITLE)
	var title_font: Resource = load(FONT_TITLE_PATH)
	if title_font is Font:
		theme.set_font("font", "TitleLabel", title_font as Font)
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


static func _apply_surface_variations(theme: Theme) -> void:
	# "ParchmentPanel" — an open-grimoire-page surface (use via
	# `theme_type_variation = "ParchmentPanel"` on a PanelContainer): the aged-parchment
	# 9-patch frame with the brass double-rule border (client/assets/ui/parchment_frame.png).
	# CONTENT GUIDANCE: labels/rich-text INSIDE a parchment panel MUST flip to
	# `P.TEXT_ON_PARCHMENT` (ink text) — the parchment-tone default (`P.TEXT_ON_INK`) is
	# authored for dark ink surfaces and vanishes against the light paper.
	theme.set_type_variation("ParchmentPanel", "PanelContainer")
	var frame_tex: Resource = load(PARCHMENT_FRAME_PATH)
	if frame_tex is Texture2D:
		var parchment := StyleBoxTexture.new()
		parchment.texture = frame_tex as Texture2D
		parchment.set_texture_margin_all(24.0)
		parchment.set_content_margin_all(24.0)
		theme.set_stylebox("panel", "ParchmentPanel", parchment)
	else:
		# Headless/no-import fallback: a flat parchment box so the variation still resolves.
		theme.set_stylebox("panel", "ParchmentPanel", _box(P.PARCHMENT, P.BRASS))
	# "PlatePanel" — a raised ink specimen plate with lit-brass rules (portrait frames, cards).
	theme.set_type_variation("PlatePanel", "PanelContainer")
	theme.set_stylebox("panel", "PlatePanel", _box(P.INK_PANEL, P.BRASS_BRIGHT))
