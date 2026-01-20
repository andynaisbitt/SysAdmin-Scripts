<#
.SYNOPSIS
Generates a report on FSRM quota health, highlighting quotas over their threshold.
#>
param (
    [string]$ExportPath
)

try {
    $Quotas = Get-FsrmQuota | Where-Object { $_.Usage -gt $_.Size } # Filter for quotas over limit

    if ($Quotas) {
        $Result = foreach ($Quota in $Quotas) {
            [PSCustomObject]@{
                Path          = $Quota.Path
                QuotaSizeGB   = [math]::Round($Quota.Size / 1GB, 2)
                QuotaUsageGB  = [math]::Round($Quota.Usage / 1GB, 2)
                PercentUsed   = [math]::Round(($Quota.Usage / $Quota.Size) * 100, 2)
                Thresholds    = ($Quota.Threshold | ForEach-Object { "$($_.Percent)% - $($_.Type)" }) -join "; "
                OverThreshold = "Yes"
            }
        }
    }
    else {
        Write-Host "No FSRM quotas are currently over their limit."
        $Result = @() # Return an empty array if no quotas are over limit
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
        $Result
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
