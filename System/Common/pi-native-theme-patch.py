"""Guarded Pi 1.5.2 source fixes for native terminal appearance synchronization."""

import sys
from pathlib import Path

root = Path(sys.argv[1])
controller = root / "packages/coding-agent/src/modes/interactive/theme/theme-controller.ts"
source = controller.read_text()
replacements = [
    (
        "private terminalColorQuery: Promise<void> = Promise.resolve();",
        "private terminalColorQuery: Promise<void> = Promise.resolve();\n"
        "\tprivate terminalColorQueryRevision = 0;",
    ),
    (
        "dispose(): void {\n\t\tthis.setAutoSync(false);",
        "dispose(): void {\n\t\t++this.terminalColorQueryRevision;\n\t\tthis.setAutoSync(false);",
    ),
    (
        "this.terminalColorQuery = requestTerminalColors(this.ui, (colors) => this.applyTerminalColors(colors));",
        "const revision = ++this.terminalColorQueryRevision;\n"
        "\t\tthis.terminalColorQuery = requestTerminalColors(this.ui, (colors) => {\n"
        "\t\t\tif (revision === this.terminalColorQueryRevision) this.applyTerminalColors(colors);\n"
        "\t\t});",
    ),
    (
        "const previous = getTerminalTheme();\n\t\tsetTerminalColorScheme(terminalTheme);",
        "const previous = getTerminalTheme();\n"
        "\t\t// A previous appearance's RGB defaults are stale after a native switch.\n"
        "\t\t// Keep its palette until a fresh reply, but do not let stale RGB defeat\n"
        "\t\t// the new scheme if that reply times out (common behind multiplexers).\n"
        "\t\tif (previous !== terminalTheme) {\n"
        "\t\t\tthis.terminalColors = { palette: this.terminalColors?.palette };\n"
        "\t\t\tsetTerminalColors(this.terminalColors);\n"
        "\t\t}\n"
        "\t\tsetTerminalColorScheme(terminalTheme);",
    ),
]
for old, new in replacements:
    assert source.count(old) == 1, f"Pi controller source changed: {old[:70]}"
    source = source.replace(old, new)
controller.write_text(source)

# Enabling notifications is not itself a request for the initial appearance.
# DSR 996 uses the same terminal/tmux scheme source as subsequent 997 reports.
tui = root / "packages/tui/src/tui.ts"
source = tui.read_text()
old = r'"\x1b[?2031h"'
assert source.count(old) == 2, "Pi TUI notification enable sites changed"
tui.write_text(source.replace(old, r'"\x1b[?2031h\x1b[?996n"'))
