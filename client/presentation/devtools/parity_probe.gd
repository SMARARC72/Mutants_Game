class_name ParityProbe
extends RefCounted
## ParityProbe (Cluster 4 / D6, TDD §11.2) — DEV-ONLY oracle-parity probe backing the LimboConsole
## `parity_battle` command. PRESENTATION/devtools layer; reached only via the DevConsole facade,
## gated by DEV_TOOLS (ADR-018). It only READS the domain oracle — it is NEVER a source of truth.
##
## What it does: for a given seed it locates the committed golden `simulate` vector
## (res://tests/golden/battle_engine.jsonl — the Python oracle's transcript), reconstructs the teams,
## runs the GDScript BattleEngine.simulate on the SAME seed, hashes both transcripts (FNV-1a 64-bit),
## and reports MATCH / MISMATCH + the two hashes + the first diverging line. A green probe means the
## GDScript battle core matches the Python oracle char-for-char (the manual counterpart to the
## automated battle_engine_parity_test). Static + pure so the GdUnit test reuses it directly.

const GOLDEN_PATH := "res://tests/golden/battle_engine.jsonl"


## Run the probe for `seed`. Returns Array[String] — console-ready report lines.
static func battle(seed: int) -> Array:
	var rec := _golden_simulate_record(seed)
	if rec.is_empty():
		return [
			(
				"[parity_battle] no golden 'simulate' vector for seed=%d in %s — try a seed present in the golden file (e.g. 0..N)."
				% [seed, GOLDEN_PATH]
			)
		]

	var inp: Dictionary = rec["inputs"]
	var exp: Dictionary = rec["expected"]
	var expected_log: Array = exp["log"]

	var teamA := _build_team(inp["teamA"])
	var teamB := _build_team(inp["teamB"])
	var rng := CanonicalRNG.new(int(inp["seed"]))
	var result: Array = BattleEngine.simulate(teamA, teamB, rng)

	var got_hash := transcript_hash(result)
	var golden_hash := transcript_hash(expected_log)
	var out: Array = []
	out.append(
		(
			"[parity_battle] seed=%d  lines: got=%d golden=%d"
			% [seed, result.size(), expected_log.size()]
		)
	)
	out.append("[parity_battle] gdscript hash = 0x%016x" % got_hash)
	out.append("[parity_battle] golden   hash = 0x%016x" % golden_hash)
	if got_hash == golden_hash and result.size() == expected_log.size():
		# Marker is NON-overlapping (PARITY_OK is NOT a substring of PARITY_DRIFT and vice-versa), so a
		# probe consumer can match success/failure unambiguously — unlike "MATCH"/"MISMATCH".
		out.append(
			"[parity_battle] PARITY_OK — GDScript battle_engine == Python oracle (TDD §11.2) ✔"
		)
	else:
		out.append("[parity_battle] PARITY_DRIFT — transcript differs from the golden vector!")
		out.append(_first_diff(result, expected_log))
	return out


## FNV-1a 64-bit hash of a transcript (Array[String]), newline-joined. Pure + reproducible; matches
## LabBench.op_purpose's FNV constants so the hashing convention is consistent across the codebase.
static func transcript_hash(lines: Array) -> int:
	var joined := "\n".join(PackedStringArray(lines))
	var h: int = -3750763034362895579  # 0xCBF29CE484222325 (FNV offset basis) as int64
	for i in joined.length():
		h = h ^ joined.unicode_at(i)
		h = h * 1099511628211  # FNV prime
	return h


# --- helpers ------------------------------------------------------------------------------------


static func _golden_simulate_record(seed: int) -> Dictionary:
	var f := FileAccess.open(GOLDEN_PATH, FileAccess.READ)
	if f == null:
		return {}
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var rec: Variant = JSON.parse_string(line)
		if not (rec is Dictionary):
			continue
		var d := rec as Dictionary
		if str(d.get("fn", "")) != "simulate":
			continue
		# JSON.parse_string decodes the bare seed as a FLOAT — coerce with int() (CLAUDE.md lesson b).
		var inp: Dictionary = d["inputs"]
		if int(inp.get("seed", -999999)) == seed:
			f.close()
			return d
	f.close()
	return {}


static func _build_team(rows: Array) -> Array:
	var team: Array = []
	for row in rows:
		var arr: Array = row
		var mon := BattleEngine.Mon.new(str(arr[0]), str(arr[1]), str(arr[2]), arr[3], arr[4])
		team.append(mon)
	return team


static func _first_diff(got: Array, golden: Array) -> String:
	var n: int = mini(got.size(), golden.size())
	for i in range(n):
		if str(got[i]) != str(golden[i]):
			return (
				"  line %d:\n    gdscript: %s\n    golden:   %s" % [i, str(got[i]), str(golden[i])]
			)
	if got.size() != golden.size():
		return "  line counts differ (got=%d, golden=%d)" % [got.size(), golden.size()]
	return "  (no line-level difference found)"
