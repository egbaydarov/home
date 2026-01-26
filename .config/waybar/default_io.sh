set -euo pipefail

DMENU="fuzzel --dmenu -w 58 -l 10"
MODE="${1:-}"

usage() {
  echo "Usage: $0 -o | -i"
  echo "  -o  pick default output (sink)"
  echo "  -i  pick default input (source)"
  exit 1
}

need() { command -v "$1" >/dev/null 2>&1; }

need pactl || { echo "Missing: pactl"; exit 1; }
need fuzzel || { echo "Missing: fuzzel"; exit 1; }

case "$MODE" in
  -o)
    # List sinks as: "<name>\t<description>"
    choice="$(
      pactl -f json list sinks \
      | jq -r '.[] | "\(.name)\t\(.description)"' \
      | $DMENU --prompt "Output: "
    )"
    [ -z "${choice:-}" ] && exit 0
    name="${choice%%$'\t'*}"
    pactl set-default-sink "$name"

    # Move current playback streams to new sink (nice UX)
    pactl list short sink-inputs | awk '{print $1}' | while read -r id; do
      pactl move-sink-input "$id" "$name" >/dev/null 2>&1 || true
    done
    ;;

  -i)
    choice="$(
      pactl -f json list sources \
      | jq -r '.[] | select(.name | endswith(".monitor") | not) | "\(.name)\t\(.description)"' \
      | fuzzel --dmenu --prompt "Input: "
    )"
    [ -z "${choice:-}" ] && exit 0
    name="${choice%%$'\t'*}"
    pactl set-default-source "$name"
    pactl list short source-outputs | awk '{print $1}' | while read -r id; do
      pactl move-source-output "$id" "$name" >/dev/null 2>&1 || true
    done
    ;;
esac

