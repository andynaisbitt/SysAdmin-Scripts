<#
.SYNOPSIS
Compares two JSON snapshots of Windows hardening settings and reports any drift, including a risk assessment.
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
            $Status = switch ($_.SideIndicator) {
                "<=" { "Removed" } # Present in baseline, not in current
                "=>" { "Added" }   # Present in current, not in baseline
                Default { "Changed" } # Value is different
            }

            $Risk = "None" # Default risk

            # --- Risk Assessment Logic ---
            switch ($PropertyName) {
                "SMBv1ClientEnabled" { if ($CurrentValue -eq $true) { $Risk = "High (SMBv1 Client Enabled)" } }
                "SMBv1ServerEnabled" { if ($CurrentValue -eq $true) { $Risk = "Critical (SMBv1 Server Enabled)" } }
                "LLMNREnabled"       { if ($CurrentValue -eq $true) { $Risk = "Medium (LLMNR Enabled)" } }
                "TLS10ClientEnabled" { if ($CurrentValue -eq $true) { $Risk = "Medium (TLS 1.0 Client Enabled)" } }
                "TLS10ServerEnabled" { if ($CurrentValue -eq $true) { $Risk = "High (TLS 1.0 Server Enabled)" } }
                # Add more risk assessments as needed for other settings
            }


            [PSCustomObject]@{
                Setting       = $PropertyName
                Status        = $Status
                BaselineValue = $BaselineValue
                CurrentValue  = $CurrentValue
                Risk          = $Risk
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
