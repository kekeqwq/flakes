from concurrent.futures import ThreadPoolExecutor
import importlib.util
from datetime import datetime
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("appearance", sys.argv.pop(1))
appearance = importlib.util.module_from_spec(spec)
spec.loader.exec_module(appearance)


class Frozen(datetime):
    clock = datetime(2026, 11, 28, 6, 59)

    @classmethod
    def now(cls):
        return cls.clock


class AppearanceTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.app = Path(self.tmp.name).resolve()
        self.root = self.app / "state"
        self.assets = self.app / "assets"
        for mode in ("light", "dark"):
            directory = self.assets / mode
            directory.mkdir(parents=True)
            (directory / "niri.kdl").write_text(mode)
        self.commands = []
        self.deny = None

        def fake_command(*args):
            self.commands.append(args)
            if self.deny and self.deny(args):
                raise subprocess.CalledProcessError(1, args)
            if args[1:2] == ("get",):
                return "'previous'"
            if "NameHasOwner" in args:
                return "b true"
            if args[0] == "emacsclient":
                return "latte" if (self.root / "current").resolve().name == "light" else "mocha"
            return ""

        for mock in (patch.object(appearance, "command", fake_command),
                     patch.object(appearance, "active", lambda _unit: True),
                     patch.object(appearance, "datetime", Frozen),
                     patch.dict(appearance.os.environ, {"XDG_CURRENT_DESKTOP": "niri"})):
            mock.start()
            self.addCleanup(mock.stop)

    def switch(self, mode, hour, minute, expected, *, stored=None):
        Frozen.clock = datetime(2026, 11, 28, hour, minute)
        appearance.main(["--root", str(self.root), "--assets", str(self.assets),
                         "--emacs-init", str(self.app / "emacs.el"), mode])
        self.assertEqual((self.root / "current").resolve(), self.assets / expected)
        status = json.loads((self.root / "status.json").read_text())
        self.assertEqual((status["mode"], status["effective"]), (stored or mode, expected))
        return status["errors"]

    def test_mode_transitions(self):
        self.switch("auto", 6, 59, "dark")
        self.switch("reconcile", 7, 0, "light", stored="auto")
        self.switch("reconcile", 17, 59, "light", stored="auto")
        self.switch("reconcile", 18, 0, "dark", stored="auto")
        self.switch("light", 23, 0, "light")
        self.switch("reconcile", 6, 59, "light", stored="light")
        self.switch("dark", 8, 0, "dark")
        self.switch("auto", 8, 0, "light")
        self.assertIn(("gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-light"), self.commands)
        for theme in ("Papirus-Light", "Papirus-Dark"):
            self.assertIn(("gsettings", "set", "org.gnome.desktop.interface", "icon-theme", theme), self.commands)
        self.assertIn(("systemctl", "--user", "reload", "mako.service"), self.commands)
        self.assertTrue(any(c[:2] == ("emacsclient", "--eval") for c in self.commands))

    def test_core_rollback_and_partial_refresh(self):
        self.switch("dark", 12, 0, "dark")
        self.deny = lambda c: c[0] == "niri" and c[-1].endswith("light/niri.kdl") and c[1] == "msg"
        with self.assertRaises(subprocess.CalledProcessError):
            self.switch("light", 12, 0, "light")
        self.assertEqual((self.root / "current").resolve(), self.assets / "dark")
        self.assertEqual((self.root / "mode").read_text(), "dark\n")
        self.deny = lambda c: c == ("systemctl", "--user", "reload", "waybar.service")
        self.assertEqual(self.switch("light", 12, 0, "light"), ["waybar.service"])
        self.deny = None
        self.assertEqual(self.switch("reconcile", 12, 0, "light", stored="light"), [])

    def test_fcitx_refresh_only_reloads_classic_ui(self):
        self.switch("light", 12, 0, "light")
        bus_calls = [command for command in self.commands if command[0] == "busctl"]
        self.assertEqual(len(bus_calls), 2)
        self.assertEqual(bus_calls[0][-3:], ("NameHasOwner", "s", "org.fcitx.Fcitx5"))
        self.assertEqual(bus_calls[1][-3:], ("ReloadAddonConfig", "s", "classicui"))
        self.assertTrue(all("--auto-start=no" in call for call in bus_calls))

    def test_emacs_non_confirmation_is_visible(self):
        original = appearance.command

        def stale(*args):
            return "mocha" if args[0] == "emacsclient" else original(*args)

        with patch.object(appearance, "command", stale):
            self.assertEqual(self.switch("light", 12, 0, "light"), ["Emacs"])

    def test_rapid_manual_switches_serialize(self):
        original_refresh = appearance.refresh
        running = []

        def slow_refresh(*args):
            self.assertFalse(running, "refreshes overlapped")
            running.append(args[2])
            try:
                time.sleep(0.002)
                return original_refresh(*args)
            finally:
                running.pop()

        def run(mode):
            appearance.main(["--root", str(self.root), "--assets", str(self.assets),
                             "--emacs-init", str(self.app / "emacs.el"), mode])

        with patch.object(appearance, "refresh", slow_refresh), ThreadPoolExecutor(4) as pool:
            list(pool.map(run, ("light", "dark") * 6))
        status = json.loads((self.root / "status.json").read_text())
        self.assertEqual(status["mode"], status["effective"])
        self.assertEqual(status["mode"], (self.root / "mode").read_text().strip())
        self.assertEqual(status["mode"], (self.root / "current").resolve().name)

    def test_prepare_does_not_touch_session(self):
        self.switch("prepare", 12, 0, "dark", stored="dark")
        self.assertEqual(self.commands, [])
        self.assertFalse((self.root / "mode").exists())


if __name__ == "__main__":
    unittest.main()
