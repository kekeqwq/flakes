#!/usr/bin/env python3
"""Reject malformed requests BEFORE keychain access. Never generates/signs keys."""
import json
import os
from pathlib import Path
import subprocess
import sys

app = Path(sys.argv[1]).resolve(strict=True)
assert str(app).startswith('/nix/store/')
exe = app / 'Contents/MacOS/se-store-probe'
assert exe.stat().st_uid == 0 and not exe.stat().st_mode & 0o022
subprocess.run(['/usr/bin/codesign', '--verify', '--strict', str(app)], check=True, capture_output=True)
valid = f'com.keke.flakes.se-store-test.v1.{os.getuid()}.11111111-1111-4111-8111-111111111111'
cases = [
    {},
    {'operation': 'delete', 'tag': 'other.namespace'},
    {'operation': 'delete', 'tag': valid.replace(f'.{os.getuid()}.', '.0.')},
    {'operation': 'create', 'tag': 123},
    {'operation': 'unknown', 'tag': valid},
]
assert os.getuid() != 0
for request in cases:
    p = subprocess.run([str(exe)], input=json.dumps(request), text=True, capture_output=True, timeout=5)
    assert p.returncode == 2 and not p.stdout, (p.returncode, p.stdout)
print('PASS: invalid operation/tag/UID rejected before any keychain call; no keys created.')
