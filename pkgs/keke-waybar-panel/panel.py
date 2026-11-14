#!/usr/bin/env python3
"""Lightweight Catppuccin popup panels for Waybar.

One small window per section (brightness, audio, network, bluetooth, clock).
Only reads system state; sliders and buttons call the usual CLI tools.
"""

import json
import os
import re
import signal
import subprocess
import sys
import threading
import time
from datetime import datetime

if os.environ.get("KEKE_PANEL_DEBUG"):
    import faulthandler
    faulthandler.dump_traceback_later(8, repeat=True)

import cairo
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

try:
    gi.require_version("GtkLayerShell", "0.1")
    from gi.repository import GtkLayerShell  # noqa: E402

    HAVE_LAYER_SHELL = True
except (ValueError, ImportError):
    HAVE_LAYER_SHELL = False

APP_ID = "keke-waybar-panel"
RUNTIME = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
PIDFILE = os.path.join(RUNTIME, f"{APP_ID}.pid")
MARGIN = 16
BAR_TOP = 12
BAR_HEIGHT = 40
GAP = 14


def run(*cmd, timeout=3):
    try:
        done = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return done.stdout


def spawn(*cmd):
    try:
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


def pct(text):
    match = re.search(r"(\d+)%", text)
    return int(match.group(1)) if match else 0


# ---------------------------------------------------------------- brightness


class Brightness(Gtk.Box):
    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.value = Gtk.Label(label="0%")
        self.value.get_style_context().add_class("keke-value")
        self.value.set_xalign(1)

        self.slider = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 1, 100, 1)
        self.slider.set_draw_value(False)
        self.slider.connect("value-changed", self.on_value)

        head = Gtk.Box(spacing=8)
        icon = Gtk.Label(label="󰃠")
        head.pack_start(icon, False, False, 0)
        title = Gtk.Label(label="Brightness")
        title.get_style_context().add_class("keke-title")
        head.pack_start(title, False, False, 0)
        head.pack_end(self.value, False, False, 0)

        self.pack_start(head, False, False, 0)
        self.pack_start(self.slider, False, False, 0)
        self.refresh()

    def refresh(self):
        level = pct(run("brightnessctl", "-m"))
        set_scale(self.slider, level)
        self.value.set_text(f"{level}%")

    def on_value(self, scale):
        if getattr(scale, "updating", False):
            return
        level = int(scale.get_value())
        self.value.set_text(f"{level}%")
        spawn("brightnessctl", "set", f"{level}%")


def set_scale(scale, value):
    scale.updating = True
    scale.set_value(value)
    scale.updating = False


# --------------------------------------------------------------------- audio


