<#
.SYNOPSIS
Reports on Windows Defender Antivirus status, signature versions, and Tamper Protection settings.
#>
param (
    [string[]]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Checking Windows Defender status on $Computer..."
    try {
        Invoke-Command -ComputerName $Computer -ScriptBlock {
            $MpStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
            $MpPreference = Get-MpPreference -ErrorAction SilentlyContinue

            [PSCustomObject]@{
                ComputerName            = $using:Computer
                AntivirusEnabled        = if ($MpStatus) { $MpStatus.AntivirusEnabled } else { "N/A" }
                RtpEnabled              = if ($MpStatus) { $MpStatus.RealTimeProtectionEnabled } else { "N/A" }
                AntivirusSignatureVersion = if ($MpStatus) { $MpStatus.AntivirusSignatureVersion } else { "N/A" }
                AntispywareSignatureVersion = if ($MpStatus) { $MpStatus.AntispywareSignatureVersion } else { "N/A" }
                TamperProtection        = if ($MpPreference) { $MpPreference.TamperProtection } else { "N/A" }
                LastFullScanDateTime    = if ($MpStatus) { $MpStatus.LastFullScanDateTime } else { "N/A" }
                LastQuickScanDateTime   = if ($MpStatus) { $MpStatus.LastQuickScanDateTime } else { "N/A" }
            }
        } -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to get Windows Defender status from '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName            = $Computer
            AntivirusEnabled        = "Error"
            RtpEnabled              = "Error"
            AntivirusSignatureVersion = "Error"
            AntispywareSignatureVersion = "Error"
            TamperProtection        = "Error"
            LastFullScanDateTime    = "Error"
            LastQuickScanDateTime   = "Error"
            Error                   = $_.Exception.Message
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
