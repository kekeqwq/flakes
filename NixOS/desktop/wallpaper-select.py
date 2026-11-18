"""Choose one image as the desktop user; emit only a normalized PNG."""

import io
import os
import random
import stat
import sys
from pathlib import Path

from PIL import Image, ImageOps

MAX_BYTES = 64 * 1024 * 1024
MAX_PIXELS = 48_000_000
EXTENSIONS = {'.png', '.jpg', '.jpeg', '.webp', '.avif', '.bmp', '.tif', '.tiff', '.gif'}
Image.MAX_IMAGE_PIXELS = MAX_PIXELS


def render(path):
    flags = os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW
    with os.fdopen(os.open(path, flags), 'rb') as source:
        st = os.fstat(source.fileno())
        if not stat.S_ISREG(st.st_mode) or st.st_size > MAX_BYTES:
            raise ValueError('not a bounded regular image file')
        with Image.open(source) as image:
            if image.width * image.height > MAX_PIXELS:
                raise ValueError('image too large')
            image = ImageOps.exif_transpose(image)
            image.thumbnail((2560, 2560))
            rgb = image.convert('RGB')
            rgb.info.clear()
            out = io.BytesIO()
            rgb.save(out, format='PNG', compress_level=3)
            return out.getvalue()


def select(home, default, previous=None):
    try:
        candidates = [p for p in (home / 'Downloads/Wallpapers').iterdir() if p.suffix.lower() in EXTENSIONS]
    except OSError:
        candidates = []
    random.SystemRandom().shuffle(candidates)
    matched = False
    for path in candidates:
        try:
            png = render(path)
        except (OSError, ValueError, SyntaxError, Image.DecompressionBombError):
            continue
        if png != previous:
            return png
        matched = True
    return previous if matched else default.read_bytes()


if __name__ == '__main__':
    if os.geteuid() == 0:
        raise SystemExit('wallpaper helper must run as the desktop user')
    home, default, current = map(Path, sys.argv[1:])
    try:
        with current.open('rb') as source:
            previous = source.read(MAX_BYTES)
    except OSError:
        previous = None
    sys.stdout.buffer.write(select(home, default, previous))
