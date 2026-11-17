#!/usr/bin/env python3
"""Consented, storage-only SE round trip. Never pairs accounts or exports private keys.
State contains ONLY own-tag/public metadata; retained privately for narrow recovery.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import shutil
import stat
import subprocess
import tempfile
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("app", type=Path)
parser.add_argument("--recover", type=Path)
args = parser.parse_args()
if os.getuid() == 0 or os.geteuid() != os.getuid():
    parser.error("Use the ordinary logged-in user, never sudo.")
app = args.app.resolve(strict=True)
assert str(app).startswith("/nix/store/")
exe = app / "Contents/MacOS/se-store-probe"
for path in (app, exe):
    s = path.stat()
    assert s.st_uid == 0 and not s.st_mode & 0o022
subprocess.run(["/usr/bin/codesign", "--verify", "--strict", str(app)], check=True, capture_output=True)
digest = hashlib.sha256(exe.read_bytes()).hexdigest()

def private(path, directory=False):
    s = path.lstat()
    assert s.st_uid == os.getuid() and not s.st_mode & 0o077
    assert stat.S_ISDIR(s.st_mode) if directory else stat.S_ISREG(s.st_mode)

if args.recover:
    directory = args.recover.absolute()
    private(directory, True)
    private(directory / "state.json")
    state = json.loads((directory / "state.json").read_text())
    assert state["uid"] == os.getuid() and state["executable"] == str(exe)
    assert state["sha256"] == digest and state["vacant_before_create"] and state["creation_attempted"]
    assert not state.get("deleted_verified"), "Already cleaned; refusing unnecessary recovery."
else:
    base = Path.home() / "Library/Application Support/flakes/se-store-probe"
    base.mkdir(mode=0o700, parents=True, exist_ok=True)
    private(base, True)
    identifier = str(uuid.uuid4()).upper()
    directory = base / ("run." + identifier)
    directory.mkdir(mode=0o700)
    state = {"uid": os.getuid(), "executable": str(exe), "sha256": digest,
             "tag": f"com.keke.flakes.se-store-test.v1.{os.getuid()}.{identifier}",
             "vacant_before_create": False, "creation_attempted": False,
             "creation_completed": False, "deleted_verified": False, "events": []}

# Only a public own-tag identifier/fingerprint, never a key blob/reference/secret.
prefix = f"com.keke.flakes.se-store-test.v1.{os.getuid()}."
assert state["tag"].startswith(prefix)
assert str(uuid.UUID(state["tag"][len(prefix):])).upper() == state["tag"][len(prefix):]

def save():
    fd, name = tempfile.mkstemp(prefix=".state.", dir=directory)
    path = Path(name)
    with os.fdopen(fd, "w") as stream:
        json.dump(state, stream, indent=2)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(path, directory / "state.json")
    fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)

def invoke(operation, fingerprint=None):
    request = {"operation": operation, "tag": state["tag"]}
    if fingerprint is not None:
        request["public_sha256"] = fingerprint
    result = subprocess.run([str(exe)], input=json.dumps(request), capture_output=True,
                            text=True, timeout=15)
    rows = [json.loads(line) for line in result.stdout.splitlines()]
    allowed = {"stage", "status", "pid", "public_sha256", "private_exported", "signing_attempted"}
    assert all(set(row) <= allowed for row in rows)
    # Keep the public fingerprint in the private manifest, omit it from console.
    for row in rows:
        print(json.dumps({k: v for k, v in row.items() if k != "public_sha256"}), flush=True)
    state["events"].append({"operation": operation, "exit": result.returncode,
                            "rows": rows, "stderr_present": bool(result.stderr)})
    save()
    return result.returncode, rows

def interrupted(signum, _frame):
    raise KeyboardInterrupt(f"signal {signum}")

signal.signal(signal.SIGTERM, interrupted)
save()
# Keep the EXACT signed executable available if native cleanup is denied or a
# creator is interrupted. A public package link contains no key material.
store_command = shutil.which("nix-store")
assert store_command
nix_store = Path(store_command).resolve(strict=True)
assert str(nix_store).startswith("/nix/store/") and nix_store.stat().st_uid == 0
assert not nix_store.stat().st_mode & 0o022
root = directory / "package"
if root.is_symlink():
    assert root.resolve(strict=True) == app.parent
else:
    assert not root.exists()
    subprocess.run([store_command, "--add-root", str(root), "--indirect", "--realise", str(app.parent)],
                   check=True, capture_output=True, text=True, timeout=15)
print("Private recovery metadata (no key material):", directory, flush=True)
success = False
try:
    if not args.recover:
        code, rows = invoke("inspect")
        assert code == 0 and any(r.get("stage") == "own_tag_lookup" and r["status"] == -25300 for r in rows), "Own-tag absence not established; no creation attempted."
        state["vacant_before_create"] = True
        state["creation_attempted"] = True
        save()  # Recovery scope durable BEFORE any persistent creation call.
        code, created = invoke("create")
        state["creation_completed"] = True
        save()
        assert code == 0, "Persistent creation failed; no software/entitlement fallback."
        proof = [r for r in created if r["stage"] == "created_hardware_key"]
        assert len(proof) == 1 and any(r["stage"] == "opaque_reference_released" for r in created)
        code, reopened = invoke("read", proof[0]["public_sha256"])
        assert code == 0
        again = [r for r in reopened if r["stage"] == "reopened_same_hardware_key"]
        assert len(again) == 1 and again[0]["pid"] != proof[0]["pid"]
        assert again[0]["public_sha256"] == proof[0]["public_sha256"]
        assert any(r["stage"] == "opaque_reference_released" for r in reopened)
    success = True
finally:
    if state["creation_attempted"]:
        try:
            code, rows = invoke("delete")
            state["deleted_verified"] = code == 0 and any(r["stage"] == "own_tag_after_delete" and r["status"] == -25300 for r in rows)
            save()
            assert state["deleted_verified"], "Own-tag cleanup NOT verified; retain recovery state."
        except BaseException:
            print("CLEANUP NEEDS REVIEW: use this exact app and --recover", directory, flush=True)
            raise
    if not args.recover and state["creation_attempted"] and not state["creation_completed"]:
        # A killed/timed-out creator could commit late in securityd. Do not call a
        # current no-item observation definitive cleanup; keep recovery available.
        state["deleted_verified"] = False
        save()
        success = False
        print("Creation completion indeterminate; recheck exact own tag with --recover. No broad cleanup.", flush=True)
if not success:
    raise SystemExit(1)
print("PASS: separate-process same hardware key reopened and own-tag deletion verified; no signing/certificate/account changes." if not args.recover else "Own-tag recovery deletion verified.")
