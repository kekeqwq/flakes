#!/usr/bin/env python3
"""Verify tmux hands keyboard focus to/from a popup on an isolated PTY."""

import os
import pty
import select
import shlex
import shutil
import subprocess
import sys
import tempfile
import time

with tempfile.TemporaryDirectory() as directory:
    env = {**os.environ, 'HOME': directory, 'XDG_STATE_HOME': directory + '/state', 'TERM': 'xterm-256color'}
    env.pop('TMUX', None)
    tmux = ['tmux', '-S', directory + '/tmux']

    def command(*args):
        return subprocess.check_output(tmux + list(args), env=env, text=True).strip()

    sleep = shutil.which('sleep')
    assert sleep, 'sleep is required'
    idle = f'exec {shlex.quote(sleep)} 60'
    command('-f', '/dev/null', 'new-session', '-d', '-s', 'probe', idle)
    command('source-file', sys.argv[1])
    pid, terminal = pty.fork()
    if not pid:
        os.execvpe('tmux', tmux + ['attach-session', '-t', 'probe'], env)

    output = bytearray()

    def until(check, description):
        deadline = time.monotonic() + 4
        while time.monotonic() < deadline:
            if select.select([terminal], [], [], 0.04)[0]:
                output.extend(os.read(terminal, 65536))
            if check():
                return
        raise AssertionError(description)

    try:
        def field(name):
            return command('list-clients', '-F', '#{' + name + '}')

        until(lambda: bool(field('client_tty')), 'client did not attach')
        # Wait for an actual focus transition before opening the popup.
        os.write(terminal, b'\x1b[O')
        until(lambda: field('@ime-pane-unfocused') == '1', 'client focus-out not reported')
        os.write(terminal, b'\x1b[I')
        until(lambda: not field('@ime-pane-unfocused'), 'client focus-in not reported')
        tty, pane = field('client_tty'), field('pane_id')
        with subprocess.Popen(tmux + ['popup', '-E', '-c', tty, idle], env=env) as popup:
            try:
                until(lambda: field('@ime-pane-unfocused') == '1', 'popup did not take focus')
                assert field('pane_id') == pane
                # Exercise redraw of an already-open popup, not just option parsing.
                for mode, theme, bg in [(2, 'light', b'48;2;239;241;245'), (1, 'dark', b'48;2;30;30;46')]:
                    output.clear()
                    os.write(terminal, f'\x1b[?997;{mode}n'.encode())
                    until(lambda: field('client_theme') == theme and bg in output,
                          f'popup did not draw {theme} background')
            finally:
                command('popup', '-C', '-c', tty)
            until(lambda: not field('@ime-pane-unfocused'), 'pane did not regain focus')
            popup.wait(timeout=3)
        print('tmux popup focus handoff: PASS')
    finally:
        command('kill-server')
        os.close(terminal)
        os.waitpid(pid, 0)
