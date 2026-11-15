#!/usr/bin/env python3
"""Opt-in real Niri idle regression. Isolated apps; never types in existing windows.

First run observes actual compositor idle notifications without locking. Use the
same swayidle binary as the deployment. Playback is genuine generated local video,
not a fake inhibitor or a fullscreen-window exemption. No account data is copied.
"""
import argparse
import functools
import fcntl
import http.server
import json
import os
from pathlib import Path
import shlex
import signal
import socket
import subprocess as sp
import struct
import sys
import tempfile
import threading
import time

if len(sys.argv) in (3, 4) and sys.argv[1] == "--record":
    if len(sys.argv) == 4:
        sp.run([sys.argv[3]], check=True)  # daemon returns only when securely locked
    with open(sys.argv[2], "a") as out:
        out.write(f"{time.monotonic()}\n")
    sys.exit(0)

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tools-file", required=True)
parser.add_argument("--timeout", type=int, default=5)
parser.add_argument("--report", required=True)
parser.add_argument("--lock-command", help="Actual deployed screen-lock executable; stop production swayidle first")
parser.add_argument("--password-stdin", action="store_true", help="Read unlock password from stdin, never argv/files")
parser.add_argument("--production-seconds", type=int, default=0, help="Also time the actual production swayidle service (normally 300)")
args = parser.parse_args()
assert args.timeout >= 3
password = sys.stdin.readline().rstrip("\r\n") if args.password_stdin else None
assert not args.lock_command or password, "real-lock tests require --password-stdin"
assert not args.production_seconds or args.lock_command, "production timing requires real-lock mode"
os.environ["IDLE_REGRESSION_TOKEN"] = f"{os.getpid()}-{time.monotonic_ns()}"
for line in sp.check_output(["systemctl", "--user", "show-environment"], text=True).splitlines():
    key, _, value = line.partition("=")
    if key in {"WAYLAND_DISPLAY", "DISPLAY", "NIRI_SOCKET", "DBUS_SESSION_BUS_ADDRESS", "XDG_RUNTIME_DIR"}:
        os.environ[key] = value
assert os.environ.get("NIRI_SOCKET"), "run in the Niri desktop session"
roots = Path(args.tools_file).read_text().splitlines()
def tool(name):
    return next((str(Path(root) / "bin" / name) for root in roots if (Path(root) / "bin" / name).is_file()), name)
def run(*cmd, **kwargs):
    return sp.run(cmd, check=True, stdout=sp.PIPE, stderr=sp.PIPE, **kwargs)
def ipc(verb):
    return json.loads(run("niri", "msg", "--json", verb).stdout)
def action(*items):
    run("niri", "msg", "action", *map(str, items))
def reset_input():
    pointer.wiggle()
def focus(window):
    action("focus-window", "--id", window)
    time.sleep(.25)
    assert (ipc("focused-window") or {}).get("id") == window, "test window lost focus; no typing allowed"
def own_window(process, app_id):
    for _ in range(100):
        for window in ipc("windows"):
            if window.get("pid") == process.pid or window.get("app_id") == app_id:
                return window["id"]
        if process.poll() is not None:
            raise RuntimeError(f"fixture exited early ({process.returncode}): {app_id}")
        time.sleep(.1)
    raise RuntimeError(f"fixture window missing: {app_id}")

class HardwareKeyboard:
    """Use real kernel input: virtual-keyboard-v1 events need not reset idle."""
    def __init__(self):
        self.fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
        fcntl.ioctl(self.fd, 0x40045564, 1)  # UI_SET_EVBIT(EV_KEY)
        for code in range(1, 256):
            fcntl.ioctl(self.fd, 0x40045565, code)  # UI_SET_KEYBIT
        setup = struct.pack("HHHH80sI", 3, 1, 1, 1, b"flakes-idle-regression-keyboard", 0)
        fcntl.ioctl(self.fd, 0x405C5503, setup)  # UI_DEV_SETUP
        fcntl.ioctl(self.fd, 0x5501)  # UI_DEV_CREATE
        time.sleep(1.5)  # allow udev/libinput to discover this test-only keyboard
    def key(self, code, value):
        events = [(1, code, value), (0, 0, 0)]
        os.write(self.fd, b"".join(struct.pack("llHHi", 0, 0, *event) for event in events))
    def press(self, code):
        self.key(code, 1); self.key(code, 0)
    def press_a(self):
        self.press(30)
    def clear_password(self):
        self.key(29, 1); self.press(22); self.key(29, 0)  # Ctrl+U
    def type_password(self, text):
        letters = dict(zip("qwertyuiopasdfghjklzxcvbnm", [16,17,18,19,20,21,22,23,24,25,30,31,32,33,34,35,36,37,38,44,45,46,47,48,49,50]))
        digits = dict(zip("1234567890", range(2, 12)))
        plain = {**letters, **digits, " ":57, "-":12, "=":13, "[":26, "]":27, ";":39, "'":40, "`":41, "\\":43, ",":51, ".":52, "/":53}
        shifted = dict(zip("!@#$%^&*()_+{}:\"~|<>?", [2,3,4,5,6,7,8,9,10,11,12,13,26,27,39,40,41,43,51,52,53]))
        for char in text:
            shift = char.isupper() or char in shifted
            code = shifted.get(char, plain.get(char.lower()))
            if code is None:
                raise ValueError("This physical keyboard fixture requires a US-layout ASCII password")
            if shift: self.key(42, 1)
            self.press(code)
            if shift: self.key(42, 0)
            time.sleep(.025)
        self.press(28)  # Enter
    def close(self):
        fcntl.ioctl(self.fd, 0x5502)  # UI_DEV_DESTROY
        os.close(self.fd)

