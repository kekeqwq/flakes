#!/usr/bin/env python3
"""Synthetic runner safety tests. NO native helper, keychain, GC daemon or keys."""
import contextlib
import io
import json
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
from unittest.mock import patch

app = Path(sys.argv[1]).resolve(strict=True)
assert str(app).startswith('/nix/store/')
runner = Path(__file__).with_name('macos-se-store.py')
for scenario in ('success', 'denied', 'ambiguous'):
    with tempfile.TemporaryDirectory() as home:
        operations = []
        def fake_run(command, **kwargs):
            if 'codesign' in command[0]:
                return subprocess.CompletedProcess(command, 0, '', '')
            if '--add-root' in command:
                Path(command[command.index('--add-root') + 1]).symlink_to(app.parent)
                return subprocess.CompletedProcess(command, 0, '', '')
            assert Path(command[0]) == app / 'Contents/MacOS/se-store-probe'
            req = json.loads(kwargs['input'])
            op = req['operation']
            operations.append(op)
            rows = []
            code = 0
            if op == 'inspect':
                rows = [{'stage':'own_tag_lookup', 'status':-25300, 'pid':100}]
            elif op == 'create':
                if scenario == 'ambiguous':
                    raise subprocess.TimeoutExpired(command, 15)
                if scenario == 'denied':
                    code = 8
                    rows = [{'stage':'persistent_create_error', 'status':-34018, 'pid':101}]
                else:
                    rows = [{'stage':'created_hardware_key', 'status':0, 'pid':101, 'public_sha256':'1'*64},
                            {'stage':'opaque_reference_released', 'status':0, 'pid':101}]
            elif op == 'read':
                assert req['public_sha256'] == '1'*64
                rows = [{'stage':'reopened_same_hardware_key', 'status':0, 'pid':102, 'public_sha256':'1'*64},
                        {'stage':'opaque_reference_released', 'status':0, 'pid':102}]
            elif op == 'delete':
                code = 9 if scenario == 'denied' else 0
                rows = [{'stage':'own_tag_delete', 'status':-34018 if code else 0, 'pid':103},
                        {'stage':'own_tag_after_delete', 'status':-25300, 'pid':103}]
            else:
                raise AssertionError(op)
            return subprocess.CompletedProcess(command, code, '\n'.join(json.dumps(r) for r in rows), '')
        failure = None
        with patch.object(Path, 'home', return_value=Path(home)), patch('subprocess.run', side_effect=fake_run), \
             patch.object(sys, 'argv', [str(runner), str(app)]), contextlib.redirect_stdout(io.StringIO()):
            try:
                runpy.run_path(str(runner), run_name='__main__')
            except (AssertionError, subprocess.TimeoutExpired, SystemExit) as error:
                failure = error
        files = list(Path(home).glob('Library/Application Support/flakes/se-store-probe/run.*/state.json'))
        assert len(files) == 1
        state = json.loads(files[0].read_text())
        assert state['creation_attempted'] and state['vacant_before_create']
        assert operations[-1] == 'delete'
        if scenario == 'success':
            assert failure is None and state['deleted_verified'] and operations == ['inspect','create','read','delete']
        else:
            assert failure is not None and not state['deleted_verified']
            assert operations == ['inspect','create','delete']
            assert state['creation_completed'] == (scenario == 'denied')
print('PASS: synthetic success, denied delete + no-item snapshot, ambiguous creator; no false cleanup pass or native calls.')
