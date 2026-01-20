# 🛠️ SysAdmin PowerShell Toolkit (2026)

A practical, modern PowerShell toolkit for **IT Support + Windows System Administration**.  
Built to be **fast to run**, **easy to audit**, and **cleanly organised** — covering identity, endpoints, servers, storage, networking, patching, M365, backups, and security.

> Goal: fewer “random scripts”, more repeatable operations + reporting you can hand to a manager or auditor.

---

## ✅ What’s inside

- **IT Support utilities** (remote triage, BitLocker checks, software inventory, GPUpdate, logged-on user, repairs)
- **Windows sysadmin ops** (RDP session mgmt, service health, pending reboot, update status, cert expiry)
- **File server management** (SMB open files, share audits, home drives, share creation)
- **Identity & access** (stale AD users/computers, privileged group audits, onboarding by template coming soon)
- **Backups** (Veeam/BE + restore readiness)
- **Networking** (port/process mapping, snapshots, SMB connections, port matrix, packet capture helpers)
- **Storage & quotas** (FSRM quota reporting + CSV-driven quotas)
- **Security** (Defender, LAPS, audit baseline, local admin reporting, RDP exposure)

---

## 📁 Folder map (current)

### Azure
Azure-related scripts and helpers (growing).

### Backup
Backup health checks and restore readiness.
- `Get-BackupHealth.ps1`
- `Test-RestoreReadiness.ps1`
- `Backup\\Backup-Exec\\Get-BEJobHistory.ps1`
- `Backup\\Veeam\\Get-VeeamJobStatus.ps1`
- `Backup\\RoboCopy\\Start-Robocopy.ps1`
- `Backup\\RoboCopy\\Start-Robocopy-Backup.ps1`
- `Backup\\RoboCopy\\Start-Robocopy-Mirror.ps1`

### Desktop-Management
Common IT Support / endpoint operations.
- `Get-LoggedOnUser.ps1`
- `Get-RemoteNetworkDrives.ps1`
- `Invoke-RemoteGPUpdate.ps1`
- `Invoke-RemoteBitLockerStatus.ps1`
- `Invoke-RemoteRepair.ps1`
- `Invoke-RemoteSoftwareInventory.ps1`
- `Get-LocalAdminDriftReport.ps1`
- `Desktop-Management\\Local-GPO\\SetLocalPWPolicy.ps1`

### Discovery
Network / device discovery.
- `Get-NetworkDevice.ps1`

### File-Server-Management
File server ops + audits (SMB, shares, home drives).
- `Get-SmbOpenFilesReport.ps1`
- `Close-SmbOpenFile.ps1`
- `Get-SharePermissionsAudit.ps1`
- `New-FileShare.ps1`
- `Set-HomeDrives.ps1`

### Identity-Access
Identity + Active Directory operations & reporting.

#### ActiveDirectory (core)
- `Get-PrivilegedGroupsAudit.ps1`
- `Get-StaleADComputers.ps1`
- `Get-StaleADUsers.ps1`
- `New-ADUserFromTemplate.ps1`
- `Get-ADGroupMember.ps1`
- `Enabled Users.ps1`
- `Disabled Users.ps1`

#### DHCP / DNS / Group Policy
- `DHCP\\Get-DhcpScopeReport.ps1`
- `DNS\\Get-DnsZoneReport.ps1`
- `Group-Policy\\Get-GPOComplianceReport.ps1`

### ITSM-Tools
Integrations / tools for service management platforms.
- `ManageEngine\\SelfScan_Deployment.ps1`
- `ManageEngine\\importschedule.xml`

### Monitoring
Health checks and reporting.
- `Get-RecentCriticalEvents.ps1`
- `Get-ServiceHealthReport.ps1`
- `Get-CertificateExpiryReport.ps1`
- `Get-BSODReport.ps1`
- `Get-BackupHealthUnified.ps1`


### Networking
Network diagnostics + capture helpers.

