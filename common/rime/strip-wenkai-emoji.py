"""Drop symbol/emoji codepoints from LXGW WenKai so Apple Color Emoji can render them."""

from __future__ import annotations

import sys
from fontTools.ttLib import TTFont


def drop(cp: int) -> bool:
    if 0x1F000 <= cp <= 0x1FAFF:
        return True
    if 0x2600 <= cp <= 0x27BF:
        return True
    if 0x2B00 <= cp <= 0x2BFF:
        return True
    if 0x2300 <= cp <= 0x23FF:
        return True
    return cp in {
        0x00A9,
        0x00AE,
        0x203C,
        0x2049,
        0x2122,
        0x2139,
        0x2194,
        0x2195,
        0x2196,
        0x2197,
        0x2198,
        0x2199,
        0x21A9,
        0x21AA,
        0x24C2,
        0x2934,
        0x2935,
        0x3030,
        0x303D,
        0x3297,
        0x3299,
        0xFE0E,
        0xFE0F,
    }


def rename(text: str) -> str:
    return (
        text.replace("LXGW WenKai", "LXGW WenKai IME")
        .replace("LXGWWenKai", "LXGWWenKaiIME")
        .replace("霞鹜文楷", "霞鹜文楷输入法")
        .replace("霞鶩文楷", "霞鶩文楷輸入法")
    )


src, dst = sys.argv[1], sys.argv[2]
font = TTFont(src)
for table in font["cmap"].tables:
    table.cmap = {cp: glyph for cp, glyph in table.cmap.items() if not drop(cp)}
for record in font["name"].names:
    record.string = rename(record.toUnicode())
font.save(dst)
