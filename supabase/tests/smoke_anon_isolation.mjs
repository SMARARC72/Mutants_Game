#!/usr/bin/env node
/**
 * smoke_anon_isolation.mjs — Phase 0 D5 smoke test (ADR-011, TDD §8.1, §9.1).
 *
 * Proves the anonymous-first auth flow end-to-end against a running Supabase stack:
 *   1. anon user A signs in -> gets a real auth.users row -> creates its players + runs rows
 *   2. anon user B signs in independently -> creates its own players + runs rows
 *   3. under RLS, B CANNOT see A's run (and vice-versa) — isolation is enforced by the DB
 *
 * Uses ONLY the public anon key (never service-role). Requires env:
 *   SUPABASE_URL, SUPABASE_ANON_KEY   (locally: `npx supabase status -o env`)
 * Run: node supabase/tests/smoke_anon_isolation.mjs
 */
import { createClient } from "@supabase/supabase-js";

const URL = process.env.SUPABASE_URL;
const ANON = process.env.SUPABASE_ANON_KEY;
if (!URL || !ANON) {
  console.error("FAIL: set SUPABASE_URL and SUPABASE_ANON_KEY (npx supabase status -o env)");
  process.exit(2);
}

const fails = [];
const ok = (cond, msg) => (cond ? console.log("  ok   - " + msg) : (fails.push(msg), console.log("  FAIL - " + msg)));

function client() {
  return createClient(URL, ANON, { auth: { persistSession: false, autoRefreshToken: false } });
}

async function bootstrapPlayer(label) {
  const sb = client();
  const { data: auth, error: aerr } = await sb.auth.signInAnonymously();
  if (aerr) throw new Error(`${label} anon sign-in failed: ${aerr.message}`);
  const uid = auth.user.id;
  ok(!!uid, `${label}: anonymous sign-in yields a uid (${uid.slice(0, 8)}…)`);

  // create the player row (RLS: insert allowed only when id = auth.uid())
  const { error: perr } = await sb.from("players").insert({ id: uid, handle: `anon_${label}_${uid.slice(0, 6)}` });
  ok(!perr, `${label}: creates own players row` + (perr ? ` (${perr.message})` : ""));

  // create an initial run (RLS: player_id must = auth.uid())
  const { data: run, error: rerr } = await sb.from("runs").insert({ player_id: uid, seed: 12345 }).select().single();
  ok(!rerr && run, `${label}: creates initial run` + (rerr ? ` (${rerr.message})` : ""));

  return { sb, uid, runId: run?.id };
}

async function main() {
  const A = await bootstrapPlayer("A");
  const B = await bootstrapPlayer("B");

  ok(A.uid !== B.uid, "A and B are distinct anonymous identities");

  // A sees its own player row and run
  const { data: aPlayers } = await A.sb.from("players").select("id");
  ok(aPlayers?.length === 1 && aPlayers[0].id === A.uid, "A sees exactly its own player row");
  const { data: aRuns } = await A.sb.from("runs").select("id");
  ok(aRuns?.length === 1 && aRuns[0].id === A.runId, "A sees exactly its own run");

  // ISOLATION: B cannot see A's run (RLS default-deny)
  const { data: bSeesA } = await B.sb.from("runs").select("id").eq("id", A.runId);
  ok((bSeesA?.length ?? 0) === 0, "B CANNOT read A's run (RLS isolation)");

  // ISOLATION: B's run list excludes A
  const { data: bRuns } = await B.sb.from("runs").select("id");
  ok(bRuns?.length === 1 && bRuns[0].id === B.runId, "B sees exactly its own run");

  // B cannot tamper with A's run
  const { data: upd } = await B.sb.from("runs").update({ notoriety: 999 }).eq("id", A.runId).select();
  ok((upd?.length ?? 0) === 0, "B's update of A's run affects 0 rows (RLS)");

  // catalog is public-readable to a signed-in user (sanity)
  const { error: cerr } = await A.sb.from("species").select("id").limit(1);
  ok(!cerr, "catalog (species) is readable" + (cerr ? ` (${cerr.message})` : ""));

  console.log(`\nanon isolation smoke: ${fails.length === 0 ? "PASS" : fails.length + " FAILED"}`);
  process.exit(fails.length === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error("FAIL:", e.message);
  process.exit(1);
});