class HardwarePointer:
    def __init__(self):
        self.fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
        for kind in (1, 2): fcntl.ioctl(self.fd, 0x40045564, kind)  # KEY, REL
        for code in (272, 273): fcntl.ioctl(self.fd, 0x40045565, code)
        for axis in (0, 1): fcntl.ioctl(self.fd, 0x40045566, axis)
        setup = struct.pack("HHHH80sI", 3, 1, 2, 1, b"flakes-idle-regression-pointer", 0)
        fcntl.ioctl(self.fd, 0x405C5503, setup)
        fcntl.ioctl(self.fd, 0x5501)
        time.sleep(1)
    def wiggle(self):
        events = [(2, 0, 1), (0, 0, 0), (2, 0, -1), (0, 0, 0)]
        os.write(self.fd, b"".join(struct.pack("llHHi", 0, 0, *event) for event in events))
    def click(self):
        events = [(1, 272, 1), (0, 0, 0), (1, 272, 0), (0, 0, 0)]
        os.write(self.fd, b"".join(struct.pack("llHHi", 0, 0, *event) for event in events))
    def close(self):
        fcntl.ioctl(self.fd, 0x5502)
        os.close(self.fd)

results = []
processes = []
with tempfile.TemporaryDirectory(prefix="idle-regression-", dir=os.environ["XDG_RUNTIME_DIR"]) as directory:
    work = Path(directory)
    def spawn(name, command):
        log = open(work / f"{name}.log", "wb")
        process = sp.Popen(command, stdout=log, stderr=log, start_new_session=True)
        log.close()
        processes.append(process)
        return process
    def stop(process):
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=8)
            except sp.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
    manual_lockers = set()
    test_cgroup = Path("/proc/self/cgroup").read_text()
    def locker_uid(entry):
        # Hardened lockers are nondumpable: /proc/<pid> can be root-owned even
        # though the process still runs as keke. Read its actual UID instead.
        status = (entry / "status").read_text()
        return int(next(line for line in status.splitlines() if line.startswith("Uid:")).split()[1])
    def all_lockers():
        found = []
        for entry in Path("/proc").iterdir():
            if not entry.name.isdecimal(): continue
            try:
                if (entry / "stat").read_text().rsplit(")", 1)[1].split()[0] == "Z": continue
                if locker_uid(entry) == os.getuid() and (entry / "comm").read_text().strip() == "swaylock": found.append(int(entry.name))
            except (FileNotFoundError, PermissionError, ProcessLookupError): pass
        return found
    def owned_lockers():
        token = ("IDLE_REGRESSION_TOKEN=" + os.environ["IDLE_REGRESSION_TOKEN"]).encode()
        found = []
        for entry in Path("/proc").iterdir():
            if not entry.name.isdecimal(): continue
            try:
                if (entry / "stat").read_text().rsplit(")", 1)[1].split()[0] == "Z": continue
                if locker_uid(entry) != os.getuid() or (entry / "comm").read_text().strip() != "swaylock": continue
                # A transient test unit/cgroup owns its observer-spawned lockers;
                # hotkey/production lockers additionally require explicit PID
                # tracking after secure acquisition. Do not require reading the
                # nondumpable locker's protected environment.
                if int(entry.name) in manual_lockers or (entry / "cgroup").read_text() == test_cgroup:
                    found.append(int(entry.name))
                elif token in (entry / "environ").read_bytes().split(b"\0"):
                    found.append(int(entry.name))
            except (FileNotFoundError, PermissionError, ProcessLookupError):
                pass
        return found
    auth_checks = {"singleton_held": None, "click_does_not_unlock": None, "wrong_password_rejected": None}
    def unlock_owned(allow_auth=True):
        if not args.lock_command or not owned_lockers(): return True
        if not allow_auth:
            # A failure must leave the secure lock intact for manual recovery,
            # not bypass authentication with a signal or terminate its cgroup.
            return False
        if auth_checks["singleton_held"] is None:
            existing = set(owned_lockers())
            marker = Path(os.environ["XDG_RUNTIME_DIR"]) / "screen-lock.ready"
            before = marker.stat().st_mtime_ns
            duplicate = sp.run([args.lock_command], stdout=sp.DEVNULL, stderr=sp.PIPE, timeout=3)
            auth_checks["singleton_held"] = duplicate.returncode == 0 and existing == set(owned_lockers()) and marker.stat().st_mtime_ns == before
            if not auth_checks["singleton_held"]: return False
        if auth_checks["click_does_not_unlock"] is None:
            pointer.click()
            time.sleep(.25)
            auth_checks["click_does_not_unlock"] = bool(owned_lockers())
            if not owned_lockers(): return False
        if auth_checks["wrong_password_rejected"] is None:
            keyboard.clear_password()
            incorrect = "idle-regression-wrong-password"
            if incorrect == password: incorrect += "x"
            keyboard.type_password(incorrect)
            time.sleep(3.5)
            auth_checks["wrong_password_rejected"] = bool(owned_lockers())
            if not owned_lockers(): return False
        keyboard.clear_password()
        keyboard.type_password(password)
        for _ in range(80):
            if not owned_lockers(): return True
            time.sleep(.1)
        # Authentication failure: retain the lock for manual recovery.
        return False
    def sample(name, expect_idle, activity=None, playback=None):
        reset_input()
        event_file = work / (name + ".events")
        callback_args = [sys.executable, str(Path(__file__).resolve()), "--record", str(event_file)]
        if args.lock_command: callback_args.append(args.lock_command)
        callback = shlex.join(callback_args)
        observer = spawn("observer-" + name, [tool("swayidle"), "-w", "timeout", str(args.timeout), callback])
        started = time.monotonic()
        duration = args.timeout + 4 if expect_idle else args.timeout * 2 + 2
        playback_checks = 0
        last_playback = playback() if playback else None
        last_probe = started
        try:
            while time.monotonic() - started < duration:
                if playback and time.monotonic() - last_probe >= 1:
                    current = playback()
                    assert not current["paused"] and current["position"] != last_playback["position"], "video stopped progressing during the case"
                    last_playback, last_probe = current, time.monotonic()
                    playback_checks += 1
                if activity:
                    activity()
                if observer.poll() is not None:
                    raise RuntimeError("swayidle exited before the observation ended")
                if event_file.exists():
                    break
                time.sleep(.15)
            elapsed = time.monotonic() - started
            fired = event_file.exists()
            ok = fired == expect_idle and (not expect_idle or elapsed >= args.timeout - .4)
            row = {"case": name, "expected_idle": expect_idle, "observed_idle": fired, "elapsed_seconds": round(elapsed, 2), "pass": ok}
            if playback:
                row["playback_checks"] = playback_checks
                row["pass"] = row["pass"] and playback_checks >= args.timeout
            if args.lock_command and not fired and owned_lockers():
                row["unconfirmed_locker_present"] = True
                row["pass"] = False
            if args.lock_command and fired:
                row["real_locker_present"] = bool(owned_lockers())
                row["password_unlock"] = unlock_owned()
                row.update(auth_checks)
                row["pass"] = row["pass"] and row["real_locker_present"] and row["password_unlock"] and all(auth_checks.values())
            results.append(row)
            print(json.dumps(row), flush=True)
        finally:
            if args.lock_command: unlock_owned(allow_auth=False)
            stop(observer)
    def key_activity():
        assert (ipc("focused-window") or {}).get("id") == keys_window, "test window lost focus; typing aborted"
        keyboard.press_a()
    def mpv_property(name):
        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        client.settimeout(3)
        client.connect(str(work / "mpv.sock"))
        client.sendall((json.dumps({"command": ["get_property", name], "request_id": 1}) + "\n").encode())
        with client.makefile("r") as stream:
            for line in stream:
                reply = json.loads(line)
                if reply.get("request_id") == 1:
                    client.close()
                    assert reply.get("error") == "success", reply
                    return reply.get("data")
        raise RuntimeError("mpv IPC returned no property")
    def mpv_pause():
        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        client.connect(str(work / "mpv.sock"))
        client.sendall(b'{"command":["set_property","pause",true]}\n')
        client.close()
    keyboard = HardwareKeyboard()
    pointer = HardwarePointer()
    try:
        assert not args.lock_command or not all_lockers(), "unlock first and stop production swayidle before real-lock tests"
        run(tool("ffmpeg"), "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc2=size=640x360:rate=24", "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo", "-t", "60", "-c:v", "libx264", "-preset", "ultrafast", "-crf", "30", "-threads", "2", "-c:a", "aac", "-shortest", str(work / "video.mp4"))
        keys = spawn("keys", ["ghostty", "--gtk-single-instance=false", "--class=org.flakes.IdleKeys", "-e", "sh", "-c", "exec cat >/dev/null"])
        keys_window = own_window(keys, "org.flakes.IdleKeys")
        focus(keys_window)
        sample("genuinely-idle", True)
        sample("mouse-moving", False, reset_input)
        sample("mouse-stopped", True)
        focus(keys_window)
        sample("keyboard-typing", False, key_activity)
        sample("keyboard-stopped", True)
        player = spawn("mpv", [tool("mpv"), "--no-config", "--stop-screensaver=yes", "--gpu-context=wayland", "--volume=0", "--loop-file=inf", "--wayland-app-id=org.flakes.IdleVideo", f"--input-ipc-server={work / 'mpv.sock'}", str(work / "video.mp4")])
        video_window = own_window(player, "org.flakes.IdleVideo")
        focus(video_window)
        time.sleep(1)
        before = mpv_property("time-pos")
        time.sleep(.7)
        assert not mpv_property("pause") and mpv_property("time-pos") != before, "mpv is not actually playing"
        mpv_playback = lambda: {"paused": mpv_property("pause"), "position": mpv_property("time-pos")}
        sample("mpv-window-playing", False, playback=mpv_playback)
        focus(video_window)
        action("fullscreen-window")
        time.sleep(.4)
        assert mpv_property("fullscreen"), "mpv never entered real fullscreen"
        sample("mpv-fullscreen-playing", False, playback=mpv_playback)
        mpv_pause()
        time.sleep(.4)
        assert mpv_property("pause"), "mpv did not pause"
        sample("mpv-paused", True)
        stop(player)
        focus(keys_window)
        sample("video-stopped", True)
        action("fullscreen-window")
        sample("static-fullscreen-is-idle", True)
        action("fullscreen-window")

        control = {"pause": False, "muted": False}
        class Handler(http.server.SimpleHTTPRequestHandler):
            def log_message(self, *unused):
                pass
            def do_GET(self):
                if self.path == "/control":
                    data = json.dumps(control).encode()
                    self.send_response(200); self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data)
                else:
                    super().do_GET()
        (work / "index.html").write_text('''<!doctype html><style>body{margin:0;background:#1e1e2e}video{width:100vw;height:100vh}</style><video id="v" autoplay loop controls src="/video.mp4"></video><script>
        setInterval(async()=>{const c=await(await fetch('/control')).json();v.muted=c.muted;if(c.pause&&!v.paused)v.pause();else if(!c.pause&&v.paused)v.play();document.title=JSON.stringify({paused:v.paused,muted:v.muted,time:v.currentTime,outer:[outerWidth,outerHeight],screen:[screen.width,screen.height]});},250);
        </script>''')
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Handler, directory=str(work)))
        threading.Thread(target=server.serve_forever, daemon=True).start()
        browser = spawn("chrome", ["google-chrome-stable", f"--user-data-dir={work / 'chrome-profile'}", "--class=org.flakes.IdleChrome", "--ozone-platform=wayland", "--no-first-run", "--no-default-browser-check", "--disable-background-networking", "--disable-component-update", "--disable-sync", "--mute-audio", "--autoplay-policy=no-user-gesture-required", f"--app=http://127.0.0.1:{server.server_port}/index.html"])
        browser_window = own_window(browser, "org.flakes.IdleChrome")
        focus(browser_window)
        def browser_state():
            title = next(w.get("title", "") for w in ipc("windows") if w["id"] == browser_window)
            start = title.find('{"paused":')
            assert start >= 0, "video fixture has not reported state"
            return json.JSONDecoder().raw_decode(title[start:])[0]
        for _ in range(40):
            try:
                first = browser_state()
                if not first["paused"] and first["time"] > .3:
                    break
            except (AssertionError, ValueError):
                pass
            time.sleep(.25)
        first = browser_state(); time.sleep(.7); second = browser_state()
        assert not second["paused"] and first["time"] != second["time"], "Chrome is not actually playing"
        assert second["outer"] != second["screen"], "Chrome window case was accidentally fullscreen"
        chrome_playback = lambda: {"paused": browser_state()["paused"], "position": browser_state()["time"]}
        sample("chrome-window-playing", False, playback=chrome_playback)
        control["muted"] = True
        time.sleep(.5)
        assert browser_state()["muted"], "Chrome did not mute the video element"
        sample("chrome-window-playing-muted", False, playback=chrome_playback)
        focus(browser_window)
        action("fullscreen-window")
        time.sleep(.4)
        assert browser_state()["outer"] == browser_state()["screen"], "Chrome never filled the screen"
        sample("chrome-fullscreen-playing-muted", False, playback=chrome_playback)
        control["muted"] = False
        time.sleep(.5)
        assert not browser_state()["muted"], "Chrome did not unmute the video element"
        sample("chrome-fullscreen-playing", False, playback=chrome_playback)
        control["pause"] = True
        for _ in range(30):
            if browser_state()["paused"]:
                break
            time.sleep(.1)
        assert browser_state()["paused"], "Chrome did not pause"
        sample("chrome-paused", True)
        stop(browser)
        server.shutdown()
        focus(keys_window)
        sample("all-playback-stopped", True)
        if args.lock_command:
            focus(keys_window)
            assert not all_lockers(), "another locker appeared; manual shortcut test aborted"
            ready_file = Path(os.environ["XDG_RUNTIME_DIR"]) / "screen-lock.ready"
            def ready_stamp():
                try:
                    info = ready_file.stat()
                    return info.st_ino, info.st_mtime_ns
                except FileNotFoundError: return None
            before_ready = ready_stamp()
            started = time.monotonic()
            keyboard.key(125, 1); keyboard.press(38); keyboard.key(125, 0)  # Win+L
            secured = False
            for _ in range(40):
                if all_lockers() and ready_stamp() not in (None, before_ready):
                    secured = True
                    break
                time.sleep(.1)
            elapsed = time.monotonic() - started
            manual_lockers.update(all_lockers())
            present = bool(manual_lockers)
            unlocked = unlock_owned() if present and secured else False
            # No secure-acquisition confirmation means no password injection
            # and no signal-based recovery. The test must fail closed.
            row = {"case": "win-l-immediate-lock", "elapsed_seconds": round(elapsed, 2), "real_locker_present": present, "secure_ready": secured, "password_unlock": unlocked, "pass": present and secured and unlocked and elapsed < 3}
            results.append(row); print(json.dumps(row), flush=True)
            if args.production_seconds:
                assert not all_lockers(), "unlock before production timing"
                command = run("systemctl", "--user", "show", "swayidle.service", "-p", "ExecStart", "--value").stdout.decode()
                assert f"timeout {args.production_seconds} " in command, "production timeout does not match the requested check"
                before_ready = ready_stamp()
                reset_input()
                run("systemctl", "--user", "start", "swayidle.service")
                run("systemctl", "--user", "is-active", "swayidle.service")
                started = time.monotonic()
                print(json.dumps({"production_timing_started": args.production_seconds}), flush=True)
                secured = False
                while time.monotonic() - started < args.production_seconds + 12:
                    if all_lockers() and ready_stamp() not in (None, before_ready):
                        secured = True
                        break
                    time.sleep(.2)
                elapsed = time.monotonic() - started
                manual_lockers.update(all_lockers())
                present = bool(manual_lockers.intersection(all_lockers()))
                unlocked = unlock_owned() if present and secured else False
                row = {"case": "production-idle-timeout", "configured_seconds": args.production_seconds, "elapsed_seconds": round(elapsed, 2), "secure_ready": secured, "password_unlock": unlocked, "pass": secured and unlocked and args.production_seconds - 1 <= elapsed < args.production_seconds + 12}
                results.append(row); print(json.dumps(row), flush=True)
                # A real password/key unlock must precede
                # stopping this service: its cgroup can contain the locker.
                if not all_lockers(): run("systemctl", "--user", "stop", "swayidle.service")
    finally:
        if args.lock_command: unlock_owned(allow_auth=False)
        keyboard.close()
        pointer.close()
        for process in reversed(processes):
            stop(process)
        Path(args.report).write_text(json.dumps(results, indent=2) + "\n")

if not results or not all(row["pass"] for row in results):
    sys.exit(1)
