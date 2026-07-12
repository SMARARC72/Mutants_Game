# Current Verification Ledger

Verified 2026-07-11 on Windows with Godot 4.7 stable, Python 3.12 and Node.js. This file is the
canonical current status; `PHASE*_REPORT.md` files are historical delivery records.

## Green repository gates

| Area | Result |
|---|---|
| Godot | 101/101 suites, 612/612 cases, 0 errors, 0 failures, 0 skipped, 0 orphans |
| Shutdown | Clean headless smoke, full-suite exit and windowed capture; no ObjectDB/resource retention |
| Creature art | 406/406 seedable species; flat + cutout parity; 0 QA errors/warnings |
| Asset contract | Clean across 2,033 tracked runtime asset files |
| Catalog | 407 registry rows → 406 seedable + 1 intentional void; JSON/Resource/seed id sets equal |
| Oracle | 113 constants checks, 140 RNG checks, all nine entrypoints deterministic |
| Golden/balance | Golden vectors regenerated without drift; splice coverage and 300-seed balance slice pass |
| Services | TypeScript typecheck and 37/37 Vitest contracts pass |
| Lint | GDScript (255 project files), JavaScript and SQL migrations clean |
| Presentation | Menu, overworld, party, lab and battle captured/reviewed at 1280×720 and 1920×1080 |

Cloud-save behavior now uses a real anonymous GoTrue session, player/run bootstrap and an
RLS-authoritative `save_run_cas` RPC with atomic create/update/version-conflict semantics. Focused
DAL/auth tests are included in the 612-case total, and the pgTAP plan contains 61 assertions.

## External-runtime gates

These checks are not runnable on this workstation until their named runtime dependency exists:

- **Supabase live proof:** Supabase CLI unavailable and Docker Desktop daemon not running. Run
  `supabase start`, `supabase db reset`, `supabase test db`, then
  `node supabase/tests/smoke_anon_isolation.mjs` with local URL/anon-key environment variables.
- **Windows export:** Godot 4.7 Windows debug/release export templates are absent. Install the
  official templates, export the `Windows Desktop` preset, and smoke-launch the executable.
- **Production rollout:** requires user-owned Supabase/Vercel projects, secrets and deployment
  authority. Repository code intentionally contains no production credentials.

## Canonical commands

```powershell
npm run gen:all
npm run gen:species-db
npm run lint:js
npm run test:catalog-parity
python -B tools/test_constants_parity.py
python -B tools/test_rng_parity.py
python -B tools/gen_golden.py
python -B tools/test_splice_rules_coverage.py
python -B tools/balance_slice_check.py
python -B tools/qa_creature_art.py
python -B tools/check_asset_contract.py
sqlfluff lint supabase/migrations --dialect postgres
npm --prefix services run typecheck
npm --prefix services test
godot --headless --path client -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add res://tests --ignoreHeadlessMode --continue
```
