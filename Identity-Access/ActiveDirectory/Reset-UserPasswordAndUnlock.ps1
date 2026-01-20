<#
.SYNOPSIS
Unlocks an Active Directory user account and resets their password, with policy checks and logging.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$SamAccountName,
    [string]$NewPassword,
    [switch]$ForcePasswordChangeAtLogon = $true
)

if (-not $SamAccountName) { $SamAccountName = Read-Host "Enter the user's SamAccountName" }
if (-not $NewPassword) { $NewPassword = Read-Host "Enter the new password" -AsSecureString }

try {
    # Get the user
    $User = Get-ADUser -Identity $SamAccountName -ErrorAction Stop

    # Check password policy (basic check, full complexity is harder)
    $PasswordPolicy = Get-ADDefaultDomainPasswordPolicy -ErrorAction SilentlyContinue
    if ($PasswordPolicy) {
        $MinLength = $PasswordPolicy.MinPasswordLength
        if ($NewPassword.Length -lt $MinLength) {
            Write-Warning "Password does not meet minimum length requirement of $MinLength characters."
            # Could add more checks for complexity, history etc.
        }
    }

    # Unlock account
    if ($User.LockedOut) {
        if ($pscmdlet.ShouldProcess("Unlock account for user '$SamAccountName'", "Unlock Account")) {
            Unlock-ADAccount -Identity $User -ErrorAction Stop
            Write-Host "Account for '$SamAccountName' unlocked."
        }
    }
    else {
        Write-Host "Account for '$SamAccountName' is not locked out."
    }

    # Reset password
    if ($pscmdlet.ShouldProcess("Reset password for user '$SamAccountName'", "Reset Password")) {
        Set-ADAccountPassword -Identity $User -NewPassword $NewPassword -Reset:$true -ErrorAction Stop
        if ($ForcePasswordChangeAtLogon) {
            Set-ADUser -Identity $User -ChangePasswordAtLogon $true -ErrorAction Stop
        }
        Write-Host "Password for '$SamAccountName' reset successfully."
        if ($ForcePasswordChangeAtLogon) {
            Write-Host "User will be forced to change password at next logon."
        }
    }
}
catch {
    Write-Error "An error occurred during password reset or account unlock: $($_.Exception.Message)"
}
