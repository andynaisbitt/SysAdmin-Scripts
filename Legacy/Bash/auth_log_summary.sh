#!/bin/bash
#
# auth_log_summary.sh
#
# Summarizes authentication events from /var/log/auth.log or /var/log/secure
# for the last 24 hours, focusing on failed login attempts.
#
# Usage: auth_log_summary.sh [HOURS_LOOKBACK]
#   HOURS_LOOKBACK: Optional. Number of hours to look back. Defaults to 24.

HOURS_LOOKBACK=${1:-24}
HOSTNAME=$(hostname)
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Determine the correct auth log file
AUTH_LOG=""
if [ -f "/var/log/auth.log" ]; then
    AUTH_LOG="/var/log/auth.log"
elif [ -f "/var/log/secure" ]; then
    AUTH_LOG="/var/log/secure"
else
    echo "Error: No auth log file found (/var/log/auth.log or /var/log/secure)." >&2
    exit 1
fi

echo "--- Authentication Log Summary for $HOSTNAME ---"
echo "Generated: $TIMESTAMP"
echo "Looking back $HOURS_LOOKBACK hours in $AUTH_LOG"
echo ""

# Get relevant log entries from the last X hours
START_TIME=$(date -d "$HOURS_LOOKBACK hours ago" +"%b %e %H:%M:%S")

# Filter for failed login attempts and count by IP and user
echo "--- Top 10 Failed Login Attempts by Source IP ---"
grep -E "Failed password|authentication failure" "$AUTH_LOG" | awk -v start="$START_TIME" '$0 ~ start { for (i=1;i<=NF;i++) if ($i ~ /rhost=/) print substr($i,7) }' | sort | uniq -c | sort -nr | head -n 10
echo ""

echo "--- Top 10 Failed Login Attempts by User ---"
grep -E "Failed password|authentication failure" "$AUTH_LOG" | awk -v start="$START_TIME" '$0 ~ start { for (i=1;i<=NF;i++) if ($i ~ /user=/) print substr($i,6) }' | sort | uniq -c | sort -nr | head -n 10
echo ""

echo "--- Recent SSH Failed Logins (last 10) ---"
grep "sshd" "$AUTH_LOG" | grep -i "Failed password" | tail -n 10
echo ""

echo "--- Sudo Failures (last 10) ---"
grep "sudo" "$AUTH_LOG" | grep -i "authentication failure" | tail -n 10
echo ""

echo "--- End of Report ---"
exit 0
