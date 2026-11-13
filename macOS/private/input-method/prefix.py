"""Hold English while the tmux prefix is armed, then restore Chinese in a Pi editor."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

SELECT = "@SELECT@"
TMUX = "@TMUX@"
REPORTER = "@REPORTER@"
ABC = "com.apple.keylayout.ABC"
RIME = "im.rime.inputmethod.Squirrel.Hans"
STATE = Path.home() / ".local/state/input-method"


def wezterm_pid():
    listed = subprocess.run(
        ["pgrep", "-f", "/MacOS/wezterm-gui"],
        capture_output=True,
        text=True,
    )
    pids = [int(line) for line in listed.stdout.split() if line.isdigit()]
    return pids[-1] if pids else None


def select(source):
    pid = wezterm_pid()
    if not pid:
        return
    subprocess.run([SELECT, source, str(pid)], timeout=2)


def write_hold(active):
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    path = STATE / "prefix.json"
    path.write_text(json.dumps({"active": active}))
    path.chmod(0o600)


def snapshot_path(socket):
    name = hashlib.sha256(os.path.realpath(socket).encode()).hexdigest() + ".json"
    return STATE / "tmux" / name


def rewrite_prefix(socket, active):
    path = snapshot_path(socket)
    try:
        data = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return
    for client in data.get("clients") or []:
        client["client_prefix"] = "1" if active else "0"
        client["client_key_table"] = "prefix" if active else "root"
        client["updated"] = time.time()
    path.write_text(json.dumps(data))


def pi_editing(socket):
    path = snapshot_path(socket)
    try:
        clients = json.loads(path.read_text()).get("clients") or []
    except (OSError, json.JSONDecodeError):
        return False
    contexts = []
    pi_dir = STATE / "pi"
    if pi_dir.is_dir():
        for name in pi_dir.iterdir():
            if name.suffix != ".json":
                continue
            try:
                contexts.append(json.loads(name.read_text()))
            except (OSError, json.JSONDecodeError):
                pass
    for client in clients:
        if client.get("client_prefix") == "1" or client.get("pane_in_mode") == "1":
            continue
        if client.get("client_key_table") not in ("root", "", None):
            continue
        pid = client.get("foreground_pid")
        pane = client.get("pane_id")
        for ctx in contexts:
            if ctx.get("editing") is True and ctx.get("pid") == pid and ctx.get("tmuxPane") == pane:
                return True
    return False


def prefix_armed(socket):
    if not socket:
        return False
    listed = subprocess.run(
        [TMUX, "-S", socket, "display-message", "-p", "#{client_prefix}"],
        capture_output=True,
        text=True,
        timeout=1,
    )
    return listed.stdout.strip() == "1"


def restore(socket, force):
    write_hold(False)
    if not socket:
        return
    if force:
        rewrite_prefix(socket, False)
    else:
        subprocess.run([REPORTER, socket], timeout=2)
    if pi_editing(socket):
        select(RIME)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    socket = sys.argv[2] if len(sys.argv) > 2 else ""
    if mode == "begin":
        write_hold(True)
        if socket:
            rewrite_prefix(socket, True)
        select(ABC)
        return
    if mode == "end":
        restore(socket, "--force" in sys.argv[3:])
        return
    if mode == "settle":
        # Prefix command finished, or Escape already left the table.
        if prefix_armed(socket):
            return
        restore(socket, False)
        return
    sys.exit(2)


if __name__ == "__main__":
    main()
