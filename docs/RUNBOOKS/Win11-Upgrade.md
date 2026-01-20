# Runbook: Windows 11 Upgrade

This runbook outlines the process for reporting on Windows 11 readiness and triggering feature updates on workstations, leveraging scripts from the SysAdmin Toolkit.

---

## 1. Windows 11 Readiness Report

**Scenario:** You need to identify which workstations in your environment meet the hardware requirements for a Windows 11 upgrade.

**Steps:**

1.  **Generate Report:** Use the toolkit script to check for TPM 2.0, Secure Boot, CPU, RAM, and disk space.
    ```powershell
    .\Desktop-Management\Windows11\Get-Win11ReadinessReport.ps1 -AdOuPath "OU=Workstations,DC=yourdomain,DC=com" -ExportPath "C:\Reports\Win11Readiness.csv"
    ```
    *   **Output:** A CSV file (and optional HTML) detailing the readiness status for each machine.
2.  **Review Report:** Analyze the output to identify compliant and non-compliant machines.
3.  **Address Non-Compliance:** For machines that do not meet requirements, plan for hardware upgrades or replacements.

---

## 2. Applying Windows 11 Baseline Configuration

**Scenario:** After upgrading to Windows 11, you want to apply a minimal, enterprise-safe baseline configuration to new or existing deployments.

**Steps:**

1.  **Run Baseline Configuration Script:**
    ```powershell
    # To see what changes would be made (WhatIf mode)
    .\Desktop-Management\Windows11\Set-Win11BaselineConfig.ps1 -ComputerName "WORKSTATION01" -WhatIf

    # To apply the changes
    .\Desktop-Management\Windows11\Set-Win11BaselineConfig.ps1 -ComputerName "WORKSTATION01" -Confirm
    ```
    *   **Configuration Areas:** This script typically covers power settings, disabling consumer experiences, disabling optional bloat suggestions, setting Windows Update active hours, and ensuring BitLocker readiness.
2.  **Verify Configuration:** After applying, you might use `Discovery\Get-ComputerInventory.ps1` to re-check relevant settings if custom fields are added.

---

## 3. Triggering Windows 11 Feature Update

**Scenario:** You have a compliant workstation and want to trigger the Windows 11 feature update via Windows Update mechanisms.

**Steps:**

1.  **Check Readiness (if not already done):** Confirm the workstation meets the Windows 11 requirements using `Get-Win11ReadinessReport.ps1`.
2.  **Trigger Update:** Use the toolkit script to initiate the feature update.
    ```powershell
    # To download the update only (without installing immediately)
    .\Desktop-Management\Windows11\Invoke-WinFeatureUpdate.ps1 -ComputerName "WORKSTATION01" -DownloadOnly

    # To download and install the update
    .\Desktop-Management\Windows11\Invoke-WinFeatureUpdate.ps1 -ComputerName "WORKSTATION01" -InstallUpdate
    ```
    *   **Important:** Ensure proper backup procedures are followed before initiating a feature update.
3.  **Monitor Progress:** Monitor the workstation's update progress via standard Windows Update settings or relevant RMM tools.
4.  **Verify Installation:** After reboot, verify the OS version: `(Get-CimInstance Win32_OperatingSystem).Caption`.

---
