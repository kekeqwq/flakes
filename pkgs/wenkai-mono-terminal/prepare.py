"""Expose genuine Medium outlines as a regular fallback, without changing Latin.

Ghostty's font-style applies to every configured family. A separate family lets
its regular CJK fallback use Medium while MonoLisa keeps its regular/bold faces.
No outlines, metrics, hinting, character coverage or license records are changed.
"""

import sys

from fontTools.ttLib import TTFont

source, destination = sys.argv[1:]
family = "Keke CJK Terminal Medium"
with TTFont(source, recalcTimestamp=False, recalcBBoxes=False) as font:
    # Preserve copyright/license/version records; avoid upstream reserved names
    # in the derivative family. Rename every localization, not just English.
    version = font["name"].getDebugName(5)
    names = {
        1: family,
        2: "Regular",
        3: f"{family};{version}",
        4: family,
        6: "KekeCJKTerminalMedium-Regular",
        16: family,
        17: "Regular",
        18: family,
        21: family,
        22: "Regular",
    }
    for record in font["name"].names:
        if record.nameID in names:
            record.string = names[record.nameID].encode(record.getEncoding())
    # Regular is the *terminal slot*, not an alteration of the Medium outlines.
    font["OS/2"].usWeightClass = 400
    font["OS/2"].fsSelection = (font["OS/2"].fsSelection & ~0x21) | 0x40
    font["head"].macStyle &= ~3
    font.save(destination)

with TTFont(source) as original, TTFont(destination) as prepared:
    assert prepared["name"].getDebugName(1) == family
    assert prepared["name"].getDebugName(2) == "Regular"
    assert prepared["OS/2"].usWeightClass == 400
    assert prepared["head"].modified == original["head"].modified
    assert prepared.getBestCmap() == original.getBestCmap()
    assert prepared["hmtx"].metrics == original["hmtx"].metrics
    # Compare the complete outline/hinting table, not just a sample character.
    assert prepared.getTableData("glyf") == original.getTableData("glyf")
    for name_id in (0, 13, 14):
        assert prepared["name"].getDebugName(name_id) == original["name"].getDebugName(name_id)
print("WenKai Medium: dedicated family; original outlines, hinting, metrics, coverage and license preserved: PASS")
