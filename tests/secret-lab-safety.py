"""Refusal-path tests only: no real disk, USB, privilege or VM operations."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory() as work:
    work = Path(work)
    marker = work / "MUTATION"
    tools = work / "bin"
    tools.mkdir()
    stubs = {
        "id": "printf '0\\n'",
        "systemd-detect-virt": "printf 'none\\n'",
    }
    for name in ("parted", "mkfs.fat", "mkfs.btrfs", "cryptsetup", "systemd-cryptenroll", "mount", "umount", "btrfs"):
        stubs[name] = f"touch '{marker}'; exit 99"
    for name, body in stubs.items():
        file = tools / name
        file.write_text("#!/bin/sh\n" + body + "\n")
        file.chmod(0o700)
    env = {**os.environ, "PATH": f"{tools}:{os.environ['PATH']}"}
    partition = root / "hosts/secret-lab/partition-and-mount.sh"
    enroll = root / "hosts/secret-lab/enroll-key.sh"
    launcher = root / "tests/secret-lab-vm.sh"
    for script in (partition, enroll, launcher):
        subprocess.run(["bash", "-n", str(script)], check=True)
    for script, args in (
        (partition, []),
        (partition, ["--erase-fresh-qemu-vda", "--unexpected"]),
        (partition, ["--erase-fresh-qemu-vda"]),
        (enroll, []),
        (enroll, ["--fido2-device", "/dev/hidraw0", "--label", "primary"]),
    ):
        result = subprocess.run(["bash", str(script), *args], env=env, capture_output=True, timeout=5)
        assert result.returncode != 0, (script, args)
        assert not marker.exists(), "A refusal path reached a disk/token mutator"
    source = launcher.read_text()
    assert "VIEWING_CONFIRMED" in source and "installed-and-closed" in source
    assert "-nic none" in source
    assert "hostfwd=tcp:127.0.0.1:22323-:22" in source
    assert "pgrep -x swaylock" in source
    assert "hostbus=$USB_BUS,hostaddr=$USB_ADDR" in source
print("secret-lab: syntax and non-QEMU/invalid-argument refusal paths PASS; no real disk/USB/VM operations")
