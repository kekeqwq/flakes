#!/usr/bin/env python3
"""Foreground identity regression; offline process/metadata fixtures only."""
import importlib.util
from importlib.machinery import SourceFileLoader
import os
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

source = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / 'System/Common/input-method/tmux-update.py'
spec = importlib.util.spec_from_file_location('tmux_update', source, loader=SourceFileLoader('tmux_update', str(source)))
reporter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reporter)


class Foreground(unittest.TestCase):
    def setUp(self):
        self.client = {'pane_pid': '37335', 'pane_tty': '/dev/ttys003',
                       'pane_id': '%2', 'socket': os.path.realpath('/tmp/ime-test')}
        self.context = {'pid': 37341, 'updated': 1000, 'tmuxPane': '%2',
                        'socket': '/tmp/ime-test', 'editing': True}
        self.processes = reporter.process_table('''
37335 37335 37335 ttys003
37341 37335 37335 ttys003
40000 40000 37335 ttys003
50000 37335 37335 ttys004
''')

    def resolve(self, contexts=None):
        return reporter.foreground_pid(self.client, self.processes,
                                       contexts if contexts is not None else [self.context], 1000)

    def test_noninteractive_fish_child(self):
        self.assertEqual(self.resolve(), 37341)

    def test_interactive_job_control(self):
        self.processes[37335] = (37335, 37341, 'ttys003')
        self.processes[37341] = (37341, 37341, 'ttys003')
        self.assertEqual(self.resolve(), 37341)

    def test_linux_tty_shape(self):
        self.client['pane_tty'] = '/dev/pts/3'
        self.processes = reporter.process_table('37335 37335 37335 pts/3\n37341 37335 37335 pts/3')
        self.assertEqual(self.resolve(), 37341)

    def test_background_pi_rejected(self):
        self.context['pid'] = 40000
        self.assertEqual(self.resolve(), 37335)

    def test_other_tty_rejected(self):
        self.context['pid'] = 50000
        self.assertEqual(self.resolve(), 37335)

    def test_wrong_pane_and_socket_rejected(self):
        for key, value in [('tmuxPane', '%1'), ('socket', '/tmp/other')]:
            with self.subTest(key=key):
                wrong = {**self.context, key: value}
                self.assertEqual(self.resolve([wrong]), 37335)

    def test_stale_future_and_dead_pi_rejected(self):
        for patch in ({'updated': 993}, {'updated': 1002}, {'pid': 99999}):
            with self.subTest(patch=patch):
                self.assertEqual(self.resolve([{**self.context, **patch}]), 37335)

    def test_no_record_preserves_leader(self):
        self.assertEqual(self.resolve([]), 37335)

    def test_editor_not_editing_still_identified(self):
        # Reporter identifies the process; policy retains authority over editing,
        # prefix/copy mode, pane/socket and leases. No second IME policy here.
        self.context['editing'] = False
        self.assertEqual(self.resolve(), 37341)

    def test_ambiguous_records_fall_back(self):
        self.processes[37342] = (37335, 37335, 'ttys003')
        self.assertEqual(self.resolve([self.context, {**self.context, 'pid': 37342}]), 37335)

    def test_missing_pane_and_wrong_terminal_rejected(self):
        self.processes.pop(37335)
        self.assertEqual(self.resolve(), 0)
        self.processes[37335] = (37335, 37335, 'ttys999')
        self.assertEqual(self.resolve(), 0)

    def test_snapshot_writer_preserves_policy_fields(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / '.local/state/input-method'
            (state / 'pi').mkdir(parents=True)
            (state / 'pi/37341.json').write_text(json.dumps(self.context))
            rows = '/dev/ttys000\t%2\t37335\t/dev/ttys003\t1\tprefix\t1\n'
            results = [SimpleNamespace(stdout=rows), SimpleNamespace(stdout=(
                '37335 37335 37335 ttys003\n37341 37335 37335 ttys003\n'))]
            with patch.object(reporter.Path, 'home', return_value=root), \
                 patch.object(reporter.sys, 'argv', ['reporter', self.client['socket']]), \
                 patch.object(reporter.time, 'time', return_value=1000), \
                 patch.object(reporter.subprocess, 'run', side_effect=results):
                reporter.main()
            files = list((state / 'tmux').glob('*.json'))
            self.assertEqual(len(files), 1)
            record = json.loads(files[0].read_text())['clients'][0]
            self.assertEqual(record['foreground_pid'], 37341)
            self.assertEqual(record['pane_in_mode'], '1')
            self.assertEqual(record['client_key_table'], 'prefix')
            self.assertEqual(record['client_prefix'], '1')
            self.assertEqual(record['updated'], 1000)
            self.assertEqual(files[0].stat().st_mode & 0o777, 0o600)

    def test_process_parser_ignores_malformed_lines(self):
        self.assertEqual(reporter.process_table('garbage\na b c tty\n1 1 1 /dev/pts/0'),
                         {1: (1, 1, 'pts/0')})


if __name__ == '__main__':
    unittest.main()
