<#
.SYNOPSIS
Bulk adds users to Active Directory groups from a CSV file.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$InputCsvPath # CSV should have columns: UserSamAccountName, GroupName
)

if (-not $InputCsvPath) {
    $InputCsvPath = Read-Host "Enter the path to the CSV file containing user and group details"
}
if (-not (Test-Path -Path $InputCsvPath)) {
    Write-Error "CSV file not found at: $InputCsvPath"
    return
}

try {
    $UserData = Import-Csv -Path $InputCsvPath

    foreach ($Entry in $UserData) {
        $UserSamAccountName = $Entry.UserSamAccountName
        $GroupName = $Entry.GroupName

        if (-not $UserSamAccountName) {
            Write-Warning "Skipping entry: 'UserSamAccountName' is missing for one row."
            continue
        }
        if (-not $GroupName) {
            Write-Warning "Skipping entry for user '$UserSamAccountName': 'GroupName' is missing."
            continue
        }

        if ($pscmdlet.ShouldProcess("Add user '$UserSamAccountName' to group '$GroupName'", "Add User to Group")) {
            try {
                # Check if user exists
                $UserExists = Get-ADUser -Identity $UserSamAccountName -ErrorAction SilentlyContinue
                if (-not $UserExists) {
                    Write-Warning "User '$UserSamAccountName' not found. Skipping."
                    continue
                }
                
                # Check if group exists
                $GroupExists = Get-ADGroup -Identity $GroupName -ErrorAction SilentlyContinue
                if (-not $GroupExists) {
                    Write-Warning "Group '$GroupName' not found. Skipping."
                    continue
                }

                Add-ADGroupMember -Identity $GroupName -Members $UserSamAccountName -ErrorAction Stop
                Write-Host "User '$UserSamAccountName' added to group '$GroupName' successfully."
            }
            catch {
                Write-Warning "Failed to add user '$UserSamAccountName' to group '$GroupName': $($_.Exception.Message)"
            }
        }
    }
}
catch {
    Write-Error "An error occurred during bulk user-to-group assignment: $($_.Exception.Message)"
}
