<#
.SYNOPSIS
A wrapper for Get-PendingRebootReport.ps1 that reads computer targets from an Active Directory OU.
#>
param (
    [string]$OrganizationalUnit,
    [string]$ExportPath
)

if (-not $OrganizationalUnit) {
    $OrganizationalUnit = Read-Host "Enter the full distinguished name of the OU to scan for workstations (e.g., OU=Workstations,DC=contoso,DC=com)"
}

try {
    # Get computer names from the specified OU
    $Computers = Get-ADComputer -Filter * -SearchBase $OrganizationalUnit | Select-Object -ExpandProperty Name

    if ($Computers) {
        # Path to the original Get-PendingRebootReport.ps1 script (assuming it's in Patch-Management)
        $PendingRebootScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Patch-Management\Get-PendingRebootReport.ps1"
        
        if (Test-Path -Path $PendingRebootScriptPath) {
            Write-Host "Found $($Computers.Count) computers in OU '$OrganizationalUnit'. Checking for pending reboots..."
            # Execute the pending reboot report script with the list of computers
            & $PendingRebootScriptPath -ComputerName $Computers -ExportPath $ExportPath
        }
        else {
            Write-Error "The core Get-PendingRebootReport.ps1 script was not found at '$PendingRebootScriptPath'."
        }
    }
    else {
        Write-Warning "No computers found in the specified OU: $OrganizationalUnit"
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
