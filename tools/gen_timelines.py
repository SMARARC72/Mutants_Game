#!/usr/bin/env python3
"""Generate Dialogic 2 timelines from the authored scene scripts (Batch E1a).

Parses the `[Dialogic]` blocks of docs/content/scripts_mvp.md (8 scenes) and
docs/content/scripts_acts2to5.md (10 scenes) and emits:
  * client/presentation/dialogue/generated/<scene_id>.dtl — one per scene, ids
    mvp_s<NN>_<slug> / acts_s<NN>_<slug>, Dialogic 2 syntax: `speaker: line`
    text events, `- choice` branches carrying `[signal arg="choice:<tag>"]`
    (the wired old_garran convention), branch blocks nested under their options;
  * client/presentation/dialogue/characters/generated/<key>.dch — stubs for NEW
    speakers (existing characters are reused where names match), display names
    per the canon cast, identity colour hashed from the name into the six-force
    GrimoirePalette ring (the OverworldTokens name-hash convention);
  * registration of every generated timeline/character in client/project.godot
    [dialogic] dtl_directory / dch_directory (sorted merge, existing kept).

DIALOGUE IS VERBATIM. Non-dialogue markup (toast/stage directives `*(...)`,
`>> GATE/CONSEQUENCE` mechanics, `→ goes to` routing, `[Ink →]` knots,
`{flag}`-guarded conditional variants) is skipped and COUNTED — the per-scene
skip census lands in tools/INGEST_NOTES.md between this tool's markers.

Deterministic: re-runs over unchanged sources are byte-identical.

Run:  python -B tools/gen_timelines.py
      python -B tools/gen_timelines.py --check
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = [
    ("mvp", os.path.join(ROOT, "docs", "content", "scripts_mvp.md")),
    ("acts", os.path.join(ROOT, "docs", "content", "scripts_acts2to5.md")),
]
DTL_DIR = os.path.join(ROOT, "client", "presentation", "dialogue", "generated")
DCH_DIR = os.path.join(
    ROOT, "client", "presentation", "dialogue", "characters", "generated"
)
PROJECT_GODOT = os.path.join(ROOT, "client", "project.godot")
NOTES_PATH = os.path.join(ROOT, "tools", "INGEST_NOTES.md")
NOTES_BEGIN = "<!-- BEGIN gen_timelines.py (generated skip-lists — do not edit) -->"
NOTES_END = "<!-- END gen_timelines.py -->"

# Existing .dch characters reused where the scripts' speakers match (project.godot
# dch_directory keys). Everything else gets a generated stub.
EXISTING_SPEAKERS = {
    "MADDOX": "old_maddox",
    "KESTREL": "mother_kestrel",
    "VEIL": "veil",
    "VAEL": "vael",
    "THESSALY": "thessaly_vance",
    "SEVVY": "matron_sevvy",
    "ONA": "hearthward_ona",
}

# NEW speakers -> canonical display names (factions_npcs.md / regional_cast.md /
# the scripts' own cast notes, leader names per _NAME_RECONCILIATION.md).
NEW_SPEAKERS = {
    "SAOIRSE": "Greenmother Saoirse Lateharvest",
    "TOVAL": "Mendwright Toval Greenmercy",
    "FENWYNN": "Sister Fenwynn",
    "HOB": "Hob Thornsoft",
    "SALLOW": "Gravekeeper Sallow Munt",
    "BRAM": "Huntmaster Bram Stoneblood",
    "YULA": "Tame-Mother Yula Stillhand",
    "POMP": "Pomp Castellan",
    "DOSS": "Marker-Keeper Doss Halloway",
    "LULL": "Spore-Speaker Lull",
    "SEVERIN": "Lord Severin Ash",
    "AURELIAN": "Magister Aurelian Vox",
    "VESH": "Doctor Vesh Quillon",
    "CASTOR": "Foreman Castor Brail",
    "CROUPIER": "The Croupier",
    "EROS": "Eros",
    "THANATOS": "Thanatos",
    "THE OLYMPIAN": "The Olympian",
    "THE GODLING": "The Godling",
    "THE PRIMORDIAL": "The Primordial",
    "THE THRONE": "The Throne",
    "THE DEAD GOD": "The Dead God",
    "THE CLIMBER": "The Climber",
    "THE GAME": "The Game",
    "PLAYER": "Player",
}

# The six-force identity ring (GrimoirePalette hexes); a speaker's colour is
# hashed from its display name — the OverworldTokens per-name convention.
FORCE_RING = ["4f5d3a", "6fb8d6", "e8d8a0", "d6248c", "e0658c", "8a5fb0"]

DCH_TEMPLATE = """{{
"@path": "res://addons/dialogic/Resources/character.gd",
"@subpath": NodePath(""),
&"_translation_id": "",
&"color": Color({r}, {g}, {b}, 1),
&"custom_info": {{}},
&"default_portrait": "",
&"description": "{description}",
&"display_name": "{display_name}",
&"mirror": false,
&"nicknames": [],
&"offset": Vector2(0, 0),
&"portraits": {{}},
&"scale": 1.0
}}"""

_SCENE_RE = re.compile(r"^# SCENE (\d+) — \"([^\"]+)\"")
_BLOCK_RE = re.compile(r"^## `\[Dialogic\]` — (.+?)\.\s*(.*)$")
_INK_RE = re.compile(r"^## `\[Ink")
_SPEAKER_RE = re.compile(
    r"^(?P<sp>[A-Z][A-Z'\-]*(?: [A-Z][A-Z'\-]*)*)\s*"
    r"(?:\*\([^)]*\)\*\s*:|\*\([^)]*\):\*|:)\s*(?P<text>.+)$"
)
_CHOICE_RE = re.compile(r"^>> CHOICE(?: — (.*))?$")
_OPTION_TEXT_RE = re.compile(r"^- \*\*\"(.+?)\"\*\*")
_BRANCH_LABEL_RE = re.compile(r"\*\((?:Branch:\s*)?([^)]*)\)\*")
_ROUTER_RE = re.compile(r"^- (?:highest|Champion) = (.+?) → \*\*([^*]+)\*\*")
_DASH_SPEAKER_RE = re.compile(r"^\s*- ([A-Z][A-Z' ]+?) \(([^)]*)\): (.+)$")
_TARGET_RE = re.compile(r"goes to \*\*([^*]+)\*\*")
_FLAG_RE = re.compile(r"[Ff]lags `([a-z0-9_]+)`")
# An in-continuation authored reply ("→ VEIL: …", "…. SEVERIN: \"…\"") — only
# KNOWN speaker tokens qualify, so gate markup (`**>> GATE:**`) never matches.
_INLINE_SPEAKER_RE = re.compile(
    r"\b(?P<sp>[A-Z][A-Z'\-]*(?: [A-Z][A-Z'\-]*)*)\s*:\s(?P<text>.+)$"
)
_SPEAKER_TOKENS = set(EXISTING_SPEAKERS) | set(NEW_SPEAKERS) | {"NARRATION"}


def slug(text: str, cap: int = 40) -> str:
    text = text.strip().lower()
    text = re.sub(r"[''`]", "", text)
    text = re.sub(r"[^a-z0-9]+", "_", text).strip("_")
    if len(text) > cap:
        cut_mid_word = text[cap] != "_"
        text = text[:cap].rstrip("_")
        if cut_mid_word and "_" in text:
            text = text.rsplit("_", 1)[0]
    return text


def speaker_key(token: str, census: dict) -> str:
    if token in EXISTING_SPEAKERS:
        return EXISTING_SPEAKERS[token]
    if token in NEW_SPEAKERS:
        return slug(token)
    census.setdefault("unmapped_speakers", set()).add(token)
    return slug(token)


def escape_plain(text: str) -> str:
    """A speaker-less text event: escape ':' so Dialogic never mistakes leading
    prose for a character name."""
    return text.replace(":", "\\:")


class Option:
    def __init__(self, text: str, tag: str):
        self.text = text
        self.tag = tag
        self.responses: list[tuple[str, str]] = []  # (speaker_token|"", text)
        self.target: str = ""


class Choice:
    def __init__(self, label: str):
        self.label = label
        self.options: list[Option] = []


class Block:
    def __init__(self, raw_id: str, title: str):
        self.raw_id = raw_id
        self.aliases = [p.strip().rstrip(".") for p in raw_id.split("/")]
        self.title = re.sub(r"\s*\*\([^)]*\)\*\s*$", "", title).strip()
        self.items: list = []  # ("line", speaker_token|"", text) | Choice
        self.nested = False


def parse_scenes(text: str) -> list[dict]:
    scenes: list[dict] = []
    lines = text.split("\n")
    i, n = 0, len(lines)
    scene = None
    block = None
    skipping_ink = False
    census = {"directives": 0, "conditionals": 0, "unparsed": 0}

    def close_scene():
        nonlocal scene, block, census
        if scene is not None:
            scene["census"] = census
            scenes.append(scene)
        scene, block = None, None
        census = {"directives": 0, "conditionals": 0, "unparsed": 0}

    while i < n:
        line = lines[i]
        m = _SCENE_RE.match(line)
        if m:
            close_scene()
            scene = {
                "num": int(m.group(1)),
                "title": m.group(2),
                "blocks": [],
                "routers": [],
            }
            skipping_ink = False
            i += 1
            continue
        if scene is None:
            i += 1
            continue
        if _INK_RE.match(line):
            skipping_ink = True
            block = None
            i += 1
            continue
        bm = _BLOCK_RE.match(line)
        if bm:
            skipping_ink = False
            block = Block(bm.group(1), bm.group(2))
            scene["blocks"].append(block)
            i += 1
            continue
        if line.startswith("#"):
            # a non-[Dialogic] heading (canon-fit summaries, notes) ends the block
            block = None
            skipping_ink = False
            i += 1
            continue
        if skipping_ink or block is None:
            i += 1
            continue
        stripped = line.strip()
        if stripped == "" or stripped == "---":
            i += 1
            continue
        cm = _CHOICE_RE.match(stripped)
        if cm:
            choice = Choice(cm.group(1) or "")
            block.items.append(choice)
            i += 1
            i = parse_options(lines, i, choice, census)
            continue
        rm = _ROUTER_RE.match(stripped)
        if rm:
            router = Choice("router")
            block.items.append(router)
            while i < n:
                rm2 = _ROUTER_RE.match(lines[i].strip())
                if not rm2:
                    break
                opt = Option("", slug(rm2.group(2)))
                opt.target = rm2.group(2).strip().rstrip(".")
                opt.text = rm2.group(1).strip()  # replaced by block title later
                router.options.append(opt)
                i += 1
            continue
        dm = _DASH_SPEAKER_RE.match(line)
        if dm:
            text_part = re.split(r"\s\*\*>>", dm.group(3))[0].strip()
            block.items.append(("line", dm.group(1).strip(), text_part))
            i += 1
            continue
        if stripped.startswith("{"):
            census["conditionals"] += 1
            i += 1
            continue
        if stripped.startswith("*(") or stripped.startswith("→") or stripped.startswith(
            "**>>"
        ):
            census["directives"] += 1
            i += 1
            continue
        sm = _SPEAKER_RE.match(stripped)
        if sm:
            token = sm.group("sp").strip()
            text_part = sm.group("text").strip()
            if token == "NARRATION":
                block.items.append(("line", "", text_part))
            else:
                block.items.append(("line", token, text_part))
            i += 1
            continue
        census["unparsed"] += 1
        i += 1
    close_scene()
    return scenes


def parse_options(lines: list[str], i: int, choice: Choice, census: dict) -> int:
    """Consume the `- **"..."**` options (+ indented continuations) of a choice."""
    n = len(lines)
    option = None
    while i < n:
        line = lines[i]
        stripped = line.strip()
        if stripped == "":
            # options are consecutive; a blank line closes the choice unless the
            # next non-blank line is another option
            j = i + 1
            while j < n and lines[j].strip() == "":
                j += 1
            if j < n and lines[j].strip().startswith("- **\""):
                i = j
                continue
            return i + 1
        if stripped.startswith("- "):
            tm = _OPTION_TEXT_RE.match(stripped)
            if tm:
                option = Option(tm.group(1), "")
                lm = _BRANCH_LABEL_RE.search(stripped[tm.end() :])
                option.label = lm.group(1) if lm else ""
                choice.options.append(option)
                consume_option_meta(stripped, option)
            else:
                census["directives"] += 1  # a non-dialogue bullet inside a choice
                option = None
            i += 1
            continue
        if line.startswith((" ", "\t")) or stripped.startswith("→"):
            if option is not None:
                consume_option_meta(stripped, option)
            else:
                census["directives"] += 1
            i += 1
            continue
        return i
    return i


def consume_option_meta(text: str, option: Option) -> None:
    if not option.target:
        tm = _TARGET_RE.search(text)
        if tm:
            option.target = tm.group(1).strip().rstrip(".")
    if not option.tag:
        fm = _FLAG_RE.search(text)
        if fm:
            option.tag = fm.group(1)
    for am in _INLINE_SPEAKER_RE.finditer(text):
        token = am.group("sp").strip()
        if token not in _SPEAKER_TOKENS:
            continue
        resp = am.group("text").strip()
        resp = resp.split(" → ")[0]
        resp = re.split(r"\s\*\*>>", resp)[0].strip()
        if resp:
            option.responses.append(("" if token == "NARRATION" else token, resp))
        break


def finalize_tags(choice: Choice) -> None:
    seen: dict = {}
    for idx, opt in enumerate(choice.options):
        tag = opt.tag or slug(getattr(opt, "label", "") or "", 32) or "option"
        base = tag
        if base in seen:
            seen[base] += 1
            tag = "%s_%d" % (base, seen[base])
        else:
            seen[base] = 1
        opt.tag = tag


def render_scene(scene: dict, source_name: str, scene_id: str, census: dict) -> str:
    blocks: list[Block] = scene["blocks"]
    by_alias: dict = {}
    for b in blocks:
        for a in b.aliases:
            by_alias[a] = b
    # count target references: a block targeted exactly once nests under its
    # option; 2+ refs = an authored convergent finish, kept top-level.
    refs: dict = {}
    for b in blocks:
        for item in b.items:
            if isinstance(item, Choice):
                finalize_tags(item)
                for opt in item.options:
                    tgt = by_alias.get(opt.target)
                    if tgt is not None and tgt is not b:
                        refs[id(tgt)] = refs.get(id(tgt), 0) + 1
    out: list[str] = []
    out.append(
        "# GENERATED by tools/gen_timelines.py from docs/content/scripts_%s.md"
        % ("mvp" if source_name == "mvp" else "acts2to5")
    )
    out.append(
        "# (SCENE %d — \"%s\") — edit the source, re-run the tool. Dialogue is"
        % (scene["num"], scene["title"])
    )
    out.append(
        "# verbatim; engine-routed forks are choices tagged choice:<block> "
        "(see tools/INGEST_NOTES.md)."
    )

    rendered: set = set()

    def render_block(b: Block, indent: int) -> None:
        if id(b) in rendered:
            return
        rendered.add(id(b))
        pad = "\t" * indent
        for item in b.items:
            if isinstance(item, Choice):
                for opt in item.options:
                    tgt = by_alias.get(opt.target)
                    text = opt.text
                    if item.label == "router" and tgt is not None:
                        text = tgt.title or opt.text
                    out.append("%s- %s" % (pad, text))
                    out.append('%s\t[signal arg="choice:%s"]' % (pad, opt.tag))
                    for token, resp in opt.responses:
                        out.append(
                            "%s\t%s" % (pad, format_line(token, resp, census))
                        )
                    if (
                        tgt is not None
                        and tgt is not b
                        and refs.get(id(tgt), 0) == 1
                        and id(tgt) not in rendered
                    ):
                        render_block(tgt, indent + 1)
            else:
                _, token, text = item
                out.append("%s%s" % (pad, format_line(token, text, census)))

    for b in blocks:
        if id(b) not in rendered and not (refs.get(id(b), 0) == 1):
            render_block(b, 0)
    # any once-referenced block whose option never rendered (forward-order guard)
    for b in blocks:
        if id(b) not in rendered:
            render_block(b, 0)
    return "\n".join(out) + "\n"


def format_line(token: str, text: str, census: dict) -> str:
    if token == "":
        return escape_plain(text)
    return "%s: %s" % (speaker_key(token, census), text)


def color_for(name: str) -> tuple[float, float, float]:
    hexcode = FORCE_RING[zlib.crc32(name.encode("utf-8")) % len(FORCE_RING)]
    return tuple(
        round(int(hexcode[k : k + 2], 16) / 255.0, 6) for k in (0, 2, 4)
    )


def dch_text(display_name: str) -> str:
    r, g, b = color_for(display_name)
    description = (
        "GENERATED by tools/gen_timelines.py from docs/content/scripts_mvp.md + "
        "scripts_acts2to5.md — edit the source, re-run the tool."
    )
    return DCH_TEMPLATE.format(
        r=r, g=g, b=b, description=description, display_name=display_name
    )


def register_in_project(dtl_ids: list[str], dch_keys: list[str]) -> None:
    with open(PROJECT_GODOT, "r", encoding="utf-8") as fh:
        text = fh.read()
    for kind, keys, path_fmt in (
        ("dch", dch_keys, "res://presentation/dialogue/characters/generated/%s.dch"),
        ("dtl", dtl_ids, "res://presentation/dialogue/generated/%s.dtl"),
    ):
        pattern = re.compile(
            r"directories/%s_directory=\{(.*?)\}" % kind, re.DOTALL
        )
        m = pattern.search(text)
        if not m:
            raise SystemExit("project.godot: missing %s_directory" % kind)
        entries: dict = {}
        for em in re.finditer(r'"([^"]+)": "([^"]+)"', m.group(1)):
            if "/generated/" not in em.group(2):
                entries[em.group(1)] = em.group(2)
        for key in keys:
            entries[key] = path_fmt % key
        body = ",\n".join(
            '"%s": "%s"' % (k, entries[k]) for k in sorted(entries)
        )
        replacement = "directories/%s_directory={\n%s\n}" % (kind, body)
        text = text[: m.start()] + replacement + text[m.end() :]
    with open(PROJECT_GODOT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


def notes_section(scene_rows: list[str], unmapped: set) -> str:
    out = [NOTES_BEGIN, ""]
    out.append(
        "**Per-scene skip census** (directives = toast/stage/`>> GATE` markup; "
        "conditionals = `{flag}`-guarded save-reactive variant lines, left to the "
        "Dialogic VAR-bridge wave; unparsed = other non-dialogue lines):"
    )
    out.append("")
    out.append("| scene | directives | conditionals | unparsed |")
    out.append("|---|---|---|---|")
    out.extend(scene_rows)
    out.append("")
    out.append(
        "**Unmapped speakers (auto title-cased .dch stubs):** "
        + (", ".join(sorted(unmapped)) if unmapped else "(none)")
    )
    out.append("")
    out.append(NOTES_END)
    return "\n".join(out)


def splice_notes(section: str) -> None:
    with open(NOTES_PATH, "r", encoding="utf-8") as fh:
        text = fh.read()
    begin = text.find(NOTES_BEGIN)
    end = text.find(NOTES_END)
    if begin < 0 or end < 0:
        raise SystemExit("INGEST_NOTES.md is missing the gen_timelines.py markers")
    with open(NOTES_PATH, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text[:begin] + section + text[end + len(NOTES_END) :])


def build() -> tuple[dict, dict, list[str], set]:
    timelines: dict = {}
    scene_rows: list[str] = []
    census_global: dict = {}
    for source_name, path in SOURCES:
        with open(path, "r", encoding="utf-8") as fh:
            scenes = parse_scenes(fh.read())
        for scene in scenes:
            scene_id = "%s_s%02d_%s" % (source_name, scene["num"], slug(scene["title"], 30))
            body = render_scene(scene, source_name, scene_id, census_global)
            timelines[scene_id] = body
            c = scene["census"]
            scene_rows.append(
                "| %s | %d | %d | %d |"
                % (scene_id, c["directives"], c["conditionals"], c["unparsed"])
            )
    used_new: dict = {}
    for body in timelines.values():
        for key in re.findall(r"^\t*([a-z0-9_]+): ", body, re.MULTILINE):
            if key in EXISTING_SPEAKERS.values():
                continue
            display = ""
            for token, name in NEW_SPEAKERS.items():
                if slug(token) == key:
                    display = name
                    break
            if not display:
                display = key.replace("_", " ").title()
            used_new[key] = display
    unmapped = census_global.get("unmapped_speakers", set())
    return timelines, used_new, scene_rows, unmapped


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    timelines, characters, scene_rows, unmapped = build()
    if args.check:
        stale: list[str] = []
        for scene_id, body in timelines.items():
            path = os.path.join(DTL_DIR, scene_id + ".dtl")
            if not os.path.exists(path):
                stale.append(scene_id)
                continue
            with open(path, "r", encoding="utf-8") as fh:
                if fh.read() != body:
                    stale.append(scene_id)
        if stale:
            print("STALE timelines: %s — re-run tools/gen_timelines.py" % ", ".join(stale))
            return 1
        print("generated timelines are current")
        return 0
    os.makedirs(DTL_DIR, exist_ok=True)
    os.makedirs(DCH_DIR, exist_ok=True)
    for scene_id in sorted(timelines):
        with open(
            os.path.join(DTL_DIR, scene_id + ".dtl"), "w", encoding="utf-8", newline="\n"
        ) as fh:
            fh.write(timelines[scene_id])
    for key in sorted(characters):
        with open(
            os.path.join(DCH_DIR, key + ".dch"), "w", encoding="utf-8", newline="\n"
        ) as fh:
            fh.write(dch_text(characters[key]))
    register_in_project(sorted(timelines), sorted(characters))
    splice_notes(notes_section(scene_rows, unmapped))
    print(
        "wrote %d timelines, %d character stubs; registered in project.godot"
        % (len(timelines), len(characters))
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
