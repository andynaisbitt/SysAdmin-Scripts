<#
.SYNOPSIS
Grants FullAccess, SendAs, or SendOnBehalf permissions to a shared mailbox for a specified user.
Requires the ExchangeOnlineManagement module to be installed.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$UserPrincipalName,
    [string]$SharedMailboxName,
    [ValidateSet("FullAccess", "SendAs", "SendOnBehalf")]
    [string]$PermissionType,
    [switch]$RemoveExistingPermissions, # Optional: Remove existing direct permissions before adding new ones
    [string]$ExportPath
)

if (-not $UserPrincipalName) { $UserPrincipalName = Read-Host "Enter the UserPrincipalName of the user to grant access" }
if (-not $SharedMailboxName) { $SharedMailboxName = Read-Host "Enter the name or email address of the shared mailbox" }
if (-not $PermissionType) { $PermissionType = Read-Host "Enter the permission type to grant (FullAccess, SendAs, SendOnBehalf)" }

$Result = [PSCustomObject]@{
    UserPrincipalName = $UserPrincipalName
    SharedMailboxName = $SharedMailboxName
    PermissionType    = $PermissionType
    Action            = "N/A"
    Status            = "Failed"
    Details           = ""
    Timestamp         = Get-Date
}

try {
    # Connect to Exchange Online
    Connect-ExchangeOnline -ShowProgress $true -ErrorAction Stop
    $Result.Details += "Connected to Exchange Online; "

    if ($RemoveExistingPermissions) {
        if ($pscmdlet.ShouldProcess("Remove existing direct permissions for '$UserPrincipalName' on '$SharedMailboxName'", "Remove Permissions")) {
            try {
                # Remove FullAccess
                Get-MailboxPermission -Identity $SharedMailboxName | Where-Object { ($_.User -eq $UserPrincipalName) -and ($_.AccessRights -like "FullAccess") -and (-not $_.IsInherited) } | Remove-MailboxPermission -Confirm:$false -ErrorAction SilentlyContinue
                # Remove SendAs
                Get-RecipientPermission -Identity $SharedMailboxName | Where-Object { ($_.Trustee -eq $UserPrincipalName) -and ($_.AccessRights -like "SendAs") -and (-not $_.IsInherited) } | Remove-RecipientPermission -Confirm:$false -ErrorAction SilentlyContinue
                # Remove SendOnBehalf
                Set-Mailbox -Identity $SharedMailboxName -GrantSendOnBehalfTo @{Remove="$UserPrincipalName"} -ErrorAction SilentlyContinue
                Write-Host "Existing direct permissions for '$UserPrincipalName' removed from '$SharedMailboxName'."
                $Result.Details += "Existing direct permissions removed; "
            }
            catch {
                Write-Warning "Failed to remove existing permissions: $($_.Exception.Message)"
                $Result.Details += "Failed to remove existing permissions; "
            }
        }
    }

    # Grant new permission
    if ($pscmdlet.ShouldProcess("Grant $($PermissionType) permission to '$SharedMailboxName' for user '$UserPrincipalName'", "Grant Permission")) {
        switch ($PermissionType) {
            "FullAccess" {
                Add-MailboxPermission -Identity $SharedMailboxName -User $UserPrincipalName -AccessRights FullAccess -ErrorAction Stop
                $Result.Action = "Granted FullAccess"
            }
            "SendAs" {
                Add-RecipientPermission -Identity $SharedMailboxName -Trustee $UserPrincipalName -AccessRights SendAs -ErrorAction Stop
                $Result.Action = "Granted SendAs"
            }
            "SendOnBehalf" {
                Set-Mailbox -Identity $SharedMailboxName -GrantSendOnBehalfTo @{Add="$UserPrincipalName"} -ErrorAction Stop
                $Result.Action = "Granted SendOnBehalf"
            }
        }
        $Result.Status = "Success"
        $Result.Details += "Permission granted successfully."
        Write-Host "Successfully granted $($PermissionType) to '$UserPrincipalName' on '$SharedMailboxName'."
    }
}
catch {
    $Result.Status = "Failed"
    $Result.Details += "Error: $($_.Exception.Message); "
    Write-Error "An error occurred while granting shared mailbox access: $($_.Exception.Message)"
}
finally {
    # Disconnect from Exchange Online
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
}

if ($ExportPath) {
    $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
}
else {
    $Result | Format-List
}
