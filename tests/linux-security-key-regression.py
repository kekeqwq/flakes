#!/usr/bin/env python3
"""Opt-in local password/locker acceptance. Secret comes only from stdin.

Run as keke inside a dedicated transient user service. Never logs passwords,
changes boot defaults, kills a locker to recover, or types into user windows.
The only typing target is this test's securely acquired compositor lock.
"""
import argparse
import ast
import fcntl
import json
import os
from pathlib import Path
import shutil
import signal
import struct
import subprocess as sp
import sys
import time

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--candidate", required=True)
p.add_argument("--report", required=True)
p.add_argument("--zenity", required=True)
p.add_argument("--password-stdin", required=True, action="store_true")
p.add_argument("--skip-activation", action="store_true")
args = p.parse_args()
os.umask(0o077)
password = sys.stdin.readline().rstrip("\r\n")
assert password and password.isascii() and all(32 <= ord(c) <= 126 for c in password), "ASCII password required for isolated uinput fixture"
for line in sp.check_output(["systemctl", "--user", "show-environment"], text=True).splitlines():
    k, _, v = line.partition("=")
    if k in {"DISPLAY", "WAYLAND_DISPLAY", "XDG_RUNTIME_DIR", "NIRI_SOCKET", "DBUS_SESSION_BUS_ADDRESS"}:
        os.environ[k] = v
scope = Path("/proc/self/cgroup").read_text()
assert "flakes-key-acceptance" in scope, "Use a dedicated flakes-key-acceptance transient unit"
results = []
report = Path(args.report)

def record(name, passed, **details):
    row = {"case": name, "passed": bool(passed), **details}
    results.append(row)
    temporary = report.with_suffix(".tmp")
    temporary.write_text(json.dumps(results, indent=2) + "\n")
    temporary.replace(report)
    print(json.dumps(row), flush=True)
    assert passed, "Failed: " + name

def processes(names, owned=False):
    found = []
    for entry in Path("/proc").iterdir():
        if not entry.name.isdecimal(): continue
        try:
            status = (entry / "status").read_text().splitlines()
            uid = int(next(s for s in status if s.startswith("Uid:")).split()[1])
            state = next(s for s in status if s.startswith("State:")).split()[1]
            if uid != os.getuid() or state == "Z": continue
            if (entry / "comm").read_text().strip() not in names: continue
            if owned and (entry / "cgroup").read_text() != scope: continue
            found.append(int(entry.name))
        except (FileNotFoundError, PermissionError, ProcessLookupError): pass
    return found

def lockers(owned=False): return processes({"swaylock"}, owned)
def workers(): return processes({"swaylock-key-au"}, True)
def quiet(*cmd): return sp.run(cmd, stdout=sp.PIPE, stderr=sp.PIPE, check=True)

def wait_clear(seconds=4):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if not lockers(True) and not workers(): return True
        time.sleep(.03)
    return False

assert not lockers(), "Existing locker: unlock manually before testing"
if not args.skip_activation:
    candidate = Path(args.candidate).resolve()
    assert (candidate / "bin/switch-to-configuration").is_file()
    result = sp.run(["sudo", "-S", "-p", "", str(candidate / "bin/switch-to-configuration"), "test"],
                    input=(password + "\n").encode(), stdout=sp.PIPE, stderr=sp.STDOUT, timeout=180)
    report.with_suffix(".activation.log").write_bytes(result.stdout)
    record("temporary-activation", result.returncode == 0 and Path("/run/current-system").resolve() == candidate)
assert not lockers(), "A locker appeared during activation; do not stop its service"
quiet("systemctl", "--user", "stop", "swayidle.service")

# Reuse only the two existing fixture class definitions; do not execute that
# script's CLI or its video/idle regression main program.
source = Path(__file__).with_name("linux-idle-regression.py").read_text()
classes = [n for n in ast.parse(source).body if isinstance(n, ast.ClassDef) and n.name in {"HardwareKeyboard", "HardwarePointer"}]
assert len(classes) == 2
exec(compile(ast.Module(body=classes, type_ignores=[]), "isolated-uinput-fixtures", "exec"))
keyboard = pointer = catcher = None
catcher_id = None
marker = Path(os.environ["XDG_RUNTIME_DIR"]) / "screen-lock.ready"
command = shutil.which("screen-lock")
assert command

