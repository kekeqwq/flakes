import importlib.util
import json
import sys
import tempfile
from pathlib import Path

spec = importlib.util.spec_from_file_location("actions", sys.argv[1])
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)
action = {"id": "lock", "label": "Lock screen", "argv": ["screen-lock"], "confirm": False}
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "actions.json"
    path.write_text(json.dumps({"common": [action], "private": []}))
    assert a.load_actions(path)["common"] == [action]
    for invalid in [
        {"common": [action], "private": [action]},
        {"common": [action | {"argv": "systemctl reboot"}], "private": []},
        {"common": [action | {"argv": []}], "private": []},
        {"common": [action | {"confirm": "yes"}], "private": []},
    ]:
        path.write_text(json.dumps(invalid))
        try:
            a.load_actions(path)
        except ValueError:
            pass
        else:
            raise AssertionError("invalid control-center spec accepted")
events = []
a.execute_action(action, lambda: events.append("closed"), lambda *argv: events.append(argv))
assert events == ["closed", ("screen-lock",)]
print("control-center argv/schema/close-before-action: PASS")
