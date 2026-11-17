"""Regression tests for the Linux input-source policy (no fcitx5 needed)."""

import runpy
import sys

policy = runpy.run_path(sys.argv[1])
now = 1000.0
terminal = {"pane": 0, "tty": "/dev/pts/1", "pid": 42}
pi = {"pid": 42, "editing": True, "updated": now, "weztermPane": "0"}


def want(app, term=terminal, clients=(), contexts=(pi,), prefix=False):
    return policy["desired"](app, term, list(clients), list(contexts), now, prefix)


assert want("org.gnu.Emacs") == "ascii"
assert want("emacs") == "ascii"
assert want("org.wezfurlong.wezterm") == "rime"
assert want("org.wezfurlong.wezterm", term={**terminal, "blocked": True}) == "ascii"
assert want("org.wezfurlong.wezterm", term={**terminal, "pane": 1}) == "ascii"
assert want("org.wezfurlong.wezterm", contexts=[{**pi, "editing": False}]) == "ascii"
assert want("org.wezfurlong.wezterm", contexts=[{**pi, "updated": now - 8}]) == "ascii"
assert want("org.wezfurlong.wezterm", prefix=True) == "ascii"
# However Pi was started, a fresh editing Pi in the focused pane is Chinese:
# PID mismatch (fish -c pi job layout, reporter gaps, restarts) must not
# force ASCII. Container identity + editing + freshness remains required.
assert want("org.wezfurlong.wezterm", contexts=[{**pi, "pid": 43}]) == "rime"
assert want("org.wezfurlong.wezterm", contexts=[{**pi, "pid": 43, "updated": now - 8}]) == "ascii"
assert policy["pi_context"](
    terminal, [], [{**pi, "pid": 43}, {**pi, "pid": 42}], now
).get("pid") == 42  # exact PID preferred over the container fallback
assert want("com.example.other") is None

client = {
    "client_tty": "/dev/pts/1",
    "pane_id": "%3",
    "pane_tty": "/dev/pts/9",
    "foreground_pid": 88,
    "socket": "/private/tmp/tmux-501/default",
    "pane_in_mode": "0",
    "client_prefix": "0",
    "client_key_table": "root",
    "updated": now,
}
tmux_pi = {
    "pid": 88,
    "editing": True,
    "updated": now,
    "tmuxPane": "%3",
    "socket": "/tmp/tmux-501/default",
}
assert want("org.wezfurlong.wezterm", clients=[client], contexts=[tmux_pi]) == "rime"
assert (
    want("org.wezfurlong.wezterm", clients=[{**client, "pane_id": "%4"}], contexts=[tmux_pi])
    == "ascii"
)
assert (
    want("org.wezfurlong.wezterm", clients=[{**client, "pane_in_mode": "1"}], contexts=[tmux_pi])
    == "ascii"
)
assert (
    want(
        "org.wezfurlong.wezterm",
        clients=[{**client, "client_prefix": "1"}],
        contexts=[tmux_pi],
    )
    == "ascii"
)
nested = {
    "client_tty": "/dev/pts/9",
    "pane_id": "%8",
    "pane_tty": "/dev/pts/10",
    "foreground_pid": 99,
    "socket": "/tmp/tmux-501/nested",
    "pane_in_mode": "0",
    "client_prefix": "0",
    "client_key_table": "root",
    "updated": now,
}
nested_pi = {"pid": 99, "editing": True, "updated": now, "tmuxPane": "%8", "socket": "/tmp/tmux-501/nested"}
assert want("org.wezfurlong.wezterm", clients=[client, nested], contexts=[tmux_pi, nested_pi]) == "rime"

