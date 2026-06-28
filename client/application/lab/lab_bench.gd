class_name LabBench
extends RefCounted
## LabBench — the application-layer entry point to the Lab (ADR-015, SpliceRules.md §0 flow).
## APPLICATION layer: orchestrates the Legality Engine (rules/CSP, infrastructure) and the oracle
## (numbers, client/domain/lab_engine.gd). It owns NEITHER side's logic — it routes:
##
##   preview(a, b, ingredients, method, player_state)
##     -> LegalitySolver.preview  -> LEGAL / ILLEGAL(reason) / TABOO(unlock_cost) + candidate configs
##
##   commit(a, b, ingredients, method, player_state, run_seed, op_id)
##     -> preview; if not LEGAL, return the verdict unchanged (NO creature)
##     -> pick ONE config with canonical_rng(run_seed, op_id) when several are legal
##     -> LabEngine.fuse(a, b, method, rng) computes EVERY number from the ORIGINAL inputs
##     -> return { creature, splice_config } (the DAL persists splice_config in lineage)
##
## The boundary (the whole point): the CSP decided permission + ingredient/trait/flag/config; the
## oracle computes the force blend, stat_block, and entropy/corruption ledger. NO number is computed
## here or in the solver. The committed result EQUALS LabEngine.fuse on the same inputs+seed (the
## contamination guard, ADR-015 / Cluster4 DoD item 4).

# Salts keep the two sub-streams disjoint: the config-choice stream never perturbs the oracle's roll.
const PICK_SALT := 0x504943  # "PIC"
const NUMERIC_SALT := 0x4E554D  # "NUM"

var _solver: LegalitySolver


func _init(rules: SpliceRules) -> void:
	_solver = LegalitySolver.new(rules)


## preview a Lab op. op defaults to "fuse" (the two-creature signature in SpliceRules §0).
## Returns the LegalitySolver verdict Dictionary verbatim (verdict/reason/unlock_cost/configs).
func preview(
	a: Array,
	b: Variant,
	ingredients: Array,
	method: Variant,
	player_state: Dictionary,
	op: String = "fuse"
) -> Dictionary:
	return _solver.preview(op, a, b, ingredients, method, player_state)


## commit a Lab op. On a non-LEGAL verdict it returns { verdict, reason, unlock_cost } and NO
## creature (backtracking never yields a half-formed result). On LEGAL it returns:
##   { "verdict": LEGAL, "creature": <LabEngine.fuse result>, "splice_config": <chosen config>,
##     "rng_seed_tag": <op_id> }
func commit(
	a: Array,
	b: Variant,
	ingredients: Array,
	method: Variant,
	player_state: Dictionary,
	run_seed: int,
	op_id: String,
	op: String = "fuse"
) -> Dictionary:
	var verdict := preview(a, b, ingredients, method, player_state, op)
	if int(verdict["verdict"]) != LegalitySolver.Verdict.LEGAL:
		# ILLEGAL or TABOO: surface the verdict, produce NOTHING. (ADR-015: no garbage creatures.)
		return verdict

	# Choice among legal variants is canonical + reproducible (SpliceRules §3/§6): a dedicated PICK
	# sub-stream from (run_seed, op_id) selects a config index. Persisting the chosen config makes the
	# op replayable. The PICK and NUMERIC streams are SEPARATE sub-streams so the config choice never
	# perturbs the oracle's numeric roll (and the numeric stream is reproducible from public helpers).
	var configs: Array = verdict["configs"]
	var pick := LabBench.pick_rng(run_seed, op_id).randint(0, configs.size() - 1)
	var config: Dictionary = configs[pick]
	config["rng_seed_tag"] = op_id

	# Map config -> lab_engine inputs and COMPUTE via the oracle. We pass the ORIGINAL a/b creatures:
	# the config GATED + RESOLVED legality/slots/flags; lab_engine recomputes the force blend, stats,
	# and the cost ledger from the real inputs (no duplication of the blend or any number here).
	var creature := _compute(op, a, b, config, method, LabBench.numeric_rng(run_seed, op_id))

	# Annotate (non-numeric) provenance from the config so the DAL persists creature+config in lineage.
	config["creature_name"] = str(creature.get("name", ""))

	return {
		"verdict": LegalitySolver.Verdict.LEGAL,
		"creature": creature,
		"splice_config": config,
		"rng_seed_tag": op_id,
	}


# --- oracle dispatch -------------------------------------------------------------------------


func _compute(
	op: String, a: Array, b: Variant, config: Dictionary, method: Variant, rng: CanonicalRNG
) -> Dictionary:
	# Numbers come from client/domain/lab_engine.gd ONLY. The fuse op is the implemented oracle path;
	# single-creature ops (graft/mutate/self_splice/reanimate) reuse fuse's blend by pairing the host
	# with the carried force_intent secondary as a synthetic partner (lab_engine still owns the math).
	if op == "fuse" and b is Array and (b as Array).size() >= 4:
		return LabEngine.fuse(a, b, method, rng)
	# Single-creature ops: lab_engine has no dedicated entry (v0.1 ships fuse), so derive the result
	# by fusing the host against a HOST-MIRRORING partner (the oracle does the blend).
	var partner := _partner_from_config(a, config)
	return LabEngine.fuse(a, partner, method, rng)


func _partner_from_config(a: Array, _config: Dictionary) -> Array:
	# Build a partner that MIRRORS the host's own poles + tier, INDEPENDENT of the chosen config. This
	# is the determinism/purity fix: blend([[pA,sA],[pA,sA]]) -> prim=pA, sec=sA, tier=max(tA,tA)=tA for
	# EVERY config, so the committed creature's forces/tier/stats can NEVER be flipped by the config-pick
	# RNG (lab_engine stays authoritative for which forces result — SpliceRules §0/§3). The config still
	# gates legality + records slots/genes/flags; it just may not perturb a NUMBER. NO math is done here.
	var prim: String = str(a[1])
	var sec: String = str(a[2]) if a.size() > 2 and a[2] != null else ""
	var tier: String = str(a[3])
	return ["graft_part", prim, sec, tier]


# --- canonical RNG derivation (public + static so tests reproduce it EXACTLY) ----------------


## The canonical sub-stream that selects among multiple legal configs. Reproducible from (seed, op_id).
static func pick_rng(run_seed: int, op_id: String) -> CanonicalRNG:
	return CanonicalRNG.new(run_seed).substream(op_purpose(op_id) ^ PICK_SALT)


## The canonical sub-stream handed to LabEngine.fuse for the numeric roll. Reproducible from
## (seed, op_id) so the contamination-guard/parity test can rebuild the EXACT rng the bench used.
static func numeric_rng(run_seed: int, op_id: String) -> CanonicalRNG:
	return CanonicalRNG.new(run_seed).substream(op_purpose(op_id) ^ NUMERIC_SALT)


## Deterministic int "purpose" for CanonicalRNG.substream from a string op id (FNV-1a 64-bit, masked
## into int64 — GDScript int wraps two's-complement on overflow). Pure + reproducible.
static func op_purpose(op_id: String) -> int:
	var h: int = -3750763034362895579  # 0xCBF29CE484222325 as int64 (FNV offset basis)
	for i in op_id.length():
		h = h ^ op_id.unicode_at(i)
		h = h * 1099511628211  # FNV prime
	return h
