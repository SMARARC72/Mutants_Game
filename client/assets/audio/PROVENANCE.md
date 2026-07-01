# Audio assets — PROVENANCE

## Generated in-repo (CC0 / public domain)

Every `.wav` under `client/assets/audio/{ui,sfx,ambience}/` is **synthesized in this
repository** by `tools/gen_audio.py` (numpy + stdlib `wave`, fixed seed `0x4D5554`,
44.1 kHz 16-bit mono, peaks normalized to ~-12 dBFS). Re-running the script reproduces
the files byte-for-byte. No third-party recordings, samples, or soundfonts were used.

These files are dedicated to the public domain under
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

| File | Description |
|---|---|
| `ui/ui_click.wav` | 2 ms band-passed tick (global button click) |
| `ui/ui_confirm.wav` | soft two-note brass-ish chime |
| `sfx/footstep_1..4.wav` | low-passed noise thuds, pitch variants |
| `sfx/hit_crunch.wav` | fast noise burst + low thump |
| `sfx/death_knell.wav` | FM bell ~220 Hz, 2.5 s decay + detuned second strike |
| `sfx/capture_sting.wav` | rising three-note bell motif |
| `sfx/boss_swell.wav` | low drone crescendo, 3 s |
| `sfx/veil_whisper.wav` | breathy band-passed noise swell |
| `ambience/ambience_marsh_loop.wav` | ~20 s seamless loop: brown-noise bed + sparse croaks/blips |
| `ambience/battle_drone_loop.wav` | ~16 s seamless loop: 55 Hz drone + slow amplitude LFO |
| `ambience/menu_bed_loop.wav` | ~20 s seamless loop: detuned-sine dark pad + slow filter sweep |

Chosen over CC0 downloads (Kenney et al.) for this slice so the whole set is
deterministic, dependency-free, and license-unambiguous; curated CC0 packs may replace
individual files later (see `sfx/PROVENANCE.md` for the candidate sources).
