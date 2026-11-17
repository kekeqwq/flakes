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
Shared content padding is 12 horizontally and 10 vertically (Ghostty points),
including space around the tmux status bar.

Chinese fallback is **仓耳今楷05 (TsangerJinKai05)**, while Latin remains
**MonoLisa Nasy**. Shared names are in `font-policy.nix`; regular uses the vendor
W03 face and bold W05. `pkgs/tsanger-jinkai/` selects those two hash-pinned assets
from chinese-fonts-overlay, preserving font bytes/names/outlines. The vendor files
both declare regular weight, so Linux corrects matching in Fontconfig scan rules,
and Ghostty explicitly selects each face without global Latin thickening.

Linux aliases cover sans/sans-serif/serif/monospace, with strong family bindings;
macOS copies managed MonoLisa/JinKai files through `macOS/private/fonts.nix`
because ATS can ignore store symlinks. Shared GUI Emacs applies the same font
policy; Squirrel uses actual PostScript names plus Apple Color Emoji. JinKai's
W03/W05 have no 🀄/🈚 cmap entries, so no IME font patch is needed.

The original `lxgw-wenkai` package is temporarily still INSTALLED at the owner's
request, but is no longer selected or configured as a fallback. Its old renamed
terminal/IME build helpers and configuration are removed; existing user font
files are not deleted. Final legacy font-body cleanup requires a later request.
TsangerType's personal/non-commercial and non-redistribution terms apply: no font
binaries added to Git or public caches. macOS system UI fonts are not replaced.

## Integration

- Ghostty selects its native light/dark theme.
- tmux uses `theme = detect` with native per-client Catppuccin theme colors.
  No appearance subprocess rewrites global hex colors, and no OS appearance
  guess competes with terminal notifications. Reload removes the old hook at
  index 92. Home Manager reloads an existing default tmux server on config changes.
  The leftmost unboxed marker denotes the **session name**, not the window:
  numeric names `0`/`1`/`2` render `0️⃣`/`1️⃣`/`2️⃣`; custom names retain their text.
  Window tabs remain plain `1.name`, `2.name` labels, bold with the current label
  underlined. Only the light palette's accent slot changes to vivid pink
  `#d81b80`; dark Mocha colors are unchanged. The marker stays fixed when changing
  windows within one session, and appearance remains native/per-client.
  A transparent second status row draws a thin `─` separator below the bar;
  native `#{R:─,#{client_width}}` adapts it to each client's width on resize.
  Its color and both Pi editor borders share `System/Common/terminal-colors.nix`:
  light pink `#d81b80`, dark blue `#89b4fa`, with no extra dim attribute or
  thinking-level color changes.
- Pi uses native mode-2031 appearance handling with
  `theme = "catppuccin-latte/catppuccin-mocha"` (light first, dark second).
  `System/Common/pi-catppuccin.nix` pins the original theme JSON from
  [otahontas/pi-coding-agent-catppuccin](https://github.com/otahontas/pi-coding-agent-catppuccin)
  at commit `9a716a630c911a4d29d9520a8d5f87e3b8867f93` plus a fixed hash.
  Only the two JSON themes and upstream attribution are extracted; the editor
  border/thinking/bash-mode color roles are then explicitly set to the shared
  accent. Other content, syntax and panel colors retain the upstream palette.
  Its flake is not imported and no extension/package is installed at runtime.
  Upstream Pi merges only this theme preference into mutable settings;
  accounts/models stay private.
  `System/Common/pi-native-theme.nix` patches source **before bundling**: request
  initial appearance with DSR 996 when enabling mode 2031; discard stale RGB
  defaults on a native appearance switch; ignore superseded/after-dispose color
  replies. Fresh actual RGB remains authoritative when a query succeeds.
  No polling, OS appearance guess or global tmux palette rewrite is used.
  **This application-code fix requires a Pi restart**, not just `/reload`.
  Leave the existing session intact and resume it with `~/.local/bin/pi --resume`.
  The user entrypoint links the same declarative package used by full systems,
  allowing narrow Home Manager deployments without a Darwin/Homebrew switch.
  New shells prioritize only that wrapper's `bin` through `home.sessionPath`;
  existing shells can use the explicit local entrypoint without changing PATH.
  Theme-only JSON/settings changes still support `/reload`.
  `showHardwareCursor = true` disables Pi's inverse-video imitation cursor;
  Ghostty owns the real cursor color/shape (Latte pink `#ea76cb`, Mocha pink
  `#f5c2e7`, steady block). Pi still positions it for IME. No second cursor
  palette or appearance observer is needed.
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
config reload, session-only emoji, unchanged markers across window switches,
plain window labels, underline/bold and native light/dark theme options. The
native macOS check is `nix build .#checks.aarch64-darwin.tmux-theme --no-link`.
Neither replaces GUI color testing.

`nix build .#checks.aarch64-darwin.pi-catppuccin --no-link` validates the prepared
JSON (including shared border roles) against the installed Pi schema and exercises its real theme controller
with simulated terminal background/appearance changes (Latte ↔ Mocha), including
a stale appearance hint. It makes no model calls and reads no private Pi state;
it is not a claim of a live GUI appearance-switch test.

`checks.aarch64-darwin.pi-native-theme` covers initial appearance requests,
missing/partial OSC replies, superseded/late replies, rapid changes, fixed theme
selection and disposal. The unmodified Pi reproduces the stale-background
failure. `checks.aarch64-darwin.pi-theme-cli` runs the **actual bundled CLI** in
isolated PTYs in fullscreen and regular modes, with synthetic terminal replies:
initial DSR plus five transitions per renderer, including absent OSC defaults.
It uses empty HOME/agent directories, `--offline`, no extensions/tools, no
prompts or saved sessions, and never changes the user's terminal/OS appearance.
Manual Ghostty/tmux rapid switching and background-tab acceptance remain separate.

`nix build .#checks.aarch64-darwin.desktop-fonts --no-link` checks vendor-byte
hashes, simplified/traditional sample coverage, regular/bold CJK and unchanged
Latin matching for all generic families, explicitly WITH the retained legacy
fonts present. The Linux counterpart is `checks.x86_64-linux.desktop-fonts`.
Ghostty's `+show-face --string='A中文，。'` checks actual Latin/CJK family selection;
it does not replace visual acceptance of font weight on the display.
