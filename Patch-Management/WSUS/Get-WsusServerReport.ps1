<#
.SYNOPSIS
Generates a report of a WSUS server's status.
#>
param (
    [string]$WsusServer = "localhost",
    [int]$Port = 8530,
    [bool]$UseSsl = $false
)

try {
    # Add the required assembly
    Add-Type -Path "$env:ProgramFiles\Update Services\Api\Microsoft.UpdateServices.Administration.dll"

    # Connect to the WSUS server
    $Wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($WsusServer, $UseSsl, $Port)

    # Get the server status
    $WsusStatus = $Wsus.GetStatus()

    # Create the report object
    $Report = [PSCustomObject]@{
        WsusServer = $Wsus.Name
        Version = $Wsus.Version
        TotalComputers = $WsusStatus.ComputerTargetCount
        ComputersNeedingUpdates = $WsusStatus.ComputerTargetsNeedingUpdatesCount
        UpdatesWithErrors = $WsusStatus.UpdatesWithClientErrorsCount
        TotalUpdates = $WsusStatus.UpdateCount
        ApprovedUpdates = $WsusStatus.ApprovedUpdateCount
        DeclinedUpdates = $WsusStatus.DeclinedUpdateCount
    }

    # Output the report
    $Report | ConvertTo-Html | Out-File -FilePath ".\WsusReport.html"
    Invoke-Expression ".\WsusReport.html"
}
catch {
    Write-Error "Failed to generate WSUS report. Please ensure the WSUS server name, port, and SSL settings are correct, and that you have the necessary permissions."
}
