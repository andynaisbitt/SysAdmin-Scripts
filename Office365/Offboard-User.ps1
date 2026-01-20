<#
.SYNOPSIS
Automates a user offboarding checklist in Office 365/Entra ID.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$UserPrincipalName,
    [string]$ManagerEmail,        # For setting auto-reply to manager
    [string]$SharedMailboxName,   # To convert user mailbox to
    [string]$AutoReplyMessage,    # Custom auto-reply message
    [switch]$DisableSignIn,
    [switch]$RevokeSessions,
    [switch]$ConvertMailboxToShared,
    [switch]$SetAutoReply,
    [switch]$RemoveFromGroups
)

if (-not $UserPrincipalName) {
    $UserPrincipalName = Read-Host "Enter the UserPrincipalName of the user to offboard"
}

try {
    # Connect to Microsoft Graph (for user management)
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "MailboxSettings.ReadWrite", "Directory.AccessAsUser.All", "Mail.ReadWrite", "Mail.Send" -ErrorAction Stop
    # Connect to Exchange Online (for mailbox specific actions)
    Connect-ExchangeOnline -ShowProgress $true -ErrorAction Stop

    $User = Get-MgUser -UserId $UserPrincipalName -ErrorAction Stop

    # 1. Disable Sign-in
    if ($DisableSignIn) {
        if ($pscmdlet.ShouldProcess("Disable sign-in for user '$UserPrincipalName'", "Disable Sign-in")) {
            Update-MgUser -UserId $User.Id -AccountEnabled $false
            Write-Host "Sign-in disabled for $UserPrincipalName."
        }
    }

    # 2. Revoke Sessions
    if ($RevokeSessions) {
        if ($pscmdlet.ShouldProcess("Revoke all sessions for user '$UserPrincipalName'", "Revoke Sessions")) {
            Revoke-MgUserSignInSession -UserId $User.Id
            Write-Host "All sessions revoked for $UserPrincipalName."
        }
    }

    # 3. Convert Mailbox to Shared
    if ($ConvertMailboxToShared -and $SharedMailboxName) {
        if ($pscmdlet.ShouldProcess("Convert mailbox of '$UserPrincipalName' to shared mailbox '$SharedMailboxName'", "Convert Mailbox")) {
            # Ensure the target shared mailbox name is available or construct one
            Set-Mailbox -Identity $UserPrincipalName -Type Shared -ErrorAction Stop
            # Optionally rename the shared mailbox if a specific name is desired and available
            Set-Mailbox -Identity $UserPrincipalName -DisplayName $SharedMailboxName -ErrorAction SilentlyContinue
            Write-Host "Mailbox of $UserPrincipalName converted to shared mailbox."
        }
    }
    elseif ($ConvertMailboxToShared -and -not $SharedMailboxName) {
        Write-Warning "Cannot convert mailbox to shared: SharedMailboxName parameter is required."
    }

    # 4. Set Auto-Reply
    if ($SetAutoReply) {
        if (-not $AutoReplyMessage) {
            $AutoReplyMessage = "The user $User.DisplayName is no longer with the company. Please contact $ManagerEmail for assistance."
        }
        if ($pscmdlet.ShouldProcess("Set auto-reply for user '$UserPrincipalName'", "Set Auto-Reply")) {
            Set-MailboxAutoReplyConfiguration -Identity $UserPrincipalName -AutoReplyState Enabled -InternalMessage $AutoReplyMessage -ExternalMessage $AutoReplyMessage
            Write-Host "Auto-reply set for $UserPrincipalName."
        }
    }

    # 5. Remove from Groups
    if ($RemoveFromGroups) {
        if ($pscmdlet.ShouldProcess("Remove user '$UserPrincipalName' from all groups", "Remove from Groups")) {
            $UserGroups = Get-MgUserMemberOf -UserId $User.Id -All -ErrorAction SilentlyContinue
            foreach ($Group in $UserGroups) {
                Remove-MgGroupMemberByRef -GroupId $Group.Id -UserId $User.Id -ErrorAction SilentlyContinue
                Write-Verbose "Removed $UserPrincipalName from group $($Group.DisplayName)."
            }
            Write-Host "User $UserPrincipalName removed from all groups."
        }
    }
}
catch {
    Write-Error "An error occurred during user offboarding: $($_.Exception.Message)"
}
finally {
    # Disconnect from Microsoft Graph
    Disconnect-MgGraph -Confirm:$false -ErrorAction SilentlyContinue
    # Disconnect from Exchange Online
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
}
