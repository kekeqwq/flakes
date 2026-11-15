# Clipboard screenshots → Pi / Telegram

No screenshot file is necessary. Snipaste is installed on macOS and x86_64
Linux; Linux starts its tray/pinning process with the graphical user session.
Upstream does not provide an aarch64 Linux binary. Niri's native capture still
works on that architecture.

## Niri

| Shortcut                   | Result                                           |
| -------------------------- | ------------------------------------------------ |
| `Print` or `Super+Shift+S` | Select a region, then Enter to copy              |
| `Ctrl+Print`               | Copy the current full screen                     |
| `Alt+Print`                | Copy the focused window                          |
| `F3` (x86_64)              | Snipaste: pin the clipboard image on the desktop |

`screenshot-path null` disables Niri screenshot file output; the image remains
available as `image/png` on the clipboard. Escape cancels region selection.
Capture uses Niri, not an X11-only attempt to read native Wayland windows.
Snipaste runs through XWayland for its tray and clipboard-pinning features.
`F3` uses `pin-clipboard`: it reads the native PNG in memory, bridges it into the
X11 selection with xclip, then asks Snipaste to pin it. No intermediate PNG is
saved. The helper refreshes DISPLAY from the graphical user manager because
Niri may have started before XWayland; pins open floating rather than tiled.
`F3` is **desktop pinning**, not pasting an attachment into a chat.

- **Pi in Ghostty, directly or in local tmux:** press **Ctrl+V** in its editor.
  This is Pi's image-paste action, not Ghostty's text paste (`Ctrl+Shift+V`).
  The shared Linux desktop provides `wl-paste`; Pi reads image bytes directly.
- **Telegram:** focus the message editor and press **Ctrl+V**. Review the preview
  before sending. No test/deployment sends a message for you.

## macOS

- **Control+Command+Shift+4:** select a region directly into the clipboard.
- **Control+Command+Shift+3:** full-screen capture directly into the clipboard.
- Alternatively launch **Snipaste**, press **F1** (possibly **Fn+F1**), select
  the area and press **Enter** to copy. Snipaste also offers
  `snip --full -o clipboard` once the application is running.
- **Pi:** press **Ctrl+V** in the terminal editor, not Command+V.
- **Telegram:** press **Command+V** in its message editor.

Snipaste's first capture may require the user's macOS Screen Recording consent.
Grant that in System Settings; Nix must not bypass privacy permissions. Native
macOS screenshot shortcuts remain an alternative without configuring Snipaste.
Snipaste's own optional history/auto-save/pinned-image persistence is separate;
use the native clipboard shortcuts for the no-screenshot-file workflow.

## Limits and private state

Screenshot and consumer must use the **same desktop clipboard**. Plain SSH does
not forward PNG clipboards; neither text-only OSC 52 nor Moonlight's text
clipboard should be mistaken for image forwarding. Capture inside the remote
Niri desktop if Pi is running there.

No PNG is written by the native capture workflow. Pi can nevertheless persist
attachments in its normal session history when messages are sent; use
`pi --no-session` for a non-persistent test. Telegram maintains its own cache.
Clipboard contents, sessions and application databases remain private runtime
state and must never be put in Git or Nix store.
