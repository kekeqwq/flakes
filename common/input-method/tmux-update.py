"""Snapshot local tmux clients/panes. Called by tmux hooks, never changes IME."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

socket = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("TMUX", "").split(",")[0]
if not socket:
    sys.exit(0)
socket = os.path.realpath(socket)
root = Path.home() / ".local/state/input-method/tmux"
root.mkdir(parents=True, exist_ok=True, mode=0o700)
fields = ["client_tty", "pane_id", "pane_pid", "pane_tty", "pane_in_mode", "client_key_table", "client_prefix"]
fmt = "\t".join("#{" + f + "}" for f in fields)
clients = []
try:
    output = subprocess.run(["@TMUX@", "-S", socket, "list-clients", "-F", fmt],
                            capture_output=True, text=True, timeout=1).stdout
    for row in output.splitlines():
        values = row.split("\t")
        if len(values) != len(fields):
            continue
        client = dict(zip(fields, values))
        result = subprocess.run(["/bin/ps", "-o", "tpgid=", "-p", client["pane_pid"]],
                                capture_output=True, text=True, timeout=1)
        client["foreground_pid"] = int(result.stdout.strip() or 0)
        client["socket"] = socket
        clients.append(client)
except (OSError, ValueError, subprocess.TimeoutExpired):
    pass
name = hashlib.sha256(socket.encode()).hexdigest() + ".json"
fd, temporary = tempfile.mkstemp(prefix=".tmux-", dir=root)
try:
    with os.fdopen(fd, "w") as f:
        json.dump({"version": 1, "clients": clients}, f)
    os.replace(temporary, root / name)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