class Audio(Gtk.Box):
    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.sink_value = Gtk.Label(label="0%")
        self.sink_value.get_style_context().add_class("keke-value")
        self.mic_value = Gtk.Label(label="0%")
        self.mic_value.get_style_context().add_class("keke-value")

        self.sink = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.mic = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        for scale in (self.sink, self.mic):
            scale.set_draw_value(False)
        self.sink.connect("value-changed", self.on_sink)
        self.mic.connect("value-changed", self.on_mic)

        self.sink_list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.mic_list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)

        self.pack_start(self.row("󰕾", "Output", self.sink_value), False, False, 0)
        self.pack_start(self.sink, False, False, 0)
        self.pack_start(self.label("DEVICES"), False, False, 0)
        self.pack_start(self.sink_list, False, False, 0)
        self.pack_start(Gtk.Separator(), False, False, 0)
        self.pack_start(self.row("󰍬", "Microphone", self.mic_value), False, False, 0)
        self.pack_start(self.mic, False, False, 0)
        self.pack_start(self.label("INPUT SOURCES"), False, False, 0)
        self.pack_start(self.mic_list, False, False, 0)
        self.refresh()

    def label(self, text):
        item = Gtk.Label(label=text)
        item.set_xalign(0)
        item.get_style_context().add_class("keke-section")
        return item

    def row(self, icon, text, value):
        head = Gtk.Box(spacing=8)
        head.pack_start(Gtk.Label(label=icon), False, False, 0)
        title = Gtk.Label(label=text)
        title.get_style_context().add_class("keke-title")
        head.pack_start(title, False, False, 0)
        head.pack_end(value, False, False, 0)
        return head

    def refresh(self):
        set_scale(self.sink, pct(run("pactl", "get-sink-volume", "@DEFAULT_SINK@")))
        set_scale(self.mic, pct(run("pactl", "get-source-volume", "@DEFAULT_SOURCE@")))
        self.sink_value.set_text(f"{int(self.sink.get_value())}%")
        self.mic_value.set_text(f"{int(self.mic.get_value())}%")
        self.fill_list(self.sink_list, "sinks", "set-default-sink", run("pactl", "get-default-sink"))
        self.fill_list(self.mic_list, "sources", "set-default-source", run("pactl", "get-default-source"))

    def fill_list(self, box, kind, setter, current):
        for child in box.get_children():
            box.remove(child)
        current = current.strip()
        for line in run("pactl", "list", "short", kind).splitlines():
            parts = line.split("\t")
            if len(parts) < 2:
                continue
            name = parts[1]
            button = device_button(humanize(name), name)
            if name == current:
                button.get_style_context().add_class("active")
            button.connect("clicked", lambda _b, n=name: (spawn("pactl", setter, n), self.refresh()))
            box.pack_start(button, False, False, 0)
        box.show_all()

    def on_sink(self, scale):
        if getattr(scale, "updating", False):
            return
        spawn("pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{int(scale.get_value())}%")
        self.sink_value.set_text(f"{int(scale.get_value())}%")

    def on_mic(self, scale):
        if getattr(scale, "updating", False):
            return
        spawn("pactl", "set-source-volume", "@DEFAULT_SOURCE@", f"{int(scale.get_value())}%")
        self.mic_value.set_text(f"{int(scale.get_value())}%")


def device_button(text, tooltip=None):
    """Long device names must not widen the card beyond the window."""
    label = Gtk.Label(label=text)
    label.set_xalign(0)
    label.set_ellipsize(3)  # Pango.EllipsizeMode.END
    label.set_max_width_chars(30)
    button = Gtk.Button()
    button.add(label)
    button.get_style_context().add_class("keke-device")
    if tooltip or text:
        button.set_tooltip_text(tooltip or text)
    return button


def humanize(name):
    name = name.replace("alsa_output.", "").replace("alsa_input.", "")
    name = re.sub(r"\.(analog|digital|hdmi)-.*", "", name)
    return name.replace("_", " ").replace(".", " ").strip().title()


# ------------------------------------------------------------------- network


