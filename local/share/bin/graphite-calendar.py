#!/usr/bin/env python3
"""Graphite Calendar — a real window, not a rofi list.

Why this exists: the agenda lived in rofi, which can only ever be a flat list of
rows. Picking "the 14th of next March" meant paging a month at a time through a
menu. A calendar needs a grid you can look at, and a year you can jump.

Left  : month grid. Days holding unfinished tasks are marked. The header moves
        by month; the two outer buttons move by year.
Right : the selected day's tasks — tick to complete, X to delete, type to add.

Storage is the same file the reminder daemon watches, so nothing here needs to
know about notifications:

    ~/.local/share/graphite-cal/events.tsv
    epoch <TAB> state(pending|done) <TAB> text

Styling matches the bar and the notification cards; GTK4 + python-gobject are
already on the system, so this pulls in nothing new.
"""

import datetime as dt
import os
import pathlib

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")   # silence the version warning; Gtk4 pulls Gdk4
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

STORE = pathlib.Path.home() / ".local/share/graphite-cal/events.tsv"

CSS = b"""
window, .bg { background: #0f0f13; color: #e6e6ea; }
* { font-family: "JetBrainsMono Nerd Font"; font-size: 12px; }

calendar {
    background: #121216;
    border: 1px solid #3a3a42;
    border-radius: 12px;
    padding: 6px;
    color: #9b9ba4;
}
calendar > header { color: #e6e6ea; font-weight: 600; }
calendar > grid > label.today { color: #ffffff; font-weight: 700; }
/* A marked day carries a task: bone text, so the month reads as a workload. */
calendar > grid > label:selected { background: #e6e6ea; color: #0f0f13; border-radius: 8px; }
calendar > grid > label.marked { color: #e6e6ea; font-weight: 700; }

.panel { background: #121216; border: 1px solid #3a3a42; border-radius: 12px; padding: 10px; }
.daytitle { color: #e6e6ea; font-weight: 600; font-size: 13px; }
.hint { color: #6e6e78; font-size: 11px; }
.task { color: #9b9ba4; }
.task-done { color: #5c5c66; }
.overdue { color: #ffffff; }

entry {
    background: #0f0f13; color: #e6e6ea;
    border: 1px solid #3a3a42; border-radius: 8px;
    padding: 6px 8px; caret-color: #e6e6ea;
}
button {
    background: #1a1a20; color: #9b9ba4;
    border: 1px solid #3a3a42; border-radius: 8px; padding: 4px 10px;
}
button:hover { background: #2a2a32; color: #ffffff; }
checkbutton check { border-radius: 5px; }
scrolledwindow { background: transparent; }
"""


def load():
    """All events as (epoch, state, text), oldest first."""
    out = []
    if not STORE.exists():
        return out
    for line in STORE.read_text().splitlines():
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        try:
            out.append((int(parts[0]), parts[1], "\t".join(parts[2:])))
        except ValueError:
            continue
    return sorted(out)


def save(rows):
    STORE.parent.mkdir(parents=True, exist_ok=True)
    STORE.write_text("".join(f"{e}\t{s}\t{t}\n" for e, s, t in rows))


class CalendarWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Calendar")
        # A popup, not an application window: small, and it leaves as soon as you
        # look away, the way a panel dropdown does.
        self.set_default_size(420, 430)
        self.set_resizable(False)
        # It stays open until YOU close it: Esc, or clicking the clock again
        # (the launcher toggles it). Auto-closing on focus loss took the popup
        # away mid-interaction, and made it impossible to keep on screen while
        # working from it.

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        root.set_margin_top(8); root.set_margin_bottom(8)
        root.set_margin_start(8); root.set_margin_end(8)
        root.add_css_class("bg")
        self.set_child(root)

        # ---- left: the grid, plus year jumps -----------------------------
        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        root.append(left)

        self.cal = Gtk.Calendar()
        self.cal.connect("day-selected", lambda *_: self.refresh_day())
        # GTK emits these when the header arrows move the view; the marks
        # belong to the visible month, so they have to be redrawn each time.
        for sig in ("next-month", "prev-month", "next-year", "prev-year"):
            self.cal.connect(sig, lambda *_: self.refresh_marks())
        left.append(self.cal)

        yearbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        yearbar.set_halign(Gtk.Align.CENTER)
        for label, delta in (("‹‹ year", -1), ("today", 0), ("year ››", 1)):
            b = Gtk.Button(label=label)
            b.connect("clicked", self.jump_year, delta)
            yearbar.append(b)
        left.append(yearbar)

        # ---- right: the selected day -------------------------------------
        right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        right.set_hexpand(True)
        right.add_css_class("panel")
        root.append(right)

        self.daylabel = Gtk.Label(xalign=0)
        self.daylabel.add_css_class("daytitle")
        right.append(self.daylabel)

        scroller = Gtk.ScrolledWindow()
        scroller.set_vexpand(True)
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.tasklist = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        scroller.set_child(self.tasklist)
        right.append(scroller)

        addbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)

        # Time gets its own box. Typing "14:30 " in front of the text worked but
        # was invisible unless you knew the trick, so most tasks silently landed
        # at 09:00.
        self.timebox = Gtk.Entry()
        self.timebox.set_max_width_chars(5)
        self.timebox.set_width_chars(5)
        self.timebox.set_placeholder_text("09:00")
        self.timebox.connect("activate", self.add_task)
        addbar.append(self.timebox)

        self.entry = Gtk.Entry()
        self.entry.set_hexpand(True)
        self.entry.set_placeholder_text("task…")
        self.entry.connect("activate", self.add_task)
        addbar.append(self.entry)
        addbtn = Gtk.Button(label="add")
        addbtn.connect("clicked", self.add_task)
        addbar.append(addbtn)
        right.append(addbar)

        hint = Gtk.Label(xalign=0, label="reminders: 2 days before · at the time · at login")
        hint.add_css_class("hint")
        right.append(hint)

        # Esc closes: this is a glance-and-go window, not an app you park.
        esc = Gtk.EventControllerKey()
        esc.connect("key-pressed", self.on_key)
        self.add_controller(esc)

        self.refresh_marks()
        self.refresh_day()

    # ---- helpers ---------------------------------------------------------
    def selected_date(self):
        d = self.cal.get_date()
        return dt.date(d.get_year(), d.get_month(), d.get_day_of_month())

    def on_key(self, _c, keyval, *_):
        if keyval == Gdk.KEY_Escape:
            self.close()
            return True
        return False

    def jump_year(self, _btn, delta):
        if delta == 0:
            today = dt.date.today()
            self.cal.select_day(GLib.DateTime.new_local(today.year, today.month, today.day, 0, 0, 0))
        else:
            d = self.selected_date()
            # 29 Feb only exists in leap years; clamp rather than crash.
            day = min(d.day, 28) if (d.month == 2 and d.day == 29) else d.day
            self.cal.select_day(GLib.DateTime.new_local(d.year + delta, d.month, day, 0, 0, 0))
        self.refresh_marks()
        self.refresh_day()

    def refresh_marks(self):
        """Mark every day in the visible month that still has work on it."""
        self.cal.clear_marks()
        d = self.cal.get_date()
        year, month = d.get_year(), d.get_month()
        for epoch, state, _text in load():
            if state != "pending":
                continue
            when = dt.datetime.fromtimestamp(epoch)
            if when.year == year and when.month == month:
                self.cal.mark_day(when.day)

    def refresh_day(self):
        self.refresh_marks()
        day = self.selected_date()
        self.daylabel.set_text(day.strftime("%A %d %B %Y"))

        child = self.tasklist.get_first_child()
        while child:
            nxt = child.get_next_sibling()
            self.tasklist.remove(child)
            child = nxt

        now = dt.datetime.now().timestamp()
        rows = [r for r in load()
                if dt.datetime.fromtimestamp(r[0]).date() == day]

        if not rows:
            empty = Gtk.Label(xalign=0, label="nothing on this day")
            empty.add_css_class("hint")
            self.tasklist.append(empty)
            return

        for epoch, state, text in rows:
            line = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)

            tick = Gtk.CheckButton()
            tick.set_active(state == "done")
            tick.connect("toggled", self.toggle, epoch, text)
            line.append(tick)

            when = dt.datetime.fromtimestamp(epoch).strftime("%H:%M")
            label = Gtk.Label(xalign=0, label=f"{when}   {text}")
            label.set_hexpand(True)
            label.add_css_class("task-done" if state == "done"
                                else "overdue" if epoch < now else "task")
            line.append(label)

            rm = Gtk.Button(label="✕")
            rm.connect("clicked", self.delete, epoch, text)
            line.append(rm)

            self.tasklist.append(line)

    # ---- mutations -------------------------------------------------------
    def add_task(self, *_):
        raw = self.entry.get_text().strip()
        if not raw:
            return
        day = self.selected_date()

        # The time box wins; a "14:30 " prefix in the text still works for
        # anyone who got used to it.
        hh, mm = 9, 0
        tval = self.timebox.get_text().strip()
        if ":" in tval:
            try:
                hh, mm = int(tval.split(":")[0]), int(tval.split(":")[1])
            except ValueError:
                hh, mm = 9, 0
        else:
            first, _, rest = raw.partition(" ")
            if ":" in first:
                try:
                    hh, mm = int(first.split(":")[0]), int(first.split(":")[1])
                    raw = rest.strip() or "reminder"
                except ValueError:
                    pass
        epoch = int(dt.datetime(day.year, day.month, day.day, hh, mm).timestamp())
        rows = load() + [(epoch, "pending", raw)]
        save(sorted(rows))
        self.entry.set_text("")
        self.timebox.set_text("")
        self.refresh_day()

    def toggle(self, btn, epoch, text):
        rows = [(e, ("done" if btn.get_active() else "pending") if (e == epoch and t == text) else s, t)
                for e, s, t in load()]
        save(rows)
        self.refresh_day()

    def delete(self, _btn, epoch, text):
        save([r for r in load() if not (r[0] == epoch and r[2] == text)])
        self.refresh_day()


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.graphite.calendar")

    def do_activate(self):
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        CalendarWindow(self).present()


if __name__ == "__main__":
    App().run(None)
