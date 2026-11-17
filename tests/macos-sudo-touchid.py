#!/usr/bin/env python3
"""Owner-operated macOS sudo biometric test. Only privileged command: true.

Creates its own PTY, ignores sudo's cache, supplies no password/PIN, and records
status only. Touch the sensor when macOS requests it. Test password fallback
separately in the owner's visible terminal. Never run this check as root.
"""
import argparse
import json
import os
from pathlib import Path
import pty
import select
import signal
import sys
import time

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--report", required=True)
p.add_argument("--timeout", type=int, default=300)
a = p.parse_args()
assert sys.platform == "darwin" and os.geteuid() != 0
assert 10 <= a.timeout <= 600
os.umask(0o077)
marker = b"FLAKES_PASSWORD_FALLBACK_REQUIRED: "
pid, fd = pty.fork()
if pid == 0:
    os.execv("/usr/bin/sudo", ["sudo", "-k", "-p", marker.decode(), "--", "/usr/bin/true"])
start = time.monotonic()
output = b""
status = None
fallback = timed_out = False
try:
    while time.monotonic() - start < a.timeout:
        if select.select([fd], [], [], .2)[0]:
            try:
                chunk = os.read(fd, 8192)
            except OSError:
                chunk = b""
            output = (output + chunk)[-32768:]
            if marker in output:
                fallback = True
                break
        done, rc = os.waitpid(pid, os.WNOHANG)
        if done:
            status = rc
            break
    else:
        timed_out = True
finally:
    if status is None:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        # Native biometric waits may ignore TERM until the UI completes.
        # Only stop our isolated sudo-true child, never another auth process.
        for _ in range(20):
            done, rc = os.waitpid(pid, os.WNOHANG)
            if done:
                status = rc
                break
            time.sleep(.1)
        if status is None:
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            _, status = os.waitpid(pid, 0)
    os.close(fd)
result = {
    "passed": os.waitstatus_to_exitcode(status) == 0 and not fallback and not timed_out,
    "exit_code": os.waitstatus_to_exitcode(status),
    "password_provided": False,
    "password_fallback_requested": fallback,
    "timed_out": timed_out,
    "elapsed_seconds": round(time.monotonic() - start, 2),
    "sudo_cache_ignored": True,
}
Path(a.report).write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result), flush=True)
raise SystemExit(0 if result["passed"] else 1)
