#!/usr/bin/env python3
"""Unit test only the stream helper; no CTK registration/authentication/locking."""
import ast
import contextlib
import io
from pathlib import Path
import queue
import subprocess
import sys
import threading
import time

source = ast.parse((Path(__file__).parent / "macos-ctk-probe.py").read_text())
function = next(n for n in source.body if isinstance(n, ast.FunctionDef) and n.name == "run_live")
namespace = dict(subprocess=subprocess, queue=queue, threading=threading, time=time)
exec(compile(ast.Module(body=[function], type_ignores=[]), "stream-helper-test", "exec"), namespace)
run_live = namespace["run_live"]

class TimedOutput(io.StringIO):
    def __init__(self):
        super().__init__()
        self.events = []

    def write(self, text):
        self.events.append((time.monotonic(), text))
        return super().write(text)

out = TimedOutput()
with contextlib.redirect_stdout(out):
    result = run_live([sys.executable, "-c",
        "import time; print('READY_TO_LOCK',flush=True); time.sleep(.25); print('DONE',flush=True)"], 3)
ready = next(t for t, s in out.events if "READY_TO_LOCK" in s)
done = next(t for t, s in out.events if "DONE" in s)
assert done - ready >= .15, "Ready was buffered until child exit"
assert result.returncode == 0 and result.stdout == "READY_TO_LOCK\nDONE\n"
with contextlib.redirect_stdout(io.StringIO()):
    start = time.monotonic()
    try:
        run_live([sys.executable, "-c", "import time; print('WAIT',flush=True); time.sleep(10)"], .15)
    except subprocess.TimeoutExpired:
        assert time.monotonic() - start < 2
    else:
        raise AssertionError("Timeout was counted as completion")
    result = run_live([sys.executable, "-c", "print('REFUSED'); raise SystemExit(7)"], 3)
    assert result.returncode == 7 and result.stdout == "REFUSED\n"
print("PASS: live READY barrier, bounded own-child timeout, nonzero status preserved; no native auth.")
