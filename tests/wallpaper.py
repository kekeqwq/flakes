"""Isolated wallpaper selection regression, without a session or activation."""
import io
import runpy
import sys
import tempfile
from pathlib import Path

from PIL import Image

select = runpy.run_path(sys.argv[1])['select']


def color(data):
    with Image.open(io.BytesIO(data)) as img:
        assert img.format == 'PNG'
        return img.getpixel((0, 0))


with tempfile.TemporaryDirectory() as directory:
    home = Path(directory)
    source = home / 'Downloads/Wallpapers'
    default = home / 'default.png'
    Image.new('RGB', (4, 4), 'green').save(default)
    assert select(home, default) == default.read_bytes()
    source.mkdir(parents=True)
    (source / 'bad.png').write_bytes(b'not an image')
    (source / 'pipe.png').symlink_to('/dev/random')
    good = source / 'a photo.JPG'
    Image.new('RGB', (4, 4), 'red').save(good)
    first = select(home, default)
    assert color(first)[0] > 200
    assert select(home, default, first) == first
    new = source / 'after switch.png'
    Image.new('RGBA', (4, 4), 'blue').save(new)
    assert color(select(home, default, first)) == (0, 0, 255)
    good.unlink()
    new.unlink()
    assert select(home, default, first) == default.read_bytes()
print('Wallpapers: live scan, decode, non-repeat and fallback passed')
