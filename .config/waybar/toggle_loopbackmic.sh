set -euo pipefail

LATENCY_MS="${LATENCY_MS:-2000}"

# Find loopback module ids (first column) whose name (second column) is module-loopback
mapfile -t ids < <(pactl list short modules | awk '$2=="module-loopback"{print $1}')

if ((${#ids[@]} > 0)); then
  # Toggle OFF: unload all existing loopbacks
  for id in "${ids[@]}"; do
    pactl unload-module "$id"
  done
  echo "Mic monitor: OFF"
else
  # Toggle ON: load a loopback
  id="$(pactl load-module module-loopback latency_msec="$LATENCY_MS")"
  echo "Mic monitor: ON (id=$id, latency=${LATENCY_MS}ms)"
fi

