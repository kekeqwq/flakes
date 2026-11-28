# macOS input-method manager

Nix manages Hammerspoon, its login LaunchAgent, the focused-app input-source
actuator, shared Pi metadata extension, tmux reporter and Squirrel guard.
Edit repository files, not generated `~/.hammerspoon` links. Ghostty replaces
WezTerm; there is no terminal Lua callback or bar plugin anymore.

## Focus policy

- Emacs and Tinycast use the actual ABC source; Emacs Rime composes internally.
  Tinycast's current bundle ID is `com.abueammar.tinycast`; legacy
  `com.tinycast.app` and `com.tinycast.app.dictation` remain supported.
- Identified Ghostty/tmux surfaces use Chinese for a fresh Pi editing context,
  and ABC for shells, menus, copy mode and prefix tables.
- Direct Pi uses `pi-ime:<pid>:<surface-id>` with a matching fresh metadata
  lease. Fish's `ghostty-shell:<surface-id>` restores ABC when Pi exits.
- Other direct surfaces can use Ghostty's asynchronous native AppleScript
  foreground-PID/TTY query (requires macOS Automation permission). Unidentified
  windows preserve manual input-source selection rather than guessing.
- Other applications retain per-bundle source memories.

Ghostty's AX window title contains the token pushed by tmux:
`tmux:<socket_path>:<client_tty>`. Hammerspoon matches this to tmux's active
pane/PID metadata and Pi's editor/menu heartbeat. Snapshots expire after seven
seconds; nested local tmux is followed up to four levels. Prompt text is never
recorded. A 200 ms fallback supplements file/app/window events.

The native actuator sends a bounded TSM input-source request to the expected
keyboard-focus PID, rather than merely changing the global menu ID. Unsupported
private APIs report failure. Squirrel's terminal-scoped `_pi_chinese_lock` flag
prevents its internal ASCII mode from defeating a selected Chinese source.

The Rime guard rejects prefix/next-key events to the OS (`kRejected = 0`),
never consumes them (`kAccepted = 1`). Releases do not consume pending state,
and the hold expires. tmux command/Escape hooks settle prefix state; no
synchronous root-key binding blocks normal tmux shortcuts.

## Activation and testing

Home Manager reloads an existing default tmux server when its config changes.
A custom server may need `tmux -S <socket> source-file ~/.config/tmux/tmux.conf`.
A tmux popup takes keyboard focus without changing the active pane. The focus
hooks make the covered Pi yield to ABC, then restore Chinese when its editor
regains focus. To exercise the focus handoff and automatic theme redraw on an
isolated client, run `python3 tests/tmux-popup.py ~/.config/tmux/tmux.conf`.
Allow Hammerspoon in macOS Privacy & Security > Accessibility. Pi extension
changes can use `/reload`; application-package changes require restarting Pi.

Tinycast upgrades that change its bundle ID do not inherit macOS privacy grants.
If its global shortcut stops working, remove the stale Tinycast entry under
Privacy & Security > Accessibility, add `/Applications/Tinycast.app` again and
allow it. Also check Input Monitoring, then quit and reopen Tinycast. These
permissions require manual authorization; the input-source policy cannot grant
or migrate them.

Use the bundled `hs` CLI or Hammerspoon console:

```lua
inputMethodManager.status()
inputMethodManager.events -- bounded metadata-only history
inputMethodManager.stop() -- leaves the current source untouched
```

Lua policy, actuator lifecycle mocks, Rime guard and shared Pi reporter tests
run during builds. They do not prove actual GUI composition: test that a new
tmux shell receives English, Pi typing composes Chinese, menus/prefix commands
use English, and Escape restores Chinese. Include multiple windows/clients,
copy mode, tabs and nested tmux. No credentials, training dictionaries or live
Rime user databases are managed by these reporters.

Read-only native Ghostty identity regression (requires one running window):

```sh
python3 tests/macos-ghostty-identity.py
```

This executes the manager's **actual AppleScript**, without focusing a window
or reading terminal text. Ghostty's dictionary defines a `tab` class, shadowing
AppleScript's bare `tab` constant inside `tell application`. Therefore the query
must construct `character id 9` outside the application block. Literal `tab`
words break the surface/PID/TTY parser and leave a plain shell unidentified.
The build-time mock also asserts the unambiguous delimiter. A real isolated
login-fish window was verified to return to ABC after selecting Rime; existing
user terminals were not used for injected input.
