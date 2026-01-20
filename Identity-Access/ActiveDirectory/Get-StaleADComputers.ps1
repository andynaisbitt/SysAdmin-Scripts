<#
.SYNOPSIS
Finds stale Active Directory computer accounts and optionally disables or moves them.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [int]$InactiveDays = 90,
    [switch]$Disable,
    [string]$MoveToOU,
    [string]$ExportPath
)

try {
    $StaleDate = (Get-Date).AddDays(-$InactiveDays)

    Write-Host "Searching for computer accounts inactive for more than $InactiveDays days..."

    # Filter for computers with lastlogontimestamp older than $StaleDate
    $StaleComputers = Get-ADComputer -Filter { LastLogonDate -lt $StaleDate } -Properties LastLogonDate, PasswordLastSet, OperatingSystem, Enabled -ErrorAction Stop

    $Result = foreach ($Computer in $StaleComputers) {
        $LastLogonDate = $Computer.LastLogonDate
        $PasswordLastSet = $Computer.PasswordLastSet
        $OS = $Computer.OperatingSystem
        $Enabled = $Computer.Enabled

        [PSCustomObject]@{
            Name            = $Computer.Name
            DistinguishedName = $Computer.DistinguishedName
            LastLogonDate   = $LastLogonDate
            PasswordLastSet = $PasswordLastSet
            OperatingSystem = $OS
            Enabled         = $Enabled
        }
    }

    if ($Result) {
        Write-Host "Found $($Result.Count) stale computer accounts."
        $Result | Format-Table -AutoSize

        if ($Disable) {
            foreach ($Computer in $Result) {
                if ($pscmdlet.ShouldProcess("Disabling computer account '$($Computer.Name)'", "Disable Computer")) {
                    Set-ADComputer -Identity $Computer.DistinguishedName -Enabled $false -ErrorAction Stop
                    Write-Host "Disabled computer account: $($Computer.Name)"
                }
            }
        }

        if ($MoveToOU) {
            foreach ($Computer in $Result) {
                if ($pscmdlet.ShouldProcess("Moving computer account '$($Computer.Name)' to OU '$MoveToOU'", "Move Computer")) {
                    Move-ADObject -Identity $Computer.DistinguishedName -TargetPath $MoveToOU -ErrorAction Stop
                    Write-Host "Moved computer account '$($Computer.Name)' to OU '$MoveToOU'."
                }
            }
        }
    }
    else {
        Write-Host "No stale computer accounts found."
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
