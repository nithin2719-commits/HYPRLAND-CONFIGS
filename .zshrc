# ─────────────────────────────────────────────────────────────────────────────
#  Powerlevel10k instant prompt.
#
#  MUST stay at the very top, above anything that prints, reads input, or runs
#  a slow command. p10k caches the rendered prompt here and replays it in a few
#  milliseconds, then loads the real prompt behind it. Without this block the
#  terminal shows nothing until the whole rc has finished -- which on this
#  machine was ~120ms of dead time on every single shell, because the p10k
#  theme alone costs ~65ms.
#
#  `quiet` rather than `verbose`: fastfetch below prints during init, and the
#  default setting complains about console output every time a shell starts.
# ─────────────────────────────────────────────────────────────────────────────
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Keep PATH unique. Everything below appends without checking, and the same
# entries were being added two and three times -- 42 entries, 13 of them
# duplicates. `-U` makes zsh drop repeats automatically, so every lookup that
# misses walks a shorter list.
typeset -U path PATH

fastfetch --config ~/.config/fastfetch/graphite.jsonc 2>/dev/null
echo ""

export PATH="/usr/bin:$PATH"

# Powerlevel10k theme
source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme

# Detect AUR wrapper
if command -v yay &>/dev/null; then
   aurhelper="yay"
elif command -v paru &>/dev/null; then
   aurhelper="paru"
fi

function in {
    local -a inPkg=("$@")
    local -a arch=()
    local -a aur=()

    for pkg in "${inPkg[@]}"; do
        if pacman -Si "${pkg}" &>/dev/null; then
            arch+=("${pkg}")
        else
            aur+=("${pkg}")
        fi
    done

    if [[ ${#arch[@]} -gt 0 ]]; then
        sudo pacman -S "${arch[@]}"
    fi

    if [[ ${#aur[@]} -gt 0 ]]; then
        ${aurhelper} -S "${aur[@]}"
    fi
}

# Helpful aliases
alias c='clear' # clear terminal
alias l='eza -lh --icons=auto' # long list
alias ls='eza -1 --icons=auto' # short list
alias ll='eza -lha --icons=auto --sort=name --group-directories-first' # long list all
alias ld='eza -lhD --icons=auto' # long list dirs
alias lt='eza --icons=auto --tree' # list folder as tree
alias un='$aurhelper -Rns' # uninstall package
alias up='$aurhelper -Syu' # update system/package/aur
alias pl='$aurhelper -Qs' # list installed package
alias pa='$aurhelper -Ss' # list available package
alias pc='$aurhelper -Sc' # remove unused cache
alias po='$aurhelper -Qtdq | $aurhelper -Rns -' # remove unused packages, also try > $aurhelper -Qqd | $aurhelper -Rsu --print -
alias vc='code' # gui code editor

# Directory navigation shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'

# Always mkdir a path (this doesn't inhibit functionality to make a single dir)
alias mkdir='mkdir -p'

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
#
# Compiled on demand: this file is 95KB and reparsing it cost 11ms on every
# shell. The .zwc drops that to 3.6ms. Recompiled automatically whenever the
# source changes, so `p10k configure` still takes effect.
if [[ -f ~/.p10k.zsh ]]; then
  [[ -f ~/.p10k.zsh.zwc && ~/.p10k.zsh.zwc -nt ~/.p10k.zsh ]] || zcompile -R ~/.p10k.zsh 2>/dev/null
  source ~/.p10k.zsh
fi

# ── PATH ─────────────────────────────────────────────────────────────────────
# typeset -U above collapses repeats, so these can stay declarative.
export PYENV_ROOT="$HOME/.pyenv"
export NVM_DIR="$HOME/.config/nvm"
path=(
  "$HOME/.local/share/bin"
  "$HOME/.npm-global/bin"
  "$HOME/.opencode/bin"
  "$PYENV_ROOT/shims"
  "$PYENV_ROOT/versions/3.10.14/bin"
  "$PYENV_ROOT/bin"
  "$HOME/.local/bin"
  "$HOME/.local/share/gem/ruby/3.4.0/bin"
  "$HOME/.spicetify"
  $path
)

# ── Plugins ──────────────────────────────────────────────────────────────────
# Sourced from /usr/share, in place.
#
# Do NOT copy these into a cache directory to zcompile them. zsh-syntax-
# highlighting finds its highlighters/ subdirectory, .version and
# .revision-hash relative to its OWN path (${0:A:h}), so a lone copy of the
# .zsh file cannot see them and the plugin aborts the shell with:
#
#   zsh-syntax-highlighting: highlighters directory '...' not found
#   zsh-syntax-highlighting: failed loading highlighters, exiting.
#
# Compiling both saved about 7ms combined. Not worth a broken shell.
# .p10k.zsh is self-contained and is still compiled above -- that was the
# bigger win anyway.
source /usr/share/oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=cyan"
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]="fg=default"

# Was: pokemon-colorscripts --no-title -r 1,3,6
# A random coloured sprite was the one thing on this desktop that could not be
# made monochrome, and it changed height on every shell, so the prompt never
# started in the same place. This prints the same compact card every time.
# The BlackArch mark, logo only, with the sword hilt intact. `ff` reprints it.
alias ff='clear && fastfetch --config ~/.config/fastfetch/graphite.jsonc && echo ""'

# Lazy load nvm
nvm() {
  unset -f nvm
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
  nvm "$@"
}

TIMEFMT="%J  %*E total"

# ── History ──────────────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY
setopt interactivecomments

# Arrow keys search history by what you have already typed, instead of walking
# it blindly. Declared once -- this block used to appear five times, and every
# repeat re-ran autoload and re-registered the same two widgets.
autoload -Uz up-line-or-beginning-search
autoload -Uz down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search

alias auto-cpufreq='/home/nithin/.pyenv/versions/3.10.14/bin/auto-cpufreq'

# The `exec Hyprland` guard that used to live here is gone: ~/.zprofile already
# starts the session on VT1, and .zshrc runs for EVERY interactive shell. A
# terminal that happened to start without DISPLAY set would have launched a
# second compositor from inside itself.
