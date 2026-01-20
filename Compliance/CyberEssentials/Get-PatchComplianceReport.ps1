<#
.SYNOPSIS
Reports on patch compliance status per machine, combining Windows Update status and pending reboot information.
#>
param (
    [string[]]$ComputerName,
    [string]$AdOuPath,
    [string]$ExportPath
)

# --- Load Core Get-Targets.ps1 ---
. (Join-Path -Path $PSScriptRoot -ChildPath "..\..\Core\Get-Targets.ps1")

try {
    $TargetComputers = Get-Targets -ComputerName $ComputerName -AdOuPath $AdOuPath
    if (-not $TargetComputers) {
        Write-Warning "No target computers found for checks. Exiting."
        return
    }

    $Result = @()
    # Paths to required scripts
    $WindowsUpdateStatusScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Patch-Management\Get-WindowsUpdateStatus.ps1"
    $PendingRebootScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Patch-Management\Get-PendingRebootReport.ps1"

    if (-not (Test-Path -Path $WindowsUpdateStatusScriptPath)) {
        Write-Error "Get-WindowsUpdateStatus.ps1 script not found at $WindowsUpdateStatusScriptPath."
        return
    }
    if (-not (Test-Path -Path $PendingRebootScriptPath)) {
        Write-Error "Get-PendingRebootReport.ps1 script not found at $PendingRebootScriptPath."
        return
    }

    # Get Windows Update Status
    $UpdateStatusReport = & $WindowsUpdateStatusScriptPath -ComputerName $TargetComputers -ErrorAction Stop

    # Get Pending Reboot Report
    $PendingRebootReport = & $PendingRebootScriptPath -ComputerName $TargetComputers -ErrorAction Stop

    foreach ($Computer in $TargetComputers) {
        $UpdateStatus = $UpdateStatusReport | Where-Object { $_.ComputerName -eq $Computer }
        $PendingReboot = $PendingRebootReport | Where-Object { $_.ComputerName -eq $Computer }

        $ComplianceStatus = "N/A"
        $ComplianceReason = @()

        if ($UpdateStatus.Error) {
            $ComplianceStatus = "Error"
            $ComplianceReason += "Update Status Error: $($UpdateStatus.Error)"
        }
        else {
            if ($PendingReboot.PendingReboot -eq $true) {
                $ComplianceStatus = "Reboot Pending"
                $ComplianceReason += "Reboot required: $($PendingReboot.Reasons)"
            }
            else {
                # This is a very basic check. A full check would involve actual missing updates.
                # For CE, "up-to-date" generally means within 14 days of release or 30 days of last install.
                if ($UpdateStatus.LastInstallDate -and ((Get-Date) - $UpdateStatus.LastInstallDate).Days -lt 30) {
                    $ComplianceStatus = "Up-to-date (Last install within 30 days)"
                }
                else {
                    $ComplianceStatus = "Missing Updates / Not Recent"
                    $ComplianceReason += "Last update install was on $($UpdateStatus.LastInstallDate). Consider running updates."
                }
            }
        }

        $Result += [PSCustomObject]@{
            ComputerName = $Computer
            LastInstallDate = $UpdateStatus.LastInstallDate
            PendingReboot = $PendingReboot.PendingReboot
            ComplianceStatus = $ComplianceStatus
            ComplianceReason = ($ComplianceReason -join "; ")
        }
    }

    if ($ExportPath) {
        if ($ExportPath.EndsWith(".csv")) {
            $Result | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        elseif ($ExportPath.EndsWith(".html")) {
            $Result | ConvertTo-Html -Title "Patch Compliance Report" | Out-File -Path $ExportPath
        }
        else {
            Write-Warning "Invalid export path. Please specify a .csv or .html file."
        }
    }
    else {
        $Result | Format-Table -AutoSize
    }
}
catch {
    Write-Error "An error occurred during patch compliance report generation: $($_.Exception.Message)"
}
