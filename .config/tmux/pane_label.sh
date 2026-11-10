#!/bin/sh
# Usage: pane_label.sh <path> <command>
# Prints the git repo name for <path> ("~" for $HOME), or <command> outside a repo.

if root="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)"; then
  [ "$root" = "$HOME" ] && echo "~" || basename "$root"
else
  echo "$2"
fi
