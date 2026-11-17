#!/usr/bin/env python3
"""Opt-in native Apple-PAM handle test, NOT a sudo/privilege acceptance test.

Calls only pam-u2f against the public mapping. Supplies no password/PIN, creates
no credentials and changes no PAM file. Default mode is unprivileged; explicit
--root-probe requires pre-existing sudo authorization and does NOT test privilege
granting by the Key. A bounded child owns the token connection; secret prompts
are rejected.
"""
import argparse
import ctypes as C
import json
import os
from pathlib import Path
import pwd
import subprocess
import sys
import time

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--module', required=True)
p.add_argument('--mapping', required=True)
p.add_argument('--label', required=True, choices=['no-key', 'primary', 'secondary'])
p.add_argument('--report', required=True)
p.add_argument('--timeout', type=int, default=65)
p.add_argument('--child', action='store_true', help=argparse.SUPPRESS)
p.add_argument('--root-probe', action='store_true', help='Diagnostic only: requires existing sudo authorization')
a = p.parse_args()
assert sys.platform == 'darwin'
if a.root_probe:
    assert os.geteuid() == 0 and os.environ.get('SUDO_USER') == 'keke'
    report = Path(a.report)
    assert report.parent == Path('/var/root/flakes-sudo-key-probes')
    assert report.parent.stat().st_uid == 0 and report.parent.stat().st_mode & 0o077 == 0
    assert not report.is_symlink()
else:
    assert os.geteuid() != 0
assert 10 <= a.timeout <= 120
os.umask(0o077)
module = Path(a.module).resolve()
mapping = Path(a.mapping).resolve()
for path in (module, mapping):
    assert str(path).startswith('/nix/store/') and path.is_file()
    assert path.stat().st_uid == 0 and not path.stat().st_mode & 0o022
if not a.child:
    start = time.monotonic()
    try:
        result = subprocess.run([sys.executable, __file__, *sys.argv[1:], '--child'],
                                capture_output=True, text=True, timeout=a.timeout)
        if result.returncode == 0:
            data = json.loads(result.stdout)
        else:
            data = {'test_error': 'child-failed', 'child_exit': result.returncode,
                    'authenticated': False}
    except subprocess.TimeoutExpired:
        data = {'test_error': 'timeout', 'authenticated': False}
    data.update(label=a.label, password_or_pin_provided=False,
                privileged_command_run=a.root_probe, existing_authorization_required=a.root_probe,
                elapsed_seconds=round(time.monotonic()-start, 3))
    data['passed'] = (not data.get('test_error')
        and not data.get('secret_prompt_rejected', False)
        and (data['authenticated'] if a.label != 'no-key' else not data['authenticated']))
    Path(a.report).write_text(json.dumps(data, indent=2)+'\n')
    print(json.dumps(data), flush=True)
    raise SystemExit(0 if data['passed'] else 1)

linkage = subprocess.check_output(['/usr/bin/otool', '-L', str(module)], text=True)
assert '/usr/lib/libpam.2.dylib' in linkage and '-openpam-' not in linkage
pam = C.CDLL('/usr/lib/libpam.2.dylib')
libc = C.CDLL('/usr/lib/libSystem.B.dylib')
plugin = C.CDLL(str(module))
class Message(C.Structure):
    _fields_ = [('style', C.c_int), ('text', C.c_char_p)]
class Response(C.Structure):
    _fields_ = [('text', C.c_void_p), ('code', C.c_int)]
Callback = C.CFUNCTYPE(C.c_int, C.c_int, C.POINTER(C.POINTER(Message)),
                      C.POINTER(C.POINTER(Response)), C.c_void_p)
class Conversation(C.Structure):
    _fields_ = [('callback', Callback), ('data', C.c_void_p)]
libc.calloc.argtypes = [C.c_size_t, C.c_size_t]
libc.calloc.restype = C.c_void_p
secret_prompt = False
@Callback
def converse(count, messages, responses, data):
    global secret_prompt
    if not 0 < count <= 32:
        return 6  # Apple/OpenPAM PAM_CONV_ERR
    if any(messages[i].contents.style not in (3, 4) for i in range(count)):
        secret_prompt = True
        return 6  # Never read password/PIN/keyboard input.
    allocation = libc.calloc(count, C.sizeof(Response))
    if not allocation:
        return 5  # PAM_BUF_ERR
    responses[0] = C.cast(allocation, C.POINTER(Response))
    return 0
conv = Conversation(converse, None)
handle = C.c_void_p()
pam.pam_start.argtypes = [C.c_char_p, C.c_char_p, C.POINTER(Conversation), C.POINTER(C.c_void_p)]
pam.pam_start.restype = C.c_int
pam.pam_end.argtypes = [C.c_void_p, C.c_int]
pam.pam_end.restype = C.c_int
user = 'keke' if a.root_probe else pwd.getpwuid(os.geteuid()).pw_name
# pam_start only creates a handle; do not call the 'other' service's auth stack.
r = pam.pam_start(b'other', user.encode(), C.byref(conv), C.byref(handle))
assert r == 0, r
args = [f'authfile={mapping}', 'origin=pam://keke-flakes', 'appid=pam://keke-flakes',
        'userpresence=1', 'pinverification=0', 'userverification=0', 'cue']
argv = (C.c_char_p * len(args))(*(x.encode() for x in args))
plugin.pam_sm_authenticate.argtypes = [C.c_void_p, C.c_int, C.c_int, C.POINTER(C.c_char_p)]
plugin.pam_sm_authenticate.restype = C.c_int
uid = os.geteuid()
try:
    r = plugin.pam_sm_authenticate(handle, 0, len(args), argv)
finally:
    end = pam.pam_end(handle, r)
assert os.geteuid() == uid
print(json.dumps({'authenticated': r == 0 and end == 0 and not secret_prompt,
                  'pam_result': r, 'pam_end_result': end,
                  'secret_prompt_rejected': secret_prompt}), flush=True)
