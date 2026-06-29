# Mutants_Game — Creatures: Legendary, God, Primordial & Constructs (Showcase Segment)

**Segment:** every `creature_registry.csv` row whose `rank` is `legendary`/`god`/`primordial` **or** whose `class` is `construct`, that was missing a name and/or description. These are the showcase tier — bosses, dead-god demon-lords, the war-construct foundries, and the apex flights.

**Method:** Names + one-line funny-grim descriptions **synced from the `Creature_Codex_Vol*` files** (Vol05/06 = batch3 · Vol07/08 = batch4 · Vol09/10/11 = batch5), keyed on registry `id`, condensed to the registry's ~15–30-word crisp-line convention. **156 rows — 156 synced from codex, 0 generated.** Names verified unique against the existing registry roster. Forces stay balanced across the six poles per the brief.

> Source-of-truth for full profiles (stat blocks, skill kits, evolution lines) remains the `Creature_Codex_*` books. This file is the registry merge-table (`| id | name | description |`) only. Do not edit `creature_registry.csv` directly — a later ingest merges by `id`.

| id | name | description |
|---|---|---|
<!-- batch3 — demon-lords (God), clockwork & bastion constructs, eldritch abominations, apex kaiju/dragons, Greek-myth champions (Vol05/06) -->
| batch3-001 | Vorraxiel, the Unmade Crown | A demon-lord who rules by subtraction, retiring kingdoms wholesale and keeping a tally of the unmade; even its weeping fire finds the work depressing. |
| batch3-002 | Pyrendax, the Open Furnace | One enormous opinion about fire with no punctuation and no defenses, because it never plans to be hit twice — by then it's already over. |
| batch3-003 | Sylvanthus, the Weeping Bloom | A god half garden, half graveyard, nursing allies and rotting foes from one root; the flowers it leaves on your corpse are sincere, and hungry. |
| batch3-004 | Nyxaeril, the Drifting Shroud | A violet lady who moves like bad news — quietly, then already here; politely lets you finish your sentence before ending the rest of them. |
| batch3-005 | Tharragost, the Iron Magistrate | A mountain of stone and gold whose ruling on every matter is "no"; it has stood in one argument for an age and considers itself winning. |
| batch3-006 | Veshrali, the Honeyed Swarm | A swarm-lord that beat mortality by being a population, beautiful up close and cheerful about it; loves its children fiercely and spends them instantly. |
| batch3-007 | Hieloquen, the Verdict of Frost | A frost-lord who decides ahead of time exactly how slowly your turn arrives; the quickest of its court, using speed only to make everyone else late. |
| batch3-008 | Grimbathok, the Roost of Endings | A winged thing that perches like a held breath and hunts only the finishable, with an unerring eye for which of you that is today. |
| batch3-009 | Maelyrra, the Gentle Current | A river-serpent whose kindness arrives faster than your enemies' cruelty; the swiftest healer in the pantheon, spending all that speed on being kind sooner. |
| batch3-010 | Skarnathoth, the Bristled Verdict | The court's hound, the size of a grievance and twice as committed; sent to end a thing loudly, in front of witnesses, so the witnesses learn. |
| batch3-011 | Malzevorrin, the Scarlet Adjudicator | A magistrate of harm who thinks everything living is mid-trial and mostly guilty; never lost a case, since it writes the law, verdict, and obituary. |
| batch3-012 | Ashvargod, the Ordered Grave | An armored lord who files every killing in triplicate and seals it with a crown; not a blade but a writ — slower, colder, impossible to appeal. |
| batch3-013 | Quorruveth, the Reaching Hollow | A lord shaped like a hunger that grew too many ways to reach, never the same silhouette twice; it has more arms than you have plans. |
| batch3-014 | Yssraketh, the Antlered Lament | A lady whose every emotion arrives as an explosion; her antlers catch other people's last moments, and she mourns each kill loudly and insincerely. |
| batch3-015 | Sceptraël, the Glass Wing | A dragon of blue glass and colder logic that breathes not fire but terms and conditions, binding; where it banks, the light apologizes for being late. |
| batch3-016 | Cryselthorn, the Pale Flame Warden | A warden whose order-colored flame doesn't destroy but files you under "later," which in a fast fight is the same as never; its blue fire seals shut. |
| batch3-017 | Heartholt, the Verdant Bastion | A serpent-lord so overgrown it became geography — a fortress that gardens, the steadiest god in a court of strange ones, healing an army behind its bulk. |
| batch3-018 | Ignavarro, the Laughing Pyre | An arsonist with wings and a sense of humour about gravity; it strikes first because it's bored by the part of fights where the enemy participates. |
| batch3-019 | Lethemora, the Tender Rot | A horror that kills the way some people hug — too long, too hard, past when you asked it to stop; it will miss you terribly, starting now. |
| batch3-020 | Mulgaroth, the Buried King | A king who was buried, disagreed, and came back wearing the hill; the heaviest thing in the pantheon, ruling by being permanently in everything's way. |
| batch3-021 | Belzaroth, the Crowned Ember | The portrait the word "demon-lord" paints before it knows better — horned, winged, crowned; old enough to have started the cliché, vain enough to keep it. |
| batch3-022 | Thronabael, the Sole Bane | A serpent-lord refined down to a single verb — end. No defense, no flourish, only the one cut, perfected across an embarrassing number of eras. |
| batch3-023 | Mossgrave, the Slow Mercy | A moss-mounded titan that heals like a forest recovering from fire — slowly, completely, on its own schedule; it considers most emergencies mere impatience. |
| batch3-024 | Zephlarael, the Silver Verdict | A dragon sanded down to pure velocity wrapped in just enough order to survive it; the quickest thing alive, spending all that speed to simply go first. |
| batch3-025 | Skritthalax, the Mandible Choir | A lord technically singular and morally a swarm, hungry in one direction; it doesn't roar — it chitters, the sound of the fight's maths turning against you. |
| batch3-026 | Aurelvane, the Antlered Decree | A stag-shouldered lord of armoured blue carrying the court's law in its antlers; the most regal and least hurried, because order properly enforced never rushes. |
| batch3-027 | Mordravspine, the Coiled Sepulchre | A serpent-lord built like a hill that decided to hunt; it kills thoroughly, not quickly, the one assassin you cannot outlast — it brought the longer afternoon. |
| batch3-028 | Cindraxis, the Forge-Heart | A draconic furnace-lord whose chest is a small sun on a short fuse, perpetually about to make that everyone's problem; closer to weather than animal. |
| batch3-029 | Brumavex, the Glacial Sentence | A frost-lord built like a moving glacier — barely moving, impossible to argue with; given time, ice wins every standoff, and it has all the time. |
| batch3-030 | Vaelgrith, the Sundering Reach | An elder of reaching things — a limb that forgot it ever needed a body, governing the tentacled Hollow-Court by being the longest thing in any room. |
| batch3-031 | Cogwright Mk.I "Sentinel" | The foundry's first and most honest model, running on wound springs and one repeating thought: stand here, hold this line. Loyal as a lock, about as talkative. |
| batch3-032 | Cogwright Mk.II "Pincer" | A brass crab built to grab one problem and have no opinions about the rest; its shell takes hits like a safe takes burglars, and it holds forever. |
| batch3-033 | Cogwright Mk.III "Watchman" | A one-eyed brass watchman on spindly legs that never blinks, built to stare at one thing until it stops being a problem and finds your leaving insulting. |
| batch3-034 | Cogwright Mk.IV "Boilerback" | A barrel-chested model with a boiler for a torso and the disposition of a closed door; it hisses constantly and works by being too solid to get past. |
| batch3-035 | Cogwright Mk.V "Deepdiver" | A foundry diver sealed for pressures that would fold lesser frames, now just standing in the way on dry land, forever wading through water only it can feel. |
| batch3-036 | Cogwright Mk.VI "Leapwork" | A pale clockwork hare built to interpose itself between an ally and a bad idea; the closest the foundry got to endearing, and it still weighs a quarter-ton. |
| batch3-037 | Cogwright Mk.VII "Skitterframe" | A low brass crawler on too many legs that lays a grid of cabling and decides who gets to hurry; unsettling the way purposeful machinery is, with excellent traction. |
| batch3-038 | Cogwright Mk.VIII "Owlwork" | A brass owl whose head turns past comfort and whose lens-eyes tally you against an unseen standard; it doesn't hoot — it ticks, which is worse at 3am. |
| batch3-039 | Cogwright Mk.IX "Tidewright" | A teal-glass dome on brass armatures projecting a field it would prefer you respect; the strangest model the foundry signed off on, and nobody's sure how it floats. |
| batch3-040 | Cogwright Mk.X "Bastion-Shell" | The capstone — a bronze tortoise-shell on treads that rolls into position once, then stops being a creature and becomes terrain nothing wants to test. |
| batch3-041 | Branchflayer | Someone grafted grief onto a growing thing and it said yes; now it reaches into wherever you used to be, mistaking you for soil. |
| batch3-042 | Vespermoth | It came to the lamp, kept coming, became the lamp's idea of a face; its almost-meaningful wings make you follow one fatal step. |
| batch3-043 | Gallowsthread | Hung once and decided not to stop, it sways in the air full of one enormous intention, doing a single thing to you very thoroughly. |
| batch3-044 | Lampveil | Beautiful from a survivable distance, it drifts trailing glowing kindnesses, mending your wounds the way a tide loves the shore: completely, unasked. |
| batch3-045 | Orantmantis | It prays without pause to no god, all those folded hands, and the unsettling part is the prayer works — nobody knows what it wants. |
| batch3-046 | Thornmitre | A priest of something that stopped writing back, it still takes confession, and rather more; it absolves you of everything you had left. |
| batch3-047 | Palewretch | Too tall, too thin, too fast for either, it crosses a room before you decide to leave; it does not run, it arrives like bad news. |
| batch3-048 | Maulbrood | A fusion that couldn't agree how many mouths to have, so it took all of them; it does not strategise, it converges, loudly, from everywhere. |
| batch3-049 | Rootmurk | A blight that grew downward and forgot to stop being hungry; it has already arrived underneath, and your roots were its several turns ago. |
| batch3-050 | Sinewchant | It lost its skin and has been upset ever since in a key only it can hold; the flaying just freed the screaming, and each kill makes it worse. |
| batch3-051 | Stormcrag | A walking ridgeline that learned to hurry and resents being asked; storms gather on its spines, and when it moves the horizon revises itself. |
| batch3-052 | Brinemaw | Something the deep grew when it tired of being calm; it carries the sea's worst mood, and the tail arrives a second after you thought you dodged. |
| batch3-053 | Cairnsaur | Built like a collapsed monument and as eager to move; things that die near it stay, becoming the cairn it carries without comment or burden. |
| batch3-054 | Galewyrm | A dragon that treats altitude as a weapon and gravity as a bullied ally; it fights from above, briefly, on the way down — your only warning. |
| batch3-055 | Hollowtithe | A mountain of an animal always emptier than its size suggests; it collects what it kills not to eat but to fill, and has never once felt full. |
| batch3-056 | Bastion-Mk.I "Aegistread" | The first thing the foundry got right and never improved on; it does not advance or retreat, it holds — that's the whole job and personality. |
| batch3-057 | Bastion-Mk.II "Striplance" | The model after defense got boring, given a lance for keeping things out, not getting them; cleaner-lined than its sibling and twice as smug. |
| batch3-058 | Bastion-Mk.III "Rivetwall" | A bunker that learned to walk and sensibly chose not to; every rivet argues against a way through, soaking hits meant for softer creatures. |
| batch3-059 | Bastion-Mk.IV "Grudgeworks" | Built after someone hit the Mk.III and got away with it; it does not forgive a blow, it files it, soot-black and patient, to refund in full. |
| batch3-060 | Bastion-Mk.V "Longbarrel" | The model where the foundry admitted it built a turret with legs; it holds ground the polite way, by making the ground ahead lethal to occupy. |
| batch3-061 | Quarryking | A walking quarry that crystallised its own bad temper and sheds it as shrapnel; it rules nothing — it just will not get out of the way. |
| batch3-062 | Worldspine | The biggest single thing in the clade, geology with a pulse; it does not attack or hurry, it is simply there, a horizon standing in your way. |
| batch3-063 | Voltdrake | A dragon wired like a coming storm and just as orderly; the glow in its chest is not a heart but a schedule, and it strikes on the beat. |
| batch3-064 | Tidalmaw | A dragon-beast built like a wave with legs, fast as surf and heavy as the water under it; it does not chase the slow — it catches everyone. |
| batch3-065 | Sporedrake | A dragon assembled in a hurry by something out of patience; faster than it should be, wildly inaccurate, brilliant or comedy turn by turn. |
| batch3-066 | Ironcrag | A kaiju whose hide grew in such tidy plates people swear it's a construct; entirely organic, entirely armored, walling calmly and resentfully. |
| batch3-067 | Vanguard-Mk.I "Skylance" | The foundry's stab at a mech that flies, which mostly hovers menacingly and insists it could; it just refuses to let anyone else have air. |
| batch3-068 | Vanguard-Mk.II "Deepkeel" | The flight model with the flight removed and enough hull to sink a harbour; it plants itself like a grounded ship and dares the tide to move it. |
| batch3-069 | Vanguard-Mk.III "Pikeward" | A construct issued a spear and one instruction — nothing gets past — obeyed with literal devotion; within reach, the battle is orderly and brief. |
| batch3-070 | Vanguard-Mk.IV "Boilerhulk" | The chassis that runs on actual fire, quaint to newer models and outlasting them all; a furnace that learned to stand a watch, leaking heat. |
| batch3-072 | Nyxhydra | A night-coloured hydra that treats decapitation as a scheduling problem; it strikes in draining waves, an argument you keep almost winning. |
| batch3-073 | Taurok, the Labyrinth-Keeper | The bull at the heart of the maze that never needed it — built to keep you in; a straight charge is the only prayer he still remembers. |
| batch3-074 | Keruthos, the Threshold Hound | The hound at the gate no one leaves, three heads so nothing slips past while one sleeps; it does not hate the dead, it files them. |
| batch3-075 | Aellopis, the Snatching Gale | The storm-wind that learned to steal, given a face, a grudge, and talons; she does not linger to fight, she passes, and your blessing is gone. |
| batch3-076 | Stheneira, the Stone-Gaze | Punished for another's crime, turning messengers to stone ever since; the snakes are honest, the face ruins you — she is not cruel, just tired. |
| batch3-077 | Khalkeon, the Unkillable Mane | The lion whose pelt turned every weapon ever raised — a marvellous, lonely gift; it guards now the way it once could not be guarded against. |

