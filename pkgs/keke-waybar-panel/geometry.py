"""Surface-local popup layout; no GTK, global pointer API or host layout."""

MARGIN = 16
TOP = 12 + 40 + 14  # Waybar margin + height + floating gap, in logical pixels.


def placement(width, height, card_width, card_height, pointer_x, section):
    center = width / 2 if section == "clock" else pointer_x
    right = max(MARGIN, width - card_width - MARGIN)
    bottom = max(MARGIN, height - card_height - MARGIN)
    x = min(max(MARGIN, round(center - card_width / 2)), right)
    y = min(TOP, bottom)
    return int(x), int(y)
