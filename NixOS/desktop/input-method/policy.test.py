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
assert want("org.wezfurlong.wezterm", contexts=[{**pi, "pid": 43}]) == "ascii"
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
}
nested_pi = {"pid": 99, "editing": True, "updated": now, "tmuxPane": "%8", "socket": "/tmp/tmux-501/nested"}
assert want("org.wezfurlong.wezterm", clients=[client, nested], contexts=[tmux_pi, nested_pi]) == "rime"

print("linux input-method policy: 17 assertions passed")
