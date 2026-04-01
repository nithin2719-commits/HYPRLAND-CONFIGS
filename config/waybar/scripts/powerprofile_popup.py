import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, GLib, Gdk
import sys

mode = sys.argv[1] if len(sys.argv) > 1 else "balanced"

modes = {
    "performance": {"icon": "󱐋", "title": "Performance Mode", "desc": "Maximum CPU performance", "bar": "▰▰▰▰▰▰▰▰▰▰", "color": "#ff6b6b"},
    "balanced": {"icon": "⚖️", "title": "Balanced Mode", "desc": "Optimized for everyday use", "bar": "▰▰▰▰▰▱▱▱▱▱", "color": "#ffd93d"},
    "power-saver": {"icon": "🍃", "title": "Eco Mode", "desc": "Maximum battery saving", "bar": "▰▰▱▱▱▱▱▱▱▱", "color": "#6bcb77"}
}

m = modes[mode]
win = Gtk.Window()
win.set_decorated(False)
win.set_keep_above(True)
win.set_default_size(340, 100)
screen = win.get_screen()
visual = screen.get_rgba_visual()
if visual:
    win.set_visual(visual)
win.set_app_paintable(True)

css = """
window { background-color: rgba(30, 30, 46, 0.95); border-radius: 16px; }
#icon { font-size: 36px; padding: 10px 15px; }
#title { font-size: 16px; font-weight: bold; color: #cdd6f4; padding: 5px 0 0 0; }
#desc { font-size: 11px; color: #6c7086; padding: 2px 0 5px 0; }
#bar { font-size: 14px; padding: 0 0 8px 0; }
"""

provider = Gtk.CssProvider()
provider.load_from_data(css.encode())
Gtk.StyleContext.add_provider_for_screen(screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
box.set_margin_start(10)
box.set_margin_end(20)
icon = Gtk.Label(label=m['icon'])
icon.set_name("icon")
icon.override_color(Gtk.StateFlags.NORMAL, Gdk.RGBA(*[int(m['color'][i:i+2], 16)/255 for i in (1,3,5)] + [1]))
right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
right.set_valign(Gtk.Align.CENTER)
title = Gtk.Label(label=m['title'])
title.set_name("title")
title.set_halign(Gtk.Align.START)
desc = Gtk.Label(label=m['desc'])
desc.set_name("desc")
desc.set_halign(Gtk.Align.START)
bar = Gtk.Label(label=m['bar'])
bar.set_name("bar")
bar.set_halign(Gtk.Align.START)
bar.override_color(Gtk.StateFlags.NORMAL, Gdk.RGBA(*[int(m['color'][i:i+2], 16)/255 for i in (1,3,5)] + [1]))
right.pack_start(title, False, False, 0)
right.pack_start(desc, False, False, 0)
right.pack_start(bar, False, False, 0)
box.pack_start(icon, False, False, 0)
box.pack_start(right, False, False, 0)
win.add(box)
win.connect("realize", lambda w: w.move(1530 - 360, 10))
win.show_all()
GLib.timeout_add(2500, Gtk.main_quit)
Gtk.main()
