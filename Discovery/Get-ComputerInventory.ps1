<#
.SYNOPSIS
Gathers extensive inventory details (hardware, OS, network, security, logged-on user) from computers.
#>
param (
    [string[]]$ComputerName,
    [string]$AdOuPath, # Optional: Search an Active Directory OU for computer names
    [string]$AdFilter = "*", # Optional: AD filter for Get-ADComputer (e.g., 'Name -like "PC*"')
    [string]$ExportPath
)

# --- Resolve Target Computers ---
$TargetComputers = @()

if ($ComputerName) {
    $TargetComputers += $ComputerName
}

if ($AdOuPath) {
    try {
        # Using -Filter with the AD filter provided by the user
        $AdComputers = Get-ADComputer -Filter $AdFilter -SearchBase $AdOuPath -ErrorAction Stop | Select-Object -ExpandProperty Name
        $TargetComputers += $AdComputers
    }
    catch {
        Write-Error "Failed to retrieve computers from AD OU '$AdOuPath' with filter '$AdFilter': $($_.Exception.Message)"
        return
    }
}
if (-not $TargetComputers) {
    Write-Warning "No computer names provided or found."
    return
}
$TargetComputers = $TargetComputers | Select-Object -Unique # Ensure unique computer names

$Result = foreach ($Computer in $TargetComputers) {
    Write-Verbose "Collecting inventory from $Computer..."
    try {
        Invoke-Command -ComputerName $Computer -ScriptBlock {
            # --- OS Info ---
            $Os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
            $Bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
            $ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
            $Processor = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue
            $Ram = (Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue | Measure-Object -Property Capacity -Sum).Sum / 1GB
            $Disks = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction SilentlyContinue | Select-Object DeviceID, @{N="SizeGB";E={[math]::Round($_.Size / 1GB, 2)}}, @{N="FreeSpaceGB";E={[math]::Round($_.FreeSpace / 1GB, 2)}}

            # --- Network Info ---
            $IPs = (Get-NetIPAddress -ErrorAction SilentlyContinue | Where-Object { $_.AddressFamily -eq 'IPv4' -and $_.InterfaceAlias -notlike 'Loopback*' }).IPAddress -join ", "

            # --- Logged-on User ---
            $LoggedOnUser = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
            
            # --- Pending Reboot (simplified) ---
            $PendingReboot = $false
            if (Test-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations" -ErrorAction SilentlyContinue) { $PendingReboot = $true }
            if (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue) { $PendingReboot = $true }

            # --- BitLocker Status ---
            $BitLocker = Get-BitLockerVolume -ErrorAction SilentlyContinue | Select-Object MountPoint, ProtectionStatus

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
                Disks           = ($Disks | ConvertTo-Json -Compress) # Export as JSON string
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
