#!/usr/bin/python3
"""Waybar notification module, styled to match ~/.config/dunst/dunstrc.

HyDE ships notifications.py for the same job, but it hardcodes white/yellow/red
pango spans into its icons, which fights the graphite notification cards. This
one is monochrome: state is carried by the glyph and by a CSS class, never by
hue, so the bar and the cards read as one system.

States, in priority order:
    paused        DND on             󰂛  dim
    waiting       cards suppressed   󰂚  bone + count
    history       nothing pending    󰂚  faint + count
    idle          nothing at all     󰂜  faint

Output is waybar's JSON: text/alt/class/tooltip. `class` is what style.css
hooks (#custom-notifications.paused etc.).
"""

import json
import subprocess
import sys


def dunstctl(*args):
    """Run dunstctl, returning stripped stdout ('' if dunst isn't up)."""
    try:
        out = subprocess.run(
            ["dunstctl", *args], stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL, timeout=2,
        )
        return out.stdout.decode().strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def counts():
    """Parse `dunstctl count` -> (waiting, displayed, history).

    The output is a padded three-line table ("      Waiting: 0"), so each line
    is split on the colon rather than by column position.
    """
    waiting = displayed = history = 0
    for line in dunstctl("count").splitlines():
        label, _, value = line.partition(":")
        try:
            n = int(value.strip())
        except ValueError:
            continue
        label = label.strip().lower()
        if label == "waiting":
            waiting = n
        elif label.startswith("currently"):
            displayed = n
        elif label == "history":
            history = n
    return waiting, displayed, history


def recent(limit=6):
    """Last few notifications, newest first, as 'App — summary' lines."""
    raw = dunstctl("history")
    if not raw:
        return []
    try:
        data = json.loads(raw)["data"][0]
    except (ValueError, KeyError, IndexError):
        return []
    lines = []
    for n in data[:limit]:
        app = n.get("appname", {}).get("data", "") or "?"
        summary = n.get("summary", {}).get("data", "") or ""
        # Pango markup is on for the tooltip, so raw & < > from a message body
        # would make waybar drop the whole tooltip.
        for bad, good in (("&", "&amp;"), ("<", "&lt;"), (">", "&gt;")):
            app, summary = app.replace(bad, good), summary.replace(bad, good)
        lines.append(f"▍ {app} — {summary}" if summary else f"▍ {app}")
    return lines


def main():
    waiting, _displayed, history = counts()
    paused = dunstctl("get-pause-level") not in ("0", "")

    if paused:
        icon, state, text = "󰂛", "paused", ""
    elif waiting:
        icon, state, text = "󰂚", "waiting", str(waiting)
    elif history:
        icon, state, text = "󰂚", "history", str(history)
    else:
        icon, state, text = "󰂜", "idle", ""

    # Count rides as a superscript so the module width barely moves as it
    # changes -- a bar item that resizes on every notification is a twitch.
    label = f"{icon}<sup>{text}</sup>" if text else icon

    tip = ["󰎟 Notifications",
           f"   waiting {waiting} · history {history}"
           + ("  · DND ON" if paused else ""),
           "",
           "󰳽 left: toggle DND",
           "󰳽 scroll: pop last back",
           "󰳽 middle: clear history",
           "󰳽 right: dismiss all"]
    lines = recent()
    if lines:
        tip += ["", *lines]

    sys.stdout.write(json.dumps({
        "text": label,
        "alt": state,
        "class": state,
        "tooltip": "\n".join(tip),
    }) + "\n")
    sys.stdout.flush()


if __name__ == "__main__":
    main()
