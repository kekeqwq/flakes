"""Patch only the session launcher's deprecated systemd environment call."""

import pathlib
import sys

source, destination, bash = map(pathlib.Path, sys.argv[1:])
text = source.read_text()
old = "    systemctl --user import-environment\n"
assert text.count(old) == 1, "Upstream niri-session changed: review the environment import"
new = f'''    # Preserve upstream's environment; enumerate names, never parse values.
    # --posix prevents the helper shell from sourcing a user's BASH_ENV.
    systemctl --user import-environment $({bash} --posix -c 'compgen -e')
'''
# Keep upstream's shebang, login-shell handling and session lifecycle unchanged.
destination.write_text(text.replace(old, new))
