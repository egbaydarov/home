#!/usr/bin/env bash
set -euo pipefail

SESSION="main"
HOME_DIR="${HOME}"
PROJ_DIR="${HOME_DIR}/stuff"
CFG_DIR="${HOME_DIR}/.config"
STUFF_DIR="${HOME_DIR}/stuff"


# Ensure session exists
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -n f1 -c "$PROJ_DIR"
fi

# Helper: ensure a named window exists (create if missing)
ensure_window() {
  local name="$1"
  local dir="$2"

  # Does a window named "$name" exist in this session?
  if ! tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -Fxq "$name"; then
    tmux new-window -t "$SESSION" -n "$name" -c "$dir"
  fi
}

ensure_split_layout() {
  ensure_window $1 $2
  # Find f1 window index
  local widx
  widx="$(tmux list-windows -t "$SESSION" -F '#{window_index}:#{window_name}' | awk -F: '$2=="'$1'"{print $1; exit}')"

  # If window has only 1 pane, create the bottom pane and resize
  local panes
  panes="$(tmux list-panes -t "$SESSION":"$widx" -F '#{pane_id}' | wc -l | tr -d ' ')"
  if [ "$panes" -lt 2 ]; then
    tmux split-window -v -t "$SESSION":"$widx" -c "$PROJ_DIR"
    tmux select-pane -t "$SESSION":"$widx".0
    tmux resize-pane -t "$SESSION":"$widx".1 -y 3 2>/dev/null || true
  fi
}

ensure_window "f1" "$STUFF_DIR"
ensure_window "f2" "$CFG_DIR"
ensure_window "f3" "$CFG_DIR"
ensure_window "f4" "$HOME_DIR"
ensure_window "f5" "$STUFF_DIR"
ensure_window "f6" "$STUFF_DIR"
ensure_window "f7" "$STUFF_DIR"
ensure_window "f8" "$STUFF_DIR"
ensure_window "f9" "$STUFF_DIR"
ensure_window "f0" "$STUFF_DIR"

# Go to f1
tmux select-window -t "$SESSION":0
tmux bind-key [ run-shell "${CFG_DIR}/tmux/vim-visual.sh"

# If already inside tmux: switch client; otherwise attach
if [[ -n "${TMUX-}" ]]; then
  tmux switch-client -t "$SESSION"
else
  exec tmux attach -t "$SESSION"
fi

