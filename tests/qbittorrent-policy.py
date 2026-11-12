"""Synthetic fixtures only; never inspect a user's qBittorrent profile."""
import configparser
import importlib.util
import json
from pathlib import Path
import stat
import sys
import tempfile
import unittest

# Importing the implementation must not create bytecode in the source tree.
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("policy", sys.argv.pop(1))
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)


class PolicyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = self.root / "profile/config/qBittorrent.conf"
        self.downloads = self.root / "downloads"
        self.policy_file = self.root / "policy.json"
        self.policy_file.write_text(json.dumps({
            "BitTorrent": {
                "Session\\AddTrackersFromURLEnabled": "true",
                "Session\\AdditionalTrackersURL": "https://example.invalid/list.txt",
                "Session\\DefaultSavePath": str(self.downloads),
            },
            "Preferences": {"WebUI\\LocalHostAuth": "true"},
        }))

    def apply(self):
        policy.apply(self.policy_file, self.config, self.downloads)

    def read(self):
        result = configparser.RawConfigParser()
        result.optionxform = str
        result.read(self.config)
        return result

    def test_empty_instance(self):
        self.apply()
        self.assertTrue(self.downloads.is_dir())
        self.assertEqual(self.read()["BitTorrent"]["Session\\AddTrackersFromURLEnabled"], "true")
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o600)
        self.assertNotIn("WebUI\\Password_PBKDF2", self.read()["Preferences"])

    def test_preserves_private_and_unmanaged_values(self):
        self.config.parent.mkdir(parents=True)
        self.config.write_text(
            '[Preferences]\nWebUI\\Password_PBKDF2=@ByteArray(synthetic-only==)\n'
            'WebUI\\Username=fixture-user\nWebUI\\LocalHostAuth=false\n'
            '[BitTorrent]\nSession\\AdditionalTrackers=fixture-only%23\n'
        )
        self.apply()
        c = self.read()
        self.assertEqual(c["Preferences"]["WebUI\\Password_PBKDF2"], "@ByteArray(synthetic-only==)")
        self.assertEqual(c["Preferences"]["WebUI\\Username"], "fixture-user")
        self.assertEqual(c["Preferences"]["WebUI\\LocalHostAuth"], "true")
        self.assertEqual(c["BitTorrent"]["Session\\AdditionalTrackers"], "fixture-only%23")
        before = self.config.read_bytes()
        self.apply()
        self.assertEqual(before, self.config.read_bytes())
        self.assertFalse(list(self.config.parent.glob(".policy-*")))

    def test_invalid_existing_config_is_not_destroyed(self):
        self.config.parent.mkdir(parents=True)
        original = b"not-an-ini-file\n"
        self.config.write_bytes(original)
        with self.assertRaises(configparser.Error):
            self.apply()
        self.assertEqual(self.config.read_bytes(), original)


unittest.main()
