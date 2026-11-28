{ reporter }:
map
  (hook: ''
    set-hook -g '${hook}[90]' 'run-shell -b "${reporter}/bin/input-method-tmux-update #{q:socket_path}"'
  '')
  [
    "client-attached"
    "client-detached"
    "client-session-changed"
    "session-window-changed"
    "after-select-pane"
    "after-select-window"
    "after-new-window"
    "after-split-window"
    "pane-mode-changed"
    "pane-exited"
    "pane-died"
    "window-pane-changed"
  ]
++ [
  # tmux hands keyboard focus to overlays without changing the active pane.
  # Save focus on the pane (not the session) before taking a new snapshot.
  ''
    set-hook -g 'pane-focus-out[90]' {
      set -p @ime-pane-unfocused 1
      run-shell -b "${reporter}/bin/input-method-tmux-update #{q:socket_path}"
    }
    set-hook -g 'pane-focus-in[90]' {
      set -pu @ime-pane-unfocused
      run-shell -b "${reporter}/bin/input-method-tmux-update #{q:socket_path}"
    }
  ''
]
