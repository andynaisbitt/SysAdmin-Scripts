<#
.SYNOPSIS
Exports local Administrators group membership, flags unknown accounts, and checks LAPS status for Cyber Essentials compliance.
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
    # Path to Get-LocalAdminReport.ps1 and Get-LAPSStatus.ps1
    $LocalAdminReportScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Security\Get-LocalAdminReport.ps1"
    $LapsStatusScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Security\Get-LAPSStatus.ps1"

    if (-not (Test-Path -Path $LocalAdminReportScriptPath)) {
        Write-Error "Get-LocalAdminReport.ps1 script not found at $LocalAdminReportScriptPath."
        return
    }
    if (-not (Test-Path -Path $LapsStatusScriptPath)) {
        Write-Error "Get-LAPSStatus.ps1 script not found at $LapsStatusScriptPath."
        return
    }

    # Get local admin report (includes SID resolution)
    $LocalAdminReport = & $LocalAdminReportScriptPath -ComputerName $TargetComputers -ErrorAction Stop

    # Get LAPS Status
    $LapsStatusReport = & $LapsStatusScriptPath -ComputerName $TargetComputers -ErrorAction Stop

    foreach ($Computer in $TargetComputers) {
        $AdminsOnComputer = $LocalAdminReport | Where-Object { $_.ComputerName -eq $Computer }
        $LapsOnComputer = $LapsStatusReport | Where-Object { $_.ComputerName -eq $Computer }

        foreach ($Admin in $AdminsOnComputer) {
            $IsKnown = "Yes"
            $IsActiveDirectory = "No"
            $IsPrivileged = "No"
            $LapsConfigured = "N/A" # From the combined LAPS report

            if ($Admin.Domain -eq $Computer -or $Admin.Domain -eq $env:COMPUTERNAME) { # Local account
                # Check if it's a well-known local account like Administrator
                if ($Admin.MemberName -eq "Administrator") {
                    $IsKnown = "Yes (Built-in)"
                }
                else {
                    # For local accounts, "known" is harder without a baseline, assume unknown if not built-in
                    $IsKnown = "No (Local Unknown)"
                }
            }
            elseif ($Admin.Domain -ne "N/A" -and $Admin.Domain -ne $Computer) { # Domain account
                $IsActiveDirectory = "Yes"
                # Check if it's a privileged group (e.g., Domain Admins in the local Administrators)
                if (($Admin.MemberName -like "*Domain Admins*" -or $Admin.MemberName -like "*Enterprise Admins*") -and $Admin.SID -ne "N/A") {
                    $IsPrivileged = "Yes"
                }
            }

            # Map LAPS status
            $LapsStatus = $LapsOnComputer | Select-Object -ExpandProperty WindowsLAPS.EnabledViaPolicy
            if ($LapsStatus -ne $null) {
                $LapsConfigured = if ($LapsStatus -eq $true) { "Yes (Windows LAPS)" } else { "No (Windows LAPS)" }
            } else {
                $LapsStatus = $LapsOnComputer | Select-Object -ExpandProperty LegacyLAPS.Installed
                if ($LapsStatus -ne $null) {
                    $LapsConfigured = if ($LapsStatus -eq $true) { "Yes (Legacy LAPS)" } else { "No (Legacy LAPS)" }
                }
            }

            $Result += [PSCustomObject]@{
                ComputerName      = $Computer
                MemberName        = $Admin.MemberName
                MemberDomain      = $Admin.Domain
                MemberSID         = $Admin.SID
                IsActiveDirectory = $IsActiveDirectory
                IsKnownAccount    = $IsKnown
                IsPrivilegedGroup = $IsPrivileged
                LAPSConfigured    = $LapsConfigured
            }
        }
    }

    if ($ExportPath) {
        $Result | Export-Csv -Path $ExportPath -NoTypeInformation
        Write-Host "Local Admin Control Report saved to $ExportPath."
    }
    else {
        $Result | Format-Table -AutoSize
    }
}
catch {
    Write-Error "An error occurred during local admin control report generation: $($_.Exception.Message)"
}
