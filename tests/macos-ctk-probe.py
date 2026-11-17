#!/usr/bin/env python3
"""User-scoped non-login CTK probe; no pairing or real private signing keys.
Hardware verification only with --lock-touch plus native lock gates; never unlocks.
Registers only the supplied immutable probe app/extension, then unregisters them.
"""
import argparse
from datetime import datetime
import json
import os
import sys
from pathlib import Path
import plistlib
import subprocess
import time
import queue
import threading

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("bundle", type=Path)
parser.add_argument("--kind", choices=("empty", "denial", "fido", "se"), required=True)
mode = parser.add_mutually_exclusive_group()
mode.add_argument("--dispatch", action="store_true")
mode.add_argument("--recover-only", action="store_true")
mode.add_argument("--lock-touch", action="store_true")
mode.add_argument("--lock-se", action="store_true")
args = parser.parse_args()
locked_test = args.lock_touch or args.lock_se
if args.lock_se and (args.kind != "se" or not sys.stdin.isatty()):
    parser.error("Locked SE test requires the se variant and a visible local terminal.")
if args.recover_only and args.kind == "empty":
    parser.error("Recovery is restricted to the non-login fixture.")
if args.lock_touch and (args.kind != "fido" or not sys.stdin.isatty()):
    parser.error("Locked hardware test requires the fido variant and a visible local terminal.")
if os.geteuid() == 0:
    raise SystemExit("Use the logged-in ordinary user, not sudo.")
app = args.bundle.resolve(strict=True)
assert str(app).startswith("/nix/store/")
info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
identifier = f"com.keke.flakes.ctk-{args.kind}-probe"
assert info["CFBundleIdentifier"] == identifier
name = {"empty": "FlakesEmptyTokenDriver", "denial": "FlakesDenialTokenDriver", "fido": "FlakesFidoTokenDriver", "se": "FlakesSETokenDriver"}[args.kind]
extension = app / f"Contents/PlugIns/{name}.appex"
extinfo = plistlib.loads((extension / "Contents/Info.plist").read_bytes())
assert extinfo["CFBundleIdentifier"] == identifier + ".driver"
assert extinfo["NSExtension"]["NSExtensionAttributes"]["com.apple.ctk.token-type"] == "persistent"
for path in (app, app / "Contents/MacOS" / info["CFBundleExecutable"], extension):
    assert path.stat().st_uid == 0 and not path.stat().st_mode & 0o022
ls = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"


def run(command, timeout=25):
    return subprocess.run(command, capture_output=True, text=True, timeout=timeout)


def run_live(command, timeout):
    """Show the host's validated READY barrier before asking the owner to lock."""
    child = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             text=True, bufsize=1)
    lines = queue.Queue()
    output = []

    def reader():
        try:
            for line in child.stdout:
                lines.put(line)
        finally:
            lines.put(None)

    thread = threading.Thread(target=reader, daemon=True)
    thread.start()
    deadline = time.monotonic() + timeout
    try:
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise subprocess.TimeoutExpired(command, timeout, output="".join(output))
            try:
                line = lines.get(timeout=min(0.1, remaining))
            except queue.Empty:
                continue
            if line is None:
                break
            output.append(line)
            print(line, end="", flush=True)
        code = child.wait(timeout=max(0.1, deadline - time.monotonic()))
        return subprocess.CompletedProcess(command, code, "".join(output), "")
    except BaseException:
        if child.poll() is None:
            child.kill()  # Only the Popen child, never a locker/auth daemon.
        child.wait(timeout=2)
        raise
    finally:
        thread.join(timeout=0.2)
        if not thread.is_alive():
            child.stdout.close()


def matches():
    return run(["/usr/bin/pluginkit", "-m", "-i", identifier + ".driver"]).stdout.strip()


