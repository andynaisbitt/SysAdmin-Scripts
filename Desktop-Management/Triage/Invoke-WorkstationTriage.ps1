<#
.SYNOPSIS
Collects a comprehensive set of triage information from a workstation and saves it to a zip file.
#>
param (
    [string]$ComputerName,
    [string]$DestinationPath
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the computer name of the workstation to triage"
}
if (-not $DestinationPath) {
    $DestinationPath = Read-Host "Enter the local path to save the zipped triage results"
}
if (-not (Test-Path -Path $DestinationPath)) {
    New-Item -Path $DestinationPath -ItemType Directory -Force
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$TempDir = Join-Path -Path $env:TEMP -ChildPath "Triage-$ComputerName-$Timestamp"
New-Item -Path $TempDir -ItemType Directory -Force

Write-Host "Starting workstation triage on '$ComputerName'..."
Write-Host "Temporary results will be stored in: $TempDir"

try {
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # --- Logged-on User ---
        $LoggedOnUser = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty UserName
        
        # --- Uptime ---
        $Uptime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
        
        # --- Disk Free ---
        $DiskFree = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object DeviceID, @{N="FreeSpaceGB";E={[math]::Round($_.FreeSpace / 1GB, 2)}}, @{N="SizeGB";E={[math]::Round($_.Size / 1GB, 2)}}

        # --- Top CPU Processes ---
        $TopCpuProcesses = Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 10 | Select-Object Id, ProcessName, CPU

        # --- Pending Reboot ---
        $PendingReboot = Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations" -or Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"

        # --- Windows Update Status ---
        $WUStatus = Get-WmiObject -Class Win32_QuickFixEngineering | Sort-Object -Property InstalledOn -Descending | Select-Object -First 5

        # --- BitLocker Status ---
        $BitLockerStatus = Get-BitLockerVolume | Select-Object MountPoint, VolumeStatus, ProtectionStatus

        # --- Network Adapters ---
        $NetworkAdapters = Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, MacAddress, @{N="IPAddress";E={ (Get-NetIPAddress -InterfaceIndex $_.ifIndex).IPAddress }}

        # --- Last 50 Critical Events ---
        $CriticalEvents = Get-WinEvent -FilterHashtable @{LogName='System','Application';Level=1,2} -MaxEvents 50

        # --- Export to temp files ---
        $LoggedOnUser | Out-File -FilePath (Join-Path $using:TempDir "LoggedOnUser.txt")
        $Uptime | Out-File -FilePath (Join-Path $using:TempDir "Uptime.txt")
        $DiskFree | Out-File -FilePath (Join-Path $using:TempDir "DiskFree.txt")
        $TopCpuProcesses | Out-File -FilePath (Join-Path $using:TempDir "TopCpuProcesses.txt")
        "Pending Reboot: $PendingReboot" | Out-File -FilePath (Join-Path $using:TempDir "PendingReboot.txt")
        $WUStatus | Out-File -FilePath (Join-Path $using:TempDir "WindowsUpdateStatus.txt")
        $BitLockerStatus | Out-File -FilePath (Join-Path $using:TempDir "BitLockerStatus.txt")
        $NetworkAdapters | Out-File -FilePath (Join-Path $using:TempDir "NetworkAdapters.txt")
        $CriticalEvents | Export-Clixml -Path (Join-Path $using:TempDir "CriticalEvents.xml")

        Write-Host "Triage data collected on '$($env:COMPUTERNAME)'."
    } -ErrorAction Stop

    # --- Zip and move results ---
    $ZipFilePath = Join-Path -Path $DestinationPath -ChildPath "TriageResults-$ComputerName-$Timestamp.zip"
    Compress-Archive -Path "$TempDir\*" -DestinationPath $ZipFilePath -Force
    Write-Host "Triage results zipped and saved to '$ZipFilePath'."

}
catch {
    Write-Error "An error occurred during workstation triage on '$ComputerName': $($_.Exception.Message)"
}
finally {
    # --- Clean up temporary directory ---
    if (Test-Path -Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force
        Write-Verbose "Temporary directory '$TempDir' cleaned up."
    }
}
