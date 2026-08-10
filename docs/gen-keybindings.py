#!/usr/bin/env python3
"""Regenerate docs/KEYBINDINGS.md from the Hyprland configs.

The cheatsheet in this repo is generated, not hand-maintained, so it can never
drift from the binds that are actually loaded. Run it after changing any bind:

    python3 docs/gen-keybindings.py            # writes docs/KEYBINDINGS.md
    python3 docs/gen-keybindings.py --check    # exit 1 if the file is stale

Only *active* binds are listed. A commented-out bind is a bind that does not
exist, and several in this config are commented out on purpose (duplicates that
made a key fire twice) -- listing them would be a lie.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
HYPR = REPO / "config" / "hypr"
OUT = REPO / "docs" / "KEYBINDINGS.md"

# Sourced by hyprland.conf, in load order.
SOURCES = ["hyprland.conf", "keybindings.conf", "userprefs.conf"]

BIND_RE = re.compile(r"^(bindd|binded|bindel|bindl|bindm|binde|bind)\s*=\s*(.*)$")

# Variables the configs define for themselves.
VARS = {
    "$mainMod": "SUPER",
    "$term": "kitty",
    "$file": "thunar",
    "$browser": "firefox",
    "$scrPath": "~/.local/share/bin",
    "$CONTROL": "CTRL",
}

FLAG_NOTE = {
    "bindl": "works while locked",
    "bindel": "repeats when held, works while locked",
    "binde": "repeats when held",
    "bindm": "mouse drag",
    "bindd": "",
    "binded": "repeats when held",
}

# (section title, ordered list of regexes matched against "MODS KEY DISPATCH ARGS")
SECTIONS: list[tuple[str, list[str]]] = [
    ("Launching things", [
        r"exec,\s*\$term", r"exec,\s*\$file", r"exec,\s*\$browser",
        r"exec,.*\brofi -show drun", r"exec,.*torbrowser", r"exec,.*google-chrome",
        r"exec,.*blackarch-launcher", r"exec,.*eDEX", r"exec,.*Claude", r"exec,.*GitHub",
        r"exec,.*Kooha", r"exec,.*firefox http",
    ]),
    ("Window control", [
        r"\bkillactive\b", r"dontkillsteam", r"\btogglefloating\b", r"\btogglegroup\b",
        r"\bfullscreen\b", r"\bcyclenext\b", r"bringactivetotop", r"\bmovefocus\b",
        r"\bresizeactive\b", r"\bmovewindow\b", r"\bresizewindow\b", r"\blayoutmsg\b",
        r"changegroupactive", r"windowpin", r"showdesktop", r"moveactive",
    ]),
    ("Workspaces", [
        r"\bworkspace\b", r"movetoworkspace", r"togglespecialworkspace",
    ]),
    ("Rice controls", [
        r"themeselect", r"themestyle", r"swwwallselect", r"swwwallpaper",
        r"wbarconfgen", r"rofiselect", r"wallbashtoggle", r"animations\.sh",
        r"killall waybar", r"aura", r"hyprpicker",
    ]),
    ("Screenshot & clipboard", [
        r"screenshot", r"\bgrim\b", r"cliphist",
    ]),
    ("Audio, brightness & media", [
        r"volume\.sh", r"vol-osd", r"volumecontrol", r"brightness", r"bright-osd",
        r"playerctl", r"XF86Audio", r"brightnessctl", r"amixer",
    ]),
    ("Notifications", [
        r"dunstctl", r"notif-", r"notify-send",
    ]),
    ("Power, session & hardware", [
        r"logoutlaunch", r"hyprlock", r"\bexit\b", r"perfmode", r"powermode",
        r"powerprofile", r"gamemode", r"keyboardswitch", r"keybinds_hint",
    ]),
    ("Dashboard", [
        r"eww", r"toggle\.sh",
    ]),
]


def expand(text: str) -> str:
    for k, v in VARS.items():
        text = text.replace(k, v)
    return text


def pretty_keys(mods: str, key: str) -> str:
    mods = expand(mods).strip()
    parts = [p for p in re.split(r"[\s+]+", mods) if p]
    seen, ordered = set(), []
    for p in parts:
        u = p.upper().replace("_L", "").replace("_R", "")
        u = {"SUPER": "SUPER", "MOD": "SUPER", "CONTROL": "CTRL"}.get(u, u)
        if u and u not in seen:
            seen.add(u)
            ordered.append(u)
    key = key.strip()
    pretty = {
        "RETURN": "Enter", "ESCAPE": "Esc", "SLASH": "/", "DELETE": "Del",
        "PRINT": "PrtSc", "TAB": "Tab", "SPACE": "Space",
        "LEFT": "←", "RIGHT": "→", "UP": "↑", "DOWN": "↓",
        "MOUSE_DOWN": "Scroll ↓", "MOUSE_UP": "Scroll ↑",
        "MOUSE:272": "LMB", "MOUSE:273": "RMB", "MOUSE:277": "Side btn",
    }
    k = pretty.get(key.upper(), key if len(key) > 1 else key.upper())
    ordered.append(k)
    return " ".join(f"`{p}`" for p in ordered)


def describe(dispatcher: str, args: str, given: str | None) -> str:
    if given:
        return given.strip()
    d, a = dispatcher.strip(), expand(args.strip())
    a = re.sub(r"\s*#.*$", "", a).strip()

    # `exec, hyprctl dispatch <d> <a>` is the same thing as a native dispatcher,
    # written the long way round. Unwrap it so it describes like one.
    m = re.match(r"^hyprctl\s+dispatch\s+(\S+)\s*(.*)$", a)
    if d == "exec" and m:
        d, a = m.group(1), m.group(2).strip()

    if d != "exec":
        if d == "fullscreen":
            return "Fullscreen" if a in ("", "0") else "Maximize (keep the bar visible)"
        if d in ("movewindow", "resizewindow") and not a:
            return "Drag to move" if d == "movewindow" else "Drag to resize"
        human = {
            "killactive": "Close the focused window",
            "togglefloating": "Toggle floating",
            "togglegroup": "Toggle window group",
            "fullscreen": "Fullscreen",
            "cyclenext": "Cycle to the next window" + (" (backwards)" if "prev" in a else ""),
            "bringactivetotop": "Raise the focused window",
            "exit": "Quit Hyprland",
            "togglesplit": "Toggle split direction",
        }.get(d)
        if human:
            return human
        arrows = {"l": "left", "r": "right", "u": "up", "d": "down"}
        if d == "movefocus":
            return f"Focus {arrows.get(a, a)}"
        if d == "movewindow":
            return f"Move window {arrows.get(a, a)}"
        if d == "resizeactive":
            return f"Resize window ({a})"
        if d == "workspace":
            return {"empty": "Go to the first empty workspace"}.get(
                a, f"Go to workspace {a}" if a.isdigit() else f"Workspace {a}")
        if d == "movetoworkspace":
            return f"Move window to workspace {a}"
        if d == "movetoworkspacesilent":
            return f"Move window to workspace {a}, stay here"
        if d == "togglespecialworkspace":
            return f"Toggle scratchpad{f' ({a})' if a else ''}"
        if d == "changegroupactive":
            return "Previous window in group" if a == "b" else "Next window in group"
        if d == "layoutmsg":
            return f"Layout: {a}"
        return f"{d} {a}".strip()

    a = re.sub(r"^pkill -x rofi \|\|\s*", "", a)
    known = [
        (r"themeselect", "Theme select menu"),
        (r"themestyle", "Theme style menu"),
        (r"swwwallselect", "Wallpaper select menu"),
        (r"swwwallpaper\.sh -n", "Next wallpaper"),
        (r"swwwallpaper\.sh -p", "Previous wallpaper"),
        (r"wbarconfgen\.sh n", "Next Waybar mode"),
        (r"wbarconfgen\.sh p", "Previous Waybar mode"),
        (r"killall waybar", "Toggle Waybar"),
        (r"rofiselect", "Rofi style menu"),
        (r"wallbashtoggle", "Wallbash mode menu"),
        (r"animations\.sh", "Animation preset menu"),
        (r"cliphist\.sh c", "Clipboard history"),
        (r"cliphist\.sh", "Clipboard manager"),
        (r"screenshot\.sh sf", "Region screenshot (frozen screen)"),
        (r"screenshot\.sh s", "Region screenshot"),
        (r"screenshot\.sh m", "Whole-monitor screenshot"),
        (r"grim .*swappy", "Screenshot, then annotate in swappy"),
        (r"hyprpicker", "Colour picker → clipboard"),
        (r"hyprlock", "Lock the screen"),
        (r"logoutlaunch", "Logout / power menu"),
        (r"keybinds_hint", "This cheatsheet, in-session"),
        (r"keyboardswitch", "Switch keyboard layout"),
        (r"dontkillsteam", "Close the focused window"),
        (r"windowpin", "Pin the window on top"),
        (r"showdesktop", "Show the desktop"),
        (r"gamemode", "Game mode (effects off)"),
        (r"dunstctl history-pop", "Replay the last notification"),
        (r"dunstctl close-all", "Dismiss all notifications"),
        (r"asusctl aura effect --next-mode", "Cycle keyboard aura (ROG)"),
        (r"kbd_backlight set 0%", "Keyboard backlight off"),
        (r"kbd_backlight set 100%", "Keyboard backlight full"),
        (r"perfmode", "Performance profile (ROG)"),
        (r"powerprofile_toggle", "Cycle power profile (ROG)"),
        (r"volume\.sh up|vol-osd\.sh up", "Volume up"),
        (r"volume\.sh down", "Volume down"),
        (r"volume\.sh mute|vol-osd\.sh mute", "Mute"),
        (r"volumecontrol\.sh -i m", "Mute the microphone"),
        (r"brightness\.sh up", "Brightness up"),
        (r"brightness\.sh down", "Brightness down"),
        (r"playerctl play-pause", "Play / pause"),
        (r"playerctl next", "Next track"),
        (r"playerctl previous", "Previous track"),
        (r"blackarch-launcher", "BlackArch tool launcher"),
        (r"torbrowser", "Tor Browser"),
        (r"eww/scripts/toggle\.sh close", "Force-close the eww dashboard"),
        (r"Kooha", "Screen recorder (Kooha)"),
        (r"eDEX", "eDEX-UI"),
        (r"rofi -show drun", "Application launcher"),
    ]
    for pat, txt in known:
        if re.search(pat, a):
            return txt
    m = re.search(r"--app=https://([^\s\"']+)", a)
    if m:
        host = m.group(1).split("/")[0].replace("www.", "")
        return f"Open {host}"
    m = re.search(r"(?:firefox|google-chrome-stable)\s+https://([^\s\"']+)", a)
    if m:
        return f"Open {m.group(1).split('/')[0].replace('www.', '')}"
    if a.startswith("notify-send"):
        return "Test notification"
    for prog, label in (("kitty", "Terminal"), ("thunar", "File manager"),
                        ("firefox", "Web browser")):
        if a.startswith(prog):
            return label
    m = re.search(r"([\w.-]+)$", a.split()[0] if a.split() else a)
    return m.group(1) if m else a


def parse() -> list[dict]:
    binds = []
    for name in SOURCES:
        path = HYPR / name
        if not path.exists():
            continue
        for lineno, raw in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            s = raw.strip()
            if not s or s.startswith("#"):
                continue
            m = BIND_RE.match(s)
            if not m:
                continue
            flag, rest = m.group(1), m.group(2)
            rest = re.sub(r"\s+#.*$", "", rest)
            parts = [p.strip() for p in rest.split(",")]
            if len(parts) < 3:
                continue
            mods, key = parts[0], parts[1]
            if flag in ("bindd", "binded"):
                desc, dispatcher, args = parts[2], (parts[3] if len(parts) > 3 else ""), ",".join(parts[4:])
            else:
                desc, dispatcher, args = None, parts[2], ",".join(parts[3:])
            binds.append({
                "file": name, "line": lineno, "flag": flag,
                "keys": pretty_keys(mods, key),
                "desc": describe(dispatcher, args, desc),
                "haystack": f"{mods} {key} {dispatcher}, {args}",
                "note": FLAG_NOTE.get(flag, ""),
            })
    return binds


def render(binds: list[dict]) -> str:
    used, buckets = set(), {title: [] for title, _ in SECTIONS}
    for title, pats in SECTIONS:
        for i, b in enumerate(binds):
            if i in used:
                continue
            if any(re.search(p, b["haystack"], re.I) for p in pats):
                buckets[title].append(b)
                used.add(i)
    other = [b for i, b in enumerate(binds) if i not in used]

    out = [
        "# Keybindings",
        "",
        "> Generated from the live configs by `docs/gen-keybindings.py` — do not",
        "> hand-edit. Re-run it after changing a bind.",
        "",
        f"`SUPER` is the mod key. **{len(binds)} active binds** across "
        + ", ".join(f"`{s}`" for s in SOURCES) + ".",
        "",
        "Commented-out binds are not listed: several in this config are disabled",
        "on purpose because Hyprland fires *every* bind matching a combo, so a",
        "duplicate made the key act twice.",
        "",
        "In-session cheatsheet: `SUPER` `/`",
        "",
    ]
    for title, _ in SECTIONS:
        rows = buckets[title]
        if not rows:
            continue
        out += [f"## {title}", "", "| Keys | Action | | Defined in |", "|---|---|---|---|"]
        for b in rows:
            note = f"<sub>{b['note']}</sub>" if b["note"] else ""
            out.append(f"| {b['keys']} | {b['desc']} | {note} | `{b['file']}:{b['line']}` |")
        out.append("")
    if other:
        out += ["## Everything else", "", "| Keys | Action | | Defined in |", "|---|---|---|---|"]
        for b in other:
            note = f"<sub>{b['note']}</sub>" if b["note"] else ""
            out.append(f"| {b['keys']} | {b['desc']} | {note} | `{b['file']}:{b['line']}` |")
        out.append("")
    out += [
        "---",
        "",
        "## Modifier flags",
        "",
        "| Directive | Meaning |",
        "|---|---|",
        "| `bind` | Fires once on press |",
        "| `binde` | Repeats while held |",
        "| `bindl` | Also fires while the screen is locked |",
        "| `bindel` | Repeats while held, and fires while locked |",
        "| `bindm` | Mouse drag binding |",
        "| `bindd` | Has a description (shown in the in-session cheatsheet) |",
        "",
    ]
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="exit 1 if KEYBINDINGS.md is stale")
    args = ap.parse_args()

    text = render(parse())
    if args.check:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != text:
            print("docs/KEYBINDINGS.md is out of date — run: python3 docs/gen-keybindings.py", file=sys.stderr)
            return 1
        print("docs/KEYBINDINGS.md is up to date")
        return 0
    OUT.write_text(text, encoding="utf-8")
    print(f"wrote {OUT.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