# Ghostty: socket + client tty identifies the client.
titled = {**client, "session_name": "0", "window_name": "pi"}
gh = {"title": "tmux:/private/tmp/tmux-501/default:/dev/pts/1"}
assert want("com.mitchellh.ghostty", term=gh, clients=[titled], contexts=[tmux_pi]) == "rime"
# An unidentified window permits manual Chinese instead of forcing ASCII.
assert (
    want("com.mitchellh.ghostty", term={"title": "keke@deck ~"}, clients=[titled], contexts=[tmux_pi])
    is None
)
# Prefix held on the focused client keeps ASCII.
assert (
    want("com.mitchellh.ghostty", term=gh, clients=[{**titled, "client_prefix": "1"}], contexts=[tmux_pi])
    == "ascii"
)
# Two clients on the same session/window still have distinct focus tokens.
other = {
    **titled,
    "client_tty": "/dev/pts/5",
    "pane_id": "%9",
    "session_name": "0",
    "window_name": "pi",
    "foreground_pid": 77,
}
other_pi = {"pid": 77, "editing": True, "updated": now, "tmuxPane": "%9", "socket": "/tmp/tmux-501/default"}
gh2 = {"title": "tmux:/private/tmp/tmux-501/default:/dev/pts/5"}
assert want("com.mitchellh.ghostty", term=gh2, clients=[titled, other], contexts=[tmux_pi]) == "ascii"
assert (
    want("com.mitchellh.ghostty", term=gh2, clients=[titled, other], contexts=[tmux_pi, other_pi])
    == "rime"
)

# A stale snapshot from a dead socket must not steal the nested walk.
stale = {
    **client,
    "client_tty": "/dev/pts/9",
    "pane_id": "%9",
    "foreground_pid": 100,
    "updated": now - 30,
}
assert want("org.wezfurlong.wezterm", clients=[client, stale], contexts=[tmux_pi]) == "rime"

# Non-tmux Pi: exact PID + Ghostty surface identity, never title/cwd guesses.
direct = {"title": "pi-ime:42:surface-a"}
direct_pi = {"pid": 42, "ghosttySurface": "surface-a", "editing": True, "updated": now}
assert want("com.mitchellh.ghostty", term=direct, contexts=[direct_pi]) == "rime"
assert want("com.mitchellh.ghostty", term=direct, contexts=[{**direct_pi, "editing": False}]) == "ascii"
# Same surface, any fresh editing Pi: Chinese even when the pid drifted.
assert want("com.mitchellh.ghostty", term=direct, contexts=[{**direct_pi, "pid": 43}]) == "rime"
assert want("com.mitchellh.ghostty", term=direct, contexts=[{**direct_pi, "pid": 43, "updated": now - 8}]) == "ascii"
assert want("com.mitchellh.ghostty", term=direct, contexts=[{**direct_pi, "ghosttySurface": "surface-b"}]) == "ascii"
assert want("com.mitchellh.ghostty", term=direct, contexts=[{**direct_pi, "updated": now - 8}]) == "ascii"
assert want("com.mitchellh.ghostty", term=direct, contexts=[{**direct_pi, "updated": now + 2}]) == "ascii"
assert want("com.mitchellh.ghostty", term=direct, contexts=[{**direct_pi, "tmuxPane": "%1"}]) == "ascii"
assert want("com.mitchellh.ghostty", term=direct, contexts=[], prefix=True) == "ascii"
assert want("com.mitchellh.ghostty", term={"title": "ghostty-shell:surface-a"}, contexts=[direct_pi]) == "ascii"
assert want("com.example.other", term=direct, contexts=[direct_pi]) is None
# A second direct Pi in another tab must never steal the active surface.
other_direct = {"pid": 43, "ghosttySurface": "surface-b", "editing": True, "updated": now}
assert want("com.mitchellh.ghostty", term=direct, contexts=[other_direct, direct_pi]) == "rime"
assert want("com.mitchellh.ghostty", term=direct, contexts=[other_direct]) == "ascii"
assert want("com.mitchellh.ghostty", term={"title": "pi-ime:0:surface-a"}, contexts=[direct_pi]) is None
assert policy["focused_tmux"]("com.mitchellh.ghostty", gh, [titled], now)
assert not policy["focused_tmux"]("emacs", gh, [titled], now)
assert not policy["focused_tmux"]("com.mitchellh.ghostty", direct, [titled], now)
assert not policy["focused_tmux"]("com.mitchellh.ghostty", gh, [{**titled, "updated": now - 8}], now)
assert not policy["focused_tmux"]("com.mitchellh.ghostty", None, [titled], now)
print("linux input-method policy: tmux/direct Ghostty, prefix scope, isolation and lease tests passed")
