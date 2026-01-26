# Get disk stats for root filesystem
DISK_INFO=$(df -h / | tail -1)
TOTAL=$(echo "$DISK_INFO" | awk '{print $2}')
USED=$(echo "$DISK_INFO" | awk '{print $3}')
AVAIL=$(echo "$DISK_INFO" | awk '{print $4}')
PERCENTAGE=$(echo "$DISK_INFO" | awk '{print $5}' | sed 's/%//')

# Cache file for large files list
# Use user-specific cache directory
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar"
mkdir -p "$CACHE_DIR" 2>/dev/null
CACHE_FILE="$CACHE_DIR/disk_large_files.cache"
CACHE_AGE=600  # 10 minutes in seconds

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

# Update cache if needed (run in background to not block)
if [ "$UPDATE_CACHE" = true ]; then
    (
        # Use find to locate large files (>100MB) and collect all results first
        # This avoids broken pipe issues by collecting before sorting
        TEMP_FILE=$(mktemp "$CACHE_DIR/waybar_disk_temp.XXXXXX" 2>/dev/null || echo "$CACHE_DIR/waybar_disk_temp.$$")

        # Find large files and collect all results into temp file first
        find /home /tmp /var/log /opt -type f -size +100M 2>/dev/null -exec du -h {} \; 2>/dev/null > "$TEMP_FILE" 2>/dev/null

        # Now sort the collected results (no pipe, so no broken pipe issues)
        if [ -s "$TEMP_FILE" ]; then
            sort -rh "$TEMP_FILE" 2>/dev/null | head -10 | awk '{
                size = $1
                file = $2
                name = file
                # Get just the filename
                if (match(file, /\/([^\/]+)$/)) {
                    name = substr(file, RSTART+1)
                }
                # Truncate name to 40 chars
                if (length(name) > 40) {
                    name = substr(name, 1, 40)
                }
                printf "%-40s %8s\n", name, size
            }' > "$CACHE_FILE" 2>/dev/null
        fi

        rm -f "$TEMP_FILE" 2>/dev/null
    ) &
fi

# Read from cache (or use empty if cache doesn't exist yet)
if [ -f "$CACHE_FILE" ]; then
    LARGE_FILES=$(cat "$CACHE_FILE" 2>/dev/null)
else
    LARGE_FILES="(Scanning for large files...)"
fi

# Build tooltip text
TOOLTIP_TEXT="Disk Usage: ${PERCENTAGE}%
Used: ${USED} / ${TOTAL}
Available: ${AVAIL}

Largest Files (>100MB):
${LARGE_FILES}"

# Escape for JSON (escape backslashes, quotes, and newlines)
TOOLTIP_JSON=$(printf '%s' "$TOOLTIP_TEXT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

# Determine class based on percentage
CLASS=""
if [ "$PERCENTAGE" -ge 90 ]; then
    CLASS="critical"
elif [ "$PERCENTAGE" -ge 80 ]; then
    CLASS="warning"
fi

# Output JSON with icon
if [ -n "$CLASS" ]; then
    echo "{\"text\": \"${PERCENTAGE}%\", \"tooltip\": \"${TOOLTIP_JSON}\", \"percentage\": ${PERCENTAGE}, \"class\": \"${CLASS}\"}"
else
    echo "{\"text\": \"${PERCENTAGE}%\", \"tooltip\": \"${TOOLTIP_JSON}\", \"percentage\": ${PERCENTAGE}}"
fi

