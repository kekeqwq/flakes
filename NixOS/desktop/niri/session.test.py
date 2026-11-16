"""Exercise both launchers with a fake user manager, never a real session/bus."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile

original, patched = map(Path, sys.argv[1:])
warning = "Calling import-environment without a list of variable names is deprecated."
with tempfile.TemporaryDirectory(prefix="niri-session-test-") as directory:
    root = Path(directory)
    bin_dir = root / "bin"
    bin_dir.mkdir()
    log = root / "commands.jsonl"
    mock = f"#!{sys.executable}\n" + '''import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['SESSION_TEST_LOG'], 'a') as out:
    out.write(json.dumps({'name': name, 'args': args}) + '\\n')
if name == 'systemctl':
    if 'is-active' in args:
        sys.exit(1)
    if args == ['--user', 'import-environment']:
        print('Calling import-environment without a list of variable names is deprecated.', file=sys.stderr)
'''
    for name in ("systemctl", "dbus-update-activation-environment"):
        path = bin_dir / name
        path.write_text(mock)
        path.chmod(0o755)
    env = {
        "PATH": str(bin_dir),
        "HOME": str(root),
        "SHELL": "",
        "SESSION_TEST_LOG": str(log),
        "DISPLAY": ":7",
        "WAYLAND_DISPLAY": "wayland-test",
        "XDG_CURRENT_DESKTOP": "niri",
        "GTK_IM_MODULE": "fcitx",
        "SESSION_MULTILINE": "public fixture value\nNOT_AN_ENV_NAME=also public",
    }
    logs = []
    for script in (original, patched):
        log.write_text("")
        result = subprocess.run([str(script)], env=env, capture_output=True, text=True, timeout=10)
        assert result.returncode == 0, result.stderr
        records = [json.loads(line) for line in log.read_text().splitlines()]
        logs.append(records)
        if script == original:
            assert warning in result.stderr, "Upstream no longer reproduces: review/remove patch"
        else:
            assert warning not in result.stderr, result.stderr
            imports = [r["args"] for r in records if r["name"] == "systemctl" and "import-environment" in r["args"]]
            assert len(imports) == 1
            names = imports[0][2:]
            assert names and all(name in names for name in env), names
            assert len(names) == len(set(names))
            assert "NOT_AN_ENV_NAME" not in names
            assert not any(value and value in names for value in env.values())
    # Session start, shutdown, cleanup and independent DBus import stay unchanged.
    def lifecycle(records):
        return [r for r in records if "import-environment" not in r["args"]]
    assert lifecycle(logs[0]) == lifecycle(logs[1])
    assert any(r["name"] == "dbus-update-activation-environment" and r["args"] == ["--all"] for r in logs[1])
assert (original.parent / "niri").resolve() == (patched.parent / "niri").resolve(), "Compositor binary changed"
print("Unpatched warning reproduced; explicit-name import, multiline environment and unchanged session lifecycle passed.")
