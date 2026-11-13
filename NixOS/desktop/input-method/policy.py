"""Pure input-source policy for Linux. No fcitx5 or IPC calls here."""

EMACS = {"emacs", "org.gnu.emacs"}
WEZTERM = {"org.wezfurlong.wezterm", "wezterm"}
RIME = "rime"
ASCII = "ascii"


def socket_name(path):
    return (path or "").replace("/private/tmp/", "/tmp/")


def pi_context(terminal, clients, contexts, now):
    """Same nested-tmux walk as the macOS policy."""
    if not terminal or terminal.get("blocked"):
        return None
    tty = terminal.get("tty")
    pid = terminal.get("pid")
    pane = None
    socket = None
    for _ in range(4):
        found = None
        for client in clients:
            if client.get("client_tty") == tty:
                found = client
                break
        if not found:
            break
        if (
            found.get("pane_in_mode") == "1"
            or found.get("client_prefix") == "1"
            or found.get("client_key_table") not in ("root", "", None)
        ):
            return None
        tty = found.get("pane_tty")
        pid = _int(found.get("foreground_pid"))
        pane = found.get("pane_id")
        socket = found.get("socket")
    for ctx in contexts:
        if ctx.get("pid") != pid or ctx.get("editing") is not True:
            continue
        updated = ctx.get("updated")
        if not isinstance(updated, (int, float)):
            continue
        if not (now - updated < 7 and now >= updated - 1):
            continue
        if pane:
            if ctx.get("tmuxPane") == pane and socket_name(ctx.get("socket")) == socket_name(socket):
                return ctx
        elif not ctx.get("tmuxPane") and str(ctx.get("weztermPane")) == str(terminal.get("pane")):
            return ctx
    return None


def _int(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def desired(app_id, terminal, clients, contexts, now, prefix_held=False):
    """Return "rime", "ascii", or None to leave the current source alone."""
    if prefix_held:
        return ASCII
    app = (app_id or "").lower()
    if app in EMACS:
        return ASCII
    if app in WEZTERM:
        return RIME if pi_context(terminal, clients, contexts, now) else ASCII
    return None
