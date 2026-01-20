<#
.SYNOPSIS
Gathers extensive inventory details (hardware, OS, network, security, logged-on user) from computers.
#>
param (
    [string[]]$ComputerName,
    [string]$AdOuPath, # Optional: Search an Active Directory OU for computer names
    [string]$ExportPath
)

if (-not $ComputerName -and -not $AdOuPath) {
    $ComputerName = Read-Host "Enter a comma-separated list of computer names or an AD OU path"
    if ($ComputerName -match "^(?:OU|CN)=.*,DC=.*") {
        $AdOuPath = $ComputerName
        $ComputerName = $null
    }
    else {
        $ComputerName = $ComputerName.Split(',')
    }
}

if ($AdOuPath) {
    try {
        $AdComputers = Get-ADComputer -Filter * -SearchBase $AdOuPath -ErrorAction Stop | Select-Object -ExpandProperty Name
        $ComputerName = if ($ComputerName) { $ComputerName + $AdComputers } else { $AdComputers }
    }
    catch {
        Write-Error "Failed to retrieve computers from AD OU '$AdOuPath': $($_.Exception.Message)"
        return
    }
}
if (-not $ComputerName) {
    Write-Warning "No computer names provided or found."
    return
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Collecting inventory from $Computer..."
    try {
        Invoke-Command -ComputerName $Computer -ScriptBlock {
            # --- OS Info ---
            $Os = Get-CimInstance -ClassName Win32_OperatingSystem
            $Bios = Get-CimInstance -ClassName Win32_BIOS
            $ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
            $Processor = Get-CimInstance -ClassName Win32_Processor
            $Ram = (Get-CimInstance -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB
            $Disks = Get-CimInstance -ClassName Win32_LogicalDisk | Select-Object DeviceID, @{N="SizeGB";E={[math]::Round($_.Size / 1GB, 2)}}, @{N="FreeSpaceGB";E={[math]::Round($_.FreeSpace / 1GB, 2)}}

            # --- Network Info ---
            $IPs = (Get-NetIPAddress | Where-Object { $_.AddressFamily -eq 'IPv4' -and $_.InterfaceAlias -notlike 'Loopback*' }).IPAddress -join ", "

            # --- Logged-on User ---
            $LoggedOnUser = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName
            
            # --- Pending Reboot ---
            $PendingReboot = $false
            if (Test-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations") { $PendingReboot = $true }
            if (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") { $PendingReboot = $true }

            # --- BitLocker Status ---
            $BitLocker = Get-BitLockerVolume | Select-Object MountPoint, ProtectionStatus -ErrorAction SilentlyContinue

            # --- TPM Status ---
            $Tpm = Get-Tpm -ErrorAction SilentlyContinue

            # --- Secure Boot ---
            $SecureBoot = (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue)

            # --- Defender Status ---
            $DefenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
            
            [PSCustomObject]@{
                ComputerName    = $using:Computer
                OS              = $Os.Caption
                OSArchitecture  = $Os.OSArchitecture
                Model           = $ComputerSystem.Model
                Manufacturer    = $ComputerSystem.Manufacturer
                SerialNumber    = $Bios.SerialNumber
                RAMGB           = [math]::Round($Ram, 2)
                Disks           = ($Disks | ConvertTo-Json -Compress)
                IPAddresses     = $IPs
                LoggedOnUser    = $LoggedOnUser
                LastBootTime    = $Os.LastBootUpTime
                PendingReboot   = $PendingReboot
                BitLockerStatus = ($BitLocker | ForEach-Object { "$($_.MountPoint):$($_.ProtectionStatus)" }) -join "; "
                TPMEnabled      = if ($Tpm) { $Tpm.TpmPresent } else { "N/A" }
                SecureBootEnabled = $SecureBoot
                DefenderRTP     = if ($DefenderStatus) { $DefenderStatus.RealTimeProtectionEnabled } else { "N/A" }
                DefenderSignatures = if ($DefenderStatus) { $DefenderStatus.AntivirusSignatureVersion } else { "N/A" }
            }
        } -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to collect inventory from '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName    = $Computer
            OS              = "Error"
            OSArchitecture  = "Error"
            Model           = "Error"
            Manufacturer    = "Error"
            SerialNumber    = "Error"
            RAMGB           = "Error"
            Disks           = "Error"
            IPAddresses     = "Error"
            LoggedOnUser    = "Error"
            LastBootTime    = "Error"
            PendingReboot   = "Error"
            BitLockerStatus = "Error"
            TPMEnabled      = "Error"
            SecureBootEnabled = "Error"
            DefenderRTP     = "Error"
            DefenderSignatures = "Error"
            Error           = $_.Exception.Message
        }
    }
}

if ($ExportPath) {
    if ($ExportPath.EndsWith(".csv")) {
        $Result | Export-Csv -Path $ExportPath -NoTypeInformation
    }
    elseif ($ExportPath.EndsWith(".html")) {
        $Result | ConvertTo-Html | Out-File -Path $ExportPath
    }
    else {
        Write-Warning "Invalid export path. Please specify a .csv or .html file."
    }
}
else {
    $Result | Format-Table -AutoSize
}
