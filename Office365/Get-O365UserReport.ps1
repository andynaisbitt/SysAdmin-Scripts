<#
.SYNOPSIS
Generates a report of Office 365 users and their properties.
Requires the Microsoft.Graph.Users module to be installed.
#>
param (
    [string]$ExportPath,
    [switch]$IncludeLicensed,
    [switch]$IncludeUnlicensed
)

try {
    # Connect to Microsoft Graph
    Connect-MgGraph -Scopes "User.Read.All"

    # Get users
    $Users = Get-MgUser -All

    if ($IncludeLicensed) {
        $Users = $Users | Where-Object { $_.AssignedLicenses.Count -gt 0 }
    }
    if ($IncludeUnlicensed) {
        $Users = $Users | Where-Object { $_.AssignedLicenses.Count -eq 0 }
    }

    $Result = foreach ($User in $Users) {
        [PSCustomObject]@{
            DisplayName        = $User.DisplayName
            UserPrincipalName  = $User.UserPrincipalName
            JobTitle           = $User.JobTitle
            Department         = $User.Department
            OfficeLocation     = $User.OfficeLocation
            Country            = $User.Country
            UsageLocation      = $User.UsageLocation
            Licensed           = if ($User.AssignedLicenses.Count -gt 0) { "Yes" } else { "No" }
            SignInActivity     = (Get-MgUser -UserId $User.Id -Select SignInActivity).SignInActivity.LastSignInDateTime
        }
    }

    if ($ExportPath) {
        $Result | Export-Csv -Path $ExportPath -NoTypeInformation
    }
    else {
        $Result
    }

    # Disconnect from Microsoft Graph
    Disconnect-MgGraph
}
catch {
    Write-Error "Failed to generate Office 365 user report. Please ensure the Microsoft.Graph.Users module is installed and you have the necessary permissions."
}
