#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  HYPRLAND-CONFIGS — bootstrap
#
#  Rebuilds this Hyprland rice on a fresh Arch install, or restores it on this
#  machine after the config has been wiped.
#
#      git clone https://github.com/nithin2719-commits/HYPRLAND-CONFIGS.git
#      cd HYPRLAND-CONFIGS
#      ./install.sh
#
#  Nothing is deleted. Every file that would be overwritten is copied to
#  ~/.config-backup-<timestamp>/ first, and the script prints where.
#
#  Flags:
#      --dry-run        show every action, change nothing
#      --configs-only   skip package installation, deploy dotfiles only
#      --packages-only  install packages, do not touch any config
#      --no-aur         skip the AUR stage (no yay bootstrap)
#      --no-nvidia      skip the NVIDIA driver packages
#      --yes            do not prompt for confirmation
#      --help
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.config-backup-$STAMP"

DRY=0; CONFIGS_ONLY=0; PACKAGES_ONLY=0; NO_AUR=0; NO_NVIDIA=0; ASSUME_YES=0

# ── output ───────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
    B=$'\e[1m'; DIM=$'\e[2m'; R=$'\e[0m'
    GRN=$'\e[32m'; YLW=$'\e[33m'; RED=$'\e[31m'; CYN=$'\e[36m'
else
    B=''; DIM=''; R=''; GRN=''; YLW=''; RED=''; CYN=''
fi
step() { printf '\n%s▎ %s%s\n' "$B$CYN" "$*" "$R"; }
ok()   { printf '  %s✓%s %s\n' "$GRN" "$R" "$*"; }
warn() { printf '  %s!%s %s\n' "$YLW" "$R" "$*"; }
die()  { printf '\n%s✗ %s%s\n' "$RED" "$*" "$R" >&2; exit 1; }
note() { printf '  %s%s%s\n' "$DIM" "$*" "$R"; }
run()  { if [ "$DRY" -eq 1 ]; then printf '  %s[dry-run]%s %s\n' "$DIM" "$R" "$*"; else eval "$@"; fi; }

usage() {
    cat <<'USAGE'
HYPRLAND-CONFIGS — bootstrap

  Rebuilds this Hyprland rice on a fresh Arch install, or restores it on this
  machine after the config has been wiped.

      git clone https://github.com/nithin2719-commits/HYPRLAND-CONFIGS.git
      cd HYPRLAND-CONFIGS
      ./install.sh

  Nothing is deleted. Every file that would be overwritten is copied to
  ~/.config-backup-<timestamp>/ first, and the script prints where.

Flags:
  --dry-run        show every action, change nothing
  --configs-only   skip package installation, deploy dotfiles only
  --packages-only  install packages, do not touch any config
  --no-aur         skip the AUR stage (no yay bootstrap)
  --no-nvidia      skip the NVIDIA driver packages
  --yes, -y        do not prompt for confirmation
  --help, -h       this text
USAGE
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)       DRY=1 ;;
        --configs-only)  CONFIGS_ONLY=1 ;;
        --packages-only) PACKAGES_ONLY=1 ;;
        --no-aur)        NO_AUR=1 ;;
        --no-nvidia)     NO_NVIDIA=1 ;;
        --yes|-y)        ASSUME_YES=1 ;;
        --help|-h)       usage ;;
        *) die "unknown flag: $1  (try --help)" ;;
    esac
    shift
done

printf '\n%s┌────────────────────────────────────────────────┐%s\n' "$B" "$R"
printf   '%s│   HYPRLAND-CONFIGS  ·  Arch + Hyprland rice    │%s\n' "$B" "$R"
printf   '%s└────────────────────────────────────────────────┘%s\n' "$B" "$R"

# ── preflight ────────────────────────────────────────────────────────────────
step "Preflight"

[ -r /etc/os-release ] || die "cannot read /etc/os-release"
# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}${ID_LIKE:-}" in
    *arch*) ok "Arch-based system detected (${PRETTY_NAME:-$ID})" ;;
    *) die "this installer is Arch-only (found: ${PRETTY_NAME:-unknown}).
     On another distro, install the packages in packages/rice-core.txt by hand,
     then re-run with --configs-only." ;;
esac

[ "$(id -u)" -ne 0 ] || die "do not run this as root — it installs into \$HOME.
     It will call sudo only for the package steps."

