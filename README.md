# 🛠️ SysAdmin Toolkit (Windows/Linux)

A comprehensive, modern PowerShell toolkit for **IT Support + Windows/Linux System Administration**.  
Built to be **fast to run**, **easy to audit**, and **cleanly organised** — covering identity, endpoints, servers, storage, networking, patching, M365, backups, and security.

> Goal: Provide a professional-grade toolkit for daily operations, triage, auditing, and automation.

---

## ✅ What’s inside

- **IT Support & Desktop Management** (remote triage, BitLocker, software inventory, GPUpdate, logged-on users, repairs, user profile reset, printer re-add, network reset)
- **Windows Server Operations** (uptime, reboot history, role inventory, event log grabbing, RDP session management, process control, server triage)
- **File Server Management** (SMB open files/sessions, share audits, permissions effective view, home drives, share creation, migration, risk summary, largest folders)
- **Identity & Access (AD DS, DHCP, DNS)** (stale AD users/computers, privileged group audits, comprehensive user onboarding/offboarding, bulk group/user-to-group management, user OU movement, password reset, DNS issue resolution, duplicate DNS records, DHCP lease management, stale DHCP reservations)
- **Backups & Restore Readiness** (Veeam/Backup Exec integration, unified backup health report, restore readiness testing, Robocopy wrappers, restore evidence packs)
- **Networking** (port/process mapping, listening ports, network snapshots, SMB connections, port matrix testing, packet capture helpers, suspicious listeners, top remote endpoints)
- **Storage & Quotas (FSRM)** (FSRM quota reporting + CSV-driven quotas)
- **Security & Compliance** (Defender status, LAPS status, audit policy baselines, RDP exposure, local firewall, hardening snapshots/drift, admin shares exposure)
- **Patch Management** (WSUS operations, declined updates, cleanup, client status, Windows Update status, pending reboot reports across estate)
- **Office 365 / Entra ID** (message trace, user reports, MFA status, licensing drift, shared mailbox access audit/grant, comprehensive user offboarding)
- **Toolbox:** Managed downloads for essential external tools (Sysinternals, tcping, psping).
- **Core Utilities:** Foundational scripts for consistent logging, standardized report export, flexible target retrieval, and remoting readiness checks.

---

## 🚀 Quick Start

To quickly get a feel for the toolkit, try these commands:

### Workstation Triage
```powershell
.\Desktop-Management\Triage\Invoke-WorkstationTriage.ps1 -ComputerName "WORKSTATION01" -DestinationPath "C:\TriageReports"
```

### Check Print Queue Health
```powershell
.\Print-Server-Management\Get-PrintServerQueueHealth.ps1 -ComputerName "PRINTSRV01" | Format-Table -AutoSize
```

### Find Who's Using a Port
```powershell
.\Networking\Connections\Find-WhoUsesPort.ps1 -Port 445
```

### Get Local Administrator Report (on a few machines)
```powershell
.\Security\Get-LocalAdminReport.ps1 -ComputerName "PC01", "PC02" | Format-Table -AutoSize
```

### Get Comprehensive Computer Inventory
```powershell
.\Discovery\Get-ComputerInventory.ps1 -AdOuPath "OU=Workstations,DC=yourdomain,DC=com" -ExportPath "C:\Inventory\WorkstationInventory.csv"
```

---

## ✨ Most Used Commands

Here are some of the most frequently used and powerful commands in the toolkit:

*   **`Invoke-WorkstationTriage.ps1`:** Collects extensive diagnostic data from a workstation.
*   **`Get-ComputerInventory.ps1`:** Comprehensive hardware/software/security inventory from endpoints.
*   **`Get-PendingRebootEstateReport.ps1`:** Checks for pending reboots across an entire OU.
*   **`New-ADUserOnboarding.ps1`:** Automates the complete new user creation process in AD.
*   **`Offboard-User.ps1`:** Automates user offboarding tasks in M365/Entra ID.
*   **`Invoke-NetworkResetLite.ps1`:** Quick network troubleshooting for endpoints.
*   **`Get-LocalAdminEstateReport.ps1`:** Audits local admin group members across the estate against an allowlist.
*   **`Get-WSUSClientStatusSummary.ps1`:** Summarizes WSUS client update status.
*   **`Get-CertificateExpiryReport.ps1`:** Monitors certificate expiration across various stores.
*   **`Invoke-FileShareMigration.ps1`:** A robust Robocopy wrapper for file share migrations.

---

## 📁 Folder Map (Current)

The project is organized into logical top-level directories:

*   **`Azure`**: Scripts related to Azure resource management (planned expansion).
*   **`Backup`**: Backup health checks, restore readiness, Robocopy wrappers, and evidence generation.
*   **`Core`**: Foundational scripts for logging, reporting, target management, and remoting checks.
*   **`Desktop-Management`**: Scripts for managing desktop endpoints, including triage, software inventory, BitLocker, user profiles, and network troubleshooting.
*   **`Discovery`**: Network and device discovery, and comprehensive inventory collection.
*   **`File-Server-Management`**: Operations and audits for file servers, including SMB sessions, shares, permissions, and home drives.
*   **`Identity-Access`**: Management and reporting for Active Directory Domain Services (AD DS), DHCP, and DNS.
*   **`ITSM-Tools`**: Integrations and tools for service management platforms (e.g., ManageEngine).
*   **`Monitoring`**: Health checks and reporting for system events, services, and certificates.
*   **`Networking`**: Network diagnostics, connection analysis, and packet capture helpers.
*   **`Office365`**: Microsoft 365/Entra ID reporting and administrative tasks.
*   **`Patch-Management`**: Patch status, WSUS operations, and Windows Update management.
*   **`Print-Server-Management`**: Print server and client management essentials.
*   **`Security`**: Security reporting, hardening checks, and compliance auditing.
*   **`Software-Deployment`**: Silent installs, remote software management, and Windows roles/features.
*   **`Storage`**: Storage management, FSRM quotas, and disk usage analysis.

---

## 🧱 Standards

For consistency and maintainability, all scripts adhere to the standards defined in `docs/STANDARDS.md`.

---

## 🧾 License

MIT. Test in non-production first.
