<#
.SYNOPSIS
Retrieves a status summary for Entra ID (Azure AD) users, including enabled status, licenses, MFA methods, sign-in risk, and last sign-in.
#>
param (
    [string]$UserPrincipalName, # Optional: Specific user to query
    [string]$ExportPath
)

try {
    # Connect to Microsoft Graph
    Connect-MgGraph -Scopes "User.Read.All", "Policy.Read.All", "AuditLog.Read.All", "IdentityRiskyUser.Read.All" -ErrorAction Stop

    $Users = if ($UserPrincipalName) {
        Get-MgUser -UserId $UserPrincipalName -Property UserPrincipalName, DisplayName, AccountEnabled, AssignedLicenses, StrongAuthenticationMethods, SignInActivity, RiskLevel, RiskyUserActivity
    } else {
        Get-MgUser -All -Property UserPrincipalName, DisplayName, AccountEnabled, AssignedLicenses, StrongAuthenticationMethods, SignInActivity, RiskLevel, RiskyUserActivity
    }

    $Result = foreach ($User in $Users) {
        $MfaMethods = ($User.StrongAuthenticationMethods | Select-Object -ExpandProperty MethodType) -join ", "
        $LastSignIn = if ($User.SignInActivity) { $User.SignInActivity.LastSignInDateTime } else { "N/A" }
        $AssignedSkus = ($User.AssignedLicenses.SkuId | ForEach-Object { (Get-MgSubscribedSku -All | Where-Object {$_.SkuId -eq $_}) | Select-Object -ExpandProperty SkuPartNumber}) -join ", "
        $SignInRisk = if ($User.RiskyUserActivity) { $User.RiskyUserActivity.RiskLevel } else { "N/A" }

        [PSCustomObject]@{
            DisplayName       = $User.DisplayName
            UserPrincipalName = $User.UserPrincipalName
            AccountEnabled    = $User.AccountEnabled
            Licensed          = if ($User.AssignedLicenses.Count -gt 0) { "Yes" } else { "No" }
            AssignedLicenses  = $AssignedSkus
            MfaRegistered     = if ($User.StrongAuthenticationMethods.Count -gt 0) { "Yes" } else { "No" }
            MfaMethods        = $MfaMethods
            LastSignIn        = $LastSignIn
            SignInRisk        = $SignInRisk
        }
    }

    if ($ExportPath) {
        if ($ExportPath.EndsWith(".csv")) {
            $Result | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        elseif ($ExportPath.EndsWith(".html")) {
            $Result | ConvertTo-Html -Title "Entra ID User Status Report" | Out-File -Path $ExportPath
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
    Write-Error "An error occurred during Entra ID user status retrieval: $($_.Exception.Message)"
}