command -v pacman >/dev/null || die "pacman not found"
[ -d "$REPO/config" ] || die "run this from inside the cloned repo (config/ not found at $REPO)"
ok "repo root: $REPO"

if [ "$DRY" -eq 1 ]; then
    warn "DRY RUN — nothing will be installed, copied or overwritten"
fi

if [ "$ASSUME_YES" -eq 0 ] && [ "$DRY" -eq 0 ]; then
    printf '\n  This will install packages and replace configs under ~/.config.\n'
    printf '  Replaced files are backed up to %s\n' "$BACKUP"
    printf '  Continue? [y/N] '
    read -r reply
    case "$reply" in [yY]*) ;; *) echo "  aborted."; exit 0 ;; esac
fi

# ── packages ─────────────────────────────────────────────────────────────────
install_packages() {
    step "Repo packages (core / extra / multilib)"

    local list=() p
    while IFS= read -r p; do
        case "$p" in ''|\#*) continue ;; esac
        if [ "$NO_NVIDIA" -eq 1 ]; then
            case "$p" in nvidia-*|egl-wayland|libva-nvidia-driver) continue ;; esac
        fi
        list+=("$p")
    done < "$REPO/packages/rice-core.txt"

    note "${#list[@]} packages requested"
    run "sudo pacman -Syu --needed --noconfirm ${list[*]}" \
        && ok "repo packages installed" \
        || warn "pacman reported errors — see output above; continuing"

    if [ "$NO_AUR" -eq 1 ]; then
        step "AUR packages"; warn "skipped (--no-aur)"; return
    fi

    step "AUR helper"
    if command -v yay >/dev/null 2>&1; then
        ok "yay already present"
    elif command -v paru >/dev/null 2>&1; then
        ok "paru present — using it instead of yay"
    else
        note "bootstrapping yay from source"
        run "sudo pacman -S --needed --noconfirm git base-devel"
        run "rm -rf /tmp/yay-bootstrap && git clone --depth 1 https://aur.archlinux.org/yay.git /tmp/yay-bootstrap"
        run "cd /tmp/yay-bootstrap && makepkg -si --noconfirm"
        command -v yay >/dev/null 2>&1 && ok "yay installed" || warn "yay bootstrap failed — AUR stage will be skipped"
    fi

    local helper=""
    command -v yay  >/dev/null 2>&1 && helper=yay
    [ -z "$helper" ] && command -v paru >/dev/null 2>&1 && helper=paru

    step "AUR packages"
    if [ -z "$helper" ]; then
        warn "no AUR helper — install these by hand: $(grep -cvE '^\s*(#|$)' "$REPO/packages/aur-core.txt") packages in packages/aur-core.txt"
        return
    fi
    local aur=()
    while IFS= read -r p; do
        case "$p" in ''|\#*) continue ;; esac
        aur+=("$p")
    done < "$REPO/packages/aur-core.txt"
    note "${#aur[@]} AUR packages via $helper"
    run "$helper -S --needed --noconfirm ${aur[*]}" \
        && ok "AUR packages installed" \
        || warn "$helper reported errors — some AUR builds may need manual attention"
}

# ── config deployment ────────────────────────────────────────────────────────
# back up dest if it exists, then copy src over it
deploy() {
    local src="$1" dest="$2" label="$3"
    [ -e "$src" ] || { warn "missing in repo, skipped: $label"; return; }

    if [ -e "$dest" ]; then
        local rel="${dest#"$HOME"/}"
        run "mkdir -p '$BACKUP/$(dirname "$rel")'"
        run "cp -a '$dest' '$BACKUP/$rel'"
    fi
    run "mkdir -p '$(dirname "$dest")'"
    if [ -d "$src" ]; then
        run "rsync -a --delete-after --exclude='.git' '$src/' '$dest/'" 2>/dev/null \
            || run "cp -a '$src/.' '$dest/'"
    else
        run "cp -a '$src' '$dest'"
    fi
    ok "$label"
}

