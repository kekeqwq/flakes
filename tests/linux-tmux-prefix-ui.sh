#!/usr/bin/env bash
# Opt-in GUI test, not a sandbox check. Opens/closes only its own Ghostty/tmux.
# Run inside Niri: nix shell .#nixosConfigurations.deck.pkgs.wtype -c bash tests/linux-tmux-prefix-ui.sh
set -euo pipefail
: "${XDG_RUNTIME_DIR:?Run in the desktop session}"
: "${WAYLAND_DISPLAY:?Run in the desktop session}"
: "${NIRI_SOCKET:?Run in the Niri session}"
for program in ghostty tmux pi wtype niri python3 fcitx5-remote; do
  command -v "$program" >/dev/null
done
extension="$HOME/.pi/agent/extensions/input-method.ts"
test -f "$extension"
private=$(mktemp -d)
socket="$private/tmux.sock"
cleanup() {
  tmux -S "$socket" kill-server 2>/dev/null || true
  rm -rf -- "$private"
}
trap cleanup EXIT
# --no-session, no prompt, no model request. Never use the user's tmux server.
nohup ghostty --gtk-single-instance=true -e tmux -S "$socket" \
  -f "$HOME/.config/tmux/tmux.conf" new-session -s ime-check \
  "exec $(command -v pi) --no-session --no-extensions -e '$extension'" \
  >"$private/ghostty.log" 2>&1 </dev/null &
window=""
for _ in $(seq 1 80); do
  window=$(niri msg --json windows | python3 -c '
import sys,json
print(next((w["id"] for w in json.load(sys.stdin)
            if sys.argv[1] in (w.get("title") or "")), ""))' "$socket")
  if [ -n "$window" ]; then break; fi
  sleep .25
done
test -n "$window"
wait_source() {
  for _ in $(seq 1 50); do
    if [ "$(fcitx5-remote)" = "$1" ]; then return; fi
    sleep .1
  done
  echo "IME did not reach state $1" >&2
  return 1
}
check_focus() {
  niri msg action focus-window --id "$window"
  sleep .3
  niri msg --json focused-window | python3 -c '
import sys,json
w=json.load(sys.stdin) or {}
assert sys.argv[1] in (w.get("title") or ""), "lost test-window focus; no input sent"' "$socket"
  wait_source 2
  # Check that Niri/watch.py recognized this exact client, not another surface.
  for _ in $(seq 1 20); do
    if grep -q '^tmux ' "$HOME/.local/state/input-method/tmux-prefix-context"; then return; fi
    sleep .1
  done
  echo 'focused tmux lease not ready' >&2
  return 1
}
check_focus
wtype -M ctrl -k b -m ctrl c
sleep .4
test "$(tmux -S "$socket" list-windows -F '#{window_id}' | wc -l)" = 2
wait_source 1
echo 'Ctrl+B,c: new window + English shell PASS'
tmux -S "$socket" select-window -t ime-check:1
check_focus
wtype -M ctrl -k space -m ctrl c
sleep .4
test "$(tmux -S "$socket" list-windows -F '#{window_id}' | wc -l)" = 3
wait_source 1
echo 'Ctrl+Space,c: new window + English shell PASS'
tmux -S "$socket" select-window -t ime-check:1
check_focus
wtype -M ctrl -k b -m ctrl -k Escape
sleep .4
wait_source 2
echo 'Return to Pi + prefix Escape: Chinese source PASS'
