"""Isolated wallpaper selection and source checks; no activation or real deletion."""
import io
import runpy
import sys
import tempfile
from pathlib import Path

from PIL import Image

api = runpy.run_path(sys.argv[1])
choose, unpack = api['choose'], api['unpack']
check_source, require_current = api['check_source'], api['require_current']


def fails(call, *args):
    try:
        call(*args)
    except (OSError, ValueError):
        return
    raise AssertionError('unsafe or stale wallpaper source accepted')


with tempfile.TemporaryDirectory() as directory:
    home = Path(directory)
    folder = home / 'Downloads/Wallpapers'
    default = home / 'default.png'
    Image.new('RGB', (4, 4), 'green').save(default)
    assert choose(home, default) == (default.read_bytes(), None)
    folder.mkdir(parents=True)
    (folder / 'bad.png').write_bytes(b'not an image')
    (folder / 'pipe.png').symlink_to('/dev/zero')
    good = folder / 'a photo.JPG'
    Image.new('RGB', (4, 4), 'red').save(good)

    picked, old = choose(home, default)
    assert old['name'] == good.name
    assert choose(home, default, picked)[1] == old
    assert choose(home, default, picked, good.name) == (default.read_bytes(), None)

    new = folder / 'after switch\n(second).png'
    Image.new('RGBA', (4, 4), 'blue').save(new)
    replacement, record = choose(home, default, picked, good.name)
    assert record['name'] == new.name
    assert choose(home, default, picked)[0] == replacement
    with Image.open(io.BytesIO(replacement)) as image:
        assert image.getpixel((0, 0)) == (0, 0, 255)

    packet, image, metadata = (home / name for name in ('packet', 'image', 'metadata'))
    with packet.open('wb') as stream:
        api['write_record'](stream, record)
        stream.write(replacement)
    unpack(packet, image, metadata)
    require_current(image, metadata)
    image.write_bytes(picked)
    fails(require_current, image, metadata)
    fails(check_source, home, old | {'name': '../default.png'})
    fails(check_source, home, old | {'name': 'pipe.png'})
    check_source(home, record, delete=True)
    assert not new.exists()
    assert choose(home, default)[1] == old

    saved = folder / 'saved.jpg'
    good.rename(saved)
    good.write_bytes(saved.read_bytes())
    fails(check_source, home, old, True)
    assert good.is_file() and default.is_file()

    # Restoring the default leaves no source record that could authorize deletion.
    with packet.open('wb') as stream:
        api['write_record'](stream, None)
        stream.write(default.read_bytes())
    unpack(packet, image, metadata)
    assert not metadata.read_bytes()

    # Changes to the folder path itself must not redirect removal.
    _, active = choose(home, default, exclude=saved.name)
    assert active['name'] == good.name
    folder.rename(home / 'moved')
    folder.symlink_to(home / 'moved', target_is_directory=True)
    fails(check_source, home, active, True)
    assert good.is_file() and default.is_file()

print('Wallpapers: fallback, non-repeat, delete rotation, identity and path checks PASS')
