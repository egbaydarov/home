#!/usr/bin/env bash
set -euo pipefail

SESSION="main"
HOME_DIR="${HOME}"
PROJ_DIR="${HOME_DIR}/stuff"
CFG_DIR="${HOME_DIR}/.config"
STUFF_DIR="${HOME_DIR}/stuff"
GIT_AUTHOR="$(git config user.email || true)"

# Repos under $STUFF_DIR (not nested in another project), most recent own commit first
recent_repos() {
  fd -H -t d '^\.git$' --max-depth 4 --exclude node_modules "$STUFF_DIR" | while read -r g; do
    local repo="${g%/}" parent
    repo="${repo%/.git}"
    [ "$repo" = "$STUFF_DIR" ] && continue
    parent="$(git -C "$(dirname "$repo")" rev-parse --show-toplevel 2>/dev/null || true)"
    [ -n "$parent" ] && [ "$parent" != "$STUFF_DIR" ] && continue
    local t
    t="$(git -C "$repo" log -1 --all --author="$GIT_AUTHOR" --format=%ct 2>/dev/null || true)"
    [ -n "$t" ] && echo "$t $repo"
  done | sort -rn | cut -d' ' -f2-
}

mapfile -t REPOS < <(recent_repos | head -8)
repo_dir() { echo "${REPOS[$1]:-$STUFF_DIR}"; }


# Ensure session exists
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -n f1 -c "$(repo_dir 0)"
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

for i in 1 2 3 4 5 6 7 8; do
  ensure_window "f$i" "$(repo_dir $((i - 1)))"
done
ensure_window "f9" "$HOME_DIR/.ssh"
ensure_window "f0" "$CFG_DIR"


# Go to f1
tmux select-window -t "$SESSION":0

# If already inside tmux: switch client; otherwise attach
if [[ -n "${TMUX-}" ]]; then
  tmux switch-client -t "$SESSION"
else
  exec tmux attach -t "$SESSION"
fi

