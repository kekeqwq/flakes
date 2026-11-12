# macOS input-method manager (Nix managed)

Installed by `macOS/private/input-method.nix` (Hammerspoon cask, login LaunchAgent,
Hammerspoon configuration, Pi extension, WezTerm bridge and tmux reporter).
Do not edit the generated files in `~/.hammerspoon` or `~/.config/wezterm`.

## Policy

- Emacs and Tinycast (including its Dictation helper): actual ABC input source.
  Emacs Rime still composes Chinese internally in Meow INSERT.
- WezTerm: ABC unless the active local terminal pane contains Pi's focused
  text editor, answer dialog, or focused custom text field (for example quiz
  notes). These use Squirrel Chinese. Inline editor suggestions do not change
  the source. Slash/bang commands, full selection menus, external editor,
  terminal search/copy key tables and tmux copy mode use ABC.
- Other applications: remember and restore the last input source per bundle.
  Tinycast's temporary ABC never replaces WeChat's stored Chinese source.
- One owner: Hammerspoon. No macism, no Emacs macOS focus switcher, and no
  Squirrel per-app English lock rules. A private Squirrel session flag keeps
  WezTerm's selected Squirrel genuinely Chinese; other apps keep normal behavior.

## How it works

`pi-ime.ts` extends the standard CustomEditor, preserving Pi shortcuts and
rendering. It reports only focus/menu/editor state, process/pane IDs and a
short heartbeat lease, **never prompt text**. It also handles non-TUI invocations
by doing nothing. A crash/kill expires the lease within seven seconds.

`wezterm.lua` atomically reports the focused GUI window's active pane, TTY,
foreground process and key-table state. It never switches input sources or
launches processes. `tmux-update.py` is called by tmux hooks (fixed index 90,
so reloading config does not multiply hooks), including pane exit and active-pane
changes; it reports each client's active pane, foreground process group and copy
mode. Pi also refreshes that snapshot on its lease timer so a missed hook cannot
leave Hammerspoon forcing ABC. Nested local tmux is resolved up
to four levels. Remote SSH/tmux is deliberately fail-closed ABC; no local
foreground identity is guessed from a remote title.

Hammerspoon reads these files under owner-only `~/.local/state/input-method/`.
It checks the frontmost app and actual AX keyboard-focus owner (Tinycast's
nonactivating panel leaves the underlying app frontmost), coalesces changes
and switches only when needed. Nonstandard dialog window events and a 200 ms
focus fallback also detect the panel closing without an app-activation event.
Retries are bounded. Unmanaged app source memories persist through
`hs.settings`, not in the Nix configuration.

There are two separate CJK failure modes:

1. `TISSelectInputSource` can update the menu/global ID while leaving WezTerm's
   actual input context in ABC. Hammerspoon therefore calls its Nix-built
   `select-source.m` actuator for **both** directions inside WezTerm. It sends
   the Input menu's TSM request directly to the keyboard-focus process, checks
   its PID before each request, and bounds message timeouts. An already-selected
   but broken Squirrel context is repaired through ABC first. The child gets a
   clean environment, not Hammerspoon's Cocoa bundle identity. No window is
   activated, no keystrokes are injected, and no macism package/daemon is used.
   The private TSM symbols are resolved at runtime; unsupported systems report
   failure rather than pretending a CJK switch succeeded.
2. Squirrel can retain its own `ascii_mode`. `macOS/private/rime/pi_chinese_lock.lua`
   enforces Chinese through the native Rime option notifier, gated by a private
   flag set only on Squirrel's WezTerm sessions. It does not consume keys or
   change other apps' Shift/ASCII behavior. Ice schemas gain this processor;
   dictionaries and user data are not patched. No live user database is shared
   or opened by this manager. Control+F18 injection has been removed: WezTerm
   can consume control/function shortcuts before they reach the IME.

## Activation and diagnostics

1. `darwin-rebuild switch --flake .#mba`.
2. Allow Hammerspoon in macOS Privacy & Security > Accessibility if prompted.
3. In existing Pi sessions use `/reload`; new sessions discover the extension
   automatically. Noninteractive child Pi processes are not modified.
4. Start a new tmux server, or reload its config if a server was already running.

Hammerspoon console (or bundled `hs` CLI):

```lua
inputMethodManager.status()
inputMethodManager.events -- bounded metadata-only transition history
inputMethodManager.stop() -- emergency stop, leaves current source untouched
```

The CLI is `/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs`.
Reload the Hammerspoon config after a Nix update using `hs.reload()`.

Nix builds syntax-check every Lua file and run `policy.test.lua`, the mocked
Hammerspoon actuator API/lifecycle test, native-guard tests, and TypeScript
editor-policy/lifecycle tests. Additional implementation smoke tests
were run with a real Pi PTY (text -> slash menu -> model selector -> answer
editor -> custom menu -> focused note field -> menu -> text -> exit), a real isolated tmux server (attach -> split -> select -> copy mode),
and a disposable native librime profile (guard enforces Chinese idempotently).
Real GUI tab-switch tests must check actual composition (`nihc` -> `你好`),
not just the menu ID or `status().source`. A tiny/incomplete static dictionary
cache was rebuilt during diagnosis; the old build cache was preserved and
user databases were not changed.