check = run(["/usr/bin/codesign", "--verify", "--strict", "--deep", str(app)])
assert check.returncode == 0, check.stderr
assert not matches(), "Existing registration; not altering it."
observed_at = datetime.now().astimezone()
started = observed_at.strftime("%Y-%m-%d %H:%M:%S")
result = None
try:
    assert run([ls, "-f", str(app)]).returncode == 0
    assert run(["/usr/bin/pluginkit", "-a", str(extension)]).returncode == 0
    host = [str(app / "Contents/MacOS" / info["CFBundleExecutable"])]
    for _ in range(5):
        time.sleep(2)
        discovery = run(host)
        if discovery.returncode == 0 or (args.recover_only and discovery.returncode == 4):
            break
    else:
        raise RuntimeError("Host configuration not available: " + discovery.stdout)
    if args.dispatch or args.recover_only or locked_test:
        option = "--cleanup-own-fixture" if args.recover_only else (
            "--dispatch-locked-se" if args.lock_se else (
                "--dispatch-locked-fido" if args.lock_touch else (
                    "--empty-instance" if args.kind == "empty" else "--dispatch-denial")))
        if locked_test:
            print("Preparing reference: keep the screen UNLOCKED until the host prints READY_TO_LOCK. No PIN/password goes into this terminal.", flush=True)
        try:
            result = run_live(host + [option], timeout=135) if locked_test else run(host + [option])
        except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
            if args.kind in ("denial", "fido", "se"):
                recovery = run(host + ["--cleanup-own-fixture"])
                print("Own non-login fixture recovery after timeout:", recovery.stdout.strip())
                assert recovery.returncode == 0, "Recovery needs review; do not touch other token classes."
            raise RuntimeError("Own probe timed out/interrupted; this is NOT a passing rejection test.") from error
        if not locked_test:
            print(result.stdout, end="")
        if result.stderr:
            print(result.stderr[:2000])
    remaining = run(host)
    print("Post-test own configuration readback:", remaining.stdout.strip())
    assert remaining.returncode == 0, "Configuration remains; inspect only this probe class."
finally:
    removed = run(["/usr/bin/pluginkit", "-r", str(extension)])
    unlisted = run([ls, "-u", str(app)])
    assert removed.returncode == 0 and unlisted.returncode == 0
    assert not matches(), "Probe registration cleanup needs review."
    print("Probe registration removed; no other drivers/settings changed.")
if args.kind in ("denial", "fido", "se"):
    logs = run(["/usr/bin/log", "show", "--start", started, "--style", "json",
                "--predicate", f'subsystem == "com.keke.flakes.ctk-{args.kind}"'])
    events = []
    for row in json.loads(logs.stdout or "[]"):
        # log's CLI takes whole seconds; exclude the preceding run in that second.
        if datetime.fromisoformat(row["timestamp"]) < observed_at:
            continue
        events.append(row.get("eventMessage"))
        print(row.get("timestamp"), row.get("eventMessage"))
    if (args.dispatch or locked_test) and result is not None and result.returncode == 0:
        records = [json.loads(line) for line in result.stdout.splitlines() if line.startswith("{")]
        attempts = [r for r in records if "attempt" in r]
        count = 2 if args.kind == "denial" else 1
        assert len(attempts) == count
        limit = 25000 if locked_test else 2000
        assert all(not r["signature_produced"] and r["error_code"] == -4 and r["elapsed_ms"] < limit for r in attempts)
        assert any(r.get("own_token_advertised_after_cleanup") is False for r in records)
        assert events.count("begin_auth_no_password_operation") == count, events
        assert events.count("finish_without_pin_CANCELLED") == count, events
        if args.kind == "fido":
            if args.lock_touch:
                if events.count("hardware_signature_VERIFIED_native_signature_STILL_DENIED") != 1:
                    reason = "native lock gate closed; hardware authentication did not start" if "hardware_gate_CLOSED_no_auth" in events else "hardware verification was not established"
                    print("NOT VERIFIED:", reason, "; native signature denied, fixture cleaned, no screen-unlock result.")
                    raise SystemExit(13)
            else:
                assert events.count("hardware_not_opted_in_no_auth") == 1
                assert "hardware_worker_started_after_native_lock" not in events
                assert events.count("sandbox_fido_selfcheck_PASSED_no_auth") == 1, events
        if args.kind == "se":
            required = "se_locked_primitives_PASSED_native_output_STILL_DENIED" if args.lock_se else "se_creation_selfcheck_PASSED_no_operations"
            assert events.count(required) == 1, events
            assert events.count("se_ephemeral_enclave_key_created_no_private_export") == 1, events
            assert events.count("se_own_tag_keychain_lookup_status_-25300") == 1, events
            assert events.count("se_test_key_reference_released") == 1, events
            assert events.count("se_released_own_tag_lookup_status_-25300") == 1, events
        print("PASS: no native signature, terminal cancellation, no retained token; requested scope checked.")
if result is not None:
    raise SystemExit(result.returncode)
