#!/usr/bin/env bash
# Usage: bash tests/tmux-theme.sh /absolute/path/to/generated/tmux.conf
# Isolated server: never source the test configuration into the user's server.
set -euo pipefail
config=${1:?generated tmux.conf path required}
name="theme-test-$$"
unset TMUX
trap 'tmux -L "$name" kill-server 2>/dev/null || true' EXIT
tmux -L "$name" -f /dev/null new-session -d -s probe
for _ in 1 2; do tmux -L "$name" source-file "$config"; done
[ "$(tmux -L "$name" show -gv set-titles-string)" = 'tmux:#{socket_path}:#{client_tty}' ]
[ "$(tmux -L "$name" show -gv theme)" = detect ]
# No asynchronous hook may overwrite global status colours anymore.
! tmux -L "$name" show-hooks -g | grep -q 'tmux-apply-catppuccin'
[ "$(tmux -L "$name" show -gv light-theme-black)" = '#eff1f5' ]
[ "$(tmux -L "$name" show -gv light-theme-white)" = '#4c4f69' ]
[ "$(tmux -L "$name" show -gv light-theme-light-grey)" = '#6c6f85' ]
[ "$(tmux -L "$name" show -gv dark-theme-black)" = '#1e1e2e' ]
[ "$(tmux -L "$name" show -gv dark-theme-white)" = '#cdd6f4' ]
[ "$(tmux -L "$name" show -gv dark-theme-light-grey)" = '#a6adc8' ]
for mode in light dark; do
  tmux -L "$name" set -g theme "$mode"
  [[ $(tmux -L "$name" show -gv window-status-format) == *themelightgrey* ]]
  [[ $(tmux -L "$name" show -gv window-status-current-format) == *themeblue* ]]
done
printf '%s\n' 'tmux config reload, unique focus token and native Catppuccin palettes: PASS'
