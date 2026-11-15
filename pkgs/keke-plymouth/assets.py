"""Generate small deterministic Plymouth UI assets; no downloaded theme data."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw

out = Path(sys.argv[1])
# Same tracked mountain image as desktop/locker, with a calm Mocha veil.
background = Image.open(out / "background.png").convert("RGBA")
background = Image.alpha_composite(
    background, Image.new("RGBA", background.size, (30, 30, 46, 80))
)
background.convert("RGB").save(out / "background.png")
logo = Image.open(out / "logo.png").convert("RGBA")
tint = Image.new("RGBA", logo.size, "#cba6f7")
tint.putalpha(logo.getchannel("A"))
tint.save(out / "logo.png")
for name, size, color, radius in [
    ("entry", (360, 48), "#313244", 10),
    ("bullet", (8, 8), "#cdd6f4", 4),
]:
    image = Image.new("RGBA", size)
    ImageDraw.Draw(image).rounded_rectangle(
        (0, 0, size[0] - 1, size[1] - 1), radius, fill=color
    )
    image.save(out / f"{name}.png")

# 36 frames, 10 degrees per frame: a muted ring with a rotating lavender arc.
# Supersampling makes the small loading ring smooth without a large asset set.
for frame in range(36):
    image = Image.new("RGBA", (256, 256))
    draw = ImageDraw.Draw(image)
    draw.ellipse((24, 24, 232, 232), outline="#45475a", width=12)
    draw.arc((24, 24, 232, 232), frame * 10 - 90, frame * 10 + 5, fill="#cba6f7", width=12)
    image.resize((64, 64), Image.Resampling.LANCZOS).save(out / f"spinner-{frame}.png")