class Network(Gtk.Box):
    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.info = Gtk.Label()
        self.info.set_xalign(0)
        self.info.set_line_wrap(True)
        self.wifi_list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.password = Gtk.Entry()
        self.password.set_visibility(False)
        self.password.set_placeholder_text("Wi-Fi password (only for secured networks)")
        self.password.get_style_context().add_class("keke-entry")
        self.pending = None
        self.message = Gtk.Label()
        self.message.set_xalign(0)
        self.message.get_style_context().add_class("keke-sub")

        head = Gtk.Box(spacing=8)
        head.pack_start(Gtk.Label(label="󰖟"), False, False, 0)
        title = Gtk.Label(label="Network")
        title.get_style_context().add_class("keke-title")
        head.pack_start(title, False, False, 0)
        self.pack_start(head, False, False, 0)
        self.pack_start(self.info, False, False, 0)
        section = Gtk.Label(label="AVAILABLE NETWORKS")
        section.set_xalign(0)
        section.get_style_context().add_class("keke-section")
        self.pack_start(section, False, False, 0)
        self.pack_start(self.wifi_list, False, False, 0)
        self.pack_start(self.password, False, False, 0)
        self.pack_start(self.message, False, False, 0)
        self.refresh()

    def refresh(self):
        lines = []
        wifi_iface = None
        for line in run("nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status").splitlines():
            parts = line.split(":")
            if len(parts) < 4 or parts[1] == "loopback":
                continue
            device, kind, state, connection = parts[0], parts[1], parts[2], ":".join(parts[3:])
            if kind == "wifi":
                wifi_iface = device
            if state != "connected":
                lines.append(f"{device} ({kind}): {state}")
                continue
            addr = json.loads(run("ip", "-j", "addr", "show", device) or "[]")
            ips = [
                a["local"]
                for entry in addr
                for a in entry.get("addr_info", [])
                if a.get("family") == "inet"
            ]
            mac = ""
            for entry in addr:
                mac = entry.get("address", "")
            signal = ""
            if kind == "wifi":
                for row in run("nmcli", "-t", "-f", "IN-USE,SIGNAL", "device", "wifi").splitlines():
                    if row.startswith("*"):
                        signal = f" · {row.split(':')[-1]}%"
                        break
            lines.append(f"{device} ({kind}) · {connection}{signal}\n{', '.join(ips)} · {mac}")
        self.info.set_text("\n".join(lines) or "No active connection")

        for child in self.wifi_list.get_children():
            self.wifi_list.remove(child)
        if not wifi_iface:
            self.wifi_list.pack_start(Gtk.Label(label="No wireless adapter"), False, False, 0)
        else:
            seen = set()
            rows = run("nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no")
            for line in rows.splitlines():
                parts = re.split(r"(?<!\\):", line)
                if len(parts) < 4:
                    continue
                active, ssid, strength, security = parts[0], parts[1], parts[2], ":".join(parts[3:])
                ssid = ssid.replace("\\:", ":")
                if not ssid or ssid in seen:
                    continue
                seen.add(ssid)
                icon = "󰤨" if int(strength or 0) > 70 else "󰤢" if int(strength or 0) > 40 else "󰤟"
                label = f"{icon}  {ssid}  {strength}%{'  󰌾' if security and security != '--' else ''}"
                button = device_button(label, ssid)
                if active == "*":
                    button.get_style_context().add_class("active")
                button.connect("clicked", self.on_pick, ssid, security)
                self.wifi_list.pack_start(button, False, False, 0)
        self.wifi_list.show_all()

    def on_pick(self, _button, ssid, security):
        self.pending = ssid
        self.password.set_visible(bool(security and security != "--"))
        if not security or security == "--":
            threading.Thread(target=self.connect_open, args=(ssid,), daemon=True).start()
        else:
            self.password.grab_focus()
            self.message.set_text(f"Enter the password for {ssid}, then press Enter")
            self.password.connect("activate", self.connect_secured)

    def connect_open(self, ssid):
        out = run("nmcli", "device", "wifi", "connect", ssid, timeout=20)
        GLib.idle_add(self.done, out)

    def connect_secured(self, _entry):
        if not self.pending:
            return
        out = run(
            "nmcli", "device", "wifi", "connect", self.pending,
            "password", self.password.get_text(), timeout=25,
        )
        self.password.set_text("")
        self.done(out)

    def done(self, out):
        self.message.set_text("Connected" if "successfully" in out.lower() else out.strip()[:120])
        self.refresh()


# ----------------------------------------------------------------- bluetooth


