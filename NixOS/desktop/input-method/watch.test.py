"""No compositor/IME calls: validate the private lease writer used by Rime."""
import runpy
import sys
import tempfile
import types
from pathlib import Path

sys.modules["policy"] = types.SimpleNamespace(**runpy.run_path(sys.argv[1]))
watch = runpy.run_path(sys.argv[2], run_name="watch_test")
with tempfile.TemporaryDirectory() as directory:
    state = Path(directory) / "state"
    writer = watch["publish_prefix_context"]
    writer.__globals__["STATE"] = state
    writer(True, 1000)
    target = state / "tmux-prefix-context"
    assert target.read_text() == "tmux 1000.000\n"
    assert target.stat().st_mode & 0o777 == 0o600
    assert state.stat().st_mode & 0o777 == 0o700
    writer(False, 1001.25)
    assert target.read_text() == "other 1001.250\n"
    assert list(state.iterdir()) == [target], "atomic replacement leaves no scratch files"
print("prefix lease writer: permissions, replacement and revocation PASS")
