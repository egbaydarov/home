#!/usr/bin/env sh
set -e
set -o pipefail

TMPFILE="$(mktemp).tmux_out"
TMPVIEW="$(mktemp).tmux_view"
VIM_COMMAND="$(command -v nvim || command -v vim)"

PANE_CMD="$(tmux display-message -p '#{pane_current_command}')"
IS_VIM=0

if [ "$PANE_CMD" = "vim" ] || [ "$PANE_CMD" = "nvim" ]; then
  IS_VIM=1
  # write buffer + view (cursor/scroll) without changing the view

  ACK="$(mktemp -u).fifo"
  mkfifo "$ACK"
  tmux send-keys ":silent! keepalt keepjumps w! $TMPFILE | call writefile([json_encode(winsaveview())], '$TMPVIEW') | call writefile(['ok'], '$ACK') | redraw! | redrawstatus!" Enter
  read _ < "$ACK"
  rm -f "$ACK"

else
  tmux capture-pane -J -pS - > "$TMPFILE"
  : > "$TMPVIEW"  # empty marker; no view to restore
fi

# Trim trailing blank lines bottom, and right
sed -i ':a;/^[[:space:]]*$/{$d;N;ba};$!{$!s/[[:space:]]\+$//}' "$TMPFILE"

WINDOW_ID="$(tmux new-window -P -d "$VIM_COMMAND -R \
  -c 'syntax on' \
  -c 'set ft=conf' \
  -c 'syntax match TmuxPrompt /^\[[^]]\+\][#$]/' \
  -c 'hi def link TmuxPrompt Special' \
  -c 'nnoremap <silent><buffer> q :quit<CR>' \
  -c 'set nomodifiable noshowcmd noruler noshowmode cmdheight=0' \
  -c 'setlocal statusline=%=%#StatusLine#\\ COPY\\ MODE\\ %=' \
  -c \"if $IS_VIM |
        set number norelativenumber signcolumn=yes foldcolumn=0 |
      else |
        set nonumber norelativenumber signcolumn=no foldcolumn=0 |
      endif\" \
  -c \"if filereadable('$TMPVIEW') && getfsize('$TMPVIEW') > 0 |
        let v=json_decode(join(readfile('$TMPVIEW'), '')) |
        call winrestview(v) |
      else |
        norm! G$ |
      endif\" \
  $TMPFILE")"

tmux rename-window -t "$WINDOW_ID" copy-mode
tmux select-window -t "$WINDOW_ID"
tmux set-window-option -t "$WINDOW_ID" remain-on-exit off