class Bluetooth(Gtk.Box):
    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.status = Gtk.Label()
        self.status.set_xalign(0)
        self.status.get_style_context().add_class("keke-sub")
        self.listbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        head = Gtk.Box(spacing=8)
        head.pack_start(Gtk.Label(label="󰂯"), False, False, 0)
        title = Gtk.Label(label="Bluetooth")
        title.get_style_context().add_class("keke-title")
        head.pack_start(title, False, False, 0)
        self.toggle = Gtk.Button(label="Power")
        self.toggle.get_style_context().add_class("keke-action")
        self.toggle.connect("clicked", self.on_toggle)
        head.pack_end(self.toggle, False, False, 0)
        self.pack_start(head, False, False, 0)
        self.pack_start(self.status, False, False, 0)
        self.pack_start(self.listbox, False, False, 0)
        self.scan = Gtk.Button(label="Scan for devices")
        self.scan.get_style_context().add_class("keke-action")
        self.scan.connect("clicked", self.on_scan)
        self.pack_start(self.scan, False, False, 0)
        self.refresh()

    def refresh(self):
        powered = "Powered: yes" in run("bluetoothctl", "show")
        self.toggle.set_label("On" if powered else "Off")
        connected = [line for line in run("bluetoothctl", "devices", "Connected").splitlines() if line.startswith("Device")]
        self.status.set_text(f"{'On' if powered else 'Off'} · {len(connected)} connected")
        for child in self.listbox.get_children():
            self.listbox.remove(child)
        known = run("bluetoothctl", "devices").splitlines()
        if not known:
            self.listbox.pack_start(Gtk.Label(label="Idle"), False, False, 0)
        for line in known[:12]:
            parts = line.split(" ", 2)
            if len(parts) < 3:
                continue
            mac, name = parts[1], parts[2]
            linked = any(mac in c for c in connected)
            button = device_button(f"{name}{'  ✓' if linked else ''}", mac)
            if linked:
                button.get_style_context().add_class("active")
            button.connect(
                "clicked",
                lambda _b, m=mac, c=linked: (
                    spawn("bluetoothctl", "disconnect" if c else "connect", m),
                    GLib.timeout_add(800, self.refresh),
                ),
            )
            self.listbox.pack_start(button, False, False, 0)
        self.listbox.show_all()

    def on_toggle(self, _button):
        powered = "Powered: yes" in run("bluetoothctl", "show")
        spawn("bluetoothctl", "power", "off" if powered else "on")
        GLib.timeout_add(700, self.refresh)

    def on_scan(self, _button):
        self.scan.set_label("Scanning…")
        spawn("bluetoothctl", "--timeout", "10", "scan", "on")
        GLib.timeout_add(11000, self.scan_done)

    def scan_done(self):
        self.scan.set_label("Scan for devices")
        self.refresh()
        return False


# --------------------------------------------------------------------- clock


class Clock(Gtk.Box):
    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.time = Gtk.Label()
        self.time.get_style_context().add_class("keke-value")
        self.time.set_xalign(0)
        self.date = Gtk.Label()
        self.date.set_xalign(0)
        self.calendar = Gtk.Calendar()
        self.pack_start(self.time, False, False, 0)
        self.pack_start(self.date, False, False, 0)
        self.pack_start(self.calendar, False, False, 0)
        self.tick()
        GLib.timeout_add_seconds(1, self.tick)

    def tick(self):
        now = datetime.now()
        self.time.set_text(now.strftime("%I:%M %p").lstrip("0"))
        self.date.set_text(now.strftime("%A, %B %d").replace(" 0", " "))
        return True


# -------------------------------------------------------------------- window


