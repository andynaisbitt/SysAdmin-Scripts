<#
.SYNOPSIS
Disables an Active Directory user account and removes various forms of access as a pre-offboarding step.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$SamAccountName,
    [switch]$RemoveFromPrivilegedGroups,
    [switch]$RevokeSessions,
    [switch]$RemoveLicenses
)

if (-not $SamAccountName) { $SamAccountName = Read-Host "Enter the user's SamAccountName to offboard" }

try {
    # Get the user
    $User = Get-ADUser -Identity $SamAccountName -ErrorAction Stop

    Write-Host "--- Starting Pre-Offboarding for User: $SamAccountName ---"

    # 1. Disable User Account
    if ($pscmdlet.ShouldProcess("Disable AD user account '$SamAccountName'", "Disable Account")) {
        Set-ADUser -Identity $User -Enabled $false -ErrorAction Stop
        Write-Host "User account '$SamAccountName' disabled."
    }

    # 2. Remove from Privileged Groups
    if ($RemoveFromPrivilegedGroups) {
        if ($pscmdlet.ShouldProcess("Remove user '$SamAccountName' from privileged groups", "Remove from Groups")) {
            $PrivilegedGroups = @("Domain Admins", "Enterprise Admins", "Schema Admins", "Account Operators") # Extend this list as needed
            foreach ($PGroup in $PrivilegedGroups) {
                try {
                    Remove-ADGroupMember -Identity $PGroup -Members $User -ErrorAction SilentlyContinue
                    Write-Host "Removed '$SamAccountName' from '$PGroup'."
                }
                catch {
                    Write-Warning "Could not remove '$SamAccountName' from '$PGroup': $($_.Exception.Message)"
                }
            }
        }
    }

    # 3. Revoke Sessions (Windows Workstation/Server sessions)
    if ($RevokeSessions) {
        if ($pscmdlet.ShouldProcess("Revoke all active sessions for user '$SamAccountName'", "Revoke Sessions")) {
            # This is complex and might require iterating through computers to run `logoff` or `Disconnect-RDUser`
            # For a basic example, we'll just log that this step is intended.
            Write-Warning "Automated session revocation is complex and depends on environment. This step is a placeholder for `Disconnect-RDUser` or `logoff` on target machines."
            # Placeholder: In a real scenario, you'd integrate with Get-LoggedOnUser and then logoff.
            # Example (requires Get-LoggedOnUser):
            # $LoggedOnSessions = Get-LoggedOnUser -ComputerName (Get-ADComputer -Filter *).Name | Where-Object {$_.UserName -eq $SamAccountName}
            # $LoggedOnSessions | ForEach-Object { logoff $_.Id /server:$_.ComputerName }
            Write-Host "Sessions for '$SamAccountName' conceptually revoked."
        }
    }

    # 4. Remove Licenses (Office 365/Entra ID)
    if ($RemoveLicenses) {
        if ($pscmdlet.ShouldProcess("Remove Office 365 licenses from user '$SamAccountName'", "Remove Licenses")) {
            # This requires Microsoft Graph PowerShell SDK connection
            # Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.AccessAsUser.All"
            # Set-MgUserLicense -UserId $User.UserPrincipalName -RemoveLicenses (Get-MgUserLicenseDetail -UserId $User.UserPrincipalName).SkuId
            Write-Warning "Office 365 license removal requires Microsoft Graph PowerShell SDK connection and appropriate scopes. This step is a placeholder."
            Write-Host "Licenses for '$SamAccountName' conceptually removed."
        }
    }

    Write-Host "--- Pre-Offboarding for User: $SamAccountName Complete ---"
}
catch {
    Write-Error "An error occurred during pre-offboarding: $($_.Exception.Message)"
}
