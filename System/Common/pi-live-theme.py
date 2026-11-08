"""Add terminal-color polling to Pi's existing automatic theme controller."""

import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
controller = root / "dist/modes/interactive/theme/theme-controller.js"
bundles = [
    path
    for path in (root / "dist/bundle/chunks").glob("*.js")
    if "terminalColorSchemeUnsubscribe" in path.read_text()
]
if len(bundles) != 1:
    raise RuntimeError("Pi theme controller bundle changed; review the live-theme patch")

replacement = """setAutoSync(enabled) {
        if (this.autoSyncEnabled === enabled) return;
        this.autoSyncEnabled = enabled;
        this.ui.setTerminalColorSchemeNotifications(enabled);
        clearInterval(this.terminalColorPollTimer);
        this.terminalColorPollTimer = undefined;
        if (enabled) {
            // WezTerm does not implement mode 2031. Keep native notifications,
            // but also refresh the actual terminal palette, not the OS theme.
            this.terminalColorPollTimer = setInterval(() => {
                // Do not query while a subprocess owns the terminal or while
                // a previous query is waiting for late replies. This also
                // bounds pending queries on terminals that do not respond.
                if (this.autoSyncEnabled && !this.ui.stopped &&
                    !this.ui.pendingTerminalColorQueries?.length) {
                    this.queryTerminalColors();
                }
            }, 1000);
            this.terminalColorPollTimer.unref?.();
        }
    }
    """
pattern = r"setAutoSync\(enabled\)\s*\{.*?(?=bindTerminalColorSchemeListener\(\)\s*\{)"
expected_bodies = {
    "setAutoSync(enabled){if(this.autoSyncEnabled===enabled)return;"
    "this.autoSyncEnabled=enabled;this.ui.setTerminalColorSchemeNotifications(enabled);}",
    "setAutoSync(enabled){this.autoSyncEnabled!==enabled&&"
    "(this.autoSyncEnabled=enabled,this.ui.setTerminalColorSchemeNotifications(enabled))}",
}


def replace_method(match):
    if re.sub(r"\s+", "", match.group()) not in expected_bodies:
        raise RuntimeError("Pi auto-sync implementation changed; review the live-theme patch")
    return replacement


for path in [controller, *bundles]:
    text = path.read_text()
    patched, count = re.subn(pattern, replace_method, text, flags=re.DOTALL)
    if count != 1:
        raise RuntimeError(f"Pi setAutoSync changed in {path}; review the live-theme patch")
    path.write_text(patched)
