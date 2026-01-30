#!/usr/bin/env sh
set -e
set -o pipefail

DIR="$HOME/.config/justatool"
CURRENT="$DIR/CURRENT"
VIM_COMMAND="$(command -v nvim || command -v vim)"
WIN_NAME="just-a-tool"

# Find existing window (if any)
WIN_INFO="$(tmux list-windows -F '#{window_name} #{window_id} #{window_active}' \
  | awk -v name="$WIN_NAME" '$1 == name { print $2, $3 }')"

if [ -n "$WIN_INFO" ]; then
  WIN_ID="$(printf '%s\n' "$WIN_INFO" | awk '{print $1}')"
  WIN_ACTIVE="$(printf '%s\n' "$WIN_INFO" | awk '{print $2}')"

  if [ "$WIN_ACTIVE" = "1" ]; then
    tmux kill-window -t "$WIN_ID"
  else
    tmux select-window -t "$WIN_ID"
  fi
  exit 0
fi

# Decide what to open and create window
if [ -f "$CURRENT" ]; then
  OPEN_CMD="edit $CURRENT"
  WINDOW_ID="$(tmux new-window -P -d "$VIM_COMMAND" \
    -c 'syntax on' \
    -c 'set noshowcmd noruler noshowmode cmdheight=0' \
    -c 'setlocal statusline=%=%#StatusLine#\ JUST\ A\ TOOL\ %=' \
    -c "$OPEN_CMD" \
    -c 'set wrap' \
    -c 'set filetype=markdown' \
  )"
else
  OPEN_CMD="lua require('oil').open(vim.fn.expand('$DIR'), { sort = { { 'mtime', 'desc' } } })"
  WINDOW_ID="$(tmux new-window -P -d "$VIM_COMMAND" \
    -c 'syntax on' \
    -c 'set noshowcmd noruler noshowmode cmdheight=0' \
    -c 'setlocal statusline=%=%#StatusLine#\ JUST\ A\ TOOL\ %=' \
    -c "$OPEN_CMD" \
    -c 'set wrap' \
  )"
fi

tmux rename-window -t "$WINDOW_ID" "$WIN_NAME"
tmux select-window -t "$WINDOW_ID"
tmux set-window-option -t "$WINDOW_ID" remain-on-exit off

