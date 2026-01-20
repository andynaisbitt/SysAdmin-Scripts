<#
.SYNOPSIS
Retrieves server uptime, last reboot reasons, and pending reboot flags.
#>
param (
    [string[]]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Checking uptime and reboot history on $Computer..."
    try {
        Invoke-Command -ComputerName $Computer -ScriptBlock {
            # Uptime
            $LastBootUpTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
            $CurrentUptime = (Get-Date) - $LastBootUpTime

            # Last Reboot Reason (Event ID 1074 for planned shutdowns/reboots)
            # You might also look for Event ID 6006 (clean shutdown) and 6008 (unexpected shutdown)
            $LastRebootEvent = Get-WinEvent -ComputerName $using:Computer -FilterHashtable @{
                LogName   = 'System'
                Id        = 1074 # System shutdown/restart
                StartTime = (Get-Date).AddDays(-30) # Last 30 days
            } -ErrorAction SilentlyContinue | Sort-Object TimeCreated -Descending | Select-Object -First 1

            $RebootReason = if ($LastRebootEvent) {
                "User: $($LastRebootEvent.Properties[6].Value); Reason: $($LastRebootEvent.Properties[0].Value); Comment: $($LastRebootEvent.Properties[7].Value)"
            }
            else {
                "No recent planned reboot event (1074) found."
            }

            # Pending Reboot (reusing logic from Get-PendingRebootReport.ps1)
            $PendingReboot = $false
            $RebootReasons = @()

            if (Test-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations") {
                $PendingReboot = $true
                $RebootReasons += "PendingFileRenameOperations"
            }
            if (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
                $PendingReboot = $true
                $RebootReasons += "WindowsUpdate_RebootRequired"
            }
            if (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
                $PendingReboot = $true
                $RebootReasons += "ComponentBasedServicing_RebootPending"
            }

            try {
                $WUSession = New-Object -ComObject "Microsoft.Update.Session"
                $WUInstaller = $WUSession.CreateUpdateInstaller()
                if ($WUInstaller.RebootRequired) {
                    $PendingReboot = $true
                    $RebootReasons += "WindowsUpdateAgent_RebootRequired"
                }
            }
            catch {} # Suppress errors if COM object not available

            [PSCustomObject]@{
                ComputerName = $using:Computer
                Uptime       = $CurrentUptime.ToString("dd\.hh\:mm\:ss") # Format as DD.HH:MM:SS
                LastBootUpTime = $LastBootUpTime
                LastRebootReason = $RebootReason
                PendingReboot = $PendingReboot
                PendingRebootReasons = ($RebootReasons -join ", ")
            }
        } -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to get uptime and reboot history from '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName = $Computer
            Uptime       = "Error"
            LastBootUpTime = "Error"
            LastRebootReason = "Error"
            PendingReboot = "Error"
            PendingRebootReasons = "Error"
            Error        = $_.Exception.Message
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
