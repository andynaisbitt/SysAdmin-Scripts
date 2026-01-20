<#
.SYNOPSIS
Retrieves inventory details for Entra ID (Azure AD) devices via Microsoft Graph.
#>
param (
    [string]$DeviceId, # Optional: Specific device to query
    [string]$ExportPath
)

try {
    # Connect to Microsoft Graph
    Connect-MgGraph -Scopes "Device.Read.All", "Directory.Read.All" -ErrorAction Stop

    $Devices = if ($DeviceId) {
        Get-MgDevice -DeviceId $DeviceId -Property DeviceId, DisplayName, TrustType, AccountEnabled, OperatingSystem, OperatingSystemVersion, ApproximateLastSignInDateTime, RegisteredOwners, ComplianceEnabled
    } else {
        Get-MgDevice -All -Property DeviceId, DisplayName, TrustType, AccountEnabled, OperatingSystem, OperatingSystemVersion, ApproximateLastSignInDateTime, RegisteredOwners, ComplianceEnabled
    }

    $Result = foreach ($Device in $Devices) {
        $Owner = if ($Device.RegisteredOwners) { ($Device.RegisteredOwners.AdditionalProperties.displayName -join ", ") } else { "N/A" }

        [PSCustomObject]@{
            DeviceId            = $Device.DeviceId
            DisplayName         = $Device.DisplayName
            TrustType           = $Device.TrustType # AzureADJoined, WorkplaceJoined, ServerAD
            JoinType            = if ($Device.TrustType -eq "AzureADJoined") { "AADJ" } elseif ($Device.TrustType -eq "WorkplaceJoined") { "WPJ" } else { "Hybrid AADJ" }
            AccountEnabled      = $Device.AccountEnabled
            OperatingSystem     = $Device.OperatingSystem
            OSVersion           = $Device.OperatingSystemVersion
            LastSignInDateTime  = $Device.ApproximateLastSignInDateTime
            RegisteredOwner     = $Owner
            ComplianceEnabled   = $Device.ComplianceEnabled # Indicates if Intune compliance is enabled
        }
    }

    if ($ExportPath) {
        if ($ExportPath.EndsWith(".csv")) {
            $Result | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        elseif ($ExportPath.EndsWith(".html")) {
            $Result | ConvertTo-Html -Title "Entra ID Device Inventory Report" | Out-File -Path $ExportPath
        }
        else {
            Write-Warning "Invalid export path. Please specify a .csv or .html file."
        }
    }
    else {
        $Result | Format-Table -AutoSize
    }

    Disconnect-MgGraph
}
catch {
    Write-Error "An error occurred during Entra ID device inventory retrieval: $($_.Exception.Message)"
}
