# 🛠️ SysAdmin PowerShell Toolkit

A mixed bag of PowerShell and batch scripts collected over the years while working in system administration.

This isn't a polished product — just real tools that helped fix real problems on real systems (from XP and Server 2003 up to modern Windows and Office 365). Mostly PowerShell, with some batch files where needed.

Use what you need, tweak what you don’t. No guarantees — just useful stuff.

---

## 📁 Folder Breakdown

### 🔹 AD
Scripts related to Active Directory:
- `Disabled Users.ps1` – Lists disabled users in AD.
- `Enabled Users.ps1` – Lists enabled users in AD.
- `Get-ADGroupMember.ps1` – Gets members of a specified AD group.

---

### 🔹 BackupExec (📦 Archive-Worthy)
Old Symantec Backup Exec tool:
- `Get-BEJobHistory.ps1` – Pulls job history (archived for reference).

---

### 🔹 DISM
For enabling .NET on older systems:
- `DISMenableNET35.bat` – Enables .NET Framework 3.5 using DISM.

---

### 🔹 DesktopManagement
Older tools for managing desktops (XP/2003 days included):
- `CheckUsers(QWINSTA).bat` – Show logged-in users via Terminal Services.
- `remote_GPUPDATE.bat` – Push a remote Group Policy update.
- `RemoveGames.bat` – Script to remove Windows XP games.
- `Get-Services(SCQuery).bat` – Quick service check on Windows Server 2003.
- `Get-RemoteNetworkDrives.ps1` – Shows mapped drives on a remote machine.

---

### 🔹 EventVWR
Simple event viewer tools:
- `5NewestEvents.ps1` – Get the 5 most recent events from a specific log.

---

### 🔹 FileManagement
Copying tools:
- `Copy Folder contents` – Self-explanatory.
- `Copy file to Drives` – Handy for pushing a file to multiple drives.

---

### 🔹 GroupPolicy
Group Policy-related scripts:
- `SetLocalPWPolicy.ps1` – Set a local password policy via PowerShell.

---

### 🔹 ManageEngine
Used with ManageEngine software:
- `SelfScan_Deployment.ps1` – Tool for deploying the Self-Scan utility.

---

### 🔹 Networking
Network diagnostics:
- `Test-Connection.ps1` – Simple ping tool.
- `FTP.ps1` – FTP file upload/download automation.
  > Requires editing `$ftp`, `$user`, `$pass`  
  > Currently set to *download* from FTP.

---

### 🔹 Office365
Cloud email tools:
- `Get-MessageTrace.ps1` – Message trace tool for O365 email delivery.

---

### 🔹 Remote Desktop Services
Remote session management:
- `Logoff Remote User from TS Session.ps1` – Kill remote TS/RDS user sessions.

---

### 🔹 Server Health Check
General server check templates:
- `Example1.ps1` – Base script for health checks (edit to match your needs).

---

### 🔹 WSUS
Windows Server Update Services:
- `Server_Report.ps1` – Pulls basic WSUS reporting (details vary).

---

## ⚙️ Usage

- These scripts are meant to be run manually or scheduled as needed.
- Some may require admin privileges.
- Many are written for on-prem environments or legacy systems.

> 🧠 Always review a script before running — a few assume certain environments or folder structures.

---

## 📎 Notes

- Some batch files are from XP/2003 days — kept for reference or specific edge cases.
- Most scripts have little to no logging — just output to the console.
- Feel free to clean up, modernize, or fork into a more structured toolkit.

---

## 🧾 License

Use at your own risk. Provided as-is under the MIT License.
