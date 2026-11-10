#!/bin/sh
# Usage: popup_shell.sh popup|split <client> <session> <window_id> <path>
#        popup_shell.sh goto <client> <session> <window_id> <path> <index>
# Persistent per-window shell, shown either in a popup (kept in its own
# "popup_<window>" session) or joined into the window as a split.
# Failed runs are traced to ~/.cache/tmux-popup-shell.log.

log="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-popup-shell.log"
trace="$(mktemp)"
trap 'rc=$?; set +x; [ "$rc" -ne 0 ] && { echo "=== $(date "+%F %T") rc=$rc: $*"; cat "$trace"; } >> "$log"; rm -f "$trace"' EXIT
exec 2>"$trace"
set -x

# Key presses run concurrently (run-shell -b); serialize them.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/tmux-popup-shell.lock"
flock 9

mode="$1" client="$2" path="$5"
case "$3" in
  popup_*) win="@${3#popup_}" ;;
  *) win="$4" ;;
esac
session="popup_${win#@}"

windows="$(tmux list-windows -a -F '#{window_id}')"
for s in $(tmux list-sessions -F '#{session_name}' | grep '^popup_'); do
  printf '%s\n' "$windows" | grep -Fxq "@${s#popup_}" || tmux kill-session -t "=$s:"
done

mark() {
  [ -n "$1" ] || return 1
  tmux set -p -t "$1" @popup_shell "$win"
  tmux set -p -t "$1" remain-on-exit off
  # The nested client can't see the real terminal colors; keep in sync with foot.ini
  tmux set -p -t "$1" window-style "fg=#657b83,bg=#fdf6e3"
}

shell_pane() {
  tmux list-panes -a -F '#{pane_id} #{@popup_shell}' | awk -v w="$win" '$2 == w { print $1; exit }'
}

parked() {
  tmux display-message -p -t "$1" '#{session_name}' | grep -q '^popup_'
}

new_session() {
  tmux new-session -d -s "$session" -c "$path"
  tmux set -t "=$session:" status off
}

park() {
  if tmux has-session -t "=$session:" 2>/dev/null; then
    tmux break-pane -d -s "$1" -t "=$session:"
    return
  fi
  new_session || return 1
  placeholder="$(tmux display-message -p -t "=$session:" '#{pane_id}')"
  tmux break-pane -d -s "$1" -t "=$session:" || return 1
  [ "$placeholder" != "$1" ] && tmux kill-pane -t "$placeholder"
}

pane="$(shell_pane)"

case "$mode" in
  goto)
    outer="$(tmux display-message -p -t "$win" '#{session_name}')"
    tmux detach-client -t "$client"
    tmux select-window -t "=$outer:$6" || true
    ;;
  split)
    if [ -z "$pane" ]; then
      mark "$(tmux split-window -h -t "$win" -c "$path" -P -F '#{pane_id}')"
    elif parked "$pane"; then
      tmux join-pane -h -s "$pane" -t "$win"
    else
      park "$pane"
    fi
    ;;
  popup)
    if [ -z "$pane" ]; then
      new_session
      mark "$(tmux display-message -p -t "=$session:" '#{pane_id}')"
    elif ! parked "$pane"; then
      park "$pane"
    fi
    flock -u 9
    tmux display-popup -c "$client" -E -w 90% -h 90% "unset TMUX; tmux attach -t '=$session:'" || true
    ;;
# Exit on this line: the script stays running while the popup is open, and
# sh would otherwise resume reading the (possibly edited) file afterwards.
esac; exit