install_configs() {
    step "Backup"
    if [ "$DRY" -eq 0 ]; then mkdir -p "$BACKUP"; fi
    ok "existing files will be copied to $BACKUP"

    step "~/.config"
    local d
    for d in "$REPO"/config/*/; do
        [ -d "$d" ] || continue
        local name; name="$(basename "$d")"
        deploy "$d" "$HOME/.config/$name" "~/.config/$name"
    done
    # loose files that live directly in ~/.config
    local f
    for f in "$REPO"/config/*; do
        [ -f "$f" ] || continue
        deploy "$f" "$HOME/.config/$(basename "$f")" "~/.config/$(basename "$f")"
    done

    step "~/.local/share/bin  (HyDE + custom scripts)"
    deploy "$REPO/local/share/bin" "$HOME/.local/share/bin" "~/.local/share/bin"
    run "chmod +x '$HOME/.local/share/bin/'* 2>/dev/null || true"
    ok "scripts marked executable"

    step "Home dotfiles"
    # .gitconfig is deliberately NOT deployed: it carries a git identity and a
    # credential helper, which belong to a person, not to a rice.
    for f in .zshrc .zprofile .bashrc .bash_profile .p10k.zsh .gtkrc-2.0; do
        [ -f "$REPO/$f" ] && deploy "$REPO/$f" "$HOME/$f" "~/$f"
    done
    note "~/.gitconfig is in the repo but not installed — set your own identity"

    step "Executable bits"
    run "chmod +x '$HOME/.config/hypr/'*.sh 2>/dev/null || true"
    run "chmod +x '$HOME/.config/hypr/scripts/'*.sh 2>/dev/null || true"
    run "chmod +x '$HOME/.config/eww/scripts/'* 2>/dev/null || true"
    run "chmod +x '$HOME/.config/blackarch-launcher/'*.sh 2>/dev/null || true"
    ok "scripts are executable"
}

# ── post-install ─────────────────────────────────────────────────────────────
post_install() {
    step "Services"
    if systemctl list-unit-files power-profiles-daemon.service >/dev/null 2>&1; then
        run "sudo systemctl enable --now power-profiles-daemon.service" && ok "power-profiles-daemon" \
            || warn "could not enable power-profiles-daemon"
    fi
    if systemctl list-unit-files supergfxd.service >/dev/null 2>&1; then
        run "sudo systemctl enable --now supergfxd.service" && ok "supergfxd (Optimus GPU switching)" \
            || warn "could not enable supergfxd"
    fi
    if systemctl list-unit-files asusd.service >/dev/null 2>&1; then
        run "sudo systemctl enable --now asusd.service" && ok "asusd (ROG keyboard aura + fan profiles)" \
            || warn "could not enable asusd"
    fi
    run "systemctl --user enable --now pipewire pipewire-pulse wireplumber" >/dev/null 2>&1 \
        && ok "pipewire user services" || warn "pipewire services not enabled"

    step "Touchpad gestures (fusuma)"
    if command -v fusuma >/dev/null 2>&1; then
        run "sudo gpasswd -a '$USER' input" && ok "added $USER to the 'input' group (re-login required)" \
            || warn "could not add $USER to 'input' — 3/4-finger gestures will not work"
    else
        note "fusuma not installed; skipping"
    fi

    step "Font cache"
    run "fc-cache -f" >/dev/null 2>&1 && ok "font cache rebuilt" || warn "fc-cache failed"

    step "Shell"
    if command -v zsh >/dev/null 2>&1; then
        note "to make zsh your login shell:  chsh -s \"\$(command -v zsh)\""
    fi
}

# ── run ──────────────────────────────────────────────────────────────────────
[ "$CONFIGS_ONLY" -eq 1 ] || install_packages
[ "$PACKAGES_ONLY" -eq 1 ] || install_configs
[ "$PACKAGES_ONLY" -eq 1 ] || [ "$CONFIGS_ONLY" -eq 1 ] || post_install

step "Done"
if [ "$DRY" -eq 1 ]; then
    echo "  dry run finished — nothing was changed."
else
    cat <<EOF
  Backup of everything replaced:  $BACKUP

  Next:
    1. Set your monitor:   ~/.config/hypr/monitors.conf
    2. Not on NVIDIA?      empty out ~/.config/hypr/nvidia.conf
    3. Not on an ROG box?  see docs/TROUBLESHOOTING.md ("non-ROG hardware")
    4. Log out and back in, or reboot, then start Hyprland.

  Keybinding cheatsheet:  SUPER + /        (or docs/KEYBINDINGS.md)
EOF
fi
echo
