# 🛠️ SysAdmin PowerShell Toolkit

A curated collection of PowerShell and batch scripts for modern system administration. This toolkit has been reorganized and updated for 2026, providing a clean, logical structure for managing various aspects of your IT infrastructure.

---

## 📁 Folder Breakdown

### 🔹 ActiveDirectory
Scripts for managing Active Directory.
- `Disabled Users.ps1` – Lists all disabled user accounts in Active Directory.
- `Enabled Users.ps1` – Lists all enabled user accounts in Active Directory.
- `Get-ADGroupMember.ps1` – Retrieves a list of members from a specified Active Directory group.

---

### 🔹 Backup
Scripts for managing backups.
- `Get-BEJobHistory.ps1` – Retrieves the job history from Backup Exec.

---

### 🔹 Desktop
Scripts for managing desktop environments.
- `CheckUsers(QWINSTA).bat` – Displays logged-in users on a terminal server.
- `Get-RemoteNetworkDrives.ps1` – Shows mapped network drives on a remote computer.
- `remote_GPUPDATE.bat` – Forces a remote Group Policy update on a computer.

---

### 🔹 Deployment
Scripts for software and system deployment.
- `enableNET35.bat` – Enables .NET Framework 3.5 on Windows using DISM.
- `importschedule.xml` – An example XML file for use with ManageEngine.
- `SelfScan_Deployment.ps1` – A script for deploying the ManageEngine Self-Scan utility.

---

### 🔹 Monitoring
Scripts for system monitoring and health checks.
- `5Newestevents.ps1` – Retrieves the five newest events from a specified event log.
- `Example.ps1` – An example script for performing server health checks.

---

### 🔹 Networking
Scripts for network diagnostics and management.
- `Test-Connection.ps1` – A simple script to test network connectivity to one or more computers.
- `FTP.ps1` – A script for automating FTP file transfers.
  > **Note:** Requires editing the script to include the FTP server, username, and password.

---

### 🔹 Office365
Scripts for managing Microsoft Office 365.
- `Get-MessageTrace.ps1` – Traces email messages in Office 365.

---

### 🔹 Security
Scripts for managing system security.
- `SetLocalPWPolicy.ps1` – Sets the local password policy on a computer.

---

### 🔹 Server
Scripts for managing servers.
- `Logoff Remote User from TS Session.ps1` – Logs off a user from a remote desktop session.

---

### 🔹 WSUS
Scripts for managing Windows Server Update Services (WSUS).
- `Server_Report.PS1` – Generates a report of WSUS server activity.

---

## ⚙️ Usage

- The scripts in this toolkit are designed to be run manually or as scheduled tasks.
- Many of the scripts require administrative privileges to run correctly.
- Please review each script before use to ensure it is compatible with your environment.

---

## 🧾 License

This project is licensed under the MIT License. Use at your own risk.