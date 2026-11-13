"""Hold ASCII while the tmux prefix is armed, then restore Pi's Chinese."""

import json
import subprocess
import sys
import time

sys.path.insert(0, "@DIR@")
import policy  # noqa: E402
import watch  # noqa: E402

STATE = watch.STATE
FCITX5_REMOTE = "@FCITX5_REMOTE@/bin/fcitx5-remote"
TMUX = "@TMUX@/bin/tmux"
HOLD_SECONDS = 3


def write(active):
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    payload = {"active": True, "expires": time.time() + HOLD_SECONDS} if active else {"active": False}
    path = STATE / "prefix.json"
    path.write_text(json.dumps(payload))
    path.chmod(0o600)


def set_source(source):
    flag = "-o" if source == policy.RIME else "-c"
    try:
        subprocess.run([FCITX5_REMOTE, flag], capture_output=True, timeout=2)
    except (OSError, subprocess.TimeoutExpired):
        pass


def restore(socket):
    """Return to Chinese only when that pane is still a Pi editor."""
    if not socket:
        return
    terminal = watch.read_json(STATE / "wezterm.json", {}) or {}
    clients = watch.records(STATE / "tmux", "clients")
    contexts = watch.records(STATE / "pi")
    now = time.time()
    if policy.pi_context(terminal, clients, contexts, now):
        set_source(policy.RIME)


def prefix_armed(socket):
    if not socket:
        return False
    try:
        done = subprocess.run(
            [TMUX, "-S", socket, "display-message", "-p", "#{client_prefix}"],
            capture_output=True,
            text=True,
            timeout=2,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return done.stdout.strip() == "1"


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    socket = sys.argv[2] if len(sys.argv) > 2 else ""
    if mode == "begin":
        # Synchronous: the next key must arrive with fcitx5 already in ASCII.
        write(True)
        set_source(policy.ASCII)
        return
    if mode == "end":
        write(False)
        restore(socket)
        return
    if mode == "settle":
        # Ran after a prefix command; a still-armed prefix keeps the hold.
        if prefix_armed(socket):
            return
        write(False)
        restore(socket)
        return
    sys.exit(2)


if __name__ == "__main__":
    main()
