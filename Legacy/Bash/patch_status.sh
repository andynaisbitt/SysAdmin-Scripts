#!/bin/bash
#
# patch_status.sh
#
# Detects the Linux package manager (apt/yum/dnf/zypper) and reports
# pending update counts and the last update time.
#
# Usage: patch_status.sh

HOSTNAME=$(hostname)
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

echo "--- Patch Status Report for $HOSTNAME ---"
echo "Generated: $TIMESTAMP"
echo ""

# Function to report APT status
report_apt() {
    echo "--- APT (Debian/Ubuntu) Status ---"
    if command -v apt &>/dev/null; then
        PENDING_UPDATES=$(sudo apt list --upgradable 2>/dev/null | grep -c "upgradable")
        LAST_UPDATE=$(stat -c %y /var/cache/apt/pkgcache.bin 2>/dev/null | cut -d'.' -f1) # Approximate last update time

        echo "Pending Updates: $PENDING_UPDATES"
        echo "Last APT Update: ${LAST_UPDATE:-"N/A"}"
    else
        echo "APT not found."
    fi
    echo ""
}

# Function to report YUM/DNF status
report_yum_dnf() {
    echo "--- YUM/DNF (RHEL/CentOS/Fedora) Status ---"
    if command -v dnf &>/dev/null; then
        PENDING_UPDATES=$(dnf check-update -q 2>/dev/null | wc -l)
        LAST_UPDATE=$(yum log | head -n 1 | awk '{print $1" "$2}' 2>/dev/null) # Approximate last update time

        echo "Package Manager: DNF"
        echo "Pending Updates: $PENDING_UPDATES"
        echo "Last DNF Update: ${LAST_UPDATE:-"N/A"}"
    elif command -v yum &>/dev/null; then
        PENDING_UPDATES=$(yum check-update -q 2>/dev/null | wc -l)
        LAST_UPDATE=$(yum log | head -n 1 | awk '{print $1" "$2}' 2>/dev/null) # Approximate last update time

        echo "Package Manager: YUM"
        echo "Pending Updates: $PENDING_UPDATES"
        echo "Last YUM Update: ${LAST_UPDATE:-"N/A"}"
    else
        echo "YUM/DNF not found."
    fi
    echo ""
}

# Function to report ZYPPER status
report_zypper() {
    echo "--- ZYPPER (openSUSE/SLES) Status ---"
    if command -v zypper &>/dev/null; then
        PENDING_UPDATES=$(zypper lu 2>/dev/null | grep -c "v ") # Count lines starting with 'v ' for upgradable
        LAST_UPDATE=$(stat -c %y /var/cache/zypp/raw/2>/dev/null | cut -d'.' -f1) # Approximate last update time

        echo "Pending Updates: $PENDING_UPDATES"
        echo "Last Zypper Update: ${LAST_UPDATE:-"N/A"}"
    else
        echo "ZYPPER not found."
    fi
    echo ""
}

# Main execution flow
report_apt
report_yum_dnf
report_zypper

echo "--- End of Report ---"
exit 0
