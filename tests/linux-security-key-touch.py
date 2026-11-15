#!/usr/bin/env python3
"""Bounded, no-secret real sudo / touch-only lock acceptance. Never types input."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess as sp
import time

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("mode", choices=("lock", "sudo"))
p.add_argument("--report", required=True)
p.add_argument("--seconds", type=int, default=120)
p.add_argument("--hotplug", action="store_true", help="Require no Key initially, then insertion before lock exits")
a = p.parse_args()
assert 5 <= a.seconds <= 180
os.umask(0o077)
for line in sp.check_output(["systemctl", "--user", "show-environment"], text=True).splitlines():
    key, _, value = line.partition("=")
    if key in {"DISPLAY", "WAYLAND_DISPLAY", "XDG_RUNTIME_DIR", "NIRI_SOCKET", "DBUS_SESSION_BUS_ADDRESS"}:
        os.environ[key] = value

def processes(names):
    found = set()
    for entry in Path("/proc").iterdir():
        if not entry.name.isdecimal(): continue
        try:
            status = (entry / "status").read_text().splitlines()
            uid = int(next(s for s in status if s.startswith("Uid:")).split()[1])
            state = next(s for s in status if s.startswith("State:")).split()[1]
            if uid == os.getuid() and state != "Z" and (entry / "comm").read_text().strip() in names:
                found.add(int(entry.name))
        except (FileNotFoundError, PermissionError, ProcessLookupError): pass
    return found

def key_present():
    for path in Path("/sys/bus/usb/devices").glob("*/idVendor"):
        try:
            if path.read_text().strip() == "1050": return True
        except FileNotFoundError: pass
    return False

def locks(): return processes({"swaylock"})
def workers(): return processes({"swaylock-key-au"})
def report(**row):
    dest = Path(a.report)
    tmp = dest.with_suffix(".tmp")
    tmp.write_text(json.dumps(row, indent=2) + "\n")
    tmp.replace(dest)
    print(json.dumps(row), flush=True)

start = time.monotonic()
def sudo_check():
    assert not locks(), "Unlock before sudo testing: avoid competing FIDO requests"
    attempts = []
    while time.monotonic() - start < a.seconds:
        # -k with a command ignores cached credentials; EOF stdin means neither
        # a password nor PIN can be supplied. The only privileged action is true.
        try:
            result = sp.run(["sudo", "-k", "-S", "-p", "", "--", "/run/current-system/sw/bin/true"],
                            stdin=sp.DEVNULL, stdout=sp.PIPE, stderr=sp.PIPE,
                            timeout=min(40, a.seconds - (time.monotonic() - start)))
        except sp.TimeoutExpired:
            report(passed=False, mode=a.mode, timed_out=True, password_or_pin_provided=False)
            raise SystemExit(1)
        attempts.append(result.returncode)
        report(passed=result.returncode == 0, mode=a.mode, attempts=attempts,
               password_or_pin_provided=False, elapsed_seconds=round(time.monotonic() - start, 2))
        if result.returncode == 0: raise SystemExit(0)
        time.sleep(.5)
    raise SystemExit(1)

if a.mode == "sudo":
    assert not locks(), "Unlock before sudo testing: avoid competing FIDO requests"
    active = sp.run(["systemctl", "--user", "is-active", "swayidle.service"], stdout=sp.DEVNULL).returncode == 0
    if active:
        sp.run(["systemctl", "--user", "stop", "swayidle.service"], check=True)
    try:
        sudo_check()
    finally:
        if active:
            sp.run(["systemctl", "--user", "start", "swayidle.service"], check=True)

assert not a.hotplug or not key_present(), "Hotplug acceptance must start with Key removed"
inserted = False
marker = Path(os.environ["XDG_RUNTIME_DIR"]) / "screen-lock.ready"
def stamp():
    try:
        st = marker.stat()
        return st.st_ino, st.st_mtime_ns
    except FileNotFoundError: return None
existing = locks()
if not existing:
    old = stamp()
    sp.run([shutil.which("screen-lock")], stdout=sp.DEVNULL, check=True, timeout=8)
    assert stamp() not in (None, old), "Secure acquisition not confirmed"
    existing = locks()
assert existing and marker.exists(), "No acquired locker"
for _ in range(40):
    if workers(): break
    time.sleep(.05)
key_workers = workers()
assert key_workers, "No parallel hardware-auth worker"
print("Touch the blinking key only; do not type or press Enter.", flush=True)
while time.monotonic() - start < a.seconds:
    inserted = inserted or key_present()
    if not locks():
        deadline = time.monotonic() + 3
        while workers() and time.monotonic() < deadline: time.sleep(.03)
        passed = not workers() and (not a.hotplug or inserted)
        report(passed=passed, mode=a.mode, locker_gone=True, worker_cleanup=not workers(),
               hotplug_required=a.hotplug, key_inserted=inserted,
               keyboard_input_injected=False, elapsed_seconds=round(time.monotonic() - start, 2))
        raise SystemExit(0 if passed else 1)
    time.sleep(.03)
report(passed=False, mode=a.mode, timed_out=True, lock_preserved=True, keyboard_input_injected=False)
raise SystemExit(1)
