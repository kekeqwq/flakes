#!/usr/bin/env python3
"""Opt-in read-only test of the exact Ghostty AppleScript used by the manager.

Requires a running Ghostty window. Does not activate it or read terminal text.
--git-ref HEAD can demonstrate the pre-fix delimiter regression.
"""
import argparse
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--git-ref")
args = parser.parse_args()
path = "macOS/private/input-method/init.lua"
source = (
    subprocess.check_output(["git", "show", f"{args.git_ref}:{path}"], text=True)
    if args.git_ref
    else Path(path).read_text()
)
script = re.search(r"\{'-e', \[\[(.*?)\]\]\}\)", source, re.S)
assert script, "manager's actual AppleScript block not found"
result = subprocess.run(
    ["/usr/bin/osascript", "-e", script.group(1)],
    capture_output=True,
    text=True,
    check=True,
    timeout=5,
)
assert re.fullmatch(r"[\w-]+\t[1-9]\d*\t/dev/[^\r\n]+\n?", result.stdout), (
    "Ghostty metadata must contain actual TAB separators, not the application "
    "dictionary's 'tab' class name"
)
print("PASS: actual Ghostty surface/PID/TTY response matches manager parser")
