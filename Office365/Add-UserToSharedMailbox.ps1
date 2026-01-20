<#
.SYNOPSIS
Adds a user to a shared mailbox with FullAccess and SendAs permissions.
Requires the ExchangeOnlineManagement module to be installed.
#>
param (
    [string]$UserPrincipalName,
    [string]$SharedMailbox
)

if (-not $UserPrincipalName) {
    $UserPrincipalName = Read-Host "Enter the user's principal name"
}
if (-not $SharedMailbox) {
    $SharedMailbox = Read-Host "Enter the shared mailbox name"
}

try {
    # Connect to Exchange Online
    Connect-ExchangeOnline -UserPrincipalName $UserPrincipalName -ShowProgress $true

    # Add FullAccess permission
    Add-MailboxPermission -Identity $SharedMailbox -User $UserPrincipalName -AccessRights FullAccess -InheritanceType All

    # Add SendAs permission
    Add-RecipientPermission -Identity $SharedMailbox -Trustee $UserPrincipalName -AccessRights SendAs

    # Disconnect from Exchange Online
    Disconnect-ExchangeOnline -Confirm:$false
}
catch {
    Write-Error "Failed to add user to shared mailbox. Please ensure the user and shared mailbox names are correct, and that you have the necessary permissions."
}
