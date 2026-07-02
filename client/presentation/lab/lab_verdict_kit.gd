extends RefCounted
## LabVerdictKit (Wave 15 extraction) — pure bbcode TEXT for the lab's parchment verdict page,
## lifted from lab_screen.gd for the 1000-line module cap. Every number rendered here arrived
## FROM the oracle (ADR-015): config_summary reads the CSP's resolved intent, ledger_text shows
## the oracle's reported creature values — the count-up fraction only interpolates the DISPLAY
## toward those values, it never computes one.


## BBCode hex for an accent deepened for the parchment verdict page (Wave 8 contrast pass — the
## bright on-ink colours washed out on ParchmentPanel; GrimoirePalette owns the adjustment).
static func parchment_hex(color: Color) -> String:
	return GrimoirePalette.on_parchment(color).to_html(false)


## A non-numeric-source summary of the candidate config's forces/tier (the oracle reports the
## final numbers on commit; the config carries the force_intent + tier_target the CSP resolved).
static func config_summary(cfg: Dictionary) -> String:
	if cfg.is_empty():
		return ""
	var fi: Array = cfg.get("force_intent", [])
	var force := ""
	if fi.size() >= 1:
		force = str(fi[0])
		if fi.size() >= 2 and str(fi[1]) != "":
			force += "/" + str(fi[1])
	var tier := str(cfg.get("tier_target", ""))
	var cls := str(cfg.get("class_target", ""))
	var label_hex := parchment_hex(GrimoirePalette.THANATOS)
	return (
		"[color=#%s]forces[/color] %s   [color=#%s]tier[/color] %s   [color=#%s]class[/color] %s"
		% [label_hex, force, label_hex, tier, label_hex, cls]
	)


## The TABOO verdict's unlock cost line (corruption threshold / rite / part — solver data).
static func cost_summary(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var parts: Array = []
	if cost.has("corruption_min"):
		parts.append("corruption ≥ %d" % int(cost["corruption_min"]))
	if cost.has("unlock"):
		parts.append("the %s rite" % str(cost["unlock"]))
	if cost.has("part"):
		parts.append("a %s" % str(cost["part"]))
	return (
		"[color=#%s]unlock cost:[/color] " % parchment_hex(GrimoirePalette.WARNING)
		+ ", ".join(PackedStringArray(parts.map(func(s: Variant) -> String: return str(s))))
	)


## The committed newborn's headline: name — forces tier (all oracle-reported).
static func commit_head(creature: Dictionary) -> String:
	var force := str(creature.get("prim", ""))
	if str(creature.get("sec", "")) != "":
		force += "/" + str(creature.get("sec", ""))
	return (
		"[color=#%s]Spliced:[/color] %s  —  %s %s"
		% [
			parchment_hex(GrimoirePalette.SUCCESS),
			str(creature.get("name", "")),
			force,
			str(creature.get("tier", "")),
		]
	)


## The cost ledger at count-up fraction `f` (1.0 = the oracle's exact numbers). The fraction only
## interpolates the DISPLAY toward the oracle's reported values — nothing is computed here.
static func ledger_text(creature: Dictionary, f: float) -> String:
	var label_hex := parchment_hex(GrimoirePalette.THANATOS)
	var t := clampf(f, 0.0, 1.0)
	var ledger := (
		"[color=#%s]HP[/color] %d   [color=#%s]BST[/color] %d   "
		+ "[color=#%s]entropy[/color] %d   [color=#%s]corruption[/color] %d"
	)
	return (
		ledger
		% [
			label_hex,
			int(round(int(creature.get("hp", 0)) * t)),
			label_hex,
			int(round(int(creature.get("bst", 0)) * t)),
			label_hex,
			int(round(int(creature.get("entropy", 0)) * t)),
			label_hex,
			int(round(int(creature.get("corruption", 0)) * t)),
		]
	)


## The commit outcome Toast (success = the newborn's name; failure = the solver's reason).
static func toast_outcome(host: Node, result: Dictionary, success: bool) -> void:
	var toast := host.get_node_or_null("/root/Toast")
	if toast == null or not toast.has_method("show"):
		return
	if success:
		var creature: Dictionary = result.get("creature", {})
		(
			toast
			. call(
				"show",
				{
					"title": "A new horror draws breath",
					"body": str(creature.get("name", "")),
					"sound": "wet",
				}
			)
		)
	else:
		(
			toast
			. call(
				"show",
				{
					"title": "The rite recoils",
					"body": str(result.get("reason", "the flesh refuses")),
					"sound": "toll",
				}
			)
		)
