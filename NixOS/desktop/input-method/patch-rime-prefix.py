"""Inject a terminal-scoped native processor into pinned Rime-Ice schemas."""
import sys
from pathlib import Path

root = Path(sys.argv[1])
count = 0
for schema in root.glob("*.schema.yaml"):
    text = schema.read_text()
    marker = "  processors:\n"
    if marker not in text:
        continue
    if text.count(marker) != 1:
        raise RuntimeError(f"Ambiguous processor list: {schema.name}")
    text = text.replace(marker, marker + "    - lua_processor@*ghostty_tmux_prefix\n", 1)
    schema.unlink()  # Replace the store symlink; never mutate the source input.
    schema.write_text(text)
    count += 1
if not count:
    raise RuntimeError("No Rime-Ice schema processor lists found")
print(f"Installed Ghostty/tmux prefix guard in {count} schemas")
