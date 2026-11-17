"""Snapshot local tmux clients/panes. Called by tmux hooks, never changes IME."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def process_table(text):
    """Metadata only: PID, process group, foreground group and terminal."""
    result = {}
    for line in text.splitlines():
        fields = line.split()
        if len(fields) != 4:
            continue
        try:
            pid, group, foreground = map(int, fields[:3])
        except ValueError:
            continue
        result[pid] = (group, foreground, fields[3].removeprefix('/dev/'))
    return result


def foreground_pid(client, processes, contexts, now):
    """Resolve a Pi inside a foreground job, including non-job-control shells.

    tpgid is a process GROUP ID, not necessarily the PID of its editor. A
    noninteractive `fish -c pi` keeps Pi in fish's group. Only select a live
    member of this exact foreground group/TTY with a fresh same-pane/socket
    record. No process names, command lines or prompt contents are inspected.
    """
    pane = processes.get(int(client['pane_pid']))
    tty = client['pane_tty'].removeprefix('/dev/')
    if not pane or pane[2] != tty:
        return 0
    group = pane[1]
    if group <= 0 or tty in ('?', '??', '-'):
        return 0
    candidates = set()
    for context in contexts:
        pid, updated = context.get('pid'), context.get('updated')
        if not isinstance(pid, int) or not isinstance(updated, (int, float)):
            continue
        if not now - 7 < updated <= now + 1:
            continue
        if context.get('tmuxPane') != client['pane_id']:
            continue
        socket = context.get('socket')
        if not isinstance(socket, str) or os.path.realpath(socket) != client['socket']:
            continue
        if processes.get(pid) == (group, group, tty):
            candidates.add(pid)
    # Ambiguous/missing reports retain the old group-leader-only behavior.
    return next(iter(candidates)) if len(candidates) == 1 else group


def pi_contexts(directory):
    result = []
    for path in directory.glob('*.json'):
        try:
            value = json.loads(path.read_text())
            if isinstance(value, dict):
                result.append(value)
        except (OSError, ValueError):
            pass
    return result


def main():
    socket = sys.argv[1] if len(sys.argv) > 1 else os.environ.get('TMUX', '').split(',')[0]
    if not socket:
        return
    socket = os.path.realpath(socket)
    state = Path.home() / '.local/state/input-method'
    root = state / 'tmux'
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    fields = ['client_tty', 'pane_id', 'pane_pid', 'pane_tty', 'pane_in_mode', 'client_key_table', 'client_prefix']
    fmt = '\t'.join('#{' + field + '}' for field in fields)
    clients = []
    try:
        output = subprocess.run(['@TMUX@', '-S', socket, 'list-clients', '-F', fmt],
                                capture_output=True, text=True, timeout=1, check=True).stdout
        processes = process_table(subprocess.run(
            ['@PS@', '-axo', 'pid=,pgid=,tpgid=,tty='],
            capture_output=True, text=True, timeout=1, check=True).stdout)
        contexts = pi_contexts(state / 'pi')
        now = time.time()
        for row in output.splitlines():
            values = row.split('\t')
            if len(values) != len(fields):
                continue
            client = dict(zip(fields, values))
            client['socket'] = socket
            client['foreground_pid'] = foreground_pid(client, processes, contexts, now)
            client['updated'] = now
            clients.append(client)
    except (OSError, ValueError, subprocess.TimeoutExpired, subprocess.CalledProcessError):
        pass
    name = hashlib.sha256(socket.encode()).hexdigest() + '.json'
    path = root / name
    if not clients:
        try:
            path.unlink()
        except FileNotFoundError:
            pass
        return
    fd, temporary = tempfile.mkstemp(prefix='.tmux-', dir=root)
    try:
        with os.fdopen(fd, 'w') as output:
            json.dump({'version': 1, 'clients': clients}, output)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == '__main__':
    main()
