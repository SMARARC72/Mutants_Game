class_name InputActions
extends RefCounted
## The action vocabulary + context map the app talks in (D4). NO addon types here.
##
## INFRASTRUCTURE/input layer. The app/presentation layers reference these STRING action ids
## (`InputService.is_pressed(InputActions.CONFIRM)`), never raw keys (D4 acceptance). `InputService`
## translates them into G.U.I.D.E actions/contexts. Keeping the vocabulary addon-free means
## swapping G.U.I.D.E for another input lib = reimplement one facade, not touch the app.

# --- Context ids (D4: Menu / Overworld / Battle / Lab) -------------------------------
const CTX_MENU := "Menu"
const CTX_OVERWORLD := "Overworld"
const CTX_BATTLE := "Battle"
const CTX_LAB := "Lab"

# --- Shared / menu actions ----------------------------------------------------------
const CONFIRM := "confirm"
const CANCEL := "cancel"
const PAUSE := "pause"
const NAV_UP := "nav_up"
const NAV_DOWN := "nav_down"
const NAV_LEFT := "nav_left"
const NAV_RIGHT := "nav_right"

# --- Overworld --------------------------------------------------------------------
const MOVE_UP := "move_up"
const MOVE_DOWN := "move_down"
const MOVE_LEFT := "move_left"
const MOVE_RIGHT := "move_right"
const INTERACT := "interact"
const SIGIL_DASH := "sigil_dash"  # the ley-line dash (design §3.5)
const OPEN_MENU := "open_menu"

# --- Battle -----------------------------------------------------------------------
const ATTACK := "attack"
const DEFEND := "defend"
const OVERCLOCK := "overclock"  # the overclock gamble (design §4.1)
const CYCLE_TARGET := "cycle_target"

# --- Lab --------------------------------------------------------------------------
const COMMIT_RITE := "commit_rite"  # "seal the rite / pull the lever" (design §4.2)
const METHOD_PRECISE := "method_precise"
const METHOD_WILD := "method_wild"


## context id -> ordered list of action ids that live in that context.
static func context_actions() -> Dictionary:
	return {
		CTX_MENU: [CONFIRM, CANCEL, NAV_UP, NAV_DOWN, NAV_LEFT, NAV_RIGHT, PAUSE],
		CTX_OVERWORLD:
		[MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT, INTERACT, SIGIL_DASH, OPEN_MENU, PAUSE],
		CTX_BATTLE:
		[CONFIRM, CANCEL, ATTACK, DEFEND, OVERCLOCK, CYCLE_TARGET, NAV_UP, NAV_DOWN, PAUSE],
		CTX_LAB: [CONFIRM, CANCEL, COMMIT_RITE, METHOD_PRECISE, METHOD_WILD, PAUSE],
	}


## Default keyboard binding per action (Key enum). Mouse/gamepad added in `InputService`.
static func default_keys() -> Dictionary:
	return {
		CONFIRM: KEY_ENTER,
		CANCEL: KEY_ESCAPE,
		PAUSE: KEY_ESCAPE,
		NAV_UP: KEY_UP,
		NAV_DOWN: KEY_DOWN,
		NAV_LEFT: KEY_LEFT,
		NAV_RIGHT: KEY_RIGHT,
		MOVE_UP: KEY_W,
		MOVE_DOWN: KEY_S,
		MOVE_LEFT: KEY_A,
		MOVE_RIGHT: KEY_D,
		INTERACT: KEY_E,
		SIGIL_DASH: KEY_SHIFT,
		OPEN_MENU: KEY_TAB,
		ATTACK: KEY_J,
		DEFEND: KEY_K,
		OVERCLOCK: KEY_L,
		CYCLE_TARGET: KEY_TAB,
		COMMIT_RITE: KEY_SPACE,
		METHOD_PRECISE: KEY_Q,
		METHOD_WILD: KEY_R,
	}


## Default gamepad button per action (JoyButton enum) — gamepad drives menus + a battle action
## (D4 acceptance). -1 = no default gamepad binding.
static func default_gamepad() -> Dictionary:
	return {
		CONFIRM: JOY_BUTTON_A,
		CANCEL: JOY_BUTTON_B,
		PAUSE: JOY_BUTTON_START,
		NAV_UP: JOY_BUTTON_DPAD_UP,
		NAV_DOWN: JOY_BUTTON_DPAD_DOWN,
		NAV_LEFT: JOY_BUTTON_DPAD_LEFT,
		NAV_RIGHT: JOY_BUTTON_DPAD_RIGHT,
		MOVE_UP: JOY_BUTTON_DPAD_UP,
		MOVE_DOWN: JOY_BUTTON_DPAD_DOWN,
		MOVE_LEFT: JOY_BUTTON_DPAD_LEFT,
		MOVE_RIGHT: JOY_BUTTON_DPAD_RIGHT,
		INTERACT: JOY_BUTTON_A,
		SIGIL_DASH: JOY_BUTTON_RIGHT_SHOULDER,
		OPEN_MENU: JOY_BUTTON_Y,
		ATTACK: JOY_BUTTON_X,
		DEFEND: JOY_BUTTON_B,
		OVERCLOCK: JOY_BUTTON_Y,
		CYCLE_TARGET: JOY_BUTTON_RIGHT_SHOULDER,
		COMMIT_RITE: JOY_BUTTON_A,
		METHOD_PRECISE: JOY_BUTTON_LEFT_SHOULDER,
		METHOD_WILD: JOY_BUTTON_RIGHT_SHOULDER,
	}
