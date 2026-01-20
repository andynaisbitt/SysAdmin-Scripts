<#
.SYNOPSIS
Compares two sets of share permissions (e.g., before and after a migration) and reports the differences.
#>
param (
    [string]$BaselineCsvPath,
    [string]$CurrentCsvPath,
    [string]$ExportPath
)

if (-not $BaselineCsvPath) {
    $BaselineCsvPath = Read-Host "Enter the path to the baseline CSV file (e.g., before migration)"
}
if (-not $CurrentCsvPath) {
    $CurrentCsvPath = Read-Host "Enter the path to the current CSV file (e.g., after migration)"
}

if (-not (Test-Path -Path $BaselineCsvPath)) {
    Write-Error "Baseline CSV file not found at: $BaselineCsvPath"
    return
}
if (-not (Test-Path -Path $CurrentCsvPath)) {
    Write-Error "Current CSV file not found at: $CurrentCsvPath"
    return
}

try {
    $BaselinePermissions = Import-Csv -Path $BaselineCsvPath
    $CurrentPermissions = Import-Csv -Path $CurrentCsvPath

    $Differences = Compare-Object -ReferenceObject $BaselinePermissions -DifferenceObject $CurrentPermissions -Property ComputerName, ShareName, AccountName, AccessRight -IncludeEqual:$false

    $Result = @()
    foreach ($Diff in $Differences) {
        $Status = switch ($Diff.SideIndicator) {
            "<<" { "Removed" }
            ">>" { "Added" }
            Default { "Unknown" }
        }
        $Result += [PSCustomObject]@{
            ComputerName = $Diff.InputObject.ComputerName
            ShareName    = $Diff.InputObject.ShareName
            AccountName  = $Diff.InputObject.AccountName
            AccessRight  = $Diff.InputObject.AccessRight
            Status       = $Status
        }
    }

    if ($Result) {
        Write-Host "Differences found between baseline and current permissions."
        $Result | Format-Table -AutoSize
    }
    else {
        Write-Host "No differences found between baseline and current permissions."
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
}
catch {
    Write-Error "An error occurred while comparing share permissions: $($_.Exception.Message)"
}
