#!/bin/sh

title="_shell"

if ! tmux list-panes -a -F '#{pane_title}' | grep -Fxq "$title"; then
  pane="$(tmux new-window -d -P -F '#{pane_id}' -n shell -c "$STUFF_DIR")"
  tmux set -pt "$pane" allow-set-title off
  tmux select-pane -t "$pane" -T "$title"
fi

if tmux list-panes -F '#{pane_title}' | grep -Fxq "$title"; then
  tmux list-windows -F '#{window_index}' | grep -Fxq 10 || tmux new-window -d -t 10
  p="$(tmux list-panes -F '#{pane_id} #{pane_title}' | awk -v t="$title" '$2==t{print $1; exit}')"
  tmux move-pane -d -s "$p" -t :10
  tmux list-panes -t :10 -F '#{pane_id}' | grep -Fxv "$p" | xargs -r -n1 tmux kill-pane -t
else
  here="$(tmux display-message -p -F '#{pane_id}')"
  path="$(tmux display-message -t "$here" -p -F '#{pane_current_path}')"
  p="$(tmux list-panes -a -F '#{pane_id} #{pane_title}' | awk -v t="$title" '$2==t{print $1; exit}')"
  shellpath="$(tmux display-message -t "$p" -p -F '#{pane_current_path}')"

  tmux join-pane -h -s "$p"

  if tmux display-message -t "$p" -p '#{pane_current_command}' | grep -Fxq bash; then
    [ "$shellpath" = "$path" ] || \
      tmux send-keys -t "$p" " cd -- '$path'; ls -lh" C-m
  fi
fi

