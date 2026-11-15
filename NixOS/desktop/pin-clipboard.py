"""Pass a Wayland PNG to Snipaste's X11 clipboard, entirely in memory."""
import os
import subprocess

# Niri can start before XWayland publishes DISPLAY. Its child environment does
# not then acquire DISPLAY, although graphical-session user services do.
manager = subprocess.run(
    ["systemctl", "--user", "show-environment"],
    capture_output=True,
    text=True,
    check=True,
    timeout=3,
)
for line in manager.stdout.splitlines():
    key, separator, value = line.partition("=")
    if separator and key in {"DISPLAY", "WAYLAND_DISPLAY", "XDG_RUNTIME_DIR"}:
        os.environ[key] = value

image = subprocess.run(
    ["wl-paste", "--type", "image/png"], capture_output=True, timeout=5
)
# Do not replace an existing text/other clipboard on a failed image read.
if image.returncode or not image.stdout.startswith(b"\x89PNG\r\n\x1a\n"):
    raise SystemExit("Copy a PNG screenshot before pinning with F3")

# XWayland background clients do not necessarily receive the native selection.
# xclip retains the bytes until the next copy. Its fork must not retain caller
# stdout/stderr (including an SSH channel); no image is written to a file.
subprocess.run(
    ["xclip", "-selection", "clipboard", "-target", "image/png"],
    input=image.stdout,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    check=True,
    timeout=5,
    start_new_session=True,
)
subprocess.run(
    ["snipaste", "paste", "--clipboard"],
    env=os.environ | {"QT_QPA_PLATFORM": "xcb", "QT_STYLE_OVERRIDE": "Fusion"},
    check=True,
    timeout=8,
)
