#!/usr/bin/env python3
"""Smoothly spinning CD for the dashboard's music card.

eww draws the rest of the card; this paints only the disc itself, in its own
click-through layer-shell window sitting exactly over the slot eww leaves for
it. It exists because eww renders an image by swapping the file it points at,
and that pipeline repaints about ten times a second no matter what it is fed —
measured, not assumed. Cairo rotates one texture instead, so the frame rate is
the compositor's, not eww's.

Inputs, all files the rest of the dashboard already maintains:
    ~/.cache/eww/art-current      path to the artwork to press
    ~/.cache/eww/player-status    Playing / Paused / Stopped
    ~/.cache/eww/dash-open        exists only while the panel is up

Geometry lives in ~/.config/eww/disc.conf (x, y, size in logical pixels) so it
can be nudged without touching this file.
"""
import math
import os
import time

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import Gtk, Gdk, GtkLayerShell, GdkPixbuf, GLib  # noqa: E402
import cairo  # noqa: E402

CACHE = os.path.expanduser("~/.cache/eww")
CONF = os.path.expanduser("~/.config/eww/disc.conf")

ART = os.path.join(CACHE, "art-current")
STATUS = os.path.join(CACHE, "player-status")
OPEN_FLAG = os.path.join(CACHE, "dash-open")

DEG_PER_SEC = 60.0          # a believable record speed
HOLE_RATIO = 0.115          # spindle radius as a fraction of the disc
LABEL_RATIO = 0.30          # the faint ring around the spindle


def read(path, default=""):
    try:
        with open(path) as fh:
            return fh.read().strip()
    except OSError:
        return default


def geometry():
    """x, y, size in logical pixels — the slot eww leaves for the disc."""
    x, y, size = 968, 99, 264
    for line in read(CONF).splitlines():
        line = line.split("#", 1)[0].strip()
        if "=" not in line:
            continue
        k, v = (p.strip() for p in line.split("=", 1))
        if k == "x" and v.lstrip("-").isdigit():
            x = int(v)
        elif k == "y" and v.lstrip("-").isdigit():
            y = int(v)
        elif k == "size" and v.isdigit():
            size = int(v)
    return x, y, size


class Disc(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.x, self.y, self.size = geometry()
        self.angle = 0.0
        self.last = time.monotonic()
        self.art_path = ""
        self.art_mtime = 0.0
        self.surface = None
        self.visible_now = False

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_namespace(self, "disc-spin")
        for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.LEFT):
            GtkLayerShell.set_anchor(self, edge, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.LEFT, self.x)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, self.y)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.NONE)

        self.set_app_paintable(True)
        self.set_default_size(self.size, self.size)
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.area = Gtk.DrawingArea()
        # Without an explicit request the area allocates 0x0 on a layer-shell
        # window and the draw handler is never called at all — the surface maps
        # with no buffer, which Hyprland reports as a layer with alpha 0.
        self.area.set_size_request(self.size, self.size)
        self.area.connect("draw", self.on_draw)
        self.add(self.area)

        self.connect("realize", self.on_realize)
        self.add_tick_callback(self.on_tick)
        GLib.timeout_add(200, self.poll_state)

    def on_realize(self, *_):
        # Click-through: the panel underneath owns every pointer event.
        region = cairo.Region()
        self.get_window().input_shape_combine_region(region, 0, 0)

    # ---- state ---------------------------------------------------------
    def poll_state(self):
        want = os.path.exists(OPEN_FLAG)
        if want != self.visible_now:
            self.visible_now = want
            (self.show_all if want else self.hide)()
            if want:
                self.on_realize()

        path = read(ART)
        if path and os.path.exists(path):
            mtime = os.path.getmtime(path)
            if path != self.art_path or mtime != self.art_mtime:
                self.art_path, self.art_mtime = path, mtime
                self.load_art(path)
        elif not path and self.surface is not None:
            self.surface = None
            self.area.queue_draw()
        return True

    def load_art(self, path):
        """Scale and centre-crop the artwork to a square the size of the disc."""
        try:
            px = GdkPixbuf.Pixbuf.new_from_file(path)
        except GLib.Error:
            self.surface = None
            return
        # Render at 2x so the disc stays crisp when the compositor scales up.
        side = self.size * 2
        w, h = px.get_width(), px.get_height()
        scale = side / min(w, h)
        sw, sh = max(side, int(w * scale + 0.5)), max(side, int(h * scale + 0.5))
        px = px.scale_simple(sw, sh, GdkPixbuf.InterpType.BILINEAR)
        px = px.new_subpixbuf((sw - side) // 2, (sh - side) // 2, side, side)

        surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, side, side)
        cr = cairo.Context(surf)
        Gdk.cairo_set_source_pixbuf(cr, px, 0, 0)
        cr.paint()
        self.surface = surf
        self.area.queue_draw()

    def on_tick(self, *_):
        now = time.monotonic()
        dt, self.last = now - self.last, now
        if self.visible_now and read(STATUS) == "Playing":
            self.angle = (self.angle + DEG_PER_SEC * dt) % 360.0
            self.area.queue_draw()
        return True

    # ---- painting ------------------------------------------------------
    def on_draw(self, _area, cr):
        size = self.size
        r = size / 2.0
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.set_source_rgba(0, 0, 0, 0)
        cr.paint()
        cr.set_operator(cairo.OPERATOR_OVER)

        cr.save()
        cr.arc(r, r, r, 0, 2 * math.pi)
        cr.clip()

        if self.surface is None:
            grad = cairo.RadialGradient(r, r, r * 0.15, r, r, r)
            grad.add_color_stop_rgb(0, 0.17, 0.17, 0.19)
            grad.add_color_stop_rgb(1, 0.07, 0.07, 0.09)
            cr.set_source(grad)
            cr.paint()
        else:
            cr.translate(r, r)
            cr.rotate(math.radians(self.angle))
            cr.scale(0.5, 0.5)          # the surface is rendered at 2x
            cr.translate(-size, -size)
            cr.set_source_surface(self.surface, 0, 0)
            cr.get_source().set_filter(cairo.FILTER_BILINEAR)
            cr.paint()
        cr.restore()

        # the faint label ring, which turns with nothing — it is part of the disc
        cr.set_source_rgba(1, 1, 1, 0.18)
        cr.set_line_width(max(1.0, size / 150))
        cr.arc(r, r, r * LABEL_RATIO, 0, 2 * math.pi)
        cr.stroke()

        # spindle hole
        cr.set_operator(cairo.OPERATOR_CLEAR)
        cr.arc(r, r, r * HOLE_RATIO, 0, 2 * math.pi)
        cr.fill()
        cr.set_operator(cairo.OPERATOR_OVER)
        return False


def main():
    win = Disc()
    win.connect("destroy", Gtk.main_quit)
    if os.path.exists(OPEN_FLAG):
        win.visible_now = True
        win.show_all()
        win.on_realize()
    Gtk.main()


if __name__ == "__main__":
    main()
