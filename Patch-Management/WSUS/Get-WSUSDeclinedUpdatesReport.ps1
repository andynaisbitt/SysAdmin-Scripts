<#
.SYNOPSIS
Generates a report of all declined updates on a WSUS server.
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

    # Get all updates that are declined
    $UpdateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
    $UpdateScope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::Declined
    $DeclinedUpdates = $Wsus.GetUpdates($UpdateScope)

    $Result = foreach ($Update in $DeclinedUpdates) {
        [PSCustomObject]@{
            WsusServer       = $WsusServer
            Title            = $Update.Title
            KnowledgebaseUrl = ($Update.KnowledgebaseArticles | Select-Object -First 1).Url
            DeclinedDate     = $Update.CreationDate # This is creation date, actual decline date might need more digging
        }
    }

    if ($Result) {
        Write-Host "Found $($Result.Count) declined updates on $WsusServer."
    }
    else {
        Write-Host "No declined updates found on $WsusServer."
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
    Write-Error "An error occurred: $($_.Exception.Message)"
}