#### Connections
- `Get-PortUsage.ps1`
- `Find-ListeningPorts.ps1`
- `Find-WhoUsesPort.ps1`
- `Get-NetstatSnapshot.ps1`
- `Get-SMBConnections.ps1`
- `Test-PortMatrix.ps1`

#### Capture
- `Get-WiresharkInterfaces.ps1`
- `Start-TsharkCapture.ps1`
- `Stop-Capture.ps1`
- `Export-CaptureSummary.ps1`

#### FTP
- `FTP.ps1`

### Office365
Microsoft 365 reporting & admin tasks.
- `Get-MessageTrace.ps1`
- `Get-O365UserReport.ps1`
- `Get-MFAStatusReport.ps1`
- `Get-LicensingDriftReport.ps1`
- `Get-SharedMailboxAccessAudit.ps1`
- `Add-UserToSharedMailbox.ps1`
- `Offboard-User.ps1`

### Patch-Management
Patch status and WSUS operations.
- `Get-PendingRebootReport.ps1`
- `Get-WindowsUpdateStatus.ps1`

#### WSUS
- `Get-WsusServerReport.ps1`
- `Invoke-WSUSCleanup.ps1`
- `Get-WSUSDeclinedUpdatesReport.ps1`
- `Get-WSUSClientStatusSummary.ps1`

### Print-Server-Management
Print server essentials.
- `Get-PrintServerQueueHealth.ps1`
- `Clear-PrintQueue.ps1`
- `Restart-PrintSpooler.ps1`
- `Get-PrinterDriverReport.ps1`
- `Backup-PrintServerConfig.ps1`

### Security
Security reporting & hardening checks.
- `Get-LocalAdminReport.ps1`
- `Get-DefenderStatusReport.ps1`
- `Get-LAPSStatus.ps1`
- `Get-AuditPolicyBaseline.ps1`
- `Get-RDPExposureReport.ps1`

### Server-Management
Server-specific scripts.

#### Linux
- `Get-LinuxSystemInfo.ps1`

#### Windows
- `Get-WindowsServiceStatus.ps1`
- `Logoff Remote User from TS Session.ps1`

### Software
Tooling and portable utilities.

#### Toolbox
- `Get-Toolbox.ps1`
- `_manifest.json`
- `Toolbox\\Windows\\`
- `Toolbox\\Linux\\`

### Software-Deployment
Silent installs + remote software management.

#### Packages
- `Install-7Zip.ps1`
- `Install-AnyDesk.ps1`
- `Install-TeamViewer.ps1`
- `Install-PackageFromUrl.ps1`

#### Remote-Software
- `Get-InstalledSoftware.ps1`
- `Find-InstalledSoftware.ps1`
- `Uninstall-Software.ps1`

#### Roles-And-Features
- `Enable-NetFx3.ps1`

### Storage
Storage & quota management.

#### FSRM
- `Set-FSRMQuotaFromCSV.ps1`
- `Get-FSRMQuotaHealthReport.ps1`

---

## 🚀 Quick examples

```powershell
.\Networking\Connections\Find-WhoUsesPort.ps1 -Port 445
.\Networking\Connections\Get-NetstatSnapshot.ps1 -Seconds 30 -Interval 2
.\File-Server-Management\Get-SmbOpenFilesReport.ps1 -ComputerName FS01
.\Print-Server-Management\Restart-PrintSpooler.ps1 -ComputerName PRINT01
.\Software-Deployment\Remote-Software\Get-InstalledSoftware.ps1 -ComputerName PC-123
.\Patch-Management\Get-PendingRebootReport.ps1 -ComputerName SRV01
```

---

## 🧱 Standards

- Consistent parameters  
- `-WhatIf` safety  
- Usable output objects  
- Evidence-ready logging (WIP)  
- No hardcoded credentials  

---

## 🧩 Roadmap

- Full Joiner–Mover–Leaver automation  
- Workstation triage pack  
- Storage + disk space intelligence  
- Core module for logging + config  
- Naming + CI standards (PSScriptAnalyzer + Pester)

---

## 🧾 License

MIT. Test in non-production first.
