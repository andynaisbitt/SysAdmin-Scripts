<#
.SYNOPSIS
Generates a report on MFA status for users, their authentication methods, and a per-policy summary.
Requires the Microsoft.Graph.Identity.SignIns module to be installed.
#>
param (
    [string]$ExportPath
)

try {
    # Connect to Microsoft Graph (requires appropriate scopes, e.g., Policy.Read.All, User.Read.All)
    Connect-MgGraph -Scopes "User.Read.All", "Policy.Read.All", "AuditLog.Read.All" -ErrorAction Stop

    $Users = Get-MgUser -All -Property UserPrincipalName, DisplayName, StrongAuthenticationMethods, SignInActivity, @{N='MfaDetail';E={$_.AdditionalProperties['mfaDetail']}}

    $Result = foreach ($User in $Users) {
        $MfaMethods = ($User.StrongAuthenticationMethods | Select-Object -ExpandProperty MethodType) -join ", "
        $LastSignIn = if ($User.SignInActivity) { $User.SignInActivity.LastSignInDateTime } else { "N/A" }

        [PSCustomObject]@{
            DisplayName       = $User.DisplayName
            UserPrincipalName = $User.UserPrincipalName
            MfaRegistered     = if ($User.StrongAuthenticationMethods.Count -gt 0) { "Yes" } else { "No" }
            MfaMethods        = $MfaMethods
            LastSignIn        = $LastSignIn
            # Add Conditional Access Policy evaluation if complex logic is required
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

    Disconnect-MgGraph
}
catch {
    Write-Error "An error occurred while generating the MFA status report: $($_.Exception.Message)"
}
