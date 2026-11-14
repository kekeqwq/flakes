# Ghostty

`ghostty.nix` manages shared fonts, Fish and Catppuccin Latte/Mocha. Ghostty is
Niri's default terminal; the WezTerm package, configuration and bar plugin have
been removed. Linux uses nixpkgs Ghostty. macOS uses the Homebrew cask with Home
Manager configuration only (`package = null`); its payload is not Nix-pinned.

Native macOS titlebar and Liquid Glass settings belong to
`macOS/private/ghostty.nix`: hidden titlebar, clear glass, opacity 0.8. Linux
retains shared opacity 0.95 without macOS glass settings. Unfocused native
splits do not dim (`unfocused-split-opacity = 1`). Ghostty 1.4 exposes no
independent setting to pin SwiftUI Liquid Glass's whole-window inactive state;
this split option does not promise identical glass rendering on window blur.

## Integration

- Ghostty selects its native light/dark theme.
- tmux uses `theme = detect` with native per-client Catppuccin theme colors.
  No appearance subprocess rewrites global hex colors, and no OS appearance
  guess competes with terminal notifications. Reload removes the old hook at
  index 92. Home Manager reloads an existing default tmux server on config changes.
- Pi uses its upstream mode-2031 appearance handling; the periodic palette-query
  patch used for WezTerm has been removed. Running Pi processes must be restarted
  by the user to use the new package; `/reload` does not replace application code.
- tmux pushes `tmux:<socket_path>:<client_tty>` as its title. Hammerspoon/Niri
  match this token to fresh tmux/Pi metadata, including nested tmux. Names of
  sessions/windows are not client identities.
- Direct Pi publishes `pi-ime:<pid>:<ghostty-surface-id>` via the public Pi title
  API and includes the surface ID in its metadata lease. Both policies match
  PID + surface + editing state + freshness; another window cannot borrow it.
  On return to Fish, `ghostty-shell:<surface-id>` restores English. New shells
  load the Fish title function; existing Pi sessions can `/reload` this reporter.
  macOS additionally has an asynchronous native AppleScript PID/TTY fallback.
- Squirrel recognizes Ghostty; the Rime guard uses `kRejected = 0` for shortcut
  passthrough, preserves pending state through release events, and expires it.
- Yazi reserves 4/5 of the columns for a preview up to 3840x2160, and tmux
  passthrough is enabled. Actual image rendering still requires GUI validation.

## Known gaps / acceptance tests

- Unidentified windows preserve manual input-source selection. Direct Pi and
  Fish are identified by their shared surface tokens, not by guessed cwd/title.
  Real Linux/Niri input composition still requires testing on a reachable host.
- Linux has a native Rime prefix processor as well: a fresh Niri-confirmed
  tmux lease is mandatory. Nonempty frontend app names are also verified;
  native Wayland may leave that field empty. Prefix and next press return
  `kRejected`, releases preserve state, and Rime reset clears pending state.
  No subprocess or synchronous tmux root binding runs on a keystroke.
  Native librime and real Ghostty/fcitx virtual-key tests cover Ctrl+B,c,
  Ctrl+Space,c, new-shell English and returning to Pi/Escape Chinese. Physical
  keyboard/streaming-client delivery and actual Chinese glyph composition
  still require interactive confirmation.
- Test real prefix/next-command/Escape, multiple clients/tabs/native splits,
  nested tmux, actual Chinese composition, light/dark changes and image previews.
- Full system `build`, activation (`switch`) and interactive GUI results are
  separate. Never use the pinned `darwin-rebuild check` as a safe dry-run.

## Regression commands

```sh
python3 NixOS/desktop/input-method/policy.test.py NixOS/desktop/input-method/policy.py
lua macOS/private/input-method/policy.test.lua macOS/private/input-method/policy.lua
lua macOS/private/input-method/manager.test.lua macOS/private/input-method/init.lua
lua macOS/private/rime/pi_chinese_lock.test.lua macOS/private/rime/pi_chinese_lock.lua
python3 tests/terminal-tmux-title.py
bash tests/tmux-theme.sh "$HOME/.config/tmux/tmux.conf"
```

The tmux tests use isolated servers, never the user's server. The title test
checks OSC output from a real attached PTY; the palette test checks generated
config reload and native theme options. Neither replaces GUI color testing.
