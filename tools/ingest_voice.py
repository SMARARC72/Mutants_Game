#!/usr/bin/env python3
"""Ingest the authored voice libraries into the VoiceBook catalog (Wave 16a).

Parses docs/content/voice_library.md (Vol I) + voice_library_2.md (Vol II) and emits
client/catalog/voice.json as {key: [variant strings]}. Lines land VERBATIM (binding
tension 11 — no paraphrasing); only markdown emphasis markers (** / *) and the
section-derived labels/tags that become part of the KEY are stripped.

Keys are stable and semantic ("capture.befriend.success", "region.verdant_glut.enter",
"battle.stalemate", ...), derived from an explicit per-section KEYMAP below — never from
run-to-run state — so a re-run over unchanged sources is byte-identical. Two volumes may
feed the same key (e.g. v1 §11.2 + v2 §9.3 -> battle.victory); variants append in
volume-then-document order, so ordering is deterministic too.

Section parse modes:
  plain    every bullet is a variant of the section's single key
  labeled  bullets carry a bold/italic label ("**Save:** ..." / "*Greeting:* ...");
           key = base.<slug(label)>, or an absolute key via the section's label_map
  tagged   bullets carry an italic parenthetical tag ("*(Threshold):* ...");
           key = fmt.format(tag=...) with tag slugs normalized via tag_map;
           untagged bullets fall to the section's "default" key when given
  grouped  bold paragraph lines ("**Aggressor**") open a group; bullets carry italic
           beat labels; key = fmt.format(group=..., label=...)

Run:  python -B tools/ingest_voice.py          (writes client/catalog/voice.json)
      python -B tools/ingest_voice.py --check  (verifies the committed file is current)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = [
    ("v1", os.path.join(ROOT, "docs", "content", "voice_library.md")),
    ("v2", os.path.join(ROOT, "docs", "content", "voice_library_2.md")),
]
OUT_PATH = os.path.join(ROOT, "client", "catalog", "voice.json")

_HEADING_RE = re.compile(r"^(#{2,3})\s+(\d+(?:\.\d+)?[a-z]?)[.\s]\s*(.*)$")
_BULLET_RE = re.compile(r"^-\s+(.*)$")
_TAG_RE = re.compile(r"^\*\((?P<tag>[^)]*)\)[:.]?\*:?\s*(?P<text>.*)$")
_BOLD_LABEL_RE = re.compile(r"^\*\*(?P<label>[^*]+?)[:.]?\*\*:?\s*(?P<text>.*)$")
_ITALIC_LABEL_RE = re.compile(r"^\*(?P<label>[^*(][^*]*?):\*:?\s*(?P<text>.*)$")
_GROUP_RE = re.compile(r"^\*\*(?P<group>[^*]+?)\*\*")


def slug(text: str) -> str:
    """Deterministic lowercase identifier from a heading/label/tag."""
    text = text.strip().lower()
    text = re.sub(r"[^a-z0-9]+", "_", text)
    return text.strip("_")


_ANNOTATION_RE = re.compile(r"\s*\(([a-z][^()]*)\)$")


def strip_emphasis(text: str) -> str:
    """Remove markdown emphasis markers only — the words stay verbatim."""
    return text.replace("**", "").replace("*", "").strip()


def strip_annotation(text: str) -> str:
    """Drop a trailing AUTHORING annotation like '(quest unlocked)' / '(rival encounter)'.

    Only lowercase-starting parentheticals with no sentence punctuation qualify — authored
    jokes that end a line ('(It wasn't.)', '(They always do.)') are sentences and stay.
    """
    match = _ANNOTATION_RE.search(text)
    if match is not None and not any(ch in match.group(1) for ch in ".!?"):
        return text[: match.start()].rstrip()
    return text


# --- The section -> key map (the curated half of the ingest). ------------------------
# Keyed by "<vol>:<section-number>". Unmapped sections are a hard error, so a library
# edit that adds a section forces a conscious mapping decision here.

_REGION_TAGS = {
    "threshold": "threshold",
    "verdant_glut": "verdant_glut",
    "mournmarch": "mournmarch",
    "forgefell": "forgefell",
    "storm_vault": "storm_vault",
    "the_sunder": "sunder",
    "titanfall": "titanfall",
    "the_tideless": "tideless",
    "astral_tier": "astral_tier",
    "the_maw_beneath": "maw_beneath",
    "the_hollow_atelier": "hollow_atelier",
}

_FACTION_TAGS = {
    "concord": "concord",
    "iron_guild": "iron_guild",
    "pale_court": "pale_court",
    "high_table": "high_table",
    "stoneblooded": "stoneblooded",
    "bloomwardens": "bloomwardens",
    "revel": "revel",
    "unbound": "unbound",
    "deep_choir": "deep_choir",
}

KEYMAP: dict = {
    # ---- Volume I ----
    "v1:1.1": {"mode": "plain", "key": "ui.title"},
    "v1:1.2": {"mode": "plain", "key": "ui.button.affirm"},
    "v1:1.3": {"mode": "plain", "key": "ui.button.negative"},
    "v1:1.4": {"mode": "labeled", "base": "ui.saveload"},
    "v1:1.5": {"mode": "labeled", "base": "ui.tooltip"},
    "v1:1.6": {
        "mode": "labeled",
        "base": "empty",
        "label_map": {
            "empty_party": "empty.party",
            "empty_bestiary": "empty.bestiary",
            "empty_parts_drawer": "empty.parts",
            "empty_inventory": "empty.inventory",
            "no_quests": "empty.quests",
            "empty_graveyard": "empty.graveyard",
            "no_factions_courted": "empty.factions",
            "empty_shop": "empty.shop",
        },
    },
    "v1:1.7": {"mode": "labeled", "base": "ui.confirm"},
    "v1:1.8": {"mode": "labeled", "base": "ui.setting"},
    "v1:1.9": {"mode": "plain", "key": "ui.loading"},
    "v1:2.1": {"mode": "plain", "key": "toast.caught"},
    "v1:2.2": {"mode": "plain", "key": "toast.harvest"},
    "v1:2.3": {"mode": "plain", "key": "toast.awakening"},
    "v1:2.4": {"mode": "plain", "key": "toast.overclock"},
    "v1:2.5": {"mode": "plain", "key": "toast.permadeath"},
    "v1:2.6": {"mode": "plain", "key": "toast.quest"},
    "v1:2.7": {"mode": "plain", "key": "toast.rival"},
    "v1:2.8": {"mode": "plain", "key": "toast.corruption"},
    "v1:2.9": {"mode": "plain", "key": "toast.faction"},
    "v1:2.10": {"mode": "plain", "key": "toast.ascension"},
    "v1:3.1": {"mode": "grouped", "fmt": "bark.role.{group}.{label}"},
    "v1:3.2": {
        "mode": "grouped",
        "fmt": "bark.force.{group}.{label}",
        "group_map": {
            "gaia": "gaia",
            "ouranos": "ouranos",
            "cosmos": "cosmos",
            "chaos": "chaos",
            "eros": "eros",
            "thanatos": "thanatos",
        },
    },
    "v1:4.1": {"mode": "plain", "key": "lab.preview"},
    "v1:4.2": {"mode": "plain", "key": "lab.commit"},
    "v1:4.3": {"mode": "plain", "key": "lab.reveal"},
    "v1:4.4": {"mode": "plain", "key": "lab.botch"},
    "v1:4.5": {"mode": "plain", "key": "lab.taboo"},
    "v1:5.1": {"mode": "plain", "key": "capture.befriend.success"},
    "v1:5.2": {"mode": "plain", "key": "capture.befriend.fail"},
    "v1:5.3": {"mode": "plain", "key": "capture.trap.success"},
    "v1:5.4": {"mode": "plain", "key": "capture.trap.fail"},
    "v1:5.5": {"mode": "plain", "key": "capture.refuses"},
    "v1:6": {
        "mode": "labeled",
        "base": "force",
        "label_map": {
            "gaia_bulk": "force.gaia.blurb",
            "ouranos_celerity": "force.ouranos.blurb",
            "cosmos_ward": "force.cosmos.blurb",
            "chaos_spike": "force.chaos.blurb",
            "eros_vitality": "force.eros.blurb",
            "thanatos_bane": "force.thanatos.blurb",
        },
    },
    "v1:7.1": {"mode": "plain", "key": "bark.region.threshold"},
    "v1:7.2": {"mode": "plain", "key": "bark.region.mournmarch"},
    "v1:7.3": {"mode": "plain", "key": "bark.region.verdant_glut"},
    "v1:7.4": {"mode": "plain", "key": "bark.region.sunder"},
    "v1:7.5": {"mode": "plain", "key": "bark.region.astral_tier"},
    "v1:7.6": {
        "mode": "tagged",
        "fmt": "bark.mortals.{tag}",
        "tag_map": {
            "low_notoriety": "low",
            "rising": "rising",
            "notorious": "notorious",
            "corrupt_feared": "feared",
            "worshipful": "worshipful",
        },
    },
    "v1:8": {
        "mode": "tagged",
        "fmt": "fourthwall.{tag}",
        "default": "fourthwall.signpost",
        "tag_map": {
            "over_talked_npc": "over_talked",
            "the_ghost_in_the_code_an_npc_that_shouldn_t_exist": "ghost",
            "an_npc_who_suspects_the_truth_badly": "suspects",
            "after_a_reload_following_a_death": "reload",
            "a_creature_staring_out_of_the_screen_once_never_again": "creature",
            "deep_corruption_an_idle_line": "corrupt_idle",
            "a_fortune_teller_breaking": "fortune_teller",
            "very_rare_on_quitting_late_at_night": "quit",
        },
    },
    "v1:9": {
        "mode": "labeled",
        "base": "status",
        "label_map": {
            "petrify_applied": "status.petrify.applied",
            "petrify_expire": "status.petrify.expire",
            "shock_applied": "status.shock.applied",
            "seal_applied": "status.seal.applied",
            "madness_applied": "status.madness.applied",
            "bloom_rot_applied": "status.bloom_rot.applied",
            "wither_applied": "status.wither.applied",
        },
    },
    "v1:10": {
        "mode": "labeled",
        "base": "care",
        "label_map": {
            "bond_increased": "care.bond_up",
            "bond_decreased": "care.bond_down",
            "creature_refuses_a_cruel_order_high_bond": "care.refuse_cruel",
            "regress_purge_entropy": "care.regress",
            "egg_obtained_breeding": "husbandry.egg.obtained",
            "storage_full": "storage.full",
            "item_is_cursed_cheerful_vendor_disclaimer": "shop.cursed",
            "fast_travel_ritual_circle": "travel.transit",
        },
    },
    "v1:11.1": {"mode": "plain", "key": "battle.start"},
    "v1:11.2": {"mode": "plain", "key": "battle.victory"},
    "v1:11.3": {"mode": "plain", "key": "battle.defeat"},
    "v1:11.4": {"mode": "plain", "key": "battle.downed"},
    # ---- Volume II ----
    "v2:1.1": {"mode": "plain", "key": "region.threshold.ambient"},
    "v2:1.2": {"mode": "plain", "key": "region.verdant_glut.ambient"},
    "v2:1.3": {"mode": "plain", "key": "region.mournmarch.ambient"},
    "v2:1.4": {"mode": "plain", "key": "region.forgefell.ambient"},
    "v2:1.5": {"mode": "plain", "key": "region.storm_vault.ambient"},
    "v2:1.6": {"mode": "plain", "key": "region.sunder.ambient"},
    "v2:1.7": {"mode": "plain", "key": "region.titanfall.ambient"},
    "v2:1.8": {"mode": "plain", "key": "region.tideless.ambient"},
    "v2:1.9": {"mode": "plain", "key": "region.astral_tier.ambient"},
    "v2:1.10": {"mode": "plain", "key": "region.maw_beneath.ambient"},
    "v2:1.11": {"mode": "plain", "key": "region.hollow_atelier.ambient"},
    "v2:1.12": {"mode": "tagged", "fmt": "region.{tag}.enter", "tag_map": _REGION_TAGS},
    "v2:1.13": {"mode": "tagged", "fmt": "region.{tag}.fauna", "tag_map": _REGION_TAGS},
    "v2:2.1": {"mode": "labeled", "base": "faction.concord"},
    "v2:2.2": {"mode": "labeled", "base": "faction.iron_guild"},
    "v2:2.3": {"mode": "labeled", "base": "faction.pale_court"},
    "v2:2.4": {"mode": "labeled", "base": "faction.high_table"},
    "v2:2.5": {"mode": "labeled", "base": "faction.stoneblooded"},
    "v2:2.6": {"mode": "labeled", "base": "faction.bloomwardens"},
    "v2:2.7": {"mode": "labeled", "base": "faction.revel"},
    "v2:2.8": {"mode": "labeled", "base": "faction.unbound"},
    "v2:2.9": {"mode": "labeled", "base": "faction.deep_choir"},
    "v2:2.10": {"mode": "tagged", "fmt": "faction.{tag}.creed", "tag_map": _FACTION_TAGS},
    "v2:2.11": {"mode": "tagged", "fmt": "faction.{tag}.ascension", "tag_map": _FACTION_TAGS},
    "v2:2.12": {
        "mode": "tagged",
        "fmt": "faction.tier.{tag}",
        "tag_map": {
            "associate": "associate",
            "sworn": "sworn",
            "champion": "champion",
            "hand": "hand",
            "standing_capped_elsewhere": "capped",
        },
    },
    "v2:2.13": {"mode": "plain", "key": "faction.refusal.grid"},
    "v2:3.1": {"mode": "plain", "key": "shop.buy"},
    "v2:3.2": {"mode": "plain", "key": "shop.sell"},
    "v2:3.3": {"mode": "plain", "key": "shop.cant_afford"},
    "v2:3.4": {"mode": "plain", "key": "shop.haggle"},
    "v2:3.5": {"mode": "plain", "key": "shop.blackmarket"},
    "v2:3.6": {"mode": "plain", "key": "shop.blessed"},
    "v2:3.7": {"mode": "plain", "key": "shop.cursed"},
    "v2:3.8": {"mode": "plain", "key": "shop.restock"},
    "v2:3.9": {"mode": "plain", "key": "shop.browse"},
    "v2:3.10": {"mode": "plain", "key": "shop.services"},
    "v2:4.1": {"mode": "plain", "key": "husbandry.incubation"},
    "v2:4.2": {"mode": "plain", "key": "husbandry.hatch"},
    "v2:4.3": {"mode": "plain", "key": "husbandry.lineage_true"},
    "v2:4.4": {"mode": "plain", "key": "husbandry.lineage_plain"},
    "v2:4.5": {"mode": "plain", "key": "husbandry.recessive_hit"},
    "v2:4.6": {"mode": "plain", "key": "husbandry.recessive_miss"},
    "v2:4.7": {"mode": "plain", "key": "husbandry.region_tint"},
    "v2:4.8": {"mode": "labeled", "base": "husbandry.bond"},
    "v2:4.9": {
        "mode": "tagged",
        "fmt": "capture.toast.{tag}",
        "tag_map": {
            "befriend_success": "befriend_success",
            "befriend_fail": "befriend_fail",
            "trap_success": "trap_success",
            "trap_fail": "trap_fail",
            "summon_the_rite_takes": "summon",
            "the_refuser_fielded": "refuser",
        },
    },
    "v2:4.10": {
        "mode": "tagged",
        "fmt": "husbandry.egg.{tag}",
        "tag_map": {
            "egg_obtained": "obtained",
            "incubation_progress": "progress",
            "rare_egg_sensed": "rare",
        },
    },
    "v2:5.1": {"mode": "labeled", "base": "lab.mutate"},
    "v2:5.2": {"mode": "labeled", "base": "lab.fuse"},
    "v2:5.3": {"mode": "labeled", "base": "lab.build"},
    "v2:5.4": {"mode": "labeled", "base": "lab.mod"},
    "v2:5.5": {"mode": "labeled", "base": "lab.sacrifice"},
    "v2:5.6": {"mode": "plain", "key": "lab.method.precise"},
    "v2:5.7": {"mode": "plain", "key": "lab.method.wild"},
    "v2:5.8": {"mode": "plain", "key": "lab.reveal"},
    "v2:5.9": {
        "mode": "labeled",
        "base": "lab.taboo",
        "label_map": {
            "opposed_force_fusion_abomination": "lab.taboo.opposed_force",
            "god_organ_graft": "lab.taboo.god_organ",
            "reanimation_rebuild_from_the_graveyard": "lab.taboo.reanimation",
            "self_splice_lab_ops_on_your_own_character": "lab.taboo.self_splice",
            "organic_construct_no_bridge": "lab.taboo.no_bridge",
        },
    },
    "v2:5.10": {
        "mode": "tagged",
        "fmt": "lab.botch.{tag}",
        "tag_map": {
            "mutate_botch": "mutate",
            "fuse_botch": "fuse",
            "build_botch": "build",
            "mod_botch": "mod",
            "sacrifice_botch": "sacrifice",
        },
    },
    "v2:5.11": {"mode": "plain", "key": "lab.instability"},
    "v2:6.1": {"mode": "labeled", "base": "status.petrify"},
    "v2:6.2": {"mode": "labeled", "base": "status.shock"},
    "v2:6.3": {"mode": "labeled", "base": "status.seal"},
    "v2:6.4": {"mode": "labeled", "base": "status.madness"},
    "v2:6.5": {"mode": "labeled", "base": "status.bloom_rot"},
    "v2:6.6": {"mode": "labeled", "base": "status.wither"},
    "v2:6.7": {"mode": "plain", "key": "toast.corruption"},
    "v2:6.8": {
        "mode": "tagged",
        "fmt": "status.event.{tag}",
        "tag_map": {
            "resisted": "resisted",
            "immune_by_force": "immune",
            "cleansed_by_ally": "cleansed",
            "status_stacked_to_limit": "stacked",
        },
    },
    "v2:6.9": {
        "mode": "tagged",
        "fmt": "corruption.{tag}",
        "tag_map": {
            "first_corruption": "first",
            "corruption_gate_crossed": "gate",
            "near_terminal_corruption": "terminal",
        },
    },
    "v2:7.1": {"mode": "plain", "key": "weather.force"},
    "v2:7.2": {"mode": "plain", "key": "weather.tide"},
    "v2:7.3": {"mode": "plain", "key": "weather.dusk"},
    "v2:7.4": {"mode": "plain", "key": "weather.dawn"},
    "v2:7.5": {"mode": "plain", "key": "weather.shift"},
    "v2:7.6": {"mode": "plain", "key": "weather.tide_locked"},
    "v2:7.7": {"mode": "plain", "key": "weather.rare"},
    "v2:8.1": {"mode": "plain", "key": "tutorial.welcome"},
    "v2:8.2": {"mode": "plain", "key": "tutorial.catch"},
    "v2:8.3": {"mode": "plain", "key": "tutorial.lab"},
    "v2:8.4": {"mode": "plain", "key": "tutorial.battle"},
    "v2:8.5": {"mode": "plain", "key": "tutorial.stakes"},
    "v2:8.6": {"mode": "plain", "key": "tutorial.currency"},
    "v2:8.7": {"mode": "plain", "key": "tutorial.graveyard"},
    "v2:8.8": {"mode": "plain", "key": "tutorial.factions"},
    "v2:8.9": {"mode": "plain", "key": "tutorial.husbandry"},
    "v2:9.1": {"mode": "plain", "key": "death.permadeath"},
    "v2:9.2": {"mode": "plain", "key": "death.graveyard"},
    "v2:9.3": {"mode": "plain", "key": "battle.victory"},
    "v2:9.4": {"mode": "plain", "key": "battle.defeat"},
    "v2:9.5": {"mode": "plain", "key": "death.run_ending"},
    "v2:9.6": {"mode": "plain", "key": "battle.downed"},
    "v2:9.7": {
        "mode": "tagged",
        "fmt": "death.region.{tag}",
        "tag_map": {
            "mournmarch": "mournmarch",
            "verdant_glut": "verdant_glut",
            "titanfall": "titanfall",
            "the_maw_beneath": "maw_beneath",
            "the_sunder": "sunder",
        },
    },
    "v2:9.8": {"mode": "plain", "key": "battle.start"},
    "v2:10.1": {"mode": "plain", "key": "rival.prefight"},
    "v2:10.2": {"mode": "plain", "key": "rival.midfight"},
    "v2:10.3": {"mode": "plain", "key": "rival.win"},
    "v2:10.4": {"mode": "plain", "key": "rival.loss"},
    "v2:10.5": {"mode": "plain", "key": "competition.arena"},
    "v2:10.6": {"mode": "plain", "key": "rival.escalation"},
    "v2:10.7": {
        "mode": "tagged",
        "fmt": "rival.taunt.{tag}",
        "tag_map": {
            "an_order_rival": "order",
            "a_corrupt_rival": "corrupt",
            "a_pure_rival": "pure",
            "a_chaos_rival": "chaos",
            "a_devourer_leaning_rival": "devourer",
        },
    },
    "v2:10.8": {"mode": "plain", "key": "rival.nemesis"},
    "v2:10.9": {
        "mode": "tagged",
        "fmt": "competition.result.{tag}",
        "tag_map": {
            "bracket_win": "bracket_win",
            "bracket_loss": "bracket_loss",
            "season_champion": "season_champion",
            "lab_craft_contest_win": "labcraft_win",
        },
    },
    "v2:10.10": {"mode": "plain", "key": "battle.boss.prefight"},
    "v2:10.11": {"mode": "plain", "key": "battle.boss.victory"},
    "v2:11": {
        "mode": "tagged",
        "fmt": "fourthwall.v2.{tag}",
        "tag_map": {
            "a_vendor_totting_up_a_long_session": "vendor",
            "madam_cessil_the_astrologer_mid_reading": "cessil",
            "an_idle_creature_at_deep_corruption_looking_out_once": "corrupt_idle",
            "a_save_name_signpost_deep_in_the_maw": "maw_signpost",
            "the_draftsman_in_the_hollow_atelier_very_quietly": "draftsman",
            "an_over_talked_npc_finally": "over_talked",
            "a_fortune_teller_breaking_on_a_re_load_after_death": "reload",
            "very_rare_on_quitting_after_a_long_run": "quit",
        },
    },
    "v2:12.1": {
        "mode": "tagged",
        "fmt": "notoriety.{tag}",
        "tag_map": {
            "notoriety_up": "up",
            "notoriety_high": "high",
            "notoriety_worshipful": "worshipful",
        },
    },
    "v2:12.2": {"mode": "plain", "key": "travel.transit"},
    "v2:12.3": {"mode": "plain", "key": "storage.full"},
    "v2:12.4a": {
        "mode": "tagged",
        "fmt": "care.{tag}",
        "tag_map": {
            "regress_purge_entropy": "regress",
            "entropy_bled": "entropy_bled",
            "creature_fed_cared_for": "fed",
            "creature_refuses_cruel_order": "refuse_cruel",
        },
    },
    "v2:12.4": {"mode": "plain", "key": "ascension.watched"},
    "v2:12.5": {
        "mode": "tagged",
        "fmt": "endgame.{tag}",
        "tag_map": {
            "god_maker_offer": "god_maker",
            "unmaking_trailhead": "unmaking",
            "the_throne_ending_snapshotted": "throne",
        },
    },
    "v2:12.6": {"mode": "plain", "key": "invasion.boss"},
    "v2:12.7": {"mode": "plain", "key": "hub.return"},
}

# Aliases: friendly call-site keys that mirror another key's variants (materialized into
# the JSON so consumers never need alias logic). battle.stalemate is the Wave 3 contract:
# the "wild slinks away" banner draws §5.5 refuser lines.
ALIASES = {
    "capture.success": "capture.befriend.success",
    "capture.fail": "capture.befriend.fail",
    "battle.stalemate": "capture.refuses",
    # SQ-05 Old Garran choice branches (W16a): refusing the shortcut is the Bloomwarden
    # faith ("that refusal is the whole faith"); taking it is the Revel's wild method —
    # Garran IS the Revel wearing a grandfather's face (old_garran.dtl).
    "quest.refused_garran": "faction.bloomwardens.standing_up",
    "quest.accepted_garran": "faction.revel.standing_up",
}

# For care.refuse_cruel, v1 §10 and v2 §12.4a both contribute — allowed (merge) keys:
MERGE_OK = {
    "toast.corruption",
    "lab.reveal",
    "battle.start",
    "battle.victory",
    "battle.defeat",
    "battle.downed",
    "shop.cursed",
    "travel.transit",
    "storage.full",
    "husbandry.egg.obtained",
    "care.regress",
    "care.refuse_cruel",
}


def parse_volume(vol: str, path: str, book: dict) -> int:
    """Parse one library volume into `book` ({key: [lines]}). Returns lines ingested."""
    with open(path, "r", encoding="utf-8") as fh:
        raw_lines = fh.read().split("\n")

    count = 0
    section = ""  # e.g. "5.1"
    group = ""  # grouped mode's current bold group
    seen_sections: set = set()

    for raw in raw_lines:
        line = raw.rstrip()
        heading = _HEADING_RE.match(line)
        if heading is not None:
            section = heading.group(2)
            group = ""
            seen_sections.add(f"{vol}:{section}")
            continue
        if line.startswith(">"):
            continue  # blockquote guidance, never player copy
        rule = KEYMAP.get(f"{vol}:{section}")
        if rule is None:
            continue  # intro prose before the first mapped heading
        mode = rule["mode"]
        group_match = _GROUP_RE.match(line)
        if mode == "grouped" and group_match is not None and not line.startswith("-"):
            group = slug(group_match.group("group"))
            group = rule.get("group_map", {}).get(group, group)
            continue
        bullet = _BULLET_RE.match(line)
        if bullet is None:
            continue
        body = bullet.group(1).strip()
        key, text = resolve_key(vol, section, rule, group, body)
        text = strip_annotation(strip_emphasis(text))
        if text == "":
            continue
        book.setdefault(key, [])
        book[key].append(text)
        count += 1

    # Every mapped section for this volume must have been seen (catches doc renames).
    for mapped in [k for k in KEYMAP if k.startswith(vol + ":")]:
        if mapped not in seen_sections:
            raise SystemExit(f"ingest_voice: mapped section {mapped} missing from {path}")
    return count


def resolve_key(vol: str, section: str, rule: dict, group: str, body: str) -> tuple:
    """Derive (key, text) for one bullet under the section's parse rule."""
    mode = rule["mode"]
    if mode == "plain":
        return rule["key"], body

    if mode == "tagged":
        tag_match = _TAG_RE.match(body)
        if tag_match is None:
            default = rule.get("default", "")
            if default == "":
                raise SystemExit(f"ingest_voice: untagged bullet in tagged {vol}:{section}: {body}")
            return default, body
        tag = slug(tag_match.group("tag"))
        tag_map = rule.get("tag_map", {})
        if tag_map and tag not in tag_map:
            raise SystemExit(f"ingest_voice: unmapped tag '{tag}' in {vol}:{section}")
        return rule["fmt"].format(tag=tag_map.get(tag, tag)), tag_match.group("text")

    if mode == "labeled":
        label_match = _BOLD_LABEL_RE.match(body) or _ITALIC_LABEL_RE.match(body)
        if label_match is None:
            raise SystemExit(f"ingest_voice: unlabeled bullet in labeled {vol}:{section}: {body}")
        label = slug(label_match.group("label"))
        label_map = rule.get("label_map", {})
        if label in label_map:
            return label_map[label], label_match.group("text")
        return rule["base"] + "." + label, label_match.group("text")

    if mode == "grouped":
        label_match = _ITALIC_LABEL_RE.match(body) or _BOLD_LABEL_RE.match(body)
        if label_match is None or group == "":
            raise SystemExit(f"ingest_voice: stray bullet in grouped {vol}:{section}: {body}")
        return (
            rule["fmt"].format(group=group, label=slug(label_match.group("label"))),
            label_match.group("text"),
        )

    raise SystemExit(f"ingest_voice: unknown mode '{mode}' for {vol}:{section}")


