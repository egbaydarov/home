# Get all CPU core temperatures
TEMP_DATA=""
MAX_TEMP=0
AVG_TEMP=0
CORE_COUNT=0
declare -A SEEN_LABELS  # Track labels to avoid duplicates

# Function to add temperature
add_temp() {
    local label="$1"
    local temp="$2"
    local temp_int=${temp%.*}

    # Normalize label for duplicate detection (remove common variations)
    local normalized_label=$(echo "$label" | tr '[:upper:]' '[:lower:]' | sed 's/temp[0-9]*//g' | sed 's/[^a-z0-9]//g')

    # Check if we've seen a similar label or very close temperature (same sensor)
    for seen_label in "${!SEEN_LABELS[@]}"; do
        local seen_temp="${SEEN_LABELS[$seen_label]}"
        local seen_temp_int=${seen_temp%.*}
        local seen_normalized=$(echo "$seen_label" | tr '[:upper:]' '[:lower:]' | sed 's/temp[0-9]*//g' | sed 's/[^a-z0-9]//g')

        # Skip if same normalized label or temperatures are within 2°C (likely same sensor)
        if [ "$normalized_label" = "$seen_normalized" ] || ([ $((temp_int - seen_temp_int)) -lt 2 ] && [ $((seen_temp_int - temp_int)) -lt 2 ]); then
            # Prefer the label with more specific info (Tctl over acpitz)
            if echo "$label" | grep -qiE "(tctl|tdie|core)"; then
                # Replace the old entry with this better one
                unset SEEN_LABELS["$seen_label"]
                # Remove from TEMP_DATA (handle newlines properly)
                TEMP_DATA=$(printf '%s' "$TEMP_DATA" | sed "s|^${seen_label}:.*||" | sed "s|\\n${seen_label}:.*||" | sed '/^$/d')
                break
            else
                # Skip this duplicate
                return
            fi
        fi
    done

    SEEN_LABELS[$label]="$temp"

    # Update max
    if [ $temp_int -gt $MAX_TEMP ]; then
        MAX_TEMP=$temp_int
    fi

    # Add to average calculation
    AVG_TEMP=$(awk "BEGIN {printf \"%.1f\", $AVG_TEMP + $temp}")
    CORE_COUNT=$((CORE_COUNT + 1))

    # Add to display data
    if [ -n "$TEMP_DATA" ]; then
        TEMP_DATA="${TEMP_DATA}\n"
    fi
    TEMP_DATA="${TEMP_DATA}${label}: ${temp}°C"
}

