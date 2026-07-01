class_name GrimoirePalette
extends RefCounted
## The single source of semantic colors for the whole UI (D6 / TDD §B5 / design §2).
##
## PRESENTATION layer. The six-force palette + parchment/ink base + the corruption rot
## accent, named SEMANTICALLY so a screen never hard-codes a hex. `GrimoireTheme` (ThemeGen
## output) consumes these; swapping a value here updates every Control node that reads the
## generated `Theme`. Colour is ALWAYS paired with an icon/shape elsewhere (colorblind-safe,
## design §2 / §5) — these names carry meaning, not just hue.

# --- The six primordial forces (design §2 — colour + motif) -------------------
const GAIA := Color("4f5d3a")  # deep moss + granite brown — stone, bark, heavy
const OURANOS := Color("6fb8d6")  # silver-blue + cyan — feathers, wind, lightning
const COSMOS := Color("e8d8a0")  # white-gold + pale azure — halos, crystalline
const CHAOS := Color("d6248c")  # hot magenta + oil-slick — jagged, glitching
const EROS := Color("e0658c")  # rose + honey-gold + verdant — blossoms, vines
const THANATOS := Color("8a5fb0")  # violet + sickly-teal soul-fire on charcoal

# --- The corruption meta-meter (design §2 — a creeping bruise-purple/green rot) ----
const CORRUPTION_LOW := Color("5a6b3a")  # sickly green at the floor
const CORRUPTION_HIGH := Color("6b2d6b")  # bruise-purple as it fills

# --- Base UI surfaces (design §2 — aged parchment + occult ink/charcoal) ----------
const PARCHMENT := Color("e8ddc4")  # light surface — aged paper
const PARCHMENT_DIM := Color("d4c7a8")  # pressed/secondary parchment
const INK := Color("17131c")  # deep occult ink/charcoal — dark surface
const INK_PANEL := Color("221c2a")  # raised dark panel
const INK_HOVER := Color("2e2638")  # hovered dark element
const BRASS := Color("b9933f")  # brass/gold sigil linework — borders, accents
const BRASS_BRIGHT := Color("e0b95a")  # lit brass — focus/active

# --- Text (on each surface) -------------------------------------------------------
const TEXT_ON_INK := Color("e3d9c6")  # parchment-tone text on dark
const TEXT_ON_PARCHMENT := Color("241c14")  # ink-tone text on light
const TEXT_MUTED := Color("9b8f7a")  # secondary/disabled
const TEXT_DANGER := Color("d6584e")  # permadeath / botched-splice loss

# --- Semantic status (death/win/risk readouts) ------------------------------------
const SUCCESS := Color("7fae5a")
const WARNING := Color("d6a23f")
const DANGER := Color("c2402f")

# --- Verdant accents (Bloomwarden greens — overworld NPC rings & husbandry beats) --
const VERDANT := Color("8ec07c")  # living growth — the husbandry creed at work
const VERDANT_DIM := Color("6b8f3d")  # deep shaded canopy — the gentle apex
const VERDANT_ASH := Color("9ab0a0")  # hospice grey-green — mercy gone quiet


## Force name -> colour, for data-driven creature/force UI. Lowercase keys match the
## catalog/icon folders (`client/assets/icons/forces/*`).
static func force_color(force_name: String) -> Color:
	match force_name.to_lower():
		"gaia":
			return GAIA
		"ouranos":
			return OURANOS
		"cosmos":
			return COSMOS
		"chaos":
			return CHAOS
		"eros":
			return EROS
		"thanatos":
			return THANATOS
		_:
			return BRASS


## Corruption meter colour at fill `t` in [0, 1] — green floor crept up to bruise-purple
## (design §2). One place owns the "rot intensifies as it fills" rule.
static func corruption_color(t: float) -> Color:
	return CORRUPTION_LOW.lerp(CORRUPTION_HIGH, clampf(t, 0.0, 1.0))
