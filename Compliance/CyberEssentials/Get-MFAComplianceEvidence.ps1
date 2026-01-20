<#
.SYNOPSIS
Wraps Get-MFAStatusReport.ps1 to produce a summary of MFA compliance, including user percentages and exceptions.
#>
param (
    [string]$OutputFolder = (Join-Path $PSScriptRoot "..\..\Output\Compliance\CyberEssentials"),
    [string]$ExportFileName = "MFAComplianceReport.csv"
)

# --- Load Core Export-Report.ps1 ---
. (Join-Path -Path $PSScriptRoot -ChildPath "..\..\Core\Export-Report.ps1")

try {
    Write-Host "Collecting MFA status report..."
    # Path to Get-MFAStatusReport.ps1
    $MfaReportScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Office365\Get-MFAStatusReport.ps1"

    if (-not (Test-Path -Path $MfaReportScriptPath)) {
        Write-Error "Get-MFAStatusReport.ps1 script not found at $MfaReportScriptPath."
        return
    }

    $MfaStatusReport = & $MfaReportScriptPath -ErrorAction Stop

    $TotalUsers = $MfaStatusReport.Count
    $MfaEnabledUsers = ($MfaStatusReport | Where-Object { $_.MfaRegistered -eq "Yes" }).Count
    $MfaDisabledUsers = $TotalUsers - $MfaEnabledUsers
    $MfaEnabledPercentage = if ($TotalUsers -gt 0) { [math]::Round(($MfaEnabledUsers / $TotalUsers) * 100, 2) } else { 0 }

    $ExceptionsList = $MfaStatusReport | Where-Object { $_.MfaRegistered -eq "No" } | Select-Object DisplayName, UserPrincipalName, MfaMethods, LastSignIn

    $Summary = [PSCustomObject]@{
        TotalUsers           = $TotalUsers
        MFAEnabledUsers      = $MfaEnabledUsers
        MFADisabledUsers     = $MfaDisabledUsers
        MFAEnabledPercentage = "$MfaEnabledPercentage%"
        ExceptionsCount      = $ExceptionsList.Count
    }

    # Ensure output folder exists
    if (-not (Test-Path -Path $OutputFolder)) {
        New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
    }

    $SummaryCsvPath = Join-Path -Path $OutputFolder -ChildPath "MFAComplianceSummary.csv"
    $ExceptionsCsvPath = Join-Path -Path $OutputFolder -ChildPath "MFAComplianceExceptions.csv"
    $SummaryHtmlPath = Join-Path -Path $OutputFolder -ChildPath "MFAComplianceReport.html"

    # Export summary and exceptions
    $Summary | Export-Csv -Path $SummaryCsvPath -NoTypeInformation -Force
    if ($ExceptionsList.Count -gt 0) {
        $ExceptionsList | Export-Csv -Path $ExceptionsCsvPath -NoTypeInformation -Force
    }

    # Generate HTML report
    $HtmlBody = "<p><strong>MFA Compliance Summary:</strong></p>"
    $HtmlBody += ($Summary | ConvertTo-Html -Fragment)
    $HtmlBody += "<p><strong>MFA Exceptions (Users without MFA):</strong></p>"
    if ($ExceptionsList.Count -gt 0) {
        $HtmlBody += ($ExceptionsList | ConvertTo-Html -Fragment)
    } else {
        $HtmlBody += "<p>No MFA exceptions found.</p>"
    }

    "<h1>MFA Compliance Report</h1>$HtmlBody" | Out-File -FilePath $SummaryHtmlPath -Force

    Write-Host "MFA Compliance Report exported to $OutputFolder."
}
catch {
    Write-Error "An error occurred during MFA compliance evidence generation: $($_.Exception.Message)"
}