class PanelGroup:
    def __init__(self, section):
        self.panels = []
        self.active = None
        display = Gdk.Display.get_default()
        for index in range(display.get_n_monitors()):
            self.panels.append(Panel(section, display.get_monitor(index), self))
        GLib.timeout_add(350, self.fallback)
        if os.environ.get("KEKE_PANEL_DEBUG"):
            GLib.timeout_add_seconds(2, self.debug_state)

    def debug_state(self):
        print("panel-state", [{"active": self.active is panel,
              "mapped": panel.get_mapped(), "size": panel.get_size(),
              "card-visible": panel.card.get_visible(),
              "placed": panel.placed} for panel in self.panels], flush=True)
        return True

    def activate(self, panel, pointer_x):
        if self.active is None:
            if panel.get_allocated_width() < 2 or panel.get_allocated_height() < 2:
                GLib.timeout_add(16, self.activate, panel, pointer_x)
                return False
            self.active = panel
            if HAVE_LAYER_SHELL:
                GtkLayerShell.set_keyboard_mode(panel, GtkLayerShell.KeyboardMode.EXCLUSIVE)
            panel.place(pointer_x)

    def fallback(self):
        if self.active is None and self.panels:
            panel = self.panels[0]
            self.activate(panel, panel.get_allocated_width() - MARGIN)
        return False

    def close(self):
        for panel in self.panels:
            panel.hide()
        if Gtk.main_level():
            Gtk.main_quit()


class Panel(Gtk.Window):
    def __init__(self, section, monitor, group):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.set_decorated(False)
        # Full-monitor input surfaces must accept compositor configure sizes.
        # A non-resizable window can get stuck at GTK's initial 200x1 size.
        self.set_resizable(True)
        geometry = monitor.get_geometry()
        self.set_default_size(geometry.width, geometry.height)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_keep_above(True)
        self.set_type_hint(Gdk.WindowTypeHint.POPUP_MENU)
        self.get_style_context().add_class("keke-panel")
        self.set_title(APP_ID)
        # The overlay surface is transparent; only the card is painted.
        visual = self.get_screen().get_rgba_visual()
        if visual is not None:
            self.set_visual(visual)
        self.set_app_paintable(True)

        # A full-monitor transparent surface receives outside clicks. The card
        # has no opaque child GdkWindow, so CSS alpha and rounded corners work.
        self.section = section
        self.group = group
        self.placed = False
        card = Gtk.EventBox()
        card.set_visible_window(False)
        card.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        card.get_style_context().add_class("keke-card")
        card.set_size_request(340, -1)
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        for setter in (content.set_margin_start, content.set_margin_end):
            setter(20)
        for setter in (content.set_margin_top, content.set_margin_bottom):
            setter(18)
        self.scroller = Gtk.ScrolledWindow()
        self.scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.scroller.set_propagate_natural_height(True)
        self.scroller.set_max_content_height(560)
        self.scroller.add(content)
        card.add(self.scroller)
        card.connect("draw", self.paint_card)
        # Clicks inside the card must not dismiss it.
        card.connect("button-press-event", lambda *_: True)
        page = {
            "brightness": Brightness,
            "audio": Audio,
            "network": Network,
            "bluetooth": Bluetooth,
            "clock": Clock,
        }[section]()
        content.pack_start(page, True, True, 0)

        self.card = card
        self.fixed = Gtk.Fixed()
        self.fixed.put(card, 0, 0)
        outside = Gtk.EventBox()
        outside.set_visible_window(False)
        outside.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        outside.add(self.fixed)
        outside.connect("button-press-event", lambda *_: (self.close(), True)[1])
        self.add(outside)
        if HAVE_LAYER_SHELL:
            GtkLayerShell.init_for_window(self)
            GtkLayerShell.set_namespace(self, APP_ID)
            GtkLayerShell.set_monitor(self, monitor)
            GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
            for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM,
                         GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
                GtkLayerShell.set_anchor(self, edge, True)
            # Cover the bar too, but reserve no space or change window layout.
            GtkLayerShell.set_exclusive_zone(self, -1)
            GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.NONE)
        else:
            self.fullscreen()

        self.add_events(Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.POINTER_MOTION_MASK
                        | Gdk.EventMask.BUTTON_PRESS_MASK)
        self.connect("draw", self.clear_background)
        self.connect("enter-notify-event", self.on_pointer)
        self.connect("motion-notify-event", self.on_pointer)
        self.connect("key-press-event", self.on_key)
        self.connect("delete-event", lambda *_: (self.group.close(), True)[1])
        self.page = page
        card.set_no_show_all(True)
        self.show_all()
        # Enter coordinates are surface-local and work on Wayland: no guessed
        # global pointer coordinates, xdotool, or host-specific output layout.

    def clear_background(self, _widget, cr):
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.set_source_rgba(0, 0, 0, 0)
        cr.paint()
        cr.set_operator(cairo.OPERATOR_OVER)
        return False

    def paint_card(self, widget, cr):
        allocation = widget.get_allocation()
        context = widget.get_style_context()
        Gtk.render_background(context, cr, 0, 0, allocation.width, allocation.height)
        Gtk.render_frame(context, cr, 0, 0, allocation.width, allocation.height)
        for child in widget.get_children():
            widget.propagate_draw(child, cr)
        return True

    def on_pointer(self, _widget, event):
        self.group.activate(self, event.x)
        return False

    def place(self, pointer_x):
        from geometry import placement

        width, height = self.get_allocated_width(), self.get_allocated_height()
        if width < 2 or height < 2:
            return
        self.placed = True
        top = BAR_TOP + BAR_HEIGHT + GAP
        available = max(80, height - top - MARGIN)
        self.card.set_no_show_all(False)
        self.card.show_all()
        card_width = min(max(340, self.page.get_preferred_width()[0] + 40), width - 2 * MARGIN)
        page_height = self.page.get_preferred_height_for_width(card_width - 40)[1]
        card_height = min(page_height + 38, available)
        self.scroller.set_max_content_height(available)
        # GtkFixed allocates a child's minimum, not its natural height. An
        # explicit bounded request prevents the calendar collapsing to 32px.
        self.card.set_size_request(card_width, card_height)
        x, y = placement(width, height, card_width, card_height, pointer_x, self.section)
        self.fixed.move(self.card, x, y)

    def on_key(self, _window, event):
        if event.keyval == Gdk.KEY_Escape:
            self.close()
            return True
        return False


