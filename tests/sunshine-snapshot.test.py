#!/usr/bin/env python3
"""Offline tests; never connect to or change a service."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "snapshot", Path(__file__).with_name("sunshine-snapshot.py")
)
snapshot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(snapshot)


class Parsers(unittest.TestCase):
    def test_stat_with_parentheses_and_spaces(self):
        fields = ["S"] + ["0"] * 49
        fields[11], fields[12], fields[19] = "70", "30", "999"
        self.assertEqual(
            snapshot.stat_fields("2215 (a name ) here) " + " ".join(fields)),
            {"state": "S", "cpu_ticks": 100, "start_ticks": 999},
        )

    def test_owned_sockets_only_and_no_addresses(self):
        table = "header\n" + (
            "0: DEADBEEF:BB78 CAFEBABE:1234 0A 00000000:00000005 "
            "00:00000000 00000000 1000 0 444 1\n"
            "1: DEADBEEF:BB79 CAFEBABE:5678 01 00000001:00000000 "
            "00:00000000 00000000 1000 0 555 1\n"
        )
        self.assertEqual(snapshot.socket_rows(table, {"444"}), [{
            "port": 47992, "state_hex": "0A", "tx_queue": 0, "rx_queue": 5,
        }])
        self.assertNotIn("CAFE", str(snapshot.socket_rows(table, {"444"})))
        self.assertEqual(snapshot.socket_rows(table, set()), [])

    def test_empty_tables(self):
        self.assertEqual(snapshot.socket_rows("header\n", {"444"}), [])


if __name__ == "__main__":
    unittest.main()
