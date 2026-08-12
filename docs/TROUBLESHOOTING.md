# Troubleshooting

Everything here has actually happened on this setup. Each entry says what you
see, why it happens, and what to change. Most of these are also recorded as
comments next to the relevant line in the config — those comments are the
primary source; this file collects them.

- [Porting to different hardware](#porting-to-different-hardware)
- [Display and scaling](#display-and-scaling)
- [The bar disappears](#the-bar-disappears)
- [Notifications look wrong or don't appear](#notifications-look-wrong-or-dont-appear)
- [Wallpaper doesn't load](#wallpaper-doesnt-load)
- [A key does two things at once](#a-key-does-two-things-at-once)
- [Borders are rainbow / borders are dead](#borders-are-rainbow--borders-are-dead)
- [Touchpad gestures do nothing](#touchpad-gestures-do-nothing)
- [Audio and volume](#audio-and-volume)
- [The terminal is slow to become usable](#the-terminal-is-slow-to-become-usable)
- [The eww dashboard is stuck](#the-eww-dashboard-is-stuck)
- [Slow first launch of a browser app](#slow-first-launch-of-a-browser-app)
- [Getting back to a clean state](#getting-back-to-a-clean-state)

---

## Porting to different hardware

This rice was built on an ASUS ROG laptop with an NVIDIA Optimus GPU. Two groups
of settings are hardware-specific and will misbehave elsewhere.

### NVIDIA

**Symptom:** black screen after login, a session that falls back to software
rendering, or Hyprland refusing to start at all on AMD/Intel.

**Cause:** these are set unconditionally.

| Where | Setting |
|---|---|
| `config/hypr/nvidia.conf` | `LIBVA_DRIVER_NAME`, `__GLX_VENDOR_LIBRARY_NAME`, `__GL_VRR_ALLOWED`, `cursor:no_hardware_cursors` |
| `config/hypr/hyprland.conf` (bottom) | `GBM_BACKEND=nvidia-drm`, `NVD_BACKEND=direct`, `WLR_DRM_NO_ATOMIC=1`, `AQ_DRM_DEVICES=/dev/dri/card1` |
| `config/hypr/hyprland.conf` (env block) | `__NV_PRIME_RENDER_OFFLOAD`, `__VK_LAYER_NV_optimus` |

**Fix:** run the installer with `--no-nvidia`, then empty `~/.config/hypr/nvidia.conf`
and delete the NVIDIA block at the bottom of `hyprland.conf`.

`AQ_DRM_DEVICES=/dev/dri/card1` is the most machine-specific line in the whole
config — it pins Hyprland to a particular DRM node. Card numbering is not stable
across machines. Check yours with `ls -l /dev/dri/by-path/` before keeping it.

### ASUS ROG

**Symptom:** certain keys do nothing; harmless errors in the Hyprland log.

These need `asusctl` / `supergfxctl` / an ASUS EC and simply won't do anything
elsewhere. Remove them if you want a clean log:

| Where | What |
|---|---|
| `keybindings.conf` | `F4` → `asusctl aura effect --next-mode` |
| `hyprland.conf` | `F2` / `F3` → `brightnessctl -d asus::kbd_backlight` |
| `hyprland.conf` | `XF86Launch1` → `powerprofile_toggle.sh` |
| `keybindings.conf` | `XF86Launch4` → `scripts/perfmode.sh` |
| `userprefs.conf` | `exec-once = … openrgb --device 0 --mode "Rainbow Wave"` |
| `config/hypr/numberpad.py` | ASUS touchpad-numpad driver |

---

## Display and scaling

**Symptom:** everything is enormous, or tiny, or the eww calendar opens
half off-screen.

The panel is declared in **three** places and they have to agree:

1. `config/hypr/monitors.conf` — `monitor = eDP-1,2560x1440@240,0x0,1.67`
2. `config/hypr/hyprland.conf` — a second `monitor=` line (scale `1.5`) plus
   `QT_SCALE_FACTOR=1.2` and `GDK_SCALE=1`
3. `config/hypr/windowrules.conf` — the calendar dropdown is positioned with
   hard-coded pixels (`move 558 68`) computed from a 1536-logical-pixel-wide
   screen

> **Note:** `monitors.conf` currently contains two `monitor=` lines for `eDP-1`
> (scale `1.5` then `1.67`); the last one wins. `hyprland.conf` declares the
> panel a third time. It works, but if you are changing your display setup,
> reduce it to one line in `monitors.conf` first so there is only one thing to
> get right.

**Fix for any other machine:**

```ini
# ~/.config/hypr/monitors.conf
monitor = ,preferred,auto,1
```

then delete the `monitor=` line from `hyprland.conf`, set `QT_SCALE_FACTOR=1`,
and recompute the calendar position: `(logical_width - 420) / 2`.

`hyprctl monitors` prints your outputs, their modes and their current scale.

---

## The bar disappears

**Symptom:** Waybar vanishes and never comes back — often right after switching
theme or wallpaper.

**Cause:** Waybar 0.15.0 on GTK 3.24.52 segfaults inside `libgdk-3` while
dispatching Wayland pointer events after the GTK cursor theme is reloaded. HyDE
runs `gsettings set org.gnome.desktop.interface cursor-theme …` on every theme
switch, which frees the `wl_cursor_theme` while Waybar still holds pointers into
it. The bar dies the next time the pointer crosses it.

**Fix:** that is what `config/hypr/scripts/waybar-watchdog.sh` is for. It should
already be running:

```bash
pgrep -af waybar-watchdog
```

If it isn't:

```bash
pkill waybar
~/.config/hypr/scripts/waybar-watchdog.sh \
  -c ~/.config/waybar/graphite/config.jsonc \
  -s ~/.config/waybar/graphite/style.css &
```

**If it refuses to start silently**, its lock is held by a leaked file
descriptor in some long-lived grandchild process:

```bash
rm -f "$XDG_RUNTIME_DIR"/waybar-watchdog.v2.{lock,pid}
```

**The wrong bar came up** (HyDE's instead of graphite): something restarted
Waybar without naming a config — `wbarconfgen.sh`, `gamemode.sh`, or a bare
`waybar`. The watchdog defaults to the graphite config precisely to stop this;
launch through the watchdog, not directly.

**Toggle it off and on:** `CTRL` `ALT` `W`.

---

## Notifications look wrong or don't appear

**Symptom:** notifications are plain white rectangles, or two different styles
appear at random, or nothing appears at all.

**Cause:** only one process may own `org.freedesktop.Notifications`. This config
has had dunst, swaync and swayosd all trying at various points, and whichever
won the startup race decided how notifications looked.

**Rule:** exactly one notification daemon. In this rice that is **dunst**.

```bash
pgrep -a dunst swaync mako          # should list only dunst
```

`swaync` is installed and its config is kept, but nothing should start it.
`swayosd-server` is disabled in `hyprland.conf` for the same reason — it drew a
second volume popup competing with the dunst card.

**Cards look flat instead of frosted:** the blur comes from the compositor, not
dunst. Check these are present in `windowrules.conf`:

```ini
layerrule = blur true,          match:namespace notifications
layerrule = ignore_alpha 0.35,  match:namespace notifications
layerrule = animation slide right, match:namespace notifications
```

Rule grammar is Hyprland ≥ 0.55 and is fussier than older examples on the wiki:
`blur true` (not bare `blur`), `ignore_alpha` (not `ignorealpha`), and
`ignorezero` no longer exists.

**Missed one:** `SUPER` `N` replays the last notification, `SUPER` `SHIFT` `N`
clears the stack.

---

## Wallpaper doesn't load

**Symptom:** grey or black desktop background.

**Cause:** Arch ships the `swww` wallpaper daemon as **`awww`**. Old lines that
call `swww` do nothing.

```bash
pgrep -a awww-daemon || awww-daemon &
awww query                                  # what is displayed now
awww img ~/.config/hyde/themes/Vanta\ Black/wallpapers/bankai-卍解.jpg
```

`hyprland.conf` still carries a legacy line pointing at
`~/.config/hypr/wallpapers/yourwallpaper.png`, which does not exist. It is a
dead no-op — the wallpaper actually comes from HyDE's `swwwallpaper.sh` and from
the `awww img` line in `userprefs.conf`. Harmless, but delete it if you are
tidying.

Change wallpaper: `SUPER` `SHIFT` `W`, or `SUPER` `ALT` `←` / `→`.

---

## A key does two things at once

**Symptom:** one press skips two volume steps, opens two logout menus, or
launches two lock screens.

**Cause:** Hyprland fires **every** bind that matches a combo, not just the last
one declared. Because `hyprland.conf`, `keybindings.conf` and `userprefs.conf`
are all sourced, the same key defined in two of them fires twice.

This has happened with, and is now commented out in one place each:

| Key | Was declared twice in |
|---|---|
| `XF86MonBrightnessUp` / `Down` | `hyprland.conf` **and** `keybindings.conf` |
| `SUPER` `Escape` (logout) | both |
| `SUPER` `L` (lock) | both |
| `F4` (aura) | `keybindings.conf` and `aura-cycle.sh` |
| `XF86Launch1` (power profile) | both |
| `ALT` `Tab` | `hyprland.conf` only, deliberately |

**Fix:** `grep -rn "<key>" ~/.config/hypr/*.conf` and keep exactly one.
`docs/KEYBINDINGS.md` lists the file and line number of every active bind, which
makes duplicates easy to spot.

---

## Borders are rainbow / borders are dead

**Rainbow:** an old `rgb.sh` / `rgb-border.sh` loop rewrote
`general:col.active_border` every 30 ms, overriding every static border colour
anywhere in the config. Both are disabled in `hyprland.conf`. If colour comes
back, something restarted them:

```bash
pkill -f rgb.sh; pkill -f rgb-border.sh
```

**No sheen:** the monochrome sweep is driven by
`config/hypr/scripts/border-sheen.sh`, not by Hyprland. On 0.56.1
`animation = borderangle, …, loop` reports itself enabled but the rendered
border does not advance.

```bash
pgrep -af border-sheen || ~/.config/hypr/scripts/border-sheen.sh &
```

If a future Hyprland fixes `borderangle`, stop the script and let the compositor
do it.

**A wallpaper change put colour back on the windows:** it shouldn't —
`userprefs.conf` is sourced after HyDE's `themes/colors.conf`, so its
`col.active_border` wins. If it doesn't, check the source order at the bottom of
`hyprland.conf`.

---

## Touchpad gestures do nothing

```bash
groups | grep -q input || sudo gpasswd -a "$USER" input   # then log out and back in
pgrep -a fusuma || fusuma -d &
```

fusuma reads `/dev/input` directly, so group membership is required, and group
changes only apply to new sessions.

Config: `config/fusuma/config.yml`.

---

## Audio and volume

Volume is routed through `config/hypr/volume.sh` → `~/.local/share/bin/vol-osd.sh`,
which shows a dunst card with a progress bar. If the volume keys are dead:

```bash
~/.config/hypr/volume.sh up          # does it work by hand?
systemctl --user status wireplumber pipewire
```

`hyprland.conf` sets `amixer sset Master 65536` at login, which pins the ALSA
Master to full so PipeWire owns the actual level. Remove that `exec-once` if it
fights your setup.

---

## The terminal is slow to become usable

**Symptom:** you open kitty, the fastfetch card paints straight away, but for
about another tenth of a second nothing you type actually runs.

**Cause:** zsh cannot execute anything until `.zshrc` has finished, and this rc
is expensive. Cold-cache breakdown of `zsh -i`, roughly 117 ms:

| Cost | What |
|---|---|
| 65 ms | `powerlevel10k.zsh-theme` |
| 21 ms | `zsh-syntax-highlighting` |
| 11 ms | `.p10k.zsh` — 95 KB, reparsed every shell |
| 8 ms | `zsh-autosuggestions` |
| 8 ms | `fastfetch` |
| 4 ms | bare `zsh -f` |

**fastfetch is not the problem.** It is the visible thing at the top of the file
so it gets blamed, and it costs 8 ms. Leave it alone.

**Fix — compile the big files.** zsh will read a `.zwc` bytecode file instead of
reparsing the script, but only when the `.zwc` sits beside the source and is
newer. `.p10k.zsh` is yours, so it compiles in place. The plugins live under
`/usr/share`, which is root-owned, so compiled copies go in the cache and are
refreshed whenever pacman updates the originals:

| File | Before | After |
|---|---|---|
| `.p10k.zsh` | 11 ms | 3.6 ms |
| `zsh-syntax-highlighting` | 11.6 ms | 5.4 ms |
| `zsh-autosuggestions` | 3.7 ms | 2.9 ms |

**Measured, 20 interleaved runs each: 86 ms → 74 ms median** to run a command
typed the instant the shell spawns. See the `_zsrc` helper and the `zcompile`
guard in `.zshrc`.

That is a 1.16× improvement, not a transformation. Be suspicious of bigger
numbers — including ones you measure yourself on the first try. A single cold
run of the old config reported 141 ms and made the change look like 1.9×; once
the page cache was warm and the two configs were measured alternately, the real
gap was 12 ms.

> **On `POWERLEVEL9K_INSTANT_PROMPT`:** it is enabled here, but be honest about
> what it buys. It makes p10k paint a cached prompt at ~5 ms instead of ~10 ms.
> It does **not** make the shell execute anything sooner — that still waits for
> the whole rc. On this setup fastfetch already paints at ~10 ms, so the screen
> is never blank and the measurable gain is close to nothing. Compiling is what
> actually helped, and even that is modest.

### The shell is not where the time goes

If opening a terminal feels slow, measure the terminal before blaming the rc.
On this machine, from keypress to a shell that will run a command:

| Cost | What |
|---|---|
| ~260 ms | kitty's own process start and window creation |
| ~100 ms | kitty's zsh shell integration |
| ~74 ms | `.zshrc` |

The rc is the smallest of the three. `shell_integration=disabled` in
`kitty.conf` removes the middle one, at the cost of prompt marks, cursor
shaping and `cwd` reporting.

For a genuinely instant terminal the lever is not the rc at all — it is
reusing one kitty process instead of starting a new one per window
(`single_instance yes` plus a `listen_on` socket, with `allow_remote_control`
already enabled here). That is **untested on this setup**; measure it before
trusting it.

> Timing kitty by wrapping the whole `kitty …` invocation is unreliable —
> window creation contends with the compositor and launching several in a loop
> produced readings from 400 ms to 5 s for the same configuration. Set a
> timestamp in the environment before launching and have the shell print the
> delta from inside.

**Two gotchas if you write your own loader:**

- Never pick the fallback from `source`'s exit status
  (`source $cached || source $system`). A plugin whose last statement returns
  non-zero gets sourced *twice*, doubling both the cost and the registered
  hooks. Choose the file first, then source it once.
- `typeset -U path PATH` near the top. This rc appends to `PATH` in a dozen
  places without checking; it had grown to 42 entries, 13 of them duplicates,
  and every failed command lookup walks the whole list. Now 26, none repeated.

**Measure it yourself.** A wall-clock timer around `zsh -i -c exit` tells you
almost nothing, because it does not measure when the shell became *interactive*.
Spawn a pty, type immediately, and time until the command actually runs:

```bash
python3 - <<'PY'
import os, pty, time, select
pid, fd = pty.fork()
if pid == 0:
    os.environ["TERM"] = "xterm-256color"; os.execvp("zsh", ["zsh", "-i"])
start, buf = time.perf_counter(), b""
os.write(fd, b"ZZMARK\r")
while time.perf_counter() - start < 8:
    r, _, _ = select.select([fd], [], [], 0.02)
    if not r: continue
    d = os.read(fd, 65536)
    if not d: break
    buf += d
    if b"command not found" in buf:
        print(f"usable in {(time.perf_counter()-start)*1000:.0f} ms"); break
os.write(fd, b"exit\n"); os.close(fd); os.waitpid(pid, 0)
PY
```

## The eww dashboard is stuck

eww takes keyboard focus while open. If Escape stops working there is a panic
bind:

**`SUPER` `SHIFT` `Escape`** → `~/.config/eww/scripts/toggle.sh close`

Or from a TTY / another terminal:

```bash
eww close-all; eww kill; eww daemon &
```

---

## Slow first launch of a browser app

`ALT` `Z` / `ALT` `X` / `ALT` `V` run `google-chrome-stable --app=…`. From cold
that takes seconds; with Chrome already resident it is about 240 ms. That is why
`userprefs.conf` has:

```ini
exec-once = google-chrome-stable --no-startup-window
```

It starts the browser process at login without opening any window. Remove it if
you don't use the Chrome app shortcuts — it costs a few hundred MB of RAM.

---

## Getting back to a clean state

`install.sh` backs up everything it replaces. To undo an install:

```bash
ls -d ~/.config-backup-*                 # find the run you want
cp -a ~/.config-backup-<timestamp>/.config/.  ~/.config/
```

To reset one component to what is in the repo:

```bash
cd HYPRLAND-CONFIGS
rsync -a --delete config/waybar/  ~/.config/waybar/
hyprctl reload
```

Reload the compositor after config edits — most changes do not need a logout:

```bash
hyprctl reload
```

`hyprctl reload` does **not** re-run `exec-once` lines. Anything started at
login (watchdog, border sheen, eww, fusuma) has to be restarted by hand or by
logging out.
