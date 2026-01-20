<#
.SYNOPSIS
Compares two JSON snapshots of Windows hardening settings and reports any drift.
#>
param (
    [string]$BaselineSnapshotPath,
    [string]$CurrentSnapshotPath,
    [string]$ExportPath
)

if (-not $BaselineSnapshotPath) {
    $BaselineSnapshotPath = Read-Host "Enter the path to the baseline JSON snapshot file"
}
if (-not $CurrentSnapshotPath) {
    $CurrentSnapshotPath = Read-Host "Enter the path to the current JSON snapshot file"
}

if (-not (Test-Path -Path $BaselineSnapshotPath)) {
    Write-Error "Baseline snapshot file not found at: $BaselineSnapshotPath"
    return
}
if (-not (Test-Path -Path $CurrentSnapshotPath)) {
    Write-Error "Current snapshot file not found at: $CurrentSnapshotPath"
    return
}

try {
    $Baseline = Get-Content -Raw -Path $BaselineSnapshotPath | ConvertFrom-Json
    $Current = Get-Content -Raw -Path $CurrentSnapshotPath | ConvertFrom-Json

    $Differences = Compare-Object -ReferenceObject $Baseline.Settings.PSObject.Properties.Name -DifferenceObject $Current.Settings.PSObject.Properties.Name -IncludeEqual:$true | ForEach-Object {
        $PropertyName = $_.InputObject
        $BaselineValue = $Baseline.Settings.$PropertyName
        $CurrentValue = $Current.Settings.$PropertyName

        if ($BaselineValue -ne $CurrentValue) {
            [PSCustomObject]@{
                Setting      = $PropertyName
                BaselineValue = $BaselineValue
                CurrentValue  = $CurrentValue
                ComputerName  = $Current.ComputerName
                Timestamp     = $Current.Timestamp
            }
        }
    }

    if ($Differences) {
        Write-Host "Drift detected between hardening snapshots."
        $Differences | Format-Table -AutoSize
    }
    else {
        Write-Host "No drift detected between hardening snapshots."
    }

    if ($ExportPath) {
        if ($ExportPath.EndsWith(".csv")) {
            $Differences | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        elseif ($ExportPath.EndsWith(".html")) {
            $Differences | ConvertTo-Html | Out-File -Path $ExportPath
        }
        else {
            Write-Warning "Invalid export path. Please specify a .csv or .html file."
        }
    }
    else {
        $Differences | Format-Table -AutoSize
    }
}
catch {
    Write-Error "An error occurred while comparing hardening snapshots: $($_.Exception.Message)"
}
