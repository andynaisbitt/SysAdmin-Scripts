<#
.SYNOPSIS
Provides a summary of WSUS client status, including reporting hierarchy, last contact, and update status.
#>
param (
    [string]$WsusServer = "localhost",
    [int]$Port = 8530,
    [bool]$UseSsl = $false,
    [string]$ExportPath
)

try {
    # Add the required assembly
    Add-Type -Path "$env:ProgramFiles\Update Services\Api\Microsoft.UpdateServices.Administration.dll" -ErrorAction Stop

    # Connect to the WSUS server
    $Wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($WsusServer, $UseSsl, $Port)

    # Get all computer targets
    $ComputerScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
    $Computers = $Wsus.GetComputerTargets($ComputerScope)

    $Result = foreach ($Computer in $Computers) {
        $UpdateSummary = $Computer.GetUpdateEventSummary()
        [PSCustomObject]@{
            ComputerName        = $Computer.FullDomainName
            LastReportedStatusTime = $Computer.LastReportedStatusTime
            LastSyncTime        = $Computer.LastSyncTime
            Group               = ($Computer.GetComputerTargetGroups() | Select-Object -ExpandProperty Name) -join ", "
            UpdatesInstalled    = $UpdateSummary.InstalledCount
            UpdatesNeeded       = $UpdateSummary.NeededCount
            UpdatesFailed       = $UpdateSummary.FailedCount
            UpdatesDownloaded   = $UpdateSummary.DownloadedCount
            UpdatesPendingReboot = $UpdateSummary.InstalledPendingRebootCount
            UpdatesNotApplicable = $UpdateSummary.NotApplicableCount
            UpdatesUnknown      = $UpdateSummary.UnknownCount
        }
    }

    if ($Result) {
        Write-Host "WSUS client status summary generated for $WsusServer. Found $($Result.Count) clients."
    }
    else {
        Write-Host "No WSUS clients found reporting to $WsusServer."
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
    Write-Error "An error occurred while getting WSUS client status summary: $($_.Exception.Message)"
}