<!-- batch4 — apex dragon flights, deep-coil kaiju, plague behemoths, lich/spirit drown-choir; incl. construct batch4-065 (Vol07/08) -->
| batch4-049 | Skysovereign | The volume's first true apex: a feathered-light dragon faster than weather that judges from above, owns all the altitude, and shares none. |
| batch4-050 | Azuredrake | Skysovereign's darker, swifter twin — a storm-riding serpent that doesn't fly so much as cut, arriving twice and gone before the thunder explains it. |
| batch4-051 | Cinderwyrm Patriarch | The Flight's oldest molten apex: a quarry-fire dragon that does not breathe flame but passes sentence, and the verdict is always ash. |
| batch4-052 | Slagmaw Tyrant | Rules its cooling lava-field and taxes every trespasser in the currency of being on fire; the foundry throat is your only warning, and it's not enough. |
| batch4-053 | Emberscourge | The Flight's working arsonist, lean and tireless and faintly bored, burning things less from fury than a sense they ought to be ash by now. |
| batch4-054 | Furnace-Crowned Wyrm | A vain apex that mistook its rack of door-sized burning horns for a crown, and you for a subject who hasn't yet bowed; carrion birds know dusk is dinner. |
| batch4-055 | Ashen Doom-Drake | The Flight's pessimist, proven right too often, raining slow burning cinders on places having a nice century; it is not in a hurry, doom rarely is. |
| batch4-056 | Riptide Wyrm | Deep-water serpent lit by cold cyan that never offered warmth; it does not maul but passes through, and afterward someone is simply gone from the line. |
| batch4-057 | Hydra of the Black Deep | An unreasonable number of teal-lit heads, each biting a different one of you and living off the difference; it hunts groups for the variety. |
| batch4-058 | Brineshade Drake | A wave with a shadow under it, fighting by rearrangement, yanking your fastest to the back with the patience of cold water that knows you must breathe. |
| batch4-059 | Abyssridge Kaiju | The Coil's heavyweight assassin, faster than its mass has any right to be, surfacing from a direction your shield wasn't pointing; bring a roof. |
| batch4-060 | Gravewater Serpent | The Coil's closer, colour of water nobody resurfaces from, drifting in after the work is done to collect what's left, swiftly and without comment. |
| batch4-061 | Mirepyre Behemoth | A walking bog that committed too hard to being alive; it knits your wounded shut and makes your enemies itch, both technically true, no contradiction seen. |
| batch4-062 | Rotwood Stag-Colossus | A stag the size of a wrong idea, antlers a hanging garden of luminous rot, pulling vitality from the dying and reseeding it green on your side. |
| batch4-063 | Plaguescale Wallcrawler | A hill that grew a bad mood and a digestive system; it plants over your wounded and dares the enemy through the fever-cloud. Safe like a quarantine tent. |
| batch4-064 | Verdant Carrion-Wing | A vulture that decided to be helpful, circling to grow your dead back into something approximately alive. The favour is genuine; the favour also itches. |
| batch4-065 | Slagheart Bastion | A relocatable fortress built around a green furnace-heart; it does not eat, sleep, or think, only occupies space and refuses to surrender it. |
| batch4-066 | Verdigris Reaper | Old-copper green left out centuries to brood; it does not hurry a kill but wraps, waits, and grows healthier as you grow less so. The Mirepyre's dark mirror. |
| batch4-067 | Chitinghast Stalker | A nightmare of elbows and edges, joint-lit from rotting within, skewering whatever you were protecting because it correctly guessed that's worth killing. |
| batch4-068 | Pallid Hunt-Hound | A hound built like a famine, running ahead to mark a chosen victim with a death-sign only its clade can see. It picks; the Reapers collect. |
| batch4-069 | Wyrmrot Dragon | Wings rotted halfway, flying out of sheer refusal, dropping on one target like a falling graveyard and getting up healthier than it landed. |
| batch4-070 | Hollow Sentinel-Wraith | A gallows that learned to float, draped in what might be robes or prior visitors; it guards nothing and simply punishes motion. Stillness is the only mercy. |
| batch4-071 | Sepulchre Cantor | A lich worn thin as a held breath; it does not scream but intones, slowing the field to a funeral's pace and setting the key the whole choir waits for. |
| batch4-072 | Mourner of the Long Halls | A grief-shape that forgot which death it set out to mourn and now mourns everyone, veiling foes in second-hand sorrow until they can barely lift their arms. |
| batch4-073 | Choir-Shade Soprano | The choir's highest voice, frozen mid-reach of a note it never finishes; its song deals no damage, it simply makes the enemy late until late turns fatal. |
| batch4-074 | Threnody Warden | The Sepulchre's bass and bodyguard, broad enough to let harm break on its shrouds; it guards the choir like a tombstone guards a name, already grieving you. |
| batch4-075 | Pale Keening Spirit | A drowned draught that floats upward from habit; its keening does not roar but erodes, a ceaseless wearing-away that makes the strong feel briefly mortal. |
| batch4-076 | Grave-Veiled Antiphon | A lich mourning in two mirrored voices, draping overlapping grey protection; cut off one voice and the other only sings louder. Worse to interrupt than watch. |
| batch4-077 | Hollow Choirmaster | A lich with the bearing of one who ran a cathedral and never accepted the resignation; a sweep of pale arms forces the battlefield into his grim tempo. |
| batch4-078 | Drowned Requiem-Singer | The voice that names the Drown-Choir, a lich that died underwater and never stopped pouring, settling a sodden weight on foes until moving feels like swimming. |
| batch4-079 | Ashen Psalm-Wraith | Hung with ribbons of half-remembered scripture, each verse forbidding the enemy a move, a moment, a mercy, with the dry authority of a rule no one recalls passing. |
| batch4-080 | Sovereign of the Silent Pews | The choir's crowned sovereign, ruling a congregation that died facing the altar; when it raises the silence, the battlefield becomes a held funeral service. |

