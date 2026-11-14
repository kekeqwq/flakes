"""Apply fcitx5 input state from focus reports (macOS Hammerspoon equivalent).

Only metadata is read: no prompt text, titles, or file names leave the session.
The policy is a pure module so it can be tested without fcitx5.
"""

import glob
import json
import os
from pathlib import Path
import subprocess
import sys
import time

sys.path.insert(0, "@DIR@")
import policy  # noqa: E402

NIRI = "@NIRI@/bin/niri"
FCITX5_REMOTE = "@FCITX5_REMOTE@/bin/fcitx5-remote"
STATE = Path.home() / ".local/state/input-method"
LEASE = 7.0
INTERVAL = 0.2


def read_json(path, default=None):
    try:
        with open(path) as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError):
        return default


def records(directory, key=None):
    result = []
    try:
        entries = list(Path(directory).iterdir())
    except OSError:
        return result
    for entry in entries:
        if entry.suffix != ".json":
            continue
        value = read_json(entry)
        if not value:
            continue
        if key:
            result.extend(value.get(key) or [])
        else:
            result.append(value)
    return result


def niri_socket():
    socket = os.environ.get("NIRI_SOCKET")
    if socket:
        return socket
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    found = sorted(glob.glob(f"{runtime}/niri.wayland-*.sock"))
    return found[-1] if found else None


def focused_window(socket):
    """niri's focused window: app_id, title, pid. None if unavailable."""
    if not socket:
        return None
    try:
        done = subprocess.run(
            [NIRI, "msg", "--json", "focused-window"],
            capture_output=True,
            text=True,
            timeout=1,
            env={**os.environ, "NIRI_SOCKET": socket},
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if done.returncode != 0:
        return None
    try:
        return json.loads(done.stdout or "null") or None
    except json.JSONDecodeError:
        return None


def terminal_record(window):
    """Build the terminal identity the policy expects for this focus."""
    app = (window or {}).get("app_id")
    if app in policy.WEZTERM:
        return read_json(STATE / "wezterm.json", {}) or {}
    if app in policy.GHOSTTY:
        return {"title": (window or {}).get("title") or "", "blocked": False}
    return None


def prefix_held(now):
    value = read_json(STATE / "prefix.json", {}) or {}
    if value.get("active") is not True:
        return False
    expires = value.get("expires")
    return isinstance(expires, (int, float)) and now <= expires


def current_source():
    try:
        done = subprocess.run([FCITX5_REMOTE], capture_output=True, text=True, timeout=1)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return {"1": policy.ASCII, "2": policy.RIME}.get(done.stdout.strip())


def apply(source):
    flag = "-o" if source == policy.RIME else "-c"
    try:
        subprocess.run([FCITX5_REMOTE, flag], capture_output=True, timeout=1)
    except (OSError, subprocess.TimeoutExpired):
        pass


def publish_prefix_context(active, now):
    """A private, expiring lease; Rime does no subprocess work on key events."""
    try:
        STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
        temporary = STATE / f".prefix-context-{os.getpid()}"
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as handle:
            handle.write(f"{'tmux' if active else 'other'} {now:.3f}\n")
        os.replace(temporary, STATE / "tmux-prefix-context")
    except OSError:
        pass


def main():
    socket = niri_socket()
    applied = None
    tick = 0
    lease_active = None
    lease_updated = 0
    while True:
        now = time.time()
        window = focused_window(socket)
        app = (window or {}).get("app_id")
        terminal = terminal_record(window)
        clients = records(STATE / "tmux", "clients")
        contexts = records(STATE / "pi")
        active = policy.focused_tmux(app, terminal, clients, now)
        if active != lease_active or now - lease_updated >= 1:
            publish_prefix_context(active, now)
            lease_active, lease_updated = active, now
        want = policy.desired(app, terminal, clients, contexts, now, prefix_held(now))
        if want is None:
            applied = None
        elif want != applied:
            apply(want)
            applied = want
        elif tick % 5 == 0 and current_source() not in (None, want):
            # A manual toggle must not fight the user; restore only the policy.
            apply(want)
        tick += 1
        time.sleep(INTERVAL)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
