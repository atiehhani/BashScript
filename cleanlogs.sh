#!/bin/bash

# =============================
# Configurable variables
# =============================
LOGDIR="/var/lotus/logs"
THRESHOLD=85
MOUNTPOINT="/var/lotus"
KEEP_DAYS=5
SLEEP_INTERVAL=2
MAX_STABLE=3

get_usage() {
    df -P "$MOUNTPOINT" | awk 'NR==2 {print $5}' | tr -d '%'
}

clean_old_gz() {
    echo "[INFO] Cleaning old .gz logs in $LOGDIR..."
    find "$LOGDIR" -type f -name "*.gz" -mtime +$KEEP_DAYS -print -delete
}

truncate_biggest_log() {
    BIGFILE=$(find "$LOGDIR" -maxdepth 1 -type f -name "*.stdout.log" -printf "%s %p\n" \
              | sort -nr | head -n1 | awk '{print $2}')

    if [ -n "$BIGFILE" ]; then
        echo "[INFO] Truncating biggest log: $BIGFILE"
        : > "$BIGFILE"
    else
        echo "[WARN] No .stdout.log files found to truncate."
        return 1
    fi
}

# =============================
# Main flow
# =============================
echo "[INFO] Starting cleanup script..."

USAGE=$(get_usage)
echo "[INFO] Initial disk usage: ${USAGE}%"


if [ "$USAGE" -ge "$THRESHOLD" ]; then
    echo "[INFO] Usage more than threshold ($THRESHOLD%), cleaning old .gz files..."
    clean_old_gz
    #USAGE=$(get_usage)
    #echo "[INFO] Usage after gz cleanup: ${USAGE}%"
else
    echo "[INFO] Usage below threshold ($THRESHOLD%), skipping gz cleanup."
fi

STABLE_COUNT=0

while true; do
    echo "[INFO] Current usage: $USAGE%"

    if [ "$USAGE" -lt "$THRESHOLD" ]; then
	    echo "[INFO] Usage below threshold ($THRESHOLD%), exiting."
        break
    fi

    # Truncate biggest log
    truncate_biggest_log
    sleep "$SLEEP_INTERVAL"

    NEW_USAGE=$(get_usage)
    echo "[INFO] Usage after log truncate: ${NEW_USAGE}%"

    if [ "$NEW_USAGE" -eq "$USAGE" ]; then
        ((STABLE_COUNT++))
        echo "[WARN] Disk usage stuck at $NEW_USAGE% ($STABLE_COUNT/$MAX_STABLE)"
        if [ "$STABLE_COUNT" -ge "$MAX_STABLE" ]; then
            echo "[ERROR] Disk usage did not change after $MAX_STABLE attempts, exiting."
            break
        fi
    else
        STABLE_COUNT=0
    fi

    USAGE=$NEW_USAGE
done

echo "[INFO] Cleanup completed."


