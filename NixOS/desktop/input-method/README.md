# Linux focus policy and tmux prefix handling

The Niri watcher owns fcitx state. Shared Pi/tmux reporters provide metadata,
not prompt text. Direct Ghostty surfaces and nested tmux are resolved separately.

Fast prefixes cannot rely on the 200 ms watcher alone. Rime-Ice schemas include
`ghostty_tmux_prefix`, a native Lua processor. It passes the prefix and next
press directly to the application (`kRejected = 0`), ignores release events,
and clears pending passthrough on Rime reset/deactivation and schema teardown.
There is no blocking subprocess or replacement tmux root binding on this path.

The processor requires an owner-only, atomic, expiring focus lease:
`~/.local/state/input-method/tmux-prefix-context`. The watcher grants it only
for a fresh tmux client matching the focused Ghostty title. Direct Pi, shells
outside tmux and unrelated apps revoke it. The frontend's nonempty `client_app`
property is additionally checked; native Wayland can leave this field empty.

`rime-data.nix` patches pinned Rime-Ice resources, preserving source dictionaries
as store links. Activation invalidates only the derived active schema YAML on
guard updates, never user dictionaries/training state. Restarting fcitx loads
updated Lua modules; its controller also exposes the deploy action:

```sh
busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 \
  SetConfig sv fcitx://config/addon/rime/deploy a{sv} 0
```

The build tests pure policy, lease permissions/revocation, Lua state transitions,
and real librime/librime-lua key processing in an isolated disposable profile.
The native test covers named and empty Wayland app properties, release events,
composition resuming, reset, other applications and stale focus leases.
Actual GUI tests use a separate tmux socket/window, never the user's session.
Run the opt-in test from an active Niri desktop (it briefly focuses its window):

```sh
nix shell .#nixosConfigurations.deck.pkgs.wtype -c bash tests/linux-tmux-prefix-ui.sh
```

It makes no model requests and keeps no Pi session. Physical/streaming keyboard
behavior and actual Chinese glyph composition still need human confirmation.
