#!/usr/bin/env python3
"""Read-only, payload-free Sunshine samples. No probes, ptrace, input or sudo.

Run on Linux as the service's user:
  python3 tests/sunshine-snapshot.py --pid PID --samples 3 --interval 2
CPU/queue changes do not establish frame, input or client presentation health.
"""

import argparse
import json
import os
from pathlib import Path
import time


def stat_fields(text):
    # comm may contain spaces and ')'; field 3 follows the final ')'.
    fields = text[text.rindex(")") + 2 :].split()
    return {
        "state": fields[0],
        "cpu_ticks": int(fields[11]) + int(fields[12]),
        "start_ticks": int(fields[19]),
    }


def socket_rows(text, owned):
    rows = []
    for line in text.splitlines()[1:]:
        fields = line.split()
        if len(fields) < 10 or fields[9] not in owned:
            continue
        tx, rx = (int(n, 16) for n in fields[4].split(":"))
        rows.append({
            "port": int(fields[1].rsplit(":", 1)[1], 16),
            "state_hex": fields[3],
            "tx_queue": tx,
            "rx_queue": rx,
        })
    # Deliberately omit local/peer addresses, client ports, inode IDs and payloads.
    return sorted(rows, key=lambda row: (row["port"], row["state_hex"]))


def snapshot(proc):
    identity = stat_fields((proc / "stat").read_text())["start_ticks"]
    threads = []
    for task in sorted((proc / "task").iterdir(), key=lambda p: int(p.name)):
        try:
            stat = stat_fields((task / "stat").read_text())
            threads.append({
                "tid": int(task.name),
                "name": (task / "comm").read_text().strip(),
                "wait": (task / "wchan").read_text().strip(),
                **stat,
            })
        except FileNotFoundError:
            pass  # A thread can exit while sampling.
    owned = set()
    for fd in (proc / "fd").iterdir():
        try:
            target = os.readlink(fd)
            if target.startswith("socket:["):
                owned.add(target[8:-1])
        except FileNotFoundError:
            pass
    sockets = {}
    for protocol in ("tcp", "tcp6", "udp", "udp6"):
        sockets[protocol] = socket_rows((proc / "net" / protocol).read_text(), owned)
    if stat_fields((proc / "stat").read_text())["start_ticks"] != identity:
        raise RuntimeError("process changed during snapshot")
    return {"start_ticks": identity, "threads": threads, "sockets": sockets}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", required=True, type=int)
    parser.add_argument("--samples", type=int, default=3, choices=range(1, 6))
    parser.add_argument("--interval", type=float, default=2)
    args = parser.parse_args()
    if args.pid < 1 or not 0.2 <= args.interval <= 10:
        parser.error("positive PID and interval between 0.2 and 10 seconds required")
    proc = Path("/proc") / str(args.pid)
    executable = Path(os.readlink(proc / "exe")).name
    if "sunshine" not in executable:
        parser.error("PID is not a Sunshine executable")
    identity = None
    previous = {}
    for index in range(args.samples):
        sample = snapshot(proc)
        if identity is not None and sample["start_ticks"] != identity:
            raise RuntimeError("PID reused; refusing to compare samples")
        identity = sample["start_ticks"]
        for thread in sample["threads"]:
            key = (thread["tid"], thread["start_ticks"])
            old = previous.get(key)
            thread["cpu_ticks_delta"] = None if old is None else thread["cpu_ticks"] - old
            previous[key] = thread["cpu_ticks"]
        print(json.dumps({
            "sample": index,
            "monotonic_seconds": time.monotonic(),
            "clock_ticks_per_second": os.sysconf("SC_CLK_TCK"),
            **sample,
        }), flush=True)
        if index + 1 < args.samples:
            time.sleep(args.interval)


if __name__ == "__main__":
    main()
