"""Declarative control-center spec: argv only, no host checks or shell eval."""
import json


def load_actions(path):
    with open(path) as handle:
        spec = json.load(handle)
    seen = set()
    for section in ("common", "private"):
        if not isinstance(spec.get(section), list):
            raise ValueError("Expected common/private action lists")
        for action in spec[section]:
            if not isinstance(action.get("id"), str) or action["id"] in seen:
                raise ValueError("Action IDs must be unique")
            seen.add(action["id"])
            if not isinstance(action.get("label"), str) or not action["label"]:
                raise ValueError("Action label required")
            argv = action.get("argv")
            if not isinstance(argv, list) or not argv or not all(isinstance(v, str) and v and "\0" not in v for v in argv):
                raise ValueError("Expected nonempty argv vector")
            if not isinstance(action.get("confirm"), bool):
                raise ValueError("Explicit confirmation policy required")
    return spec


def execute_action(action, close, launch):
    # Hide the overlay before changing session, locking or asking logind to act.
    close()
    launch(*action["argv"])
