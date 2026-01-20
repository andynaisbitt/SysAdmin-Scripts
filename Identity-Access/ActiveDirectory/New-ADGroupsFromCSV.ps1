<#
.SYNOPSIS
Bulk creates Active Directory groups from a CSV file.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$InputCsvPath # CSV should have columns: Name, Description, OrganizationalUnit (DN format), GroupScope (e.g., Global), GroupCategory (e.g., Security)
)

if (-not $InputCsvPath) {
    $InputCsvPath = Read-Host "Enter the path to the CSV file containing group details"
}
if (-not (Test-Path -Path $InputCsvPath)) {
    Write-Error "CSV file not found at: $InputCsvPath"
    return
}

try {
    $GroupData = Import-Csv -Path $InputCsvPath

    foreach ($Group in $GroupData) {
        $GroupName = $Group.Name
        $GroupDescription = $Group.Description
        $OrganizationalUnit = $Group.OrganizationalUnit
        $GroupScope = $Group.GroupScope
        $GroupCategory = $Group.GroupCategory

        if (-not $GroupName) {
            Write-Warning "Skipping group creation: 'Name' column is missing for one entry."
            continue
        }
        if (-not $OrganizationalUnit) {
            Write-Warning "Skipping group '$GroupName': 'OrganizationalUnit' column is missing."
            continue
        }

        if ($pscmdlet.ShouldProcess("Create AD group '$GroupName' in '$OrganizationalUnit'", "Create Group")) {
            try {
                New-ADGroup -Name $GroupName `
                    -Description $GroupDescription `
                    -Path $OrganizationalUnit `
                    -GroupScope $GroupScope `
                    -GroupCategory $GroupCategory `
                    -ErrorAction Stop
                Write-Host "Group '$GroupName' created successfully."
            }
            catch {
                Write-Warning "Failed to create group '$GroupName': $($_.Exception.Message)"
            }
        }
    }
}
catch {
    Write-Error "An error occurred during bulk group creation: $($_.Exception.Message)"
}
