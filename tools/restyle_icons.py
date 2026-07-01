#!/usr/bin/env python3
"""Strip the baked full-canvas backgrounds out of the client/assets/icons SVGs (Wave 4).

The curated game-icons.net SVGs ship with an opaque backdrop as their first element
(e.g. `<path d="M0 0h512v512H0z"/>` or a canvas-sized `<circle>`), which makes every
icon render as a solid black box in-game instead of a glyph on the themed surface.
This script parses each SVG, removes any full-canvas backdrop element(s) that sit as
direct children of the root, and writes the file back.

IDEMPOTENT: a second run finds nothing to remove and leaves every file byte-identical.
Dependency-light: stdlib only (xml.etree). Verifies its own work by re-parsing.

Run:  python -B tools/restyle_icons.py
"""
import os
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIR = os.path.join(ROOT, "client", "assets", "icons")
SVG_NS = "http://www.w3.org/2000/svg"
EPS = 0.5  # geometry tolerance in SVG user units

# "M0 0h512v512H0z"-style full-canvas rectangle path (relative or absolute closing edge).
FULL_RECT_D = re.compile(
    r"^M\s*0[\s,]+0\s*"
    r"[hH]\s*(?P<w>-?[\d.]+)\s*"
    r"[vV]\s*(?P<h>-?[\d.]+)\s*"
    r"[hH]\s*(?P<back>-?[\d.]+)\s*"
    r"[zZ]$"
)


def _viewbox(root):
    """Return (width, height) of the drawing canvas from viewBox (or width/height attrs)."""
    vb = root.get("viewBox")
    if vb:
        parts = [float(p) for p in vb.replace(",", " ").split()]
        if len(parts) == 4:
            return parts[2], parts[3]
    try:
        return float(root.get("width", "0")), float(root.get("height", "0"))
    except ValueError:
        return 0.0, 0.0


def _covers_canvas(el, vb_w, vb_h):
    """True when `el` is a rect/path/circle whose geometry blankets the whole canvas."""
    tag = el.tag.split("}")[-1]
    if tag == "rect":
        x = float(el.get("x", "0"))
        y = float(el.get("y", "0"))
        w = float(el.get("width", "0"))
        h = float(el.get("height", "0"))
        return x <= EPS and y <= EPS and w >= vb_w - EPS and h >= vb_h - EPS
    if tag == "path":
        d = (el.get("d") or "").strip()
        m = FULL_RECT_D.match(d)
        if not m:
            return False
        w, h = abs(float(m.group("w"))), abs(float(m.group("h")))
        return w >= vb_w - EPS and h >= vb_h - EPS
    if tag == "circle":
        cx = float(el.get("cx", "0"))
        cy = float(el.get("cy", "0"))
        r = float(el.get("r", "0"))
        centered = abs(cx - vb_w / 2.0) <= EPS and abs(cy - vb_h / 2.0) <= EPS
        return centered and r >= min(vb_w, vb_h) / 2.0 - EPS
    return False


def _is_backdrop(el, vb_w, vb_h):
    """A backdrop = full-canvas geometry painted as a plain unstroked fill.

    `fill` unset defaults to black in SVG — exactly the audit's "black box". Any solid
    full-canvas fill is a backdrop regardless of colour; stroked full-canvas shapes are
    kept (they are ring artwork, not backgrounds).
    """
    stroke = (el.get("stroke") or "none").strip().lower()
    if stroke not in ("", "none"):
        return False
    fill = (el.get("fill") or "").strip().lower()
    if fill == "none":
        return False
    return _covers_canvas(el, vb_w, vb_h)


def restyle(path):
    """Remove backdrop children from one SVG. Returns the number of elements removed."""
    ET.register_namespace("", SVG_NS)
    tree = ET.parse(path)
    root = tree.getroot()
    vb_w, vb_h = _viewbox(root)
    if vb_w <= 0 or vb_h <= 0:
        return 0
    doomed = [el for el in list(root) if _is_backdrop(el, vb_w, vb_h)]
    for el in doomed:
        root.remove(el)
    if doomed:
        tree.write(path, encoding="unicode", xml_declaration=False)
    return len(doomed)


def verify(path):
    """Re-parse and confirm no full-canvas backdrop remains. Returns True when clean."""
    tree = ET.parse(path)
    root = tree.getroot()
    vb_w, vb_h = _viewbox(root)
    if vb_w <= 0 or vb_h <= 0:
        return True
    return not any(_is_backdrop(el, vb_w, vb_h) for el in list(root))


def main():
    svgs = []
    for dirpath, _dirnames, filenames in os.walk(ICON_DIR):
        svgs.extend(os.path.join(dirpath, f) for f in sorted(filenames) if f.endswith(".svg"))
    if not svgs:
        print("no SVGs found under", ICON_DIR)
        return 1
    removed_total = 0
    for svg in svgs:
        removed = restyle(svg)
        removed_total += removed
        if removed:
            print("stripped %d backdrop(s): %s" % (removed, os.path.relpath(svg, ROOT)))
    dirty = [svg for svg in svgs if not verify(svg)]
    for svg in dirty:
        print("STILL HAS BACKDROP:", os.path.relpath(svg, ROOT))
    print("%d SVGs scanned, %d backdrops removed, %d dirty" % (len(svgs), removed_total, len(dirty)))
    return 1 if dirty else 0


if __name__ == "__main__":
    sys.exit(main())
