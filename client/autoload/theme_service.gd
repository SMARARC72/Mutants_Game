extends Node
## ThemeService autoload (D6) — owns the ONE grimoire Theme and hands it to every screen.
##
## PRESENTATION/autoload layer. Builds the Theme once via `GrimoireTheme` (theme-as-code) and
## exposes it as the single source consumed by all Control nodes (D6 acceptance: one Theme,
## one semantic-colour source). A screen calls `ThemeService.apply_to(root)` in `_ready`, or
## reads `ThemeService.theme`. Rebuilding here (e.g. after a palette edit during a hot-reload)
## re-themes the whole app.

const GrimoireThemeBuilder := preload("res://presentation/ui/theme/grimoire_theme.gd")

var theme: Theme


func _ready() -> void:
	theme = GrimoireThemeBuilder.build()


## Apply the grimoire theme to a Control subtree. Idempotent; safe to call per-screen.
func apply_to(control: Control) -> void:
	if theme == null:
		theme = GrimoireThemeBuilder.build()
	control.theme = theme


## Rebuild from the current palette (D6: swapping a semantic colour updates everywhere).
func rebuild() -> void:
	theme = GrimoireThemeBuilder.build()