def build_book() -> dict:
    book: dict = {}
    per_volume: dict = {}
    for vol, path in SOURCES:
        before = {k: len(v) for k, v in book.items()}
        per_volume[vol] = parse_volume(vol, path, book)
        # Guard: a key growing across volumes must be an intentional merge.
        for key, lines in book.items():
            if key in before and len(lines) > before[key] and key not in MERGE_OK:
                raise SystemExit(f"ingest_voice: unintended cross-volume merge on '{key}'")
    for alias, target in sorted(ALIASES.items()):
        if target not in book:
            raise SystemExit(f"ingest_voice: alias target '{target}' missing")
        if alias in book:
            raise SystemExit(f"ingest_voice: alias '{alias}' collides with a real key")
        book[alias] = list(book[target])
    total = sum(len(v) for k, v in book.items() if k not in ALIASES)
    book["_meta"] = {
        "generator": "tools/ingest_voice.py",
        "sources": ["docs/content/voice_library.md", "docs/content/voice_library_2.md"],
        "line_count": total,
        "ingested": per_volume,
    }
    return book


def render(book: dict) -> str:
    return json.dumps(book, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify committed output is current")
    args = parser.parse_args()

    payload = render(build_book())
    if args.check:
        with open(OUT_PATH, "r", encoding="utf-8", newline="") as fh:
            if fh.read() != payload:
                print("voice.json is STALE — re-run tools/ingest_voice.py", file=sys.stderr)
                return 1
        print("voice.json is current.")
        return 0
    with open(OUT_PATH, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(payload)
    meta = build_book()["_meta"]
    print(f"wrote {OUT_PATH}: {meta['line_count']} lines, {meta['ingested']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
