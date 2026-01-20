<#
.SYNOPSIS
Audits FullAccess, SendAs, and SendOnBehalf permissions for shared mailboxes.
Requires the ExchangeOnlineManagement module to be installed.
#>
param (
    [string]$SharedMailboxName, # Optional: Specific shared mailbox to audit
    [string]$ExportPath
)

try {
    # Connect to Exchange Online
    Connect-ExchangeOnline -ShowProgress $true -ErrorAction Stop

    $SharedMailboxes = if ($SharedMailboxName) {
        Get-Mailbox -Identity $SharedMailboxName -RecipientTypeDetails SharedMailbox -ErrorAction Stop
    }
    else {
        Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited -ErrorAction Stop
    }

    $Result = @()
    foreach ($Mailbox in $SharedMailboxes) {
        Write-Verbose "Auditing shared mailbox: $($Mailbox.DisplayName)"

        # FullAccess Permissions
        $FullAccessPerms = Get-MailboxPermission -Identity $Mailbox.Identity | Where-Object { ($_.AccessRights -like "FullAccess") -and (-not $_.IsInherited) -and ($_.User -notlike "NT AUTHORITY\SELF") }
        foreach ($Perm in $FullAccessPerms) {
            $Result += [PSCustomObject]@{
                MailboxName   = $Mailbox.DisplayName
                PermissionType = "FullAccess"
                User          = $Perm.User
                AccessRight   = ($Perm.AccessRights -join ", ")
                IsInherited   = $Perm.IsInherited
            }
        }

        # SendAs Permissions
        $SendAsPerms = Get-RecipientPermission -Identity $Mailbox.Identity | Where-Object { ($_.AccessRights -like "SendAs") -and (-not $_.IsInherited) -and ($_.Trustee -notlike "NT AUTHORITY\SELF") }
        foreach ($Perm in $SendAsPerms) {
            $Result += [PSCustomObject]@{
                MailboxName   = $Mailbox.DisplayName
                PermissionType = "SendAs"
                User          = $Perm.Trustee
                AccessRight   = ($Perm.AccessRights -join ", ")
                IsInherited   = $Perm.IsInherited
            }
        }

        # SendOnBehalf Permissions (usually set on the mailbox itself via GrantSendOnBehalfTo)
        $SendOnBehalfTo = $Mailbox.GrantSendOnBehalfTo
        if ($SendOnBehalfTo) {
            foreach ($User in $SendOnBehalfTo) {
                $Result += [PSCustomObject]@{
                    MailboxName   = $Mailbox.DisplayName
                    PermissionType = "SendOnBehalf"
                    User          = $User
                    AccessRight   = "SendOnBehalfTo"
                    IsInherited   = $false # Direct permission
                }
            }
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

    Disconnect-ExchangeOnline -Confirm:$false
}
catch {
    Write-Error "An error occurred while auditing shared mailbox access: $($_.Exception.Message)"
}
