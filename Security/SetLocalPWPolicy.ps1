<#
.SYNOPSIS
Sets the local password policy for a user.
#>
param (
    [string]$UserName,
    [int]$MaxPasswordAge = 60
)

if (-not $UserName) {
    $UserName = Read-Host "Enter the user name"
}

try {
    # Set password to expire
    Set-LocalUser -Name $UserName -PasswordNeverExpires $false

    # Set maximum password age
    Set-ADDefaultDomainPasswordPolicy -MaxPasswordAge ([timespan]::FromDays($MaxPasswordAge))
}
catch {
    Write-Error "Failed to set password policy for user '$UserName'. Please ensure the user name is correct and you have the necessary permissions."
}