<!-- batch5 — celestial host, infernal demon broods, deep aquatics, shadow-assassins, frost flights, crystal wyrms, radiant sanctum-lords (Vol09/10/11) -->
| batch5-025 | Empyriel | Descends only to correct an offense it calls a battle, rearranging who acts and when with bored, pre-ancient authority. |
| batch5-026 | Astraveil | A night-sky watcher who edits what each side can be sure of; your aim finds after-images while it stays unknowable. |
| batch5-027 | Aureon | A winged hart wearing a crown of cold light, refereeing endings and imposing peace without asking the violence first. |
| batch5-028 | Throneward | The host's last resort, planting an immovable throne over what must not fall and daring the battle to break on the floor. |
| batch5-029 | Argentveil | A drake of running silver light that owns a fight's rhythm, mireing the swift and keeping initiative as a ledger. |
| batch5-030 | Caelumwyrm | A heaven-serpent that shields by enclosing, wrapping allies in cold high light the battlefield's worst can't reach. |
| batch5-037 | Magmoloch | A walking magma cliff that erupts at you rather than attacks, cracking the earth open; the death in its fire is the quiet part. |
| batch5-038 | Ashreaver | A starved blade-limbed fiend that harvests endings, growing keener with every soul it takes. Nothing about it is wasted. |
| batch5-039 | Cindergeist | An armored demon with a furnace where its grudge should be, overloading until everything nearby burns, including its composure. |
| batch5-040 | Pyrabaddon | A winged ruin that descends like bad news; where it lands the fight is a formality, death in the heat, arrogance in all else. |
| batch5-041 | Sunderwail | A demon shaped like a collapsing roof, splitting its own form to double the scream that empties the front rank. |
| batch5-042 | Maledict | Takes up cursing like gardening, naming you guilty in a flat clerical mutter and bleeding your defenses to nothing over days. |
| batch5-049 | Pyreghast | An ash-grey demon that flies to funerals uninvited and improves attendance by adding to the guest list, then detonating. |
| batch5-050 | Glorivore | The Brood's most beautiful liar, a false-holy radiance that eats anything that kneels and bills like a loan shark. |
| batch5-051 | Carrionlord | A plated demon built like a tax, arriving once the dying starts to collect with a flooded-landlord's entitlement. |
| batch5-052 | Tendrilbane | Mostly arms and entirely opinions, delivering a beating by committee where each tendril feuds over whom to hit first. |
| batch5-053 | Houndsorrow | A grief that grew teeth from being left in the cold, howling like a slammed door you feel through the floor. |
| batch5-054 | Nocturnex | The last-hatched and worst-tempered, a serpent that gave the dark a spine; it moves like rumor and lands like a verdict. |
| batch5-055 | Squallmaw | A finned horror quick as a squall, striking twice before the water finishes parting, the second blow carrying drowned rot. |
| batch5-056 | Brineflense | A grievance with too many legs that doesn't pinch so much as file you down, one quick stripping cut at a time. |
| batch5-057 | Maelkraken | A kraken that mistook ambush predator for being everywhere at once; its eight arms arrive on their own schedule, which is now. |
| batch5-058 | Inkrender | A squid the colour of a drowning and twice as quick, clouding the water then carving it in a dark it brought. |
| batch5-059 | Fathomdread | A horror that hauled the sea's crushing bottom up like a held breath, arriving at speed and without asking permission. |
| batch5-060 | Wraithtide | The palest Drownkith, a tide that kept walking after the water left, drifting in like fog and striking like surf. |
| batch5-085 | Mantissable | Scythe-armed mantis that folds in mock prayer, then unfolds into your back line; every kill it lands sharpens the next reaping. |
| batch5-086 | Scarabnox | Grave-beetle that rolls the unburied into a withering cloud, draining what it touches and growing fatter the longer the slaughter runs. |
| batch5-087 | Pallpanther | Panther stitched from 3 a.m. dark, striking first and unseen; if it kills, it slips back into shadow and the next kill comes free. |
| batch5-088 | Direhusk | Armored ambush-slab that looks like terrain, then locks its jaw on one throat and drains harder the longer it refuses to let go. |
| batch5-089 | Vesperdrake | Bruise-colored drake that stoops from the dark for a staggering dive, magnificent in descent and fatal to whoever the landing finds. |
| batch5-090 | Mourningmare | Pale death-courier that glides the line dealing Bane and dragging the struck toward the back, offering everyone a ride they won't return from. |
| batch5-091 | Glacewyrm | First-frost serpent that glazes the room and lands three lashes ahead of the shiver, slowing all it touches before the cold even arrives. |
| batch5-092 | Frostfawn | Thin-ice darter that never falls, bursting ahead to lend the squad its rush and lay a sliver of frost-Ward over everyone. |
| batch5-093 | Hoarhart | Antlered stag goring with the brisk efficiency of weather, striking early and frost-locking pinned prey where the silence is total. |
| batch5-094 | Rimelion | Lion frozen mid-roar and permanently furious, pouncing first to chill its prey and shave their speed before they can answer. |
| batch5-095 | Sleetquill | Blizzard-chimed bird crossing the field faster than its own cold, clipping two front targets before either reacts and molting icicles as it goes. |
| batch5-096 | Frostfen Vixen | Frost-fox of nine crystalline tails, one move ahead always, stacking evasion while it dances; catching it is like catching your reflection. |
| batch5-097 | Geodecrane | Faceted crystal-crane holding its neck like a loaded prism, firing a splitting light-lance when the angle pleases it, rarely and devastatingly. |
| batch5-098 | Prismcoil | More window than wyrm, it hoards light then spends it in one chiming detonation that leaves the air full of glittering regret. |
| batch5-099 | Facetflit | Stained-glass scalpel on wings; it molts razor edges and beats them into the whole line, the already-wounded catching the worst shrapnel. |
| batch5-100 | Jadefang | Crystal-lizard whose smile keeps adding teeth, biting and biting until the geometry of its jaw becomes everyone's problem. |
| batch5-101 | Spinegeode | Walking pincushion with opinions, launching its own back at you and regrowing it, an arms race it always wins against itself. |
| batch5-102 | Geodewrath | Slab of dark crystal with a grudge in its chest, lighting its own fuse for one colossal core-blast and standing there smug while it recharges. |
| batch5-109 | Gildgrub | Fat radiant grub humming hymns it shouldn't know, cocooning the most-wounded in gilded silk and healing everything it inches past, foes included. |
| batch5-110 | Aureate Wyrm | Dragon that looks minted rather than hatched, blessing the whole squad at once and gilding the dying in a temporary Ward shell. |
| batch5-111 | Haloquill | Winged saint who canopies the squad in ordered light, smoothing the worst dice into something survivable and pitying your panic. |
| batch5-112 | Goldhart | Dawn-plated stag whose antlers branch into little suns; where it steps the wounded stand, serene while the enemy seethes. |
| batch5-113 | Sanctum Colossus | Cathedral that learned to walk, planting itself amid the squad to bank every hit and discharge it back as grace on a liturgical schedule. |
| batch5-114 | Empyrean Coil | Serpent of pure dawn-light that loops the squad in a halo, healing without tiring and correcting death once like a clerical error. |

