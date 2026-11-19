"""Wallpaper selection and source removal run as the desktop user."""

from contextlib import contextmanager
import hashlib
import io
import json
import os
import random
import stat
import sys
from pathlib import Path

from PIL import Image, ImageOps

MAX_BYTES = 64 * 1024 * 1024
MAX_PIXELS = 48_000_000
MAX_HEADER = 4096
EXTENSIONS = {'.png', '.jpg', '.jpeg', '.webp', '.avif', '.bmp', '.tif', '.tiff', '.gif'}
PNG = b'\x89PNG\r\n\x1a\n'
Image.MAX_IMAGE_PIXELS = MAX_PIXELS


@contextmanager
def folder(home):
    # Resolve one component at a time, refusing symlinks and pinning the
    # directory descriptor even if a component is renamed concurrently.
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    fd = os.open(home, flags)
    try:
        for name in ('Downloads', 'Wallpapers'):
            child = os.open(name, flags, dir_fd=fd)
            os.close(fd)
            fd = child
        yield fd
    finally:
        os.close(fd)


def identity(st):
    return [st.st_dev, st.st_ino, st.st_size, st.st_mtime_ns, st.st_ctime_ns]


def valid_name(name):
    return (isinstance(name, str) and name not in ('', '.', '..') and
            '/' not in name and '\0' not in name and Path(name).suffix.lower() in EXTENSIONS)


def render(fd, name):
    flags = os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW
    with os.fdopen(os.open(name, flags, dir_fd=fd), 'rb') as source:
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
        if identity(os.fstat(source.fileno())) != identity(st):
            raise ValueError('source changed while reading')
        return out.getvalue(), identity(st)


def choose(home, default, previous=None, exclude=None):
    try:
        with folder(home) as fd:
            candidates = [name for name in os.listdir(fd) if valid_name(name) and name != exclude]
            random.SystemRandom().shuffle(candidates)
            fallback = None
            for name in candidates:
                try:
                    png, source_id = render(fd, name)
                except (OSError, ValueError, SyntaxError, Image.DecompressionBombError):
                    continue
                if exclude is not None and png == previous:
                    continue  # Deletion must visibly switch away from the old image.
                result = png, {'name': name, 'identity': source_id}
                if png != previous:
                    return result
                fallback = result
            if fallback is not None:
                return fallback
    except FileNotFoundError:
        pass
    return default.read_bytes(), None


def source_record(value):
    if not isinstance(value, dict) or not valid_name(value.get('name')):
        raise ValueError('invalid wallpaper source')
    fields = value.get('identity')
    if not isinstance(fields, list) or len(fields) != 5 or any(type(n) is not int for n in fields):
        raise ValueError('invalid wallpaper source identity')
    return {'name': value['name'], 'identity': fields}


def read_record(stream):
    line = stream.readline(MAX_HEADER + 1)
    if len(line) > MAX_HEADER or not line.endswith(b'\n'):
        raise ValueError('invalid wallpaper record')
    return json.loads(line)


def write_record(stream, value):
    stream.write(json.dumps(value, ensure_ascii=True).encode('ascii') + b'\n')


def unpack(packet, image, metadata):
    # No image decoder or home-path access as root. Only split the bounded
    # packet emitted by the desktop user into two trusted staging paths.
    with packet.open('rb') as stream:
        record = read_record(stream)
        png = stream.read(MAX_BYTES + 1)
    if len(png) > MAX_BYTES or not png.startswith(PNG):
        raise ValueError('invalid wallpaper output')
    image.write_bytes(png)
    with metadata.open('wb') as stream:
        if record is not None:
            write_record(stream, source_record(record) | {'image_sha256': digest(png)})


def digest(png):
    return hashlib.sha256(png).hexdigest()


def require_current(image, record_path):
    with record_path.open('rb') as stream:
        record = read_record(stream)
    source_record(record)
    if record.get('image_sha256') != digest(image.read_bytes()):
        raise ValueError('wallpaper selection changed; select again before deleting')


def check_source(home, record, delete=False):
    record = source_record(record)
    name = record['name']
    with folder(home) as fd:
        st = os.stat(name, dir_fd=fd, follow_symlinks=False)
        if not stat.S_ISREG(st.st_mode) or identity(st) != record['identity']:
            raise ValueError('wallpaper source missing or changed; not deleting')
        if delete:
            os.unlink(name, dir_fd=fd)


def main(operation, *args):
    if operation == 'unpack':
        unpack(*map(Path, args))
    elif operation == 'require-current':
        require_current(*map(Path, args))
    else:
        if os.geteuid() == 0:
            raise ValueError('source operations must run as the desktop user')
        if operation == 'pick':
            home, default, current = map(Path, args[:3])
            deleting = args[3] == 'delete'
            exclude = None
            if deleting:
                record = source_record(read_record(sys.stdin.buffer))
                check_source(home, record)
                exclude = record['name']
            try:
                previous = current.read_bytes()
            except FileNotFoundError:
                previous = None
            png, record = choose(home, default, previous, exclude)
            write_record(sys.stdout.buffer, record)
            sys.stdout.buffer.write(png)
        elif operation == 'unlink':
            check_source(Path(args[0]), read_record(sys.stdin.buffer), delete=True)
        else:
            raise ValueError('unknown wallpaper operation')


if __name__ == '__main__':
    try:
        main(*sys.argv[1:])
    except (OSError, ValueError):
        # Do not log private filenames or pass exceptions through sudo's UI.
        raise SystemExit('Wallpaper source or state unavailable; see desktop configuration.')
