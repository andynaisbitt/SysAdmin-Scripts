<#
.SYNOPSIS
Checks for pending reboots on one or more computers using various methods.
#>
param (
    [string[]]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Checking for pending reboot on $Computer..."
    try {
        Invoke-Command -ComputerName $Computer -ScriptBlock {
            $PendingReboot = $false
            $Reasons = @()

            # Registry Check 1: PendingFileRenameOperations
            if (Test-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations") {
                $PendingReboot = $true
                $Reasons += "PendingFileRenameOperations"
            }

            # Registry Check 2: WindowsUpdate\RebootRequired
            if (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
                $PendingReboot = $true
                $Reasons += "WindowsUpdate_RebootRequired"
            }

            # Registry Check 3: Component-Based Servicing (CBS)
            if (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
                $PendingReboot = $true
                $Reasons += "ComponentBasedServicing_RebootPending"
            }

            # Windows Update Agent API (requires COM object)
            try {
                $WUSession = New-Object -ComObject "Microsoft.Update.Session"
                $WUInstaller = $WUSession.CreateUpdateInstaller()
                if ($WUInstaller.RebootRequired) {
                    $PendingReboot = $true
                    $Reasons += "WindowsUpdateAgent_RebootRequired"
                }
            }
            catch {
                Write-Verbose "Could not check Windows Update Agent API for reboot status: $($_.Exception.Message)"
            }

            # SCCM Client Check (if installed)
            try {
                $CcmClient = Get-WmiObject -Namespace "root\ccm\ClientSDK" -Class "CCM_ClientUtilities" -ErrorAction SilentlyContinue
                if ($CcmClient) {
                    $RebootStatus = $CcmClient.GetRebootStatus()
                    if ($RebootStatus.RebootRequired -eq $true) {
                        $PendingReboot = $true
                        $Reasons += "SCCM_RebootRequired"
                    }
                }
            }
            catch {
                Write-Verbose "Could not check SCCM client for reboot status: $($_.Exception.Message)"
            }

            [PSCustomObject]@{
                ComputerName  = $using:Computer
                PendingReboot = $PendingReboot
                Reasons       = ($Reasons -join ", ")
            }
        } -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to check for pending reboot on '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName  = $Computer
            PendingReboot = "Error"
            Reasons       = $_.Exception.Message
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