# Try to get temperatures from sensors command
if command -v sensors >/dev/null 2>&1; then
    # First, try to get individual core temperatures
    CORE_TEMP_LINES=$(sensors 2>/dev/null | grep -E "Core [0-9]+" | grep -E "°C")

    if [ -n "$CORE_TEMP_LINES" ]; then
        # We have individual core temps
        while IFS= read -r line; do
            TEMP=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+°C' | head -1 | sed 's/°C//')
            if [ -n "$TEMP" ]; then
                LABEL=$(echo "$line" | awk -F: '{print $1}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                add_temp "$LABEL" "$TEMP"
            fi
        done <<< "$CORE_TEMP_LINES"
    else
        # No individual cores, get any CPU temperatures (Tdie, Tctl, etc.)
        TEMP_LINES=$(sensors 2>/dev/null | grep -E "(Tdie|Tctl)" | grep -E "°C")

        if [ -n "$TEMP_LINES" ]; then
            while IFS= read -r line; do
                TEMP=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+°C' | head -1 | sed 's/°C//')
                if [ -n "$TEMP" ]; then
                    LABEL=$(echo "$line" | awk -F: '{print $1}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    add_temp "$LABEL" "$TEMP"
                fi
            done <<< "$TEMP_LINES"
        fi
    fi
fi

# Try hwmon for additional CPU temperatures
# Check all hwmon devices for CPU-related temps
for hwmon in /sys/class/hwmon/hwmon*/temp*_input; do
    if [ -f "$hwmon" ]; then
        TEMP_MILLI=$(cat "$hwmon" 2>/dev/null)
        if [ -n "$TEMP_MILLI" ] && [ "$TEMP_MILLI" -gt 20000 ] && [ "$TEMP_MILLI" -lt 150000 ]; then
            TEMP=$(awk "BEGIN {printf \"%.1f\", $TEMP_MILLI/1000}")

            # Get device name
            HWMON_NAME=$(cat "${hwmon%/*}/name" 2>/dev/null)

            # Get label
            LABEL_FILE="${hwmon%_input}_label"
            if [ -f "$LABEL_FILE" ]; then
                LABEL=$(cat "$LABEL_FILE" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            else
                TEMP_NUM=$(basename "$hwmon" | sed 's/temp\([0-9]*\)_input/\1/')
                if [ -n "$HWMON_NAME" ]; then
                    if echo "$HWMON_NAME" | grep -qiE "(k10|amd|cpu|acpitz)"; then
                        LABEL="${HWMON_NAME} Temp${TEMP_NUM}"
                    else
                        LABEL="${HWMON_NAME} Temp${TEMP_NUM}"
                    fi
                else
                    LABEL="Temp ${TEMP_NUM}"
                fi
            fi

            # Add CPU-related temps (k10temp, acpitz) but exclude GPU
            if echo "$HWMON_NAME" | grep -qiE "(k10|amd|cpu|acpitz)"; then
                # Skip GPU temps
                if ! echo "$HWMON_NAME" | grep -qiE "(amdgpu|gpu|nvme)"; then
                    # Clean up label - use device name if label is generic
                    if [ "$LABEL" = "Temp${TEMP_NUM}" ] || [ -z "$LABEL" ]; then
                        LABEL="${HWMON_NAME}"
                    fi
                    add_temp "$LABEL" "$TEMP"
                fi
            elif echo "$LABEL" | grep -qiE "(tctl|tdie|core|cpu)"; then
                add_temp "$LABEL" "$TEMP"
            fi
        fi
    fi
done

# Also check thermal zones for additional CPU temps
for zone in /sys/class/thermal/thermal_zone*/temp; do
    if [ -f "$zone" ]; then
        TEMP_MILLI=$(cat "$zone" 2>/dev/null)
        if [ -n "$TEMP_MILLI" ] && [ "$TEMP_MILLI" -gt 20000 ] && [ "$TEMP_MILLI" -lt 150000 ]; then
            TEMP=$(awk "BEGIN {printf \"%.1f\", $TEMP_MILLI/1000}")
            ZONE_NAME=$(cat "${zone%/temp}/type" 2>/dev/null)
            ZONE_NUM=$(echo "$zone" | grep -oE 'thermal_zone[0-9]+' | grep -oE '[0-9]+')

            # Only add CPU-related thermal zones
            if [ -n "$ZONE_NAME" ] && echo "$ZONE_NAME" | grep -qiE "(cpu|x86|acpitz|k10)"; then
                add_temp "$ZONE_NAME" "$TEMP"
            elif [ -z "$ZONE_NAME" ] && [ $CORE_COUNT -eq 0 ]; then
                # If no name but we have nothing else, add it
                add_temp "Thermal Zone $ZONE_NUM" "$TEMP"
            fi
        fi
    fi
done

# Calculate average
if [ $CORE_COUNT -gt 0 ]; then
    AVG_TEMP=$(awk "BEGIN {printf \"%.0f\", $AVG_TEMP / $CORE_COUNT}")
else
    # Fallback: try to get any temperature
    TEMP=$(sensors 2>/dev/null | grep -E "°C" | head -1 | grep -oE '[0-9]+\.[0-9]+°C' | head -1 | sed 's/°C//')
    if [ -n "$TEMP" ]; then
        MAX_TEMP=${TEMP%.*}
        AVG_TEMP=$MAX_TEMP
        CORE_COUNT=1
        TEMP_DATA="Temperature: ${TEMP}°C"
    else
        MAX_TEMP=0
        AVG_TEMP=0
    fi
fi

# Build tooltip text
if [ $CORE_COUNT -gt 0 ]; then
    # Get CPU core count
    CPU_CORES=$(nproc 2>/dev/null || echo "?")

    # Check if we have individual cores or just aggregate temps
    HAS_INDIVIDUAL_CORES=false
    if echo "$TEMP_DATA" | grep -qiE "Core [0-9]"; then
        HAS_INDIVIDUAL_CORES=true
    fi

    if [ "$HAS_INDIVIDUAL_CORES" = true ]; then
        TOOLTIP_TEXT="CPU Temperature (${CPU_CORES} cores)
Average: ${AVG_TEMP}°C
Max: ${MAX_TEMP}°C

Per-Core Temperatures:
${TEMP_DATA}"
    else
        TOOLTIP_TEXT="CPU Temperature (${CPU_CORES} cores)
Average: ${AVG_TEMP}°C
Max: ${MAX_TEMP}°C

Temperatures:
${TEMP_DATA}"
    fi
else
    TOOLTIP_TEXT="Temperature: No sensors found"
fi

# Escape for JSON (properly handle newlines)
TOOLTIP_JSON=$(printf '%s' "$TOOLTIP_TEXT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

# Determine class based on max temperature
CLASS=""
if [ "$MAX_TEMP" -ge 90 ]; then
    CLASS="critical"
elif [ "$MAX_TEMP" -ge 80 ]; then
    CLASS="warning"
fi

# Output JSON - show max temperature in main display
if [ -n "$CLASS" ]; then
    echo "{\"text\": \"${MAX_TEMP}°\", \"tooltip\": \"${TOOLTIP_JSON}\", \"class\": \"${CLASS}\"}"
else
    echo "{\"text\": \"${MAX_TEMP}°\", \"tooltip\": \"${TOOLTIP_JSON}\"}"
fi