def stamp():
    try:
        st = marker.stat()
        return st.st_ino, st.st_mtime_ns
    except FileNotFoundError: return None

def acquire():
    assert not lockers(), "Unexpected existing locker; do not inject input"
    assert catcher and catcher.poll() is None and catcher_id is not None
    quiet("niri", "msg", "action", "focus-window", "--id", str(catcher_id))
    focused = json.loads(quiet("niri", "msg", "--json", "focused-window").stdout)
    assert focused and focused["id"] == catcher_id, "No isolated input catcher"
    previous = stamp()
    start = time.monotonic()
    sp.run([command], check=True, stdout=sp.DEVNULL, timeout=8)
    assert stamp() not in (None, previous) and lockers(True), "No secure, owned lock acquisition"
    return time.monotonic() - start

def guarded_input(action):
    assert lockers(True) and marker.exists(), "No secured owned locker: no input sent"
    action()

try:
    keyboard = HardwareKeyboard()
    pointer = HardwarePointer()
    # If an unexpected physical touch unlocks while a test is typing, input
    # lands only in this disposable password field, never a chat or shell.
    catcher = sp.Popen([args.zenity, "--password",
                        "--title=Flakes isolated lock-test input catcher"],
                       stdout=sp.DEVNULL, stderr=sp.DEVNULL, start_new_session=True)
    for _ in range(80):
        windows = json.loads(quiet("niri", "msg", "--json", "windows").stdout)
        match = next((w for w in windows if w.get("pid") == catcher.pid), None)
        if match:
            catcher_id = match["id"]
            break
        assert catcher.poll() is None, "Input catcher exited"
        time.sleep(.1)
    assert catcher_id is not None, "No isolated input catcher window"
    record("secure-acquisition", acquire() < 3)
    deadline = time.monotonic() + 3
    while not workers() and time.monotonic() < deadline: time.sleep(.05)
    record("parallel-key-worker-running", bool(workers()))
    worker_status = Path(f"/proc/{workers()[0]}/status").read_text().splitlines()
    main_pid = int(next(line for line in worker_status if line.startswith("PPid:")).split()[1])
    assert main_pid in lockers(True), "No owned compositor-facing locker"
    os.kill(main_pid, signal.SIGUSR1)
    time.sleep(.25)
    record("signal-is-not-authentication", main_pid in lockers(True))
    before = stamp(); old = set(lockers(True))
    result = sp.run([command], stdout=sp.DEVNULL, timeout=3)
    record("singleton-held", result.returncode == 0 and stamp() == before and set(lockers(True)) == old)
    guarded_input(pointer.click)
    time.sleep(.25)
    record("mouse-does-not-unlock", bool(lockers(True)))
    guarded_input(lambda: keyboard.press(28))
    time.sleep(.25)
    record("empty-enter-does-not-unlock", bool(lockers(True)))
    wrong = "flakes-fixture-wrong-password"
    if wrong == password: wrong += "x"
    guarded_input(lambda: keyboard.type_password(wrong))
    time.sleep(3.5)
    record("wrong-password-rejected", bool(lockers(True)))
    guarded_input(keyboard.clear_password)
    start = time.monotonic()
    guarded_input(lambda: keyboard.type_password(password))
    clear = wait_clear(4)
    record("password-while-key-waits", clear and time.monotonic() - start < 3,
           elapsed_seconds=round(time.monotonic() - start, 3))
    record("worker-cleanup", not workers())
    # No FD-9 leak or stale hardware notification may prevent an immediate new
    # secure lock, or authorize it using the previous session's result.
    record("immediate-relock", acquire() < 3)
    time.sleep(.5)
    record("no-stale-key-proof", bool(lockers(True)))
    guarded_input(lambda: keyboard.type_password(password))
    record("relock-password-unlock", wait_clear(4))
finally:
    if keyboard: keyboard.close()
    if pointer: pointer.close()
    if catcher and catcher.poll() is None:
        catcher.terminate()
        catcher.wait(timeout=5)
    # Starting idle does not kill this separate test cgroup. Never stop/restart
    # a service containing an active locker, nor signal a locker to recover.
    sp.run(["systemctl", "--user", "start", "swayidle.service"], stdout=sp.DEVNULL, stderr=sp.DEVNULL)
print("Password-path regression complete. Hardware-touch acceptance still pending.", flush=True)
