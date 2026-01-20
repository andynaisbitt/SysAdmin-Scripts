<#
.SYNOPSIS
Retrieves a quick status summary for an Active Directory user account.
#>
param (
    [string]$SamAccountName,
    [string]$ExportPath
)

if (-not $SamAccountName) {
    $SamAccountName = Read-Host "Enter the user's SamAccountName"
}

$Result = [PSCustomObject]@{
    SamAccountName    = $SamAccountName
    DisplayName       = "N/A"
    Enabled           = "N/A"
    LockedOut         = "N/A"
    PasswordLastSet   = "N/A"
    PasswordExpires   = "N/A"
    LastLogonDate     = "N/A"
    OrganizationalUnit = "N/A"
    Manager           = "N/A"
    DirectGroupCount  = "N/A"
    TotalGroupCount   = "N/A"
    PrivilegedMember  = "No"
    ErrorDetails      = ""
}

try {
    $User = Get-ADUser -Identity $SamAccountName -Properties DisplayName, Enabled, LockedOut, PasswordLastSet, PasswordNeverExpires, AccountExpirationDate, LastLogonDate, Manager, MemberOf, CanonicalName -ErrorAction Stop
    
    $Result.DisplayName = $User.DisplayName
    $Result.Enabled = $User.Enabled
    $Result.LockedOut = $User.LockedOut
    $Result.PasswordLastSet = $User.PasswordLastSet
    
    if ($User.PasswordNeverExpires -eq $true) {
        $Result.PasswordExpires = "Never"
    }
    elseif ($User.AccountExpirationDate) {
        $Result.PasswordExpires = $User.AccountExpirationDate
    }
    else {
        # Calculate expiry based on domain policy and PasswordLastSet
        try {
            $DomainPolicy = Get-ADDefaultDomainPasswordPolicy -ErrorAction Stop
            if ($DomainPolicy.MaxPasswordAge -ne 0) {
                $Result.PasswordExpires = $User.PasswordLastSet.Add($DomainPolicy.MaxPasswordAge)
            }
            else {
                $Result.PasswordExpires = "Not enforced by domain policy"
            }
        }
        catch {
            $Result.PasswordExpires = "Error calculating expiry: $($_.Exception.Message)"
        }
    }

    $Result.LastLogonDate = $User.LastLogonDate
    $Result.OrganizationalUnit = $User.CanonicalName -replace "^.+?/", "" # Extract OU from CanonicalName
    $Result.Manager = if ($User.Manager) { (Get-ADUser $User.Manager).DisplayName } else { "N/A" }

    # Group Counts
    $DirectGroups = $User.MemberOf
    $Result.DirectGroupCount = $DirectGroups.Count
    $AllGroups = @()
    if ($DirectGroups) {
        $DirectGroups | ForEach-Object {
            try {
                $AllGroups += Get-ADGroupMember -Identity $_ -Recursive -ErrorAction SilentlyContinue | Select-Object -ExpandProperty SamAccountName
            }
            catch {}
        }
    }
    $AllGroups = ($AllGroups | Select-Object -Unique)
    $Result.TotalGroupCount = $AllGroups.Count

    # Privileged Membership
    $PrivilegedADGroups = @("Domain Admins", "Enterprise Admins", "Schema Admins", "Account Operators", "Server Operators", "Print Operators", "Backup Operators", "Administrators")
    foreach ($PGroup in $PrivilegedADGroups) {
        try {
            if ($AllGroups -contains (Get-ADGroup -Identity $PGroup -ErrorAction SilentlyContinue).SamAccountName) {
                $Result.PrivilegedMember = "Yes (in $PGroup)"
                break
            }
        }
        catch {}
    }
}
catch {
    $Result.ErrorDetails = $_.Exception.Message
}

if ($ExportPath) {
    if ($ExportPath.EndsWith(".csv")) {
        $Result | Export-Csv -Path $ExportPath -NoTypeInformation
    }
    elseif ($ExportPath.EndsWith(".html")) {
        $Result | ConvertTo-Html -Title "User Quick Status Report for $SamAccountName" | Out-File -Path $ExportPath
    }
    else {
        Write-Warning "Invalid export path. Please specify a .csv or .html file."
    }
}
else {
    $Result | Format-List
}
