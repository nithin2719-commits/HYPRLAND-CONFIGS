# pyenv (kept before the interactive guard so `bash -c` / scripts see it too).
# Was declared twice, which added $PYENV_ROOT/bin to PATH a second time.
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"

# If not running interactively, don't do anything below
[[ $- != *i* ]] && return

# Set DBUS_SESSION_BUS_ADDRESS if not set.
# Must stay BELOW the interactive guard: a non-interactive bash (`bash -c ...`,
# `ssh host cmd`) with no bus set would otherwise spawn an orphan dbus-daemon
# via --exit-with-session that nothing ever reaps.
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
  eval $(dbus-launch --sh-syntax --exit-with-session) >/dev/null 2>&1
fi

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

. "$HOME/.local/bin/env"
echo "Welcome hacker 😎"
