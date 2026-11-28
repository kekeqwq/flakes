"""One writer for the per-user Linux desktop appearance state."""
import argparse
from datetime import datetime
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

MODES = ("auto", "light", "dark")


def effective(mode, local_time):
    return ("light" if 7 <= local_time.hour < 18 else "dark") if mode == "auto" else mode


def read_mode(root):
    try:
        mode = (root / "mode").read_text().strip()
    except FileNotFoundError:
        return "dark"
    return mode if mode in MODES else "dark"


def atomic_text(path, text):
    fd, tmp = tempfile.mkstemp(prefix=".state-", dir=path.parent, text=True)
    try:
        with os.fdopen(fd, "w") as file:
            file.write(text)
        os.replace(tmp, path)
    finally:
        Path(tmp).unlink(missing_ok=True)


def publish(root, path):
    temporary = root / ".next"
    temporary.unlink(missing_ok=True)
    temporary.symlink_to(path)
    os.replace(temporary, root / "current")


def command(*argv):
    return subprocess.run(argv, check=True, capture_output=True, text=True, timeout=8).stdout.strip()


def active(unit):
    return subprocess.run(["systemctl", "--user", "is-active", "--quiet", unit], timeout=5).returncode == 0


def refresh_fcitx():
    """Reload only the candidate UI; let its portal monitor choose the palette."""
    name = "org.fcitx.Fcitx5"
    bus = ("busctl", "--user", "--auto-start=no", "call")
    owner = command(*bus, "org.freedesktop.DBus", "/org/freedesktop/DBus",
                    "org.freedesktop.DBus", "NameHasOwner", "s", name)
    if owner == "b true":
        command(*bus, name, "/controller", "org.fcitx.Fcitx.Controller1",
                "ReloadAddonConfig", "s", "classicui")


def interface(mode):
    light = mode == "light"
    return {
        "gtk-theme": f"catppuccin-{'latte' if light else 'mocha'}-mauve-standard+rimless",
        "icon-theme": "Papirus-Light" if light else "Papirus-Dark",
        "color-scheme": "prefer-light" if light else "prefer-dark",
    }


def refresh(root, assets, mode, operation, emacs_init):
    current = root / "current"
    target = assets / mode
    if not (target / "niri.kdl").is_file():
        raise RuntimeError(f"missing appearance assets: {target}")
    prior = Path(os.readlink(current)) if current.is_symlink() else None
    changed = target != prior
    if operation == "prepare":
        if changed:
            publish(root, target)
        return []

    graphical = os.environ.get("XDG_CURRENT_DESKTOP", "").lower() == "niri"
    # Change the compositor only after the generated input is validated. If
    # the desktop is not active, the next graphical-session start applies it.
    if graphical:
        command("niri", "validate", "-c", str(target / "niri.kdl"))
    schema = "org.gnome.desktop.interface"
    desired = interface(mode)
    old_interface = {key: command("gsettings", "get", schema, key) for key in desired}
    try:
        if changed:
            publish(root, target)
        if graphical:
            command("niri", "msg", "action", "load-config-file", "--path", str(target / "niri.kdl"))
        for key, value in desired.items():
            command("gsettings", "set", schema, key, value)
    except (OSError, subprocess.SubprocessError) as failure:
        rollback = []
        if changed:
            try:
                if prior is not None:
                    publish(root, prior)
                else:
                    current.unlink(missing_ok=True)
            except OSError:
                rollback.append("palette link")
        if graphical:
            old_config = (prior / "niri.kdl") if prior is not None else (
                Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "niri/config.kdl"
            )
            try:
                command("niri", "msg", "action", "load-config-file", "--path", str(old_config))
            except (OSError, subprocess.SubprocessError):
                rollback.append("Niri")
        for key, value in old_interface.items():
            try:
                command("gsettings", "set", schema, key, value)
            except (OSError, subprocess.SubprocessError):
                rollback.append(key)
        if rollback:
            raise RuntimeError(f"{failure}; rollback incomplete: {', '.join(rollback)}") from failure
        raise

    failures = []
    if graphical:
        for unit in ("waybar.service", "mako.service"):
            try:
                if active(unit):
                    command("systemctl", "--user", "reload", unit)
            except (OSError, subprocess.SubprocessError):
                failures.append(unit)
        try:
            refresh_fcitx()
        except (OSError, subprocess.SubprocessError):
            failures.append("Fcitx5 Classic UI")
        try:
            if active("emacs.service"):
                load = f"(load {json.dumps(str(emacs_init), ensure_ascii=False)} nil 'nomessage)"
                result = command("emacsclient", "--eval", f"(progn {load} (flakes-appearance-apply))")
                if result != ("latte" if mode == "light" else "mocha"):
                    failures.append("Emacs")
        except (OSError, subprocess.SubprocessError):
            failures.append("Emacs")
    return failures


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--assets", type=Path, required=True)
    parser.add_argument("--emacs-init", type=Path, required=True)
    parser.add_argument("action", choices=("prepare", "status", "reconcile", *MODES))
    args = parser.parse_args(argv)
    root = args.root
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (root / "lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        selection = args.action if args.action in MODES else read_mode(root)
        if args.action == "status":
            try:
                result = json.loads((root / "status.json").read_text())
            except FileNotFoundError:
                result = {"mode": selection, "effective": effective(selection, datetime.now()), "errors": []}
        else:
            theme = effective(selection, datetime.now())
            failures = refresh(root, args.assets, theme, args.action, args.emacs_init)
            if args.action in MODES:
                atomic_text(root / "mode", selection + "\n")
            result = {"mode": selection, "effective": theme, "errors": failures}
            atomic_text(root / "status.json", json.dumps(result) + "\n")
        print(json.dumps(result))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
        print(f"desktop appearance: {exc}", file=sys.stderr)
        sys.exit(1)
