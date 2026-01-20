<#
.SYNOPSIS
Automates a user offboarding checklist in Office 365/Entra ID and creates an evidence pack.
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
    [switch]$RemoveFromGroups,
    [string]$EvidencePath = (Join-Path $PSScriptRoot "OffboardingEvidence") # Base path for evidence folders
)

if (-not $UserPrincipalName) {
    $UserPrincipalName = Read-Host "Enter the UserPrincipalName of the user to offboard"
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$UserEvidenceFolder = Join-Path -Path $EvidencePath -ChildPath "$($UserPrincipalName)_Offboarding_$Timestamp"
New-Item -Path $UserEvidenceFolder -ItemType Directory -Force | Out-Null
Write-Host "Offboarding evidence will be stored in: $UserEvidenceFolder"

$OffboardingLog = Join-Path -Path $UserEvidenceFolder -ChildPath "OffboardingLog.txt"
$UserDetailReport = Join-Path -Path $UserEvidenceFolder -ChildPath "UserDetails.json"
$GroupMembershipReport = Join-Path -Path $UserEvidenceFolder -ChildPath "GroupMembership_Before.json"

function Write-OffboardingLog ([string]$Message) {
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Time - $Message" | Add-Content -Path $OffboardingLog
    Write-Host $Message
}

try {
    # Connect to Microsoft Graph (for user management)
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "MailboxSettings.ReadWrite", "Directory.AccessAsUser.All", "Mail.ReadWrite", "Mail.Send" -ErrorAction Stop
    Write-OffboardingLog "Connected to Microsoft Graph."
    
    # Connect to Exchange Online (for mailbox specific actions)
    Connect-ExchangeOnline -ShowProgress $true -ErrorAction Stop
    Write-OffboardingLog "Connected to Exchange Online."

    $User = Get-MgUser -UserId $UserPrincipalName -ErrorAction Stop
    $ADUser = Get-ADUser -Identity $User.SamAccountName -Properties MemberOf -ErrorAction SilentlyContinue

    # Export User Details Before Offboarding
    $User | ConvertTo-Json -Depth 5 | Out-File -FilePath $UserDetailReport -Force
    Write-OffboardingLog "User details saved to $UserDetailReport."

    if ($ADUser) {
        ($ADUser.MemberOf | Get-ADGroup | Select-Object Name) | ConvertTo-Json | Out-File -FilePath $GroupMembershipReport -Force
        Write-OffboardingLog "User's current AD group memberships saved to $GroupMembershipReport."
    }

    # 1. Disable Sign-in
    if ($DisableSignIn) {
        if ($pscmdlet.ShouldProcess("Disable sign-in for user '$UserPrincipalName'", "Disable Sign-in")) {
            Update-MgUser -UserId $User.Id -AccountEnabled $false
            Write-OffboardingLog "Sign-in disabled for $UserPrincipalName."
        }
    }

    # 2. Revoke Sessions
    if ($RevokeSessions) {
        if ($pscmdlet.ShouldProcess("Revoke all sessions for user '$UserPrincipalName'", "Revoke Sessions")) {
            Revoke-MgUserSignInSession -UserId $User.Id
            Write-OffboardingLog "All sessions revoked for $UserPrincipalName."
        }
    }

    # 3. Convert Mailbox to Shared
    if ($ConvertMailboxToShared -and $SharedMailboxName) {
        if ($pscmdlet.ShouldProcess("Convert mailbox of '$UserPrincipalName' to shared mailbox '$SharedMailboxName'", "Convert Mailbox")) {
            Set-Mailbox -Identity $UserPrincipalName -Type Shared -ErrorAction Stop
            Set-Mailbox -Identity $UserPrincipalName -DisplayName $SharedMailboxName -ErrorAction SilentlyContinue
            Write-OffboardingLog "Mailbox of $UserPrincipalName converted to shared mailbox '$SharedMailboxName'."
        }
    }
    elseif ($ConvertMailboxToShared -and -not $SharedMailboxName) {
        Write-OffboardingLog "Cannot convert mailbox to shared: SharedMailboxName parameter is required."
    }

    # 4. Set Auto-Reply
    if ($SetAutoReply) {
        $ActualAutoReplyMessage = if ($AutoReplyMessage) { $AutoReplyMessage } else { "The user $User.DisplayName is no longer with the company. Please contact $ManagerEmail for assistance." }
        if ($pscmdlet.ShouldProcess("Set auto-reply for user '$UserPrincipalName'", "Set Auto-Reply")) {
            Set-MailboxAutoReplyConfiguration -Identity $UserPrincipalName -AutoReplyState Enabled -InternalMessage $ActualAutoReplyMessage -ExternalMessage $ActualAutoReplyMessage
            Write-OffboardingLog "Auto-reply set for $UserPrincipalName with message: '$ActualAutoReplyMessage'."
        }
    }

    # 5. Remove from Groups
    if ($RemoveFromGroups) {
        if ($pscmdlet.ShouldProcess("Remove user '$UserPrincipalName' from all groups", "Remove from Groups")) {
            $UserGroups = Get-MgUserMemberOf -UserId $User.Id -All -ErrorAction SilentlyContinue
            foreach ($Group in $UserGroups) {
                Remove-MgGroupMemberByRef -GroupId $Group.Id -UserId $User.Id -ErrorAction SilentlyContinue
                Write-OffboardingLog "Removed $UserPrincipalName from group $($Group.DisplayName)."
            }
            Write-OffboardingLog "User $UserPrincipalName removed from all groups."
        }
    }
    Write-OffboardingLog "--- Offboarding Process for $UserPrincipalName Completed ---"
}
catch {
    Write-OffboardingLog "An error occurred during user offboarding: $($_.Exception.Message)"
}
finally {
    Write-OffboardingLog "Disconnecting from Microsoft Graph and Exchange Online."
    # Disconnect from Microsoft Graph
    Disconnect-MgGraph -Confirm:$false -ErrorAction SilentlyContinue
    # Disconnect from Exchange Online
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
}
