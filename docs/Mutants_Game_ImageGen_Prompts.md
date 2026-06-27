# MUTANTS_GAME — Image-Gen Prompt Pack

**Purpose:** fill the seed-set gaps and keep every new creature on-model. Built for OpenAI / ChatGPT image generation. · 2026-06-25

---

## How to use (read once)

1. **Attach 3–4 of your existing creatures** as reference images in the same generation, and add: *"Match the exact illustration style, linework, palette discipline, and bestiary-plate framing of the attached references."* This is what keeps the whole seed coherent — the authored art steers the model.
2. **Prepend the STYLE ANCHOR** (below) to every creature prompt.
3. **Aspect ratio:** portrait **2:3** for single creatures; plain background.
4. **Batch & curate:** generate 3–4 variants per prompt, keep the best as canon, log it in `creature_registry.csv`.
5. **Mature-occult, kept stylized:** aim "mythic / eerie / storybook-dark," not gore — fits the tone *and* stays inside content filters.

> **Note:** the FORCE VISUAL KEY below is also the prototype of the in-game **genome → prompt** system. Lock this vocabulary now and the live OpenAI layer reuses it later.

---

## STYLE ANCHOR  *(prepend to every prompt)*

> *Painterly digital creature concept art for an occult monster-collecting RPG, in the style of a hand-illustrated bestiary plate. A single full-body creature, 3/4 view, centered on a plain warm parchment/cream background with a soft contact shadow. Richly detailed, cohesive brushwork, characterful and a little eerie, with faint glowing sigil-markings worked into the body. No text, no border, no watermark.*

---

## FORCE VISUAL KEY  *(the look of each pole)*

- **Cosmos (Order):** serene symmetry, concentric halo-rings and geometric sigils, crystalline filigree; white, pale gold, soft blue; an aura of calm precision.
- **Chaos (Disorder):** broken symmetry, fracturing shifting forms, mismatched parts, jagged runes; oil-slick iridescence and hot magenta; unstable flickering energy.
- **Eros (Life):** blossoms, curling vines, moss and ripe fruit growing from the body; warm greens, rose, honey-gold; soft and overflowing with growth.
- **Thanatos (Death):** exposed bone, ash, withered hide; cold violet-and-teal soul-fire; desaturated greys with one sickly accent; quiet decay.
- **Gaia (Earth):** plates of stone and bark, embedded crystal and moss; heavy grounded silhouette; granite browns and deep greens; immense mass.
- **Ouranos (Sky):** layered feathers, trailing wind-ribbons, sparks of lightning and star-glow; silver-blue and cyan; weightless, lifted.

---

## 1. Complete the broken evolution lines
*(these four lines only have an adult — add baby + mid so the cute→grim chain is whole)*

**Ember Drake line — Chaos/Ouranos (adult: Emberwyrm)**
- *Baby:* a palm-sized fire-dragon hatchling with an oversized head and stubby wings it hasn't grown into, embers leaking from its mouth, warm orange scales with faint jagged runes; clumsy, curious, smoking slightly.
- *Mid:* a lean adolescent fire-drake, spikier, wings now functional, cracks of magma glowing along its flanks, cocky and restless.

**Tide Serpent line — Ouranos/Cosmos (adult: Tidecoil)**
- *Baby:* a small ribbon-like sea-serpent pup with oversized fins and bright curious eyes, translucent blue scales ringed with orderly sigils, trailing a curl of water.
- *Mid:* a longer adolescent serpent, finned crest unfurling, sigil-rings glowing down its length, sleek and sinuous on a coil of conjured tide.

**Rime Bear line — Cosmos/Gaia (adult: Rimewarden)**
- *Baby:* a round fluffy bear cub with the first blue ice-crystals budding along its spine, snow-white fur, calm pale-blue markings, sitting in a dusting of frost.
- *Mid:* a sturdier young bear, ice plates now armoring back and shoulders, breath fogging, heavy and patient.

