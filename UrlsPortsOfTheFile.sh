#!/bin/bash
#
# check_urls.sh - Read a list of URLs from a file (one per line) and test
# TCP connectivity to each host:port using `nc -vz`.
#
# Usage:
#   ./check_urls.sh urls.txt
#   ./check_urls.sh urls.txt results.log
#
# Notes:
#   - Lines can be plain URLs or wrapped in [ ] (as in markdown links).
#   - If the URL has no explicit port, 80 is used for http:// and 443 for https://.
#   - Empty lines and lines starting with # are skipped.

set -u

INPUT_FILE="${1:-}"
LOGFILE="${2:-nc_results_$(date +%Y%m%d_%H%M%S).log}"
TIMEOUT=3   # seconds to wait per connection attempt

if [[ -z "$INPUT_FILE" ]]; then
    echo "Usage: $0 <urls_file> [logfile]"
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: file '$INPUT_FILE' not found."
    exit 1
fi

echo "Results will be saved to: $LOGFILE"
echo "----------------------------------------" | tee -a "$LOGFILE"

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    # Trim whitespace
    line="$(echo "$raw_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    # Skip empty lines and comments
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue

    # Strip surrounding [ ] if present (markdown-style links)
    line="${line#[}"
    line="${line%]}"

    # Extract scheme, host, port using a regex
    # Matches: scheme://host[:port][/path]
    if [[ "$line" =~ ^([a-zA-Z]+)://([^/:]+)(:([0-9]+))?(/.*)?$ ]]; then
        scheme="${BASH_REMATCH[1]}"
        host="${BASH_REMATCH[2]}"
        port="${BASH_REMATCH[4]}"

        if [[ -z "$port" ]]; then
            case "$scheme" in
                https) port=443 ;;
                *)     port=80 ;;
            esac
        fi
    else
        echo "SKIP (unparsable): $line" | tee -a "$LOGFILE"
        continue
    fi

    printf "Testing %-40s -> %s:%s ... " "$line" "$host" "$port"

    if result=$(nc -vz -w "$TIMEOUT" "$host" "$port" 2>&1); then
        echo "OPEN"
        echo "[OPEN] $line ($host:$port)" >> "$LOGFILE"
    else
        echo "CLOSED/FILTERED"
        echo "[FAIL] $line ($host:$port) - $result" >> "$LOGFILE"
    fi

done < "$INPUT_FILE"

echo "----------------------------------------"
echo "Done. Full results in $LOGFILE"
