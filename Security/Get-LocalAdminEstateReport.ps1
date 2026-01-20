<#
.SYNOPSIS
Generates an estate-wide report of local administrator group members, comparing them against a baseline allowlist to detect drift.
#>
param (
    [string[]]$ComputerName,     # Optional: Direct computer names
    [string]$AdOuPath,           # Optional: AD OU path to retrieve computer names
    [string]$AllowListCsvPath,   # Path to a CSV containing the allowed local admin members
    [string]$ExportPath
)

# --- Load Core Get-Targets.ps1 ---
. (Join-Path -Path $PSScriptRoot -ChildPath "..\Core\Get-Targets.ps1")

try {
    $TargetComputers = Get-Targets -ComputerName $ComputerName -AdOuPath $AdOuPath

    if (-not $TargetComputers) {
        Write-Warning "No target computers provided or found. Exiting."
        return
    }

    if (-not (Test-Path -Path $AllowListCsvPath)) {
        Write-Error "AllowList CSV file not found at: $AllowListCsvPath"
        return
    }
    $AllowList = Import-Csv -Path $AllowListCsvPath

    Write-Host "Running Get-LocalAdminReport.ps1 across $($TargetComputers.Count) computers..."
    # Path to the core Get-LocalAdminReport.ps1 script
    $LocalAdminReportScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Get-LocalAdminReport.ps1"

    if (-not (Test-Path -Path $LocalAdminReportScriptPath)) {
        Write-Error "The core Get-LocalAdminReport.ps1 script was not found at '$LocalAdminReportScriptPath'."
        return
    }

    $AllLocalAdmins = & $LocalAdminReportScriptPath -ComputerName $TargetComputers -ErrorAction Stop

    $DriftResults = @()
    foreach ($AdminEntry in $AllLocalAdmins) {
        $IsAllowed = $AllowList | Where-Object {
            ($_.ComputerName -eq $AdminEntry.ComputerName -or $_.ComputerName -eq "*") -and
            ($_.MemberName -eq $AdminEntry.MemberName -or $_.MemberName -eq "*") -and
            ($_.SID -eq $AdminEntry.SID -or $_.SID -eq "*") # Compare by SID for better accuracy
        }
        
        if (-not $IsAllowed) {
            $DriftResults += [PSCustomObject]@{
                ComputerName = $AdminEntry.ComputerName
                MemberName   = $AdminEntry.MemberName
                SID          = $AdminEntry.SID
                Domain       = $AdminEntry.Domain
                Status       = "Not in AllowList (Drift Detected)"
            }
        }
    }

    if ($DriftResults) {
        Write-Host "Drift detected in local administrators:"
        $DriftResults | Format-Table -AutoSize
    }
    else {
        Write-Host "No local administrator drift detected against the allowlist."
    }

    if ($ExportPath) {
        if ($ExportPath.EndsWith(".csv")) {
            $DriftResults | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        elseif ($ExportPath.EndsWith(".html")) {
            $DriftResults | ConvertTo-Html | Out-File -Path $ExportPath
        }
        else {
            Write-Warning "Invalid export path. Please specify a .csv or .html file."
        }
    }
    else {
        $DriftResults | Format-Table -AutoSize
    }
}
catch {
    Write-Error "An error occurred during local administrator estate report generation: $($_.Exception.Message)"
}
