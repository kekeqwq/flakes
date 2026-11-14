"""Check the focus token against OSC output from a real attached tmux client.

Run with Python 3 and tmux on PATH. Uses an isolated socket, never the user's
server. Does not require Ghostty or an active GUI session.
"""

import os
import pty
import select
import subprocess
import time

name = "ghostty-title-test-" + str(os.getpid())
env = {**os.environ, "TERM": "xterm-256color"}
env.pop("TMUX", None)
master, slave = pty.openpty()
proc = subprocess.Popen(
    ["tmux", "-L", name, "-f", "/dev/null", "new-session", "-s", "probe"],
    stdin=slave,
    stdout=slave,
    stderr=slave,
    env=env,
    start_new_session=True,
)
os.close(slave)
try:
    deadline = time.monotonic() + 5
    while True:
        clients = subprocess.run(
            ["tmux", "-L", name, "list-clients", "-F", "tmux:#{socket_path}:#{client_tty}"],
            capture_output=True,
            env=env,
        )
        if clients.returncode == 0 and clients.stdout.strip():
            break
        if time.monotonic() > deadline:
            raise AssertionError("tmux client did not attach")
        time.sleep(0.05)
    for option, value in (
        ("set-titles-string", "tmux:#{socket_path}:#{client_tty}"),
        ("set-titles", "on"),
    ):
        subprocess.run(["tmux", "-L", name, "set-option", "-g", option, value], check=True, env=env)
    expected = clients.stdout.strip()
    data = b""
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if select.select([master], [], [], 0.1)[0]:
            data += os.read(master, 65536)
        if expected in data:
            break
    assert expected in data, "OSC title did not match the client's focus token"
    print("real attached tmux client title matches snapshot token: PASS")
finally:
    subprocess.run(
        ["tmux", "-L", name, "kill-server"], env=env,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    proc.wait(timeout=5)
    os.close(master)
