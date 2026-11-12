"""Merge non-secret policy without replacing an instance's WebUI credentials."""
import configparser
import json
import os
from pathlib import Path
import sys
import tempfile


def apply(policy_path, config_path, download_path):
    target = Path(config_path)
    config = configparser.RawConfigParser(strict=False, delimiters=("=",))
    config.optionxform = str
    if target.exists():
        config.read(target, encoding="utf-8")
    for section, values in json.loads(Path(policy_path).read_text()).items():
        if not config.has_section(section):
            config.add_section(section)
        for key, value in values.items():
            config.set(section, key, value)
    Path(download_path).mkdir(parents=True, exist_ok=True)
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(dir=target.parent, prefix=".policy-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            config.write(stream, space_around_delimiters=False)
        os.replace(name, target)
    finally:
        if os.path.exists(name):
            os.unlink(name)


if __name__ == "__main__":
    apply(*sys.argv[1:])
