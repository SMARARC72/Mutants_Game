class_name SupabaseAuthPath
extends RefCounted
## Anonymous-first auth path (ADR-011, TDD §8.1). INFRASTRUCTURE layer only.
##
## Phase 0 scaffold/interface. The functional proof of this flow lives in
## supabase/tests/smoke_anon_isolation.mjs (run against the live stack). The real
## implementation wires the vendored Supabase Godot addon (Phase 0.5) + repositories
## (Phase 3). This file deliberately has NO addon dependency yet so the project compiles
## headless before the addon is installed.
##
## SECRET POLICY (TDD §9.2): the client ships ONLY the Supabase URL + anon key. The
## service-role key and the OpenAI key NEVER appear here or anywhere in client/.


## The bootstrap flow, documented as the contract Phase 3 implements:
##   1. signInAnonymously()  -> a real auth.users row; players.id == auth.uid() from launch
##   2. insert players { id = uid }                      (RLS: with check id = auth.uid())
##   3. insert runs { player_id = uid, seed = secure }   (RLS: with check player_id = auth.uid())
##   4. later: link an email (manual identity linking) — the uid is PRESERVED (ADR-011).
## Returns the new run id, or "" on failure. Stubbed until the addon lands.
func bootstrap_anonymous_run(_secure_seed: int) -> String:
	push_error("SupabaseAuthPath.bootstrap_anonymous_run is a Phase-0 stub; wired in Phase 3.")
	return ""


## True once the addon + session exist. Stub returns false in Phase 0.
func is_signed_in() -> bool:
	return false
