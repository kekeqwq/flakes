"""Drive the actual bundled CLI through a PTY, with synthetic terminal replies.

Empty HOME/agent dir, offline, no prompts, credentials, providers or saved session.
No user terminal or OS appearance is changed. Test both renderers, initial DSR,
native appearance switches and missing OSC RGB defaults, not just mocked methods.
"""

import fcntl
import json
import os
from pathlib import Path
import pty
import re
import select
import shutil
import struct
import subprocess
import sys
import tempfile
import termios
import time

binary, themes = sys.argv[1:]
OSC = re.compile(rb"\x1b\](10|11|4;(\d+));\?(?:\x07|\x1b\\)")
QUERY = re.compile(OSC.pattern + rb"|\x1b\[\?996n|\x1b\[(?:0)?c|\x1b\[6n")

for mode in ("fullscreen", "regular"):
    with tempfile.TemporaryDirectory(prefix="pi-theme-cli-") as work:
        home = Path(work)
        agent = home / ".pi/agent"
        (agent / "themes").mkdir(parents=True)
        for flavor in ("latte", "mocha"):
            shutil.copyfile(Path(themes) / f"catppuccin-{flavor}.json", agent / "themes" / f"catppuccin-{flavor}.json")
        (agent / "settings.json").write_text(json.dumps({
            "theme": "catppuccin-latte/catppuccin-mocha", "tuiMode": mode,
            "showHardwareCursor": True,
            "cacheWarming": "off", "enableInstallTelemetry": False,
            "enableAnalytics": False, "defaultProjectTrust": "never",
        }))
        env = {
            "HOME": work, "XDG_CONFIG_HOME": str(home / ".config"),
            "XDG_CACHE_HOME": str(home / ".cache"), "PI_CODING_AGENT_DIR": str(agent),
            "TERM": "xterm-256color", "COLORTERM": "truecolor", "PI_TRUE_COLOR": "1",
            "PI_OFFLINE": "1", "PATH": os.environ["PATH"], "LANG": "en_US.UTF-8",
        }
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))
        process = subprocess.Popen(
            [binary, "--offline", "--no-session", "--no-extensions", "--no-skills", "--no-prompt-templates", "--no-context-files", "--no-tools"],
            stdin=slave, stdout=slave, stderr=slave, cwd=work, env=env, start_new_session=True,
        )
        os.close(slave)
        pending = b""
        output = b""
        appearance = "light"
        drop_defaults = False
        drop_all = False
        dsr_count = 0

        def pump():
            global pending, output, dsr_count
            if not select.select([master], [], [], 0.05)[0]:
                return
            try:
                data = os.read(master, 131072)
            except OSError:
                raise AssertionError(f"{mode}: CLI ended before appearance test: {output[-1000:]!r}")
            assert data, f"{mode}: unexpected EOF"
            output += data
            pending += data
            end = 0
            for match in QUERY.finditer(pending):
                request = match.group()
                end = match.end()
                response = b""
                if request == b"\x1b[?996n":
                    dsr_count += 1
                    response = b"\x1b[?997;2n" if appearance == "light" else b"\x1b[?997;1n"
                elif request.endswith(b"6n"):
                    response = b"\x1b[1;1R"
                elif request.endswith(b"c"):
                    response = b"" if drop_all else b"\x1b[?1;2c"
                else:
                    color = OSC.fullmatch(request)
                    channel = color.group(1)
                    if not drop_all and not (drop_defaults and channel in (b"10", b"11")):
                        rgb = (239, 241, 245) if appearance == "light" else (30, 30, 46)
                        if channel == b"10":
                            rgb = (76, 79, 105) if appearance == "light" else (205, 214, 244)
                        response = b"\x1b]" + channel + b";rgb:" + b"/".join(f"{v * 257:04x}".encode() for v in rgb) + b"\x1b\\"
                if response:
                    os.write(master, response)
            pending = pending[end:][-512:]

        def wait_for_border(start):
            color = b"216;27;128" if appearance == "light" else b"137;180;250"
            marker = b"\x1b[38;2;" + color + b"m"
            deadline = time.monotonic() + 12
            while time.monotonic() < deadline:
                pump()
                if marker in output[start:]:
                    # Allow outstanding queries/frames to settle, then check no exit.
                    until = time.monotonic() + 0.25
                    while time.monotonic() < until:
                        pump()
                    assert process.poll() is None
                    return
            raise AssertionError(f"{mode}: missing {appearance} border (drop RGB={drop_defaults}); tail={output[-1500:]!r}")

        try:
            wait_for_border(0)
            assert dsr_count > 0, "the bundled CLI must request its initial native appearance"
            assert b"\x1b[?25h" in output, "Pi must expose the terminal's native cursor"
            for appearance, drop_defaults, drop_all in [("dark", True, True), ("light", True, False), ("dark", False, False), ("light", False, False), ("dark", True, True)]:
                start = len(output)
                os.write(master, b"\x1b[?997;2n" if appearance == "light" else b"\x1b[?997;1n")
                wait_for_border(start)
            print(f"Pi bundled CLI/{mode}: initial native scheme + 5 appearance changes, including complete query timeouts: PASS")
        finally:
            # This is only the isolated fixture, never a user's Pi/tmux process.
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
            os.close(master)
