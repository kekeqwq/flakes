#!/usr/bin/env python3
"""Staged cold/hotplug acceptance. No keyboard injection or secret collection.

Start while unlocked; remove the Key, wait for retry validation, insert without
 touching, then touch only after FIDO device ownership has been observed.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess as sp
import time

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--report", required=True)
a = p.parse_args()
os.umask(0o077)
for line in sp.check_output(["systemctl", "--user", "show-environment"], text=True).splitlines():
    k, _, v = line.partition("=")
    if k in {"DISPLAY", "WAYLAND_DISPLAY", "XDG_RUNTIME_DIR", "NIRI_SOCKET", "DBUS_SESSION_BUS_ADDRESS"}:
        os.environ[k] = v

def keys():
    devices = []
    for e in Path("/sys/class/hidraw").glob("*"):
        try:
            props = sp.check_output(["udevadm", "info", "--query=property", "--path", str(e)], text=True)
            if "ID_FIDO_TOKEN=1" in props and "ID_VENDOR_ID=1050" in props:
                devices.append(Path("/dev") / e.name)
        except (FileNotFoundError, sp.CalledProcessError): pass
    return devices

def processes(name):
    result = set()
    for e in Path("/proc").iterdir():
        if not e.name.isdecimal(): continue
        try:
            lines = (e / "status").read_text().splitlines()
            uid = int(next(s for s in lines if s.startswith("Uid:")).split()[1])
            state = next(s for s in lines if s.startswith("State:")).split()[1]
            if uid == os.getuid() and state != "Z" and (e / "comm").read_text().strip() == name:
                result.add(int(e.name))
        except (FileNotFoundError, PermissionError, ProcessLookupError): pass
    return result

def locked(): return processes("swaylock")
def workers(): return processes("swaylock-key-au")
def report(stage, **data):
    dest = Path(a.report); temp = dest.with_suffix(".tmp")
    temp.write_text(json.dumps({"stage": stage, **data}, indent=2) + "\n")
    temp.replace(dest)
    print(json.dumps({"stage": stage, **data}), flush=True)

def wait_for(condition, seconds):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        if condition(): return True
        time.sleep(.1)
    return False

report("waiting-for-key-removal", passed=False)
assert wait_for(lambda: not keys(), 600), "Key was not removed"
marker = Path(os.environ["XDG_RUNTIME_DIR"]) / "screen-lock.ready"
def stamp():
    try:
        st = marker.stat(); return st.st_ino, st.st_mtime_ns
    except FileNotFoundError: return None
if not locked():
    before = stamp()
    sp.run([shutil.which("screen-lock")], stdout=sp.DEVNULL, check=True, timeout=8)
    assert stamp() not in (None, before), "No secure acquisition"
assert locked() and marker.exists()
report("checking-fresh-no-key-retries", passed=False)
seen = set(); end = time.monotonic() + 12
while time.monotonic() < end:
    assert locked(), "Lock disappeared without a registered-key touch"
    seen.update(workers())
    time.sleep(.015)
assert len(seen) >= 2, "No fresh auth-process retries observed"
assert not keys(), "Do not insert before the retry check completes"
report("ready-for-insertion-only", passed=False, fresh_worker_pids=len(seen), lock_preserved=True)
assert wait_for(lambda: bool(keys()), 600), "Key was not inserted"
report("inserted-waiting-for-fido-ownership", passed=False, fresh_worker_pids=len(seen))
# This observes kernel advisory ownership, not an unlock proof. The actual
# authenticated release still has to arrive via the private checked channel.
def fido_owner():
    devices = keys()
    if not devices: return None
    inodes = {str(path.stat().st_ino) for path in devices if path.exists()}
    current = workers()
    for line in Path("/proc/locks").read_text().splitlines():
        columns = line.split()
        if len(columns) >= 8 and "FLOCK" in columns and columns[5].split(":")[-1] in inodes:
            try: pid = int(columns[4])
            except ValueError: continue
            if pid in current: return pid
    return None
# Intentionally outwait a normal touch-request window. A later touch must
# work without restarting the locker, and expired attempts must release the
# device lock to a new process rather than retaining one stale owner forever.
seen_key_owners = set()
report("observing-unattended-fido-timeouts", passed=False, fresh_worker_pids=len(seen))
settle = time.monotonic() + 70
while time.monotonic() < settle:
    assert locked(), "Do not unlock during unattended retry validation"
    current = fido_owner()
    if current: seen_key_owners.add(current)
    time.sleep(.1)
assert len(seen_key_owners) >= 2, "FIDO ownership did not advance to fresh attempts"
owner = None; end = time.monotonic() + 60
while time.monotonic() < end:
    assert locked(), "Unexpected unlock before the touch stage"
    candidate = fido_owner()
    if candidate:
        time.sleep(.5)
        if fido_owner() == candidate:
            owner = candidate
            break
    time.sleep(.05)
assert owner, "No live authentication attempt acquired the inserted FIDO device"
report("ready-for-one-touch", passed=False, fresh_worker_pids=len(seen),
       unattended_fido_owners=len(seen_key_owners), fido_owner_pid=owner)
assert wait_for(lambda: not locked(), 120), "Touch did not unlock"
assert wait_for(lambda: not workers(), 4), "Auth worker survived unlock"
report("complete", passed=True, fresh_worker_pids=len(seen),
       unattended_fido_owners=len(seen_key_owners), hotplug=True,
       worker_cleanup=True, keyboard_input_injected=False)
