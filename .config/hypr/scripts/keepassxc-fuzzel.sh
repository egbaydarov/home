set -euo pipefail

DB="$HOME/.config/keepassxc/Passwords.kdbx"
SLOT=1

notify_fdo() {
    local title="$1"
    local body="$2"

    busctl --user call \
      org.freedesktop.Notifications \
      /org/freedesktop/Notifications \
      org.freedesktop.Notifications Notify \
      susssasa{sv}i \
      "keepassxc" 0 "" "$title" "$body" 0 0 7000 >/dev/null 2>&1 || true
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# Basic deps
for c in ykman keepassxc-cli fuzzel sed; do
  if ! need_cmd "$c"; then
    notify_fdo "KeePassXC" "Missing command: $c"
    exit 1
  fi
done

# Auto-type dep
if ! need_cmd wtype; then
  notify_fdo "KeePassXC" "Missing command: wtype (needed for auto-type)"
  exit 1
fi

# Pick first connected YubiKey
serial=$(ykman list --serials 2>/dev/null | head -n1 || true)
if [ -z "${serial:-}" ]; then
    notify_fdo "KeePassXC" "No YubiKey detected"
    exit 1
fi

YUBI_OPT="${SLOT}:${serial}"

cleanup() {
    MASTERPW=""
    password=""
    unset MASTERPW password 2>/dev/null || true
}
trap cleanup EXIT

# Password prompt
MASTERPW=$(
    fuzzel --dmenu --prompt-only "KeePass password: " --password --cache /dev/null </dev/null 2>/dev/null
)
[ -z "${MASTERPW:-}" ] && exit 0

notify_fdo "KeePassXC" "Touch your YubiKey to unlock"

# Unlock & list entries
entries=$(printf '%s\n' "$MASTERPW" \
    | keepassxc-cli ls -R -f -y "$YUBI_OPT" "$DB" 2>/dev/null \
    | sed -e '/\/$/d' -e '/^Recycle Bin\//d')

if [ -z "${entries:-}" ]; then
    notify_fdo "KeePassXC" "Unlock failed or no entries found"
    exit 1
fi

# Choose entry
choice=$(printf '%s\n' "$entries" \
    | fuzzel --dmenu -w 50 -l 20 --prompt "KeePass entry: " 2>/dev/null)

[ -z "${choice:-}" ] && exit 0

notify_fdo "KeePassXC" "Touch your YubiKey to type password"

# Extract password
password=$(printf '%s\n' "$MASTERPW" \
    | keepassxc-cli show -s -a password -y "$YUBI_OPT" "$DB" "$choice" 2>/dev/null)

if [ -z "${password:-}" ]; then
    notify_fdo "KeePassXC" "Failed to read password or empty"
    exit 1
fi

# Auto-type into currently focused window
notify_fdo "KeePassXC" "Typing password into focused window…"
wtype -d 2 -- "$password"

# Optional: press Enter after typing
# wtype -k Return

# Clear sensitive vars
password=""
MASTERPW=""
unset password MASTERPW 2>/dev/null || true

notify_fdo "KeePassXC" "Done"

