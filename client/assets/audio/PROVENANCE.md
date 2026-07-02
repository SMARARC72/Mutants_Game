# Audio assets — PROVENANCE

## Curated real recordings (wave/w-oss-assets, 2026-07-02)

The placeholder set synthesized by `tools/gen_audio.py` has been replaced (except
`sfx/veil_whisper.wav`, still generated — see below) with curated CC0 / public-domain
recordings from the shared local library `../_asset-library/` (kenney / freepd /
opengameart subfolders, each with `LICENSE_NOTES.md` recording URL + license + date +
author). One-shots were converted to 44.1 kHz 16-bit mono WAV (peaks normalized to
-4.4 dBFS) via libsndfile; music beds ship as MP3 (loaded natively by Godot, loop forced
by `MusicService._load_bed`).

### Music / ambience beds (`ambience/`) — filenames keep the service keys

| File | Source | Author | License |
|---|---|---|---|
| `menu_bed_loop.mp3` | "Ancient Rite" — FreePD.com (site closed 2025; retrieved via Wayback Machine, see `_asset-library/freepd/LICENSE_NOTES.md`) | Kevin MacLeod | CC0 / PD |
| `battle_drone_loop.mp3` | "Battle Theme A" — https://opengameart.org/content/battle-theme-a | cynicmusic (pixelsphere.org) | CC0 |
| `ambience_marsh_loop.mp3` | "Swamp Environment Audio" — https://opengameart.org/content/swamp-environment-audio (gain-normalized to -5 dBFS peak, re-encoded from the CC0 ogg) | LokiF | CC0 |

### One-shots (`ui/`, `sfx/`) — Kenney packs (all CC0, https://kenney.nl)

| File | Kenney source |
|---|---|
| `ui/ui_click.wav` | Interface Sounds — `click_001.ogg` |
| `ui/ui_confirm.wav` | Interface Sounds — `confirmation_002.ogg` |
| `sfx/footstep_1..4.wav` | Impact Sounds — `footstep_grass_000..003.ogg` |
| `sfx/hit_crunch.wav` | Impact Sounds — `impactSoft_heavy_000.ogg` |
| `sfx/death_knell.wav` | Impact Sounds — `impactBell_heavy_001.ogg` (real bell strike) |
| `sfx/capture_sting.wav` | Music Jingles — `jingles_PIZZI07.ogg` (pizzicato sting) |
| `sfx/boss_swell.wav` | Music Jingles — `jingles_HIT15.ogg` (orchestral hit) |

### Still generated in-repo (CC0)

| File | Description |
|---|---|
| `sfx/veil_whisper.wav` | breathy band-passed noise swell — `tools/gen_audio.py` (no suitable CC0 whisper found; deterministic seed `0x4D5554`) |

All shipped licenses are CC0 / public domain — no attribution required (courtesy credits
optional). Every file was magic-byte- and decode-verified (libsndfile) before landing.
The one CC-BY item fetched during foraging (Iwan Gabovitch — Dark Ambience Loop) stays
in the library only and is NOT shipped, so `CREDITS.md` needs no new rows.
