"""Resolve the Surface's external Sunshine display from Niri, at startup."""

import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

EXTERNAL = ("Ugreen Group Ltd.", "SAMZHE", "0x20200210")
OUTPUT_NAME = re.compile(r"[A-Za-z0-9-]+")


def select(outputs):
    active = {
        name: info for name, info in outputs.items()
        if OUTPUT_NAME.fullmatch(name) and info.get("current_mode") is not None
    }
    matches = [
        name for name, info in active.items()
        if tuple((info.get(key) or "").strip() for key in ("make", "model", "serial")) == EXTERNAL
    ]
    return (matches[0] if len(matches) == 1 else None, "eDP-1" if "eDP-1" in active else None)


def wait_for_output(niri, timeout=5):
    deadline = time.monotonic() + timeout
    while True:
        preferred, fallback = None, None
        try:
            outputs = subprocess.check_output(
                [niri, "msg", "--json", "outputs"], stderr=subprocess.DEVNULL,
                timeout=1, text=True,
            )
            preferred, fallback = select(json.loads(outputs))
        except (subprocess.SubprocessError, json.JSONDecodeError):
            pass
        if preferred:
            return preferred
        if time.monotonic() >= deadline:
            return fallback
        time.sleep(0.25)


def main(niri, base_config, sunshine):
    output = wait_for_output(niri)
    if output is None:
        sys.exit("Sunshine: no matching external display or active eDP-1")
    runtime = Path(os.environ["RUNTIME_DIRECTORY"])
    with tempfile.NamedTemporaryFile(mode="w", dir=runtime, delete=False) as f:
        f.write(Path(base_config).read_text().rstrip() + f"\noutput_name = {output}\n")
    config = runtime / "sunshine.conf"
    os.replace(f.name, config)
    print(f"Sunshine selected Niri output {output}", flush=True)
    os.execv(sunshine, [sunshine, str(config)])


if __name__ == "__main__":
    main(*sys.argv[1:])
