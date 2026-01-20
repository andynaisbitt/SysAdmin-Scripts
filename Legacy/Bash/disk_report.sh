#!/bin/bash
#
# disk_report.sh
#
# Generates a disk usage and inode report for a Linux system.
#
# Usage: disk_report.sh [PATH]
#   PATH: Optional. The directory to scan for largest files. Defaults to / if not provided.

REPORT_PATH=${1:-/}
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
HOSTNAME=$(hostname)

echo "--- Disk Report for $HOSTNAME ---"
echo "Generated: $TIMESTAMP"
echo ""

echo "--- System Uptime ---"
uptime
echo ""

echo "--- Disk Space (df -h) ---"
df -h
echo ""

echo "--- Inode Usage (df -i) ---"
df -i
echo ""

echo "--- Top 20 Largest Directories under $REPORT_PATH ---"
# Using du to find largest directories, excluding common system directories
# -x: Skip directories on other filesystems
# -d 2: Limit depth to 2 levels
# -h: Human-readable sizes
# sort -rh: Sort by human-readable size, reverse (largest first)
# head -n 20: Take top 20
sudo du -x -h -d 2 "$REPORT_PATH" 2>/dev/null | sort -rh | head -n 20
echo ""

echo "--- End of Report ---"

exit 0
