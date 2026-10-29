#!/usr/bin/env python3
"""Builds the static brand fonts bundled in Rumi/Fonts from the Google Fonts variable sources.

Usage:
  curl -sSLf -o /tmp/inter.ttf "https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf"
  curl -sSLf -o /tmp/fraunces.ttf "https://github.com/google/fonts/raw/main/ofl/fraunces/Fraunces%5BSOFT,WONK,opsz,wght%5D.ttf"
  python3 scripts/build_fonts.py /tmp/inter.ttf /tmp/fraunces.ttf

Each output font gets the PostScript name used by Theme.swift (Inter-Regular, Inter-Medium,
Fraunces-SemiBold), so Font.custom(...) resolves it.
"""
import os
import sys

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

OUT = os.path.join(os.path.dirname(__file__), "..", "Rumi", "Fonts")

INSTANCES = [
    # (source index, family, style, postscript name, axis locations)
    (0, "Inter", "Regular", "Inter-Regular", {"opsz": 14, "wght": 400}),
    (0, "Inter", "Medium", "Inter-Medium", {"opsz": 14, "wght": 500}),
    (1, "Fraunces", "SemiBold", "Fraunces-SemiBold", {"opsz": 48, "wght": 600, "SOFT": 0, "WONK": 0}),
]


def set_names(font, family, style, ps_name):
    name = font["name"]
    full = f"{family} {style}"
    for rec in list(name.names):
        if rec.nameID in (1, 2, 3, 4, 6, 16, 17, 25):
            name.removeNames(nameID=rec.nameID)
    if style in ("Regular",):
        name.setName(family, 1, 3, 1, 0x409)
        name.setName(style, 2, 3, 1, 0x409)
    else:
        name.setName(f"{family} {style}", 1, 3, 1, 0x409)
        name.setName("Regular", 2, 3, 1, 0x409)
        name.setName(family, 16, 3, 1, 0x409)
        name.setName(style, 17, 3, 1, 0x409)
    name.setName(f"{ps_name};rumi", 3, 3, 1, 0x409)
    name.setName(full, 4, 3, 1, 0x409)
    name.setName(ps_name, 6, 3, 1, 0x409)


def main(sources):
    os.makedirs(OUT, exist_ok=True)
    for idx, family, style, ps, loc in INSTANCES:
        font = TTFont(sources[idx])
        static = instancer.instantiateVariableFont(font, loc)
        for table in ("STAT",):
            if table in static:
                del static[table]
        set_names(static, family, style, ps)
        path = os.path.join(OUT, f"{ps}.ttf")
        static.save(path)
        print("wrote", os.path.normpath(path))


if __name__ == "__main__":
    main(sys.argv[1:3])
