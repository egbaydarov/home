#!/usr/bin/env sh
# https://github.com/niilohlin/tmux-vim-visual

set -e
set -o pipefail

TMPFILE=$(mktemp).tmux_pane_out
VIM_COMMAND=$(command -v nvim || command -v vim)

# -J: join lines, removes soft wraps
# -p: output to stdout
# -S: start at the beginning of the history
tmux capture-pane -J -pS - > $TMPFILE

# -P: print window id
# -d: open window in the background
# -R: read-only mode
WINDOW_ID=$(tmux new-window -P -d "$VIM_COMMAND -R \
  -c 'norm G' \
  -c 'set nomodifiable' \
  -c 'nnoremap <silent><buffer> q :quit<CR>' \
  -c 'set laststatus=0' -c 'set noshowcmd' -c 'set noruler' -c 'set noshowmode' -c 'set cmdheight=0' \
  $TMPFILE")

tmux rename-window -t "$WINDOW_ID" "copy"
# -s: source window id
# -t: target window id
#tmux swap-pane -s $WINDOW_ID -t $CURRENT_WINDOW_ID
# works better in my setup
tmux select-window -t $WINDOW_ID
tmux set-window-option -t $WINDOW_ID remain-on-exit off;

