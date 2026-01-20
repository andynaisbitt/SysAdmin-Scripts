<#
.SYNOPSIS
Provides a comprehensive summary of a user's access across various systems (AD groups, shared mailboxes, local admin, mapped drives).
#>
param (
    [string]$SamAccountName,
    [string]$ExportPath
)

if (-not $SamAccountName) {
    $SamAccountName = Read-Host "Enter the user's SamAccountName"
}

$Result = [PSCustomObject]@{
    UserSamAccountName = $SamAccountName
    DisplayName        = "N/A"
    ADGroups           = @()
    SharedMailboxAccess = @()
    LocalAdminOn       = @()
    MappedDrivesGPO    = @()
    KeyPermissions     = @() # Generic placeholder
}

try {
    # 1. Get AD User Info
    $ADUser = Get-ADUser -Identity $SamAccountName -Properties DisplayName, MemberOf, Manager -ErrorAction SilentlyContinue
    if ($ADUser) {
        $Result.DisplayName = $ADUser.DisplayName
        $Result.ADGroups = ($ADUser.MemberOf | Get-ADGroup | Select-Object -ExpandProperty Name) -join ", "
    }
    else {
        Write-Warning "AD User '$SamAccountName' not found."
    }

    # 2. Shared Mailbox Access (Requires ExchangeOnlineManagement module and connection)
    try {
        # Assuming Connect-ExchangeOnline is done prior to running this script
        $SharedMailboxes = Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited -ErrorAction SilentlyContinue
        foreach ($Mailbox in $SharedMailboxes) {
            $FullAccess = Get-MailboxPermission -Identity $Mailbox.Identity | Where-Object { ($_.AccessRights -like "FullAccess") -and ($_.User -like "*$SamAccountName*") }
            if ($FullAccess) {
                $Result.SharedMailboxAccess += "$($Mailbox.DisplayName) (FullAccess)"
            }
            $SendAs = Get-RecipientPermission -Identity $Mailbox.Identity | Where-Object { ($_.AccessRights -like "SendAs") -and ($_.Trustee -like "*$SamAccountName*") }
            if ($SendAs) {
                $Result.SharedMailboxAccess += "$($Mailbox.DisplayName) (SendAs)"
            }
            # SendOnBehalf - more complex, might need to check Get-Mailbox for GrantSendOnBehalfTo property
        }
        $Result.SharedMailboxAccess = ($Result.SharedMailboxAccess -join ", ")
    }
    catch {
        Write-Warning "Could not retrieve Shared Mailbox Access: $($_.Exception.Message). Ensure Exchange Online is connected."
    }

    # 3. Local Admin Membership (Requires Get-LocalAdminReport.ps1 to be executed first to populate data)
    # This would typically be a separate report run against all machines.
    # For this script, we can only report if a pre-existing report is available or if we iterate.
    # Iterating all computers for local admin for one user is inefficient.
    Write-Warning "To get 'Local Admin On' information, run Get-LocalAdminReport.ps1 across your estate first."

    # 4. Mapped Drives from GPO (Complex, requires GPO analysis or client-side WMI query)
    # This is quite complex to retrieve reliably across all GPOs without a dedicated GPO parsing tool.
    # Client-side WMI might give some, but not all GPO-driven mapped drives.
    Write-Warning "Mapped drives from GPO is complex to retrieve comprehensively."
    
    # Final Output
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
}
catch {
    Write-Error "An error occurred while generating user access summary: $($_.Exception.Message)"
}
