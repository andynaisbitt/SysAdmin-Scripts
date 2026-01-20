#!/bin/bash
#
# service_health.sh
#
# Checks the health of services on a Linux system, supporting systemd and SysVinit.
# Returns non-zero exit code if any critical service is failed.
#
# Usage: service_health.sh [CRITICAL_SERVICES]
#   CRITICAL_SERVICES: Optional, comma-separated list of service names to specifically check.

CRITICAL_SERVICES_ARG=$1
HOSTNAME=$(hostname)
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
FAILED_COUNT=0

echo "--- Service Health Report for $HOSTNAME ---"
echo "Generated: $TIMESTAMP"
echo ""

# Function to check service status using systemctl
check_systemd() {
    echo "--- Systemd Failed Services ---"
    if command -v systemctl &>/dev/null; then
        systemctl --failed --no-pager
        if [ $? -ne 0 ]; then
            echo "No failed systemd services found."
        else
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    else
        echo "systemctl not found. Skipping systemd check."
    fi
    echo ""
}

# Function to check service status using SysVinit
check_sysv() {
    echo "--- SysVinit Services (Status All) ---"
    if command -v service &>/dev/null; then
        service --status-all 2>&1 | grep -E '\[ \- \]|\[ \? \]' # Look for stopped or unknown states
        if [ $? -ne 0 ]; then
            echo "No stopped or unknown SysVinit services found."
        else
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    else
        echo "service command not found. Skipping SysVinit check."
    fi
    echo ""
}

# Function to check specific critical services
check_critical_services() {
    if [ -n "$CRITICAL_SERVICES_ARG" ]; then
        echo "--- Checking Critical Services: $CRITICAL_SERVICES_ARG ---"
        IFS=',' read -ra ADDR <<< "$CRITICAL_SERVICES_ARG"
        for SERVICE in "${ADDR[@]}"; do
            echo -n "Checking $SERVICE: "
            if command -v systemctl &>/dev/null; then
                if systemctl is-active --quiet "$SERVICE"; then
                    echo "Active (Running)"
                elif systemctl is-failed --quiet "$SERVICE"; then
                    echo "Failed"
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                else
                    echo "Inactive/Stopped"
                fi
            elif command -v service &>/dev/null; then
                if service "$SERVICE" status &>/dev/null; then
                    echo "Running (SysVinit)"
                else
                    echo "Stopped/Unknown (SysVinit)"
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                fi
            else
                echo "systemctl or service command not found. Cannot check."
            fi
        done
        echo ""
    fi
}

# Main execution flow
check_systemd
check_sysv
check_critical_services

echo "--- End of Report ---"

if [ $FAILED_COUNT -gt 0 ]; then
    echo "WARNING: $FAILED_COUNT service(s) reported issues."
    exit 1
else
    echo "All checked services appear healthy."
    exit 0
fi
