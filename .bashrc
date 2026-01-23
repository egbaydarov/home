runbg () {
  [ -n "${TMUX:-}" ] || { echo "runbg: not inside tmux" >&2; return 1; }
  [ $# -gt 0 ] || { echo "usage: runbg <command...>" >&2; return 2; }

  local win=1000
  local cmd="$*"

  if ! tmux list-windows -F '#{window_index}' | grep -qx "$win"; then
    tmux new-window -d -t "$win" -n "bg" -c "$PWD"
  fi

  tmux split-window -t "${win}" -c "$PWD" "$cmd"
  tmux select-layout -t "${win}" tiled
}

eval "$(fzf --bash)"
alias nd='nix develop'

