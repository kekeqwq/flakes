#!/usr/bin/env bash
# Usage: bash tests/tmux-theme.sh /absolute/path/to/generated/tmux.conf
# Isolated server: never source the test configuration into the user's server.
set -euo pipefail
trap 'printf "tmux style assertion failed at line %s\\n" "$LINENO" >&2' ERR
# The Darwin build sandbox defaults to C; emoji output needs an explicit UTF-8
# locale just like the real Ghostty client. Linux CI supplies its own locale.
if [[ $(uname -s) == Darwin ]]; then export LC_ALL=en_US.UTF-8; fi
config=${1:?generated tmux.conf path required}
name="theme-test-$$"
work=$(mktemp -d)
export TMUX_TMPDIR="$work" SHELL=/bin/sh
unset TMUX
trap 'tmux -L "$name" kill-server 2>/dev/null || true; rm -rf "$work"' EXIT
tmux -L "$name" -f /dev/null new-session -d -s probe 'exec /bin/sleep 300'
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
[ "$(tmux -L "$name" show -gv light-theme-blue)" = '#d81b80' ]
[ "$(tmux -L "$name" show -gv dark-theme-blue)" = '#89b4fa' ]
# Context menus must use per-client colour slots, not fixed RGB or tmux defaults.
[ "$(tmux -L "$name" show -gv menu-style)" = 'bg=themeblack,fg=themewhite' ]
[ "$(tmux -L "$name" show -gv menu-border-style)" = 'bg=themeblack,fg=themelightgrey' ]
[ "$(tmux -L "$name" show -gv menu-selected-style)" = 'bg=themeblue,fg=themeblack' ]
[ "$(tmux -L "$name" show -gv popup-style)" = 'bg=themeblack,fg=themewhite' ]
[ "$(tmux -L "$name" show -gv popup-border-style)" = 'bg=themeblack,fg=themeblue' ]
tmux -L "$name" show-hooks -g 'pane-focus-out' | grep -q '@ime-pane-unfocused 1'
tmux -L "$name" show-hooks -g 'pane-focus-in' | grep -q '@ime-pane-unfocused'
[[ $(tmux -L "$name" show -gv status-left) != *'bg=themeblue'* ]]
[ "$(tmux -L "$name" show -gv status)" = 2 ]
separator=$(tmux -L "$name" show -gv 'status-format[1]')
[[ $separator == *'#{client_width}'* && $separator == *'fg=themeblue,bg=default'* ]]
# Detached tests substitute only client width; expansion uses tmux's real R op.
for width in 20 80 137; do
	format=${separator//'#{client_width}'/$width}
	expanded=$(tmux -L "$name" display-message -p "$format")
	expected='#[fg=themeblue,bg=default]'
	for ((i = 0; i < width; i++)); do expected+='─'; done
	[ "$expanded" = "$expected" ]
done
[[ $(tmux -L "$name" show -gv window-status-style) == *bold* ]]
[[ $(tmux -L "$name" show -gv window-status-current-style) == *bold*underscore* ]]
# Session emoji stays on the far left; windows remain plain index.name text.
[[ $(tmux -L "$name" show -gv window-status-current-format) == *'#[underscore]#I.#W#[nounderscore]'* ]]
tmux -L "$name" set -g default-shell /bin/sh
tmux -L "$name" set -g default-command ''
tmux -L "$name" move-window -r -t probe
for index in $(seq 2 11); do
	tmux -L "$name" new-window -d -t "probe:$index" -n "window$index" 'exec /bin/sleep 300'
done
for index in 1 2 3 9 10 11; do
	expanded=$(tmux -L "$name" display-message -p -t "probe:$index" '#{E:window-status-current-format}')
	[[ $expanded == *"$index."* ]]
	[[ $expanded != *'️⃣'* && $expanded != *'🔟'* ]]
done
for spec in '0:0️⃣' '1:1️⃣' '2:2️⃣' '9:9️⃣' '10:🔟' '11:11' 'work:work'; do
	session=${spec%%:*}
	expected=${spec#*:}
	tmux -L "$name" new-session -d -s "$session" -n sample 'exec /bin/sleep 300'
	expanded=$(tmux -L "$name" display-message -p -t "$session:" '#{E:status-left}')
	[[ $expanded == *" $expected "* ]]
done
tmux -L "$name" new-window -d -t 0:2 -n second 'exec /bin/sleep 300'
first=$(tmux -L "$name" display-message -p -t 0:1 '#{E:status-left}')
second=$(tmux -L "$name" display-message -p -t 0:2 '#{E:status-left}')
[[ $first == "$second" && $first == *'0️⃣'* ]]
for mode in light dark; do
	tmux -L "$name" set -g theme "$mode"
	[[ $(tmux -L "$name" show -gv window-status-format) == *themelightgrey* ]]
	[[ $(tmux -L "$name" show -gv window-status-current-format) == *themeblue* ]]
done
printf '%s\n' 'tmux reload, identity token, session emoji, plain windows, adaptive separator, context menus and per-client palettes: PASS'
