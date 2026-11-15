#!/usr/bin/env python3
"""No-secret idle acceptance: real compositor inhibitors, then 300 s real lock.

Leaves the authenticated production lock intact for subsequent human hotplug /
password acceptance. Never types a password, stops an idle service, or kills a
locker. Run only with the owner's permission not to use the Deck during timing.
"""
import argparse
import ast
import fcntl
import json
import os
from pathlib import Path
import signal
import struct
import subprocess as sp
import sys
import time

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--tools-file", required=True)
p.add_argument("--idle-report", required=True)
p.add_argument("--production-report", required=True)
a = p.parse_args()
os.umask(0o077)
for line in sp.check_output(["systemctl", "--user", "show-environment"], text=True).splitlines():
    k, _, v = line.partition("=")
    if k in {"DISPLAY", "WAYLAND_DISPLAY", "XDG_RUNTIME_DIR", "NIRI_SOCKET", "DBUS_SESSION_BUS_ADDRESS"}:
        os.environ[k] = v

def pids(name):
    found = set()
    for entry in Path("/proc").iterdir():
        if not entry.name.isdecimal(): continue
        try:
            status = (entry / "status").read_text().splitlines()
            uid = int(next(s for s in status if s.startswith("Uid:")).split()[1])
            state = next(s for s in status if s.startswith("State:")).split()[1]
            if uid == os.getuid() and state != "Z" and (entry / "comm").read_text().strip() == name:
                found.add(int(entry.name))
        except (FileNotFoundError, PermissionError, ProcessLookupError): pass
    return found

def key_present():
    for path in Path("/sys/bus/usb/devices").glob("*/idVendor"):
        try:
            if path.read_text().strip() == "1050": return True
        except FileNotFoundError: pass
    return False

report = Path(a.production_report)
def update(**data):
    temp = report.with_suffix(".tmp")
    temp.write_text(json.dumps(data, indent=2) + "\n")
    temp.replace(report)
    print(json.dumps(data), flush=True)

deadline = time.monotonic() + 600
update(stage="waiting-for-unlocked-desktop", passed=False)
while pids("swaylock") and time.monotonic() < deadline: time.sleep(.2)
assert not pids("swaylock"), "Unlock manually before starting observation"
assert not key_present(), "Keep keys removed during no-key idle acceptance"
source = Path(__file__).with_name("linux-idle-regression.py")
update(stage="real-input-and-playback-observation", passed=False)
with report.with_suffix(".observation.log").open("wb") as log:
    result = sp.run([sys.executable, str(source), "--tools-file", a.tools_file,
                     "--timeout", "5", "--report", a.idle_report],
                    stdout=log, stderr=sp.STDOUT, timeout=650)
assert result.returncode == 0, "Idle/inhibitor observations failed; inspect status-only report"
rows = json.loads(Path(a.idle_report).read_text())
assert rows and all(row["pass"] for row in rows)
assert not pids("swaylock") and not key_present()
command = sp.check_output(["systemctl", "--user", "show", "swayidle.service", "-p", "ExecStart", "--value"], text=True)
assert "timeout 300 " in command, "Not the production 300-second policy"
sp.run(["systemctl", "--user", "start", "swayidle.service"], check=True)
marker = Path(os.environ["XDG_RUNTIME_DIR"]) / "screen-lock.ready"
def stamp():
    try:
        st = marker.stat()
        return st.st_ino, st.st_mtime_ns
    except FileNotFoundError: return None
old = stamp()
classes = [node for node in ast.parse(source.read_text()).body
           if isinstance(node, ast.ClassDef) and node.name == "HardwarePointer"]
assert len(classes) == 1
exec(compile(ast.Module(body=classes, type_ignores=[]), "isolated-pointer-fixture", "exec"))
pointer = HardwarePointer()
try:
    pointer.wiggle()  # A single real uinput event, not pointer-position polling.
    start = time.monotonic()
    update(stage="production-300-second-timing", passed=False, observation_cases=len(rows))
    while time.monotonic() - start < 315:
        if pids("swaylock") and stamp() not in (None, old): break
        time.sleep(.1)
    elapsed = time.monotonic() - start
    acquired = bool(pids("swaylock")) and stamp() not in (None, old)
    assert acquired and 299 <= elapsed < 312, "Production secure acquisition outside timing bounds"
    for _ in range(30):
        workers = pids("swaylock-key-au")
        if workers: break
        time.sleep(.05)
    assert workers, "No parallel key worker on production idle lock"
    status = Path(f"/proc/{next(iter(workers))}/status").read_text().splitlines()
    main = int(next(s for s in status if s.startswith("PPid:")).split()[1])
    assert main in pids("swaylock")
    os.kill(main, signal.SIGUSR1)
    time.sleep(1)
    signal_rejected = main in pids("swaylock")
    update(stage="complete-production-lock-preserved", passed=signal_rejected and not key_present(),
           observation_cases=len(rows), configured_seconds=300,
           elapsed_seconds=round(elapsed, 2), secure_acquisition=acquired,
           key_worker_running=True, no_key_present=not key_present(),
           signal_did_not_unlock=signal_rejected, password_input_injected=False)
    assert signal_rejected and not key_present()
finally:
    pointer.close()
print("Production lock preserved. Owner may now insert the authorized key and touch, or unlock with password.", flush=True)
