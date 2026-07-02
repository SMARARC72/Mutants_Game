# VoiceBook key contract (Wave 16a)

`client/catalog/voice.json` is GENERATED — never edit it by hand. Source of truth is
`docs/content/voice_library.md` + `voice_library_2.md`; regenerate with:

```
python -B tools/ingest_voice.py          # rewrite client/catalog/voice.json
python -B tools/ingest_voice.py --check  # verify the committed file is current
```

Consume via the static loader:

```gdscript
const VoiceBookScript := preload("res://presentation/narrative/voice_book.gd")
var line := VoiceBookScript.pick("battle.victory", salt)  # "" when the key is missing
```

`pick(key, salt)` is deterministic per `(key, salt)` (LOCAL string hash — never the
canonical PCG32 streams); vary `salt` (e.g. a per-run counter or turn index) to walk the
variants. ALWAYS keep an authored fallback for `""` so a missing key degrades gracefully.

## Battle keys (reserved for the battle-screen sibling — W16 batch B)

battle_screen.gd is owned by a batch-B sibling; these keys are ingested and ready so the
rewire is a pure key swap:

| Beat | Key | Variants | Notes |
|---|---|---|---|
| Battle start | `battle.start` | 6 | v1 §11.1 + v2 §9.8 |
| Victory banner/toast | `battle.victory` | 7 | v1 §11.2 + v2 §9.3 |
| Defeat banner/toast | `battle.defeat` | 7 | v1 §11.3 + v2 §9.4 |
| Stalemate ("the wild slinks away") | `battle.stalemate` | 6 | alias of `capture.refuses` (v1 §5.5); **contains the exact Wave 3 `STALEMATE_VOICE_LINE`**, so swapping the const for `pick("battle.stalemate", salt)` is copy-compatible |
| Creature downed (KO, not dead) | `battle.downed` | 6 | v1 §11.4 + v2 §9.6 |
| Boss pre-fight splash | `battle.boss.prefight` | 3 | v2 §10.10 |
| Boss victory | `battle.boss.victory` | 2 | v2 §10.11 |
| Capture success toast | `capture.success` | 5 | alias of `capture.befriend.success` (v1 §5.1) |
| Capture failure toast | `capture.fail` | 5 | alias of `capture.befriend.fail` (v1 §5.2) |
| Trap-flavored capture | `capture.trap.success` / `capture.trap.fail` | 5/5 | v1 §5.3–5.4 |
| The refuser (non-combat encounter) | `capture.refuses` | 6 | v1 §5.5 — also the peculiar "sits down and vents" beat |
| Permadeath | `toast.permadeath` / `death.permadeath` | 5/4 | short toast vs ceremonial long form |
| In-battle barks by role | `bark.role.<aggressor\|support\|controller>.<beat>` | 1–2 | beats: `turn_start`, `crit`, `low_hp`, `ally_down`, `victory`, `defeat` |
| In-battle barks by force | `bark.force.<gaia\|ouranos\|cosmos\|chaos\|eros\|thanatos>.<beat>` | 1 | same beats |
| Status applied/expire (short) | `status.<name>.applied` / `.expire` | 1 | v1 §9; names: `petrify shock seal madness bloom_rot wither` |
| Status inflicted/suffered/cured (long) | `status.<name>.<inflicted\|suffered\|cured_expired>` | 1 | v2 §6.1–6.6 |
| Status resisted/immune/cleansed | `status.event.<resisted\|immune\|cleansed\|stacked>` | 1–2 | v2 §6.8 |

Tokens like `{creature}`, `{rival}`, `{n}` are runtime fills — `String.format()` them at
the call site.

## Keys already wired by 16a (do not double-wire)

- `toast.caught|harvest|awakening|quest|rival|corruption` — ToastMicrocopy preset bodies
- `region.<region_id>.enter` — overworld HUD region blurb (OverworldContent.region_climate)
- `empty.quests` (journal), `empty.party` (party detail), `empty.parts` (lab reagent drawer)
- `quest.refused_garran` / `quest.accepted_garran` — SQ-05 choice-branch toasts

## Other reserved banks (batch B: peculiars / barks / Act-0)

- Ambient NPC barks per region: `bark.region.<threshold|mournmarch|verdant_glut|sunder|astral_tier>`
- Mortal reactions by notoriety: `bark.mortals.<low|rising|notorious|feared|worshipful>`
- Region ambient/fauna: `region.<id>.ambient`, `region.<id>.fauna`
- Fourth-wall one-shots (RATIONED registry only, never boss/death):
  `fourthwall.<signpost|over_talked|ghost|suspects|reload|creature|corrupt_idle|fortune_teller|quit>`
  and `fourthwall.v2.<vendor|cessil|corrupt_idle|maw_signpost|draftsman|over_talked|reload|quit>`
- Tutorial (Maddox/Threshold cast): `tutorial.<welcome|catch|lab|battle|stakes|currency|graveyard|factions|husbandry>`
- Faction voice: `faction.<id>.<greeting|standing_up|standing_down|refusal|creed|ascension>`
- Lab per-op: `lab.<mutate|fuse|build|mod|sacrifice>.<preview|commit|result>`, `lab.method.<precise|wild>`,
  `lab.reveal`, `lab.botch.<op>`, `lab.taboo.<opposed_force|god_organ|reanimation|self_splice|no_bridge>`
- Weather/tide: `weather.<force|tide|dusk|dawn|shift|tide_locked|rare>`

Full key list: `python -c "import json;print('\n'.join(sorted(json.load(open('client/catalog/voice.json',encoding='utf-8')))))"`
