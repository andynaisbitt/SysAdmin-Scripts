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
    DirectGroupCount   = 0
    NestedGroupCount   = 0
    TotalGroupCount    = 0
    PrivilegedGroups   = @()
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
        
        # Direct Group Memberships
        $DirectGroups = $ADUser.MemberOf | Get-ADGroup -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        $Result.DirectGroupCount = $DirectGroups.Count
        
        # Nested Group Memberships (and all unique groups)
        $AllGroups = @()
        $ADUser.MemberOf | ForEach-Object {
            try {
                $AllGroups += Get-ADGroupMember -Identity $_ -Recursive -ErrorAction Stop | Select-Object -ExpandProperty SamAccountName
            }
            catch {
                Write-Verbose "Could not get nested members for group $_: $($_.Exception.Message)"
            }
        }
        $AllGroups = ($AllGroups | Select-Object -Unique)
        $Result.TotalGroupCount = $AllGroups.Count
        $Result.NestedGroupCount = $Result.TotalGroupCount - $Result.DirectGroupCount

        $Result.ADGroups = ($DirectGroups -join ", ") # Display only direct for simplicity, total count shows depth

        # Privileged Group Flags
        $PrivilegedADGroups = @("Domain Admins", "Enterprise Admins", "Schema Admins", "Account Operators", "Server Operators", "Print Operators", "Backup Operators", "Administrators") # Extend as needed
        foreach ($PGroup in $PrivilegedADGroups) {
            if ($AllGroups -contains (Get-ADGroup -Identity $PGroup -ErrorAction SilentlyContinue).SamAccountName) {
                $Result.PrivilegedGroups += $PGroup
            }
        }
        $Result.PrivilegedGroups = ($Result.PrivilegedGroups -join ", ")
    }
    else {
        Write-Warning "AD User '$SamAccountName' not found."
    }

    # 2. Shared Mailbox Access (Requires ExchangeOnlineManagement module and connection)
    # Ensure Exchange Online connection is established *before* running this script
    try {
        if (Get-Module -Name ExchangeOnlineManagement -ListAvailable) {
            # Check if connected (simplistic)
            $ExoConnected = (Get-EXOCasMailbox -ErrorAction SilentlyContinue).count -gt 0
            if (-not $ExoConnected) {
                Write-Warning "Exchange Online session not connected. Cannot retrieve shared mailbox access."
            }
            else {
                $SharedMailboxes = Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited -ErrorAction SilentlyContinue
                foreach ($Mailbox in $SharedMailboxes) {
                    $FullAccessPerms = Get-MailboxPermission -Identity $Mailbox.Identity | Where-Object { ($_.AccessRights -like "FullAccess") -and ($_.User -like "*$SamAccountName*") -and (-not $_.IsInherited) -and ($_.User -notlike "NT AUTHORITY\SELF") }
                    if ($FullAccessPerms) { $Result.SharedMailboxAccess += "$($Mailbox.DisplayName) (FullAccess)" }

                    $SendAsPerms = Get-RecipientPermission -Identity $Mailbox.Identity | Where-Object { ($_.AccessRights -like "SendAs") -and ($_.Trustee -like "*$SamAccountName*") -and (-not $_.IsInherited) -and ($_.Trustee -notlike "NT AUTHORITY\SELF") }
                    if ($SendAsPerms) { $Result.SharedMailboxAccess += "$($Mailbox.DisplayName) (SendAs)" }

                    $SendOnBehalfTo = $Mailbox.GrantSendOnBehalfTo | Where-Object {$_ -like "*$SamAccountName*"}
                    if ($SendOnBehalfTo) { $Result.SharedMailboxAccess += "$($Mailbox.DisplayName) (SendOnBehalf)" }
                }
                $Result.SharedMailboxAccess = ($Result.SharedMailboxAccess -join ", ")
            }
        }
        else {
            Write-Warning "ExchangeOnlineManagement module not found. Cannot retrieve shared mailbox access."
        }
    }
    catch {
        Write-Warning "Error retrieving Shared Mailbox Access: $($_.Exception.Message)"
    }

    # 3. Local Admin Membership (still a note, as it requires iterating all machines)
    Write-Warning "Local Admin membership requires running Get-LocalAdminReport.ps1 across your estate and correlating."

    # 4. Mapped Drives from GPO (still complex)
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