def existing_instance():
    try:
        with open(PIDFILE) as handle:
            pid = int(handle.read().strip())
        os.kill(pid, 0)
        if os.stat(f"/proc/{pid}").st_uid != os.getuid():
            return None
        with open(f"/proc/{pid}/cmdline", "rb") as handle:
            if APP_ID.encode() not in handle.read():
                return None
        return pid
    except (OSError, ValueError):
        return None


def main():
    section = sys.argv[1] if len(sys.argv) > 1 else "clock"
    if section == "--diagnostics":
        context = Gtk.Label().get_pango_context()
        font = context.load_font(context.get_font_description())
        print(json.dumps({
            "gtk-font-name": Gtk.Settings.get_default().get_property("gtk-font-name"),
            "resolved-font": font.describe().to_string() if font else None,
            "monitors": Gdk.Display.get_default().get_n_monitors(),
        }))
        return
    if section not in {"brightness", "audio", "network", "bluetooth", "clock"}:
        sys.exit("Expected brightness, audio, network, bluetooth or clock")
    previous = existing_instance()
    if previous:
        try:
            os.kill(previous, signal.SIGTERM)
        except OSError:
            pass
        time.sleep(0.15)

    with open(PIDFILE, "w") as handle:
        handle.write(str(os.getpid()))

    provider = Gtk.CssProvider()
    provider.load_from_path(os.environ["KEKE_PANEL_CSS"])
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )

    def bye(*_args):
        try:
            with open(PIDFILE) as handle:
                owner = int(handle.read().strip())
            if owner == os.getpid():
                os.unlink(PIDFILE)
        except (OSError, ValueError):
            pass
        if Gtk.main_level():
            Gtk.main_quit()

    def terminate(*_args):
        bye()
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGINT, terminate)
    panels = PanelGroup(section)
    Gtk.main()
    panels.close()
    bye()


if __name__ == "__main__":
    main()
