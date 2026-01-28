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
  tmux send-keys ":silent! keepalt keepjumps w! $TMPFILE | call writefile([json_encode(winsaveview())], '$TMPVIEW')" Enter

  # wait until files exist (tmux send-keys is async)
  i=0
  while [ $i -lt 200 ] && { [ ! -s "$TMPFILE" ] || [ ! -s "$TMPVIEW" ]; }; do
    i=$((i+1))
    sleep 0.001
  done
else
  tmux capture-pane -J -pS - > "$TMPFILE"
  : > "$TMPVIEW"  # empty marker; no view to restore
fi

# Trim trailing blank lines top, bottom, and right
awk '
{
  sub(/[[:space:]]+$/, "", $0)
  if (!started) {
    if ($0 ~ /^[[:space:]]*$/) next
    started = 1
  }
  if ($0 ~ /^[[:space:]]*$/) {
    blank = blank $0 ORS
    next
  }
  if (blank) { printf "%s", blank; blank = "" }
  print
}
' "$TMPFILE" > "$TMPFILE.trim" && mv "$TMPFILE.trim" "$TMPFILE"

WINDOW_ID="$(tmux new-window -P -d "$VIM_COMMAND -R \
  -c 'syntax on' \
  -c 'set ft=conf' \
  -c 'syntax match TmuxPrompt /^\[[^]]\+\][#$]/' \
  -c 'hi def link TmuxPrompt Special' \
  -c 'nnoremap <silent><buffer> q :quit<CR>' \
  -c 'set nomodifiable laststatus=0 noshowcmd noruler noshowmode cmdheight=0' \
  -c \"if $IS_VIM | set number norelativenumber | else | set nonumber norelativenumber | endif\" \
  -c \"if filereadable('$TMPVIEW') && getfsize('$TMPVIEW') > 0 | let v=json_decode(join(readfile('$TMPVIEW'), '')) | call winrestview(v) | else | norm! G$ | endif\" \
  $TMPFILE")"

tmux rename-window -t "$WINDOW_ID" copy
tmux select-window -t "$WINDOW_ID"
tmux set-window-option -t "$WINDOW_ID" remain-on-exit off