**Thorn Lion line — Eros/Gaia (adult: Thornmane)**
- *Baby:* a small lion cub whose mane is sprouting leaves and tiny buds, bark-textured paws, moss tufts, warm green-gold, soft and blinking.
- *Mid:* an adolescent wood-lion, mane thickening into a crown of branches and blossoms, bark spreading up its legs, rooted strength.

---

## 2. Pure-pole anchors
*(priority: Cosmos, Chaos, pure Eros, pure Thanatos — your lightest poles. These seed the god-seed lines too.)*

- **Pure Cosmos base:** a small serene construct-creature built of concentric glowing rings and geometric crystal, perfectly symmetrical, white-gold-pale-blue, ringed by an ordered halo; calm and watchful.
- **Pure Chaos base:** a small unstable creature of broken shifting forms — mismatched limbs, flickering oil-slick iridescence, jagged magenta runes, never quite holding one shape; mischievous and unsettling.
- **Pure Eros base:** a gentle creature overflowing with flowers, vines and ripe fruit, a soft rounded body of petals and moss, warm rose and honey-gold, radiating growth.
- **Pure Thanatos base:** a small hollow-eyed death-spirit of ash and bone wrapped in cold violet soul-fire, desaturated greys, quietly sorrowful, a single sickly-teal flame for a heart.
- **Pure Gaia base:** a stout little creature of stone and embedded crystal with a mossy back, granite-heavy and grounded.
- **Pure Ouranos base:** a weightless feathered sky-chick trailing wind-ribbons and tiny sparks of lightning, silver-blue and cyan.

---

## 3. The 6 God-Seeds — Apotheosis forms
*(each looks like the **primordial itself**: divine scale, awe + dread. These are the ascension targets.)*

- **Cosmos — "The Orderer":** a towering serene deity of perfect geometry, concentric halo-rings, a calm astral mask for a face, crystalline filigree wings, radiant white-gold; impartial and a little terrifying in its perfection.
- **Chaos — "The Unmaker":** a vast god-form that never settles, a churning silhouette of fracturing limbs and shifting faces, oil-slick void shot through with magenta lightning and broken runes; beautiful and wrong.
- **Eros — "The Mother-Bloom":** a colossal life-deity, a walking garden crowned in blossoming trees with rivers of vines and fruit pouring from her, warm and overwhelming, fertile to the point of menace.
- **Thanatos — "The Pale Quiet":** a gaunt towering death-god of bone and ash robed in cold soul-fire, hollow and patient, a single teal flame where a heart should be; not cruel, just final.
- **Gaia — "The Old Weight":** a mountain-sized earth-deity of living stone, bark and crystal, a slow continental silhouette with valleys and forests on its back; ancient, immovable.
- **Ouranos — "The High Vault":** a vast celestial sky-god of layered feathers and storm, a constellation-lit form trailing wind and lightning, lifted on impossible wings; remote and bright.

---

## 4. Taboo-fusion abomination  *(the "you made something wrong" register)*

- A deliberately **wrong** chimera stitched from mismatched creatures — too many limbs and eyes, visible seams and sutures, parts that don't belong together, instability leaking from the joins as flickering corrupted sigils; powerful and pitiable, the kind of thing the world would hunt. *Keep it eerie and uncanny, not gory.*

---

## 5. Individual sigil / aura overlay  *(for the in-game uniqueness layer)*

- A single glowing occult **sigil/aura motif** on a flat dark or transparent background, themed to one force (geometric for Cosmos, jagged for Chaos, floral for Eros, bone-flame for Thanatos, stone-rune for Gaia, feather-star for Ouranos), designed to be composited over a base creature as its unique mark. Vary the seed for one-of-one results.

---

## Priority order to flesh out the seed

1. The **4 missing baby + mid forms** (completes your existing chains).
2. **Pure Cosmos, Chaos, Eros, Thanatos** anchors (balances the type space).
3. The **6 god-seeds** (unlocks the Apotheosis endgame visually).
4. A **taboo-fusion** plate + a few **sigil overlays** (establish the dark-crafting + uniqueness looks).
