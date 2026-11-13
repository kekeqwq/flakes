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
