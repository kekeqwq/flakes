"""Pure input-source policy for Linux. No fcitx5 or IPC calls here."""

import re

EMACS = {"emacs", "org.gnu.emacs"}
WEZTERM = {"org.wezfurlong.wezterm", "wezterm"}
GHOSTTY = {"com.mitchellh.ghostty", "ghostty"}
RIME = "rime"
ASCII = "ascii"


def socket_name(path):
    return (path or "").replace("/private/tmp/", "/tmp/")


def _fresh(client, now):
    """Ignore leftover snapshots from dead tmux sockets."""
    updated = client.get("updated")
    return isinstance(updated, (int, float)) and now - updated < 7 and now >= updated - 1


def _blocked(client):
    return (
        client.get("pane_in_mode") == "1"
        or client.get("client_prefix") == "1"
        or client.get("client_key_table") not in ("root", "", None)
    )


def client_for_title(title, clients, now):
    """Match the pushed socket/client-tty token, never a user window name."""
    if not title:
        return None
    for client in clients:
        if not _fresh(client, now):
            continue
        expected = f"tmux:{client.get('socket', '')}:{client.get('client_tty', '')}"
        if title == expected:
            return client
    return None


def focused_tmux(app_id, terminal, clients, now):
    """Authority for the native Rime prefix guard, not general key interception."""
    return (
        (app_id or "").lower() in GHOSTTY
        and bool(terminal)
        and not terminal.get("blocked")
        and client_for_title(terminal.get("title"), clients, now) is not None
    )


def _walk(first, clients, now):
    """Follow nested tmux from the matched client; None means prefix/mode."""
    current = first
    for _ in range(4):
        if _blocked(current):
            return None
        tty = current.get("pane_tty")
        pid = _int(current.get("foreground_pid"))
        pane = current.get("pane_id")
        socket = current.get("socket")
        nxt = None
        for client in clients:
            if _fresh(client, now) and client.get("client_tty") == tty:
                nxt = client
                break
        if nxt is None or nxt is current:
            break
        current = nxt
    return tty, pid, pane, socket


def direct_identity(title):
    return re.fullmatch(r"pi-ime:([1-9][0-9]*):([a-zA-Z0-9-]{1,64})", title or "")


def pi_context(terminal, clients, contexts, now):
    """Resolve the focused pane to a Pi editing context."""
    if not terminal or terminal.get("blocked"):
        return None
    identity = direct_identity(terminal.get("title"))
    if identity:
        pid, surface = identity.groups()
        for ctx in contexts:
            if (ctx.get("pid") == int(pid) and ctx.get("ghosttySurface") == surface
                    and not ctx.get("tmuxPane") and ctx.get("editing") is True
                    and _fresh(ctx, now)):
                return ctx
        return None
    if terminal.get("title"):
        # Ghostty/tmux path: the terminal window title identifies the client.
        seed = client_for_title(terminal["title"], clients, now)
        if seed is None:
            return None
        walked = _walk(seed, clients, now)
        if walked is None:
            return None
        tty, pid, pane, socket = walked
    else:
        # Wezterm path: the reported pane tty identifies the client.
        tty = terminal.get("tty")
        pid = terminal.get("pid")
        pane = None
        socket = None
        first = None
        for client in clients:
            if _fresh(client, now) and client.get("client_tty") == tty:
                first = client
                break
        if first is not None:
            walked = _walk(first, clients, now)
            if walked is None:
                return None
            tty, pid, pane, socket = walked
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
    title = (terminal or {}).get("title")
    if app in GHOSTTY and re.fullmatch(r"ghostty-shell:[a-zA-Z0-9-]{1,64}", title or ""):
        return ASCII
    if app in GHOSTTY and direct_identity(title):
        return RIME if pi_context(terminal, clients, contexts, now) else ASCII
    if app in GHOSTTY and not client_for_title(title, clients, now):
        # No surface identity yet: allow manual selection, including direct Pi.
        return None
    if app in WEZTERM or app in GHOSTTY:
        return RIME if pi_context(terminal, clients, contexts, now) else ASCII
    return None
