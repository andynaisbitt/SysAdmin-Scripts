<#
.SYNOPSIS
Bulk adds users to Active Directory groups from a CSV file and generates a rollback file for added memberships.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$InputCsvPath, # CSV should have columns: UserSamAccountName, GroupName
    [string]$RollbackFilePath # Path to save the rollback CSV file
)

if (-not $InputCsvPath) {
    $InputCsvPath = Read-Host "Enter the path to the CSV file containing user and group details"
}
if (-not (Test-Path -Path $InputCsvPath)) {
    Write-Error "CSV file not found at: $InputCsvPath"
    return
}

if (-not $RollbackFilePath) {
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $RollbackFilePath = Join-Path -Path (Split-Path -Path $InputCsvPath -Parent) -ChildPath "Rollback_Add-UserToGroups_$Timestamp.csv"
}

try {
    $UserData = Import-Csv -Path $InputCsvPath
    $RollbackData = @()

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
                
                # Add to rollback data
                $RollbackData += [PSCustomObject]@{
                    UserSamAccountName = $UserSamAccountName
                    GroupName = $GroupName
                    Action = "Added"
                    Timestamp = Get-Date
                }
            }
            catch {
                Write-Warning "Failed to add user '$UserSamAccountName' to group '$GroupName': $($_.Exception.Message)"
            }
        }
    }

    if ($RollbackData.Count -gt 0) {
        $RollbackData | Export-Csv -Path $RollbackFilePath -NoTypeInformation -Force
        Write-Host "Rollback file generated: $RollbackFilePath"
        Write-Host "To revert changes, manually remove users from groups based on the rollback file."
    }
    else {
        Write-Host "No group memberships were added, no rollback file generated."
    }
}
catch {
    Write-Error "An error occurred during bulk user-to-group assignment: $($_.Exception.Message)"
}
