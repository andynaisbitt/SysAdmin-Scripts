# 🛠️ The SysAdmin Toolkit (Windows & Linux)

Welcome to the SysAdmin Toolkit, a comprehensive, professional-grade PowerShell toolkit designed for modern **IT Support, Windows, and Linux System Administration**.

This repository isn't just a collection of scripts; it's a structured, extensible framework for automating daily operations, performing in-depth triage, conducting security audits, and managing your entire IT estate with confidence.

> **Goal:** To move beyond "random scripts" and provide a powerful, repeatable, and well-documented set of tools that you can trust in any environment.

---

## ✨ Core Principles

*   **Fast to Run & Easy to Audit:** Scripts are designed to be efficient and provide clear, actionable output.
*   **Cleanly Organized:** A logical folder structure makes it easy to find the right tool for the job.
*   **Safety First:** Scripts that make changes support `-WhatIf` and `-Confirm` to prevent accidents.
*   **Consistent & Standardized:** All scripts follow the clear guidelines laid out in `docs/STANDARDS.md`.
*   **Extensible:** The framework is designed to be easily expanded with new scripts and capabilities.

---

## 🚀 Quick Start

Get a feel for the toolkit's power with these common commands.

### Triage a Workstation
```powershell
# Gathers dozens of data points (uptime, disk space, top processes, pending reboots, etc.) into a zip file.
.\Desktop-Management\Triage\Invoke-WorkstationTriage.ps1 -ComputerName "WORKSTATION01" -DestinationPath "C:\TriageReports"
```

### Get a Full Computer Inventory
```powershell
# Queries an entire AD OU for hardware, software, security, and OS details.
.\Discovery\Get-ComputerInventory.ps1 -AdOuPath "OU=Workstations,DC=yourdomain,DC=com" -ExportPath "C:\Inventory\WorkstationInventory.csv"
```

### Find Stale Computers
```powershell
# Find computer accounts that haven't logged on in 90+ days.
.\Identity-Access\ActiveDirectory\Get-StaleADComputers.ps1 -InactiveDays 90
```

### Audit Over-Permissive File Shares
```powershell
# Scans a file server for shares where 'Everyone' or 'Authenticated Users' have Full Control.
.\File-Server-Management\Find-OverPermissiveShares.ps1 -ComputerName "FILE-SERVER-01"
```

---

## 📁 Toolkit Structure

The toolkit is organized into logical, high-level categories:

```
.
├── 📄 .gitignore
├── 📄 PLANNED_FEATURES.md
├── 📄 README.md
├── 📂 Azure/
├── 📂 Backup/
│   ├── 📂 Backup-Exec/
│   ├── 📂 RoboCopy/
│   └── 📂 Veeam/
├── 📂 Core/
├── 📂 Desktop-Management/
│   ├── 📂 Local-GPO/
│   └── 📂 Triage/
├── 📂 Discovery/
├── 📂 docs/
│   └── 📄 STANDARDS.md
├── 📂 File-Server-Management/
├── 📂 Identity-Access/
│   └── 📂 ActiveDirectory/
│       ├── 📂 DHCP/
│       ├── 📂 DNS/
│       └── 📂 Group-Policy/
├── 📂 ITSM-Tools/
│   └── 📂 ManageEngine/
├── 📂 Monitoring/
│   └── 📂 _Legacy/
├── 📂 Networking/
│   ├── 📂 Capture/
│   ├── 📂 Connections/
│   └── 📂 FTP/
├── 📂 Office365/
├── 📂 Patch-Management/
│   └── 📂 WSUS/
├── <h4>📂 Print-Server-Management/
├── 📂 Security/
├── 📂 Server-Management/
│   ├── 📂 Linux/
│   └── 📂 Windows/
├── 📂 Software-Deployment/
│   ├── 📂 Packages/
│   ├── 📂 Remote-Software/
│   └── 📂 Roles-And-Features/
└── 📂 Storage/
    └── 📂 FSRM/
```

---

## ✨ Most Used Commands

These are some of the most powerful and frequently used scripts in the toolkit:

*   **`Invoke-WorkstationTriage.ps1`:** The go-to script for front-line support to quickly diagnose endpoint issues.
*   **`Get-ComputerInventory.ps1`:** Your source of truth for hardware, software, and security posture across the estate.
*   **`New-ADUserOnboarding.ps1`:** A comprehensive "Joiner" script to automate new user creation from start to finish.
*   **`Offboard-User.ps1`:** A "Leaver" script to securely and consistently offboard users from M365/Entra ID.
*   **`Get-LocalAdminEstateReport.ps1`:** Audits local admin group membership across all workstations/servers to find drift.
*   **`Get-ShareRiskSummary.ps1`:** Identifies and reports on over-permissive file shares.
*   **`Get-PendingRebootEstateReport.ps1`:** Scans an entire AD OU to find out which machines need a reboot.
*   **`Invoke-FileShareMigration.ps1`:** A robust Robocopy wrapper for migrating file shares with full logging and error handling.
*   **`Get-UserAccessSummary.ps1`:** Provides a 360-degree view of a user's access rights.
*   **`Get-Toolbox.ps1`:** Downloads and validates essential sysadmin tools like the Sysinternals Suite.

---

## 🧱 Standards & Contribution

All scripts adhere to the standards defined in **`docs/STANDARDS.md`**. This ensures consistency, safety, and readability. Contributions are welcome, provided they follow these guidelines.

---

## 🧾 License

MIT License. This is a powerful toolkit—always test scripts in a non-production environment first.
