# Get network interface info
ACTIVE_IF=$(ip route | grep default | awk '{print $5}' | head -1 2>/dev/null)
if [ -z "$ACTIVE_IF" ]; then
    ACTIVE_IF=$(ip link show up 2>/dev/null | grep -E "^[0-9]+:" | grep -v lo | head -1 | awk -F: '{print $2}' | sed 's/^[[:space:]]*//')
fi

# Check if interface is up
if [ -z "$ACTIVE_IF" ] || ! ip link show "$ACTIVE_IF" 2>/dev/null | grep -q "state UP"; then
    echo "{\"text\": \"󱘖  Offline\", \"tooltip\": \"Network: Offline\"}"
    exit 0
fi

# Get network stats (download speed)
# Use cache file to store previous values for speed calculation
# Use user-specific cache directory
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar"
mkdir -p "$CACHE_DIR" 2>/dev/null
SPEED_CACHE="$CACHE_DIR/network_speed.cache"
RX_BYTES_NEW=$(cat /sys/class/net/"$ACTIVE_IF"/statistics/rx_bytes 2>/dev/null || echo 0)
TX_BYTES_NEW=$(cat /sys/class/net/"$ACTIVE_IF"/statistics/tx_bytes 2>/dev/null || echo 0)

if [ -f "$SPEED_CACHE" ]; then
    RX_BYTES_OLD=$(head -1 "$SPEED_CACHE" 2>/dev/null || echo "$RX_BYTES_NEW")
    TX_BYTES_OLD=$(sed -n '2p' "$SPEED_CACHE" 2>/dev/null || echo "$TX_BYTES_NEW")
    OLD_TIME=$(sed -n '3p' "$SPEED_CACHE" 2>/dev/null || echo 0)
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - OLD_TIME))

    if [ $TIME_DIFF -gt 0 ] && [ $TIME_DIFF -le 5 ]; then
        RX_SPEED=$(((RX_BYTES_NEW - RX_BYTES_OLD) / TIME_DIFF))
        TX_SPEED=$(((TX_BYTES_NEW - TX_BYTES_OLD) / TIME_DIFF))
        # Ensure non-negative
        if [ $RX_SPEED -lt 0 ]; then RX_SPEED=0; fi
        if [ $TX_SPEED -lt 0 ]; then TX_SPEED=0; fi
    else
        RX_SPEED=0
        TX_SPEED=0
    fi
else
    RX_SPEED=0
    TX_SPEED=0
fi

# Save current values and time for next run
echo "$RX_BYTES_NEW" > "$SPEED_CACHE" 2>/dev/null
echo "$TX_BYTES_NEW" >> "$SPEED_CACHE" 2>/dev/null
echo "$(date +%s)" >> "$SPEED_CACHE" 2>/dev/null

# Convert to human readable
format_bytes() {
    local bytes=$1
    if [ $bytes -ge 1073741824 ]; then
        awk "BEGIN {printf \"%.2f GiB/s\", $bytes/1073741824}"
    elif [ $bytes -ge 1048576 ]; then
        awk "BEGIN {printf \"%.2f MiB/s\", $bytes/1048576}"
    elif [ $bytes -ge 1024 ]; then
        awk "BEGIN {printf \"%.2f KiB/s\", $bytes/1024}"
    else
        echo "${bytes} B/s"
    fi
}

RX_FORMATTED=$(format_bytes $RX_SPEED)
TX_FORMATTED=$(format_bytes $TX_SPEED)

# Determine icon based on interface type
if [ -d "/sys/class/net/$ACTIVE_IF/wireless" ]; then
    # WiFi
    SIGNAL=$(iw dev "$ACTIVE_IF" link 2>/dev/null | grep signal | awk '{print $2}')
    if [ -n "$SIGNAL" ]; then
        if [ "$SIGNAL" -ge -50 ]; then
            ICON="󰤨"
        elif [ "$SIGNAL" -ge -60 ]; then
            ICON="󰤥"
        elif [ "$SIGNAL" -ge -70 ]; then
            ICON="󰤢"
        elif [ "$SIGNAL" -ge -80 ]; then
            ICON="󰤟"
        else
            ICON="󰤫"
        fi
    else
        ICON="󰤨"
    fi
    DISPLAY_TEXT="${ICON} ${RX_FORMATTED}"
else
    # Ethernet
    ICON="󰈀"
    DISPLAY_TEXT="${ICON} ${RX_FORMATTED}"
fi

# Cache file for network users list
CACHE_FILE="$CACHE_DIR/network_users.cache"
CACHE_AGE=30  # 30 seconds

# Check if cache exists and is recent
UPDATE_CACHE=false
if [ ! -f "$CACHE_FILE" ]; then
    UPDATE_CACHE=true
else
    CACHE_TIME=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    CURRENT_TIME=$(date +%s)
    if [ $((CURRENT_TIME - CACHE_TIME)) -ge $CACHE_AGE ]; then
        UPDATE_CACHE=true
    fi
fi

# Update cache if needed (run in background)
if [ "$UPDATE_CACHE" = true ]; then
    (
        # Get network connections by process using ss
        NETWORK_USERS=$(ss -tnp 2>/dev/null | awk 'NR>1 {
            process = $NF
            gsub(/users:\(\(|\)\)/, "", process)
            if (match(process, /"([^"]+)"/)) {
                proc_name = substr(process, RSTART+1, RLENGTH-2)
            } else if (match(process, /([^,]+),/)) {
                proc_name = substr(process, RSTART, RLENGTH-1)
            } else {
                proc_name = process
            }
            gsub(/\/nix\/store\/[^\/]+\//, "", proc_name)
            gsub(/\/run\/current-system\//, "", proc_name)
            if (match(proc_name, /\/([^\/]+)$/)) {
                proc_name = substr(proc_name, RSTART+1)
            }
            if (length(proc_name) > 0 && proc_name != "-") {
                count[proc_name]++
            }
        } END {
            n = asorti(count, sorted)
            for (i = n; i >= 1 && i > n - 10; i--) {
                proc = sorted[i]
                cnt = count[proc]
                if (length(proc) > 35) {
                    proc = substr(proc, 1, 35)
                }
                printf "%-35s %6d\n", proc, cnt
            }
        }')

        if [ -n "$NETWORK_USERS" ]; then
            echo "$NETWORK_USERS" > "$CACHE_FILE" 2>/dev/null
        else
            echo "(No active connections)" > "$CACHE_FILE" 2>/dev/null
        fi
    ) &
fi

# Read from cache
if [ -f "$CACHE_FILE" ]; then
    NETWORK_USERS=$(cat "$CACHE_FILE" 2>/dev/null)
else
    NETWORK_USERS="(Scanning...)"
fi

# Build tooltip text
TOOLTIP_TEXT="Network: ${ACTIVE_IF}
󰇚 Down: ${RX_FORMATTED}
󰕒 Up: ${TX_FORMATTED}

Top Network Users:
${NETWORK_USERS}"

# Escape for JSON
TOOLTIP_JSON=$(printf '%s' "$TOOLTIP_TEXT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

# Output JSON
echo "{\"text\": \"${DISPLAY_TEXT}\", \"tooltip\": \"${TOOLTIP_JSON}\"}"

