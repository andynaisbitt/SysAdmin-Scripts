<#
.SYNOPSIS
Finds stale Active Directory user accounts based on last logon, mailbox presence, and group membership.
#>
param (
    [int]$InactiveDays = 90,
    [string]$ExportPath
)

try {
    $StaleDate = (Get-Date).AddDays(-$InactiveDays)

    Write-Host "Searching for user accounts inactive for more than $InactiveDays days..."

    $StaleUsers = Get-ADUser -Filter { LastLogonDate -lt $StaleDate -and Enabled -eq $true } -Properties LastLogonDate, mail, MemberOf -ErrorAction Stop

    $Result = foreach ($User in $StaleUsers) {
        $LastLogonDate = $User.LastLogonDate
        $MailboxPresent = if ($User.mail) { "Yes" } else { "No" }
        $GroupMembershipSummary = ($User.MemberOf | Get-ADGroup | Select-Object -ExpandProperty Name) -join ", "

        [PSCustomObject]@{
            Name                   = $User.Name
            UserPrincipalName      = $User.UserPrincipalName
            LastLogonDate          = $LastLogonDate
            MailboxPresent         = $MailboxPresent
            GroupMembershipSummary = $GroupMembershipSummary
        }
    }

    if ($Result) {
        Write-Host "Found $($Result.Count) stale user accounts."
        $Result | Format-Table -AutoSize
    }
    else {
        Write-Host "No stale user accounts found."
    }

    if ($ExportPath) {
        if ($ExportPath.EndsWith(".csv")) {
            $Result | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        else {
            Write-Warning "Invalid export path. Please specify a .csv file."
        }
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
