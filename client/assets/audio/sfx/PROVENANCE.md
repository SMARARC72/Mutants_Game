# SFX — provenance

**Current contents (2026-07-02, wave/w-oss-assets):** curated **Kenney CC0** recordings
(Impact Sounds / Music Jingles packs, https://kenney.nl), converted to 44.1 kHz 16-bit
mono WAV — full per-file table in `client/assets/audio/PROVENANCE.md`. Raw packs +
`LICENSE_NOTES.md` live in the local library `../_asset-library/kenney/`.

Exception: `veil_whisper.wav` is still generated in-repo by `tools/gen_audio.py`
(CC0, deterministic seed) — no suitable CC0 whisper recording found yet.

## Candidate replacement sources (future curation)

- **Sonniss GameAudioGDC** bundle — royalty-free, no attribution. ⚠ The bundle is **tens of GB and
  gated behind a download form**, so it is NOT fetched automatically; it lives in `../_asset-library/sonniss/`
  (local only, never committed). A curated **≤10** clips (hit/crit/catch/splice/UI) may land here via LFS.
  Source: https://sonniss.com/gameaudiogdc
