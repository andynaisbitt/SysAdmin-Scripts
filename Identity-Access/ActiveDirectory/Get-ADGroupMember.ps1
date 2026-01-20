<#
.SYNOPSIS
Gets the members of a specified Active Directory group.
#>
param (
    [string]$Group = "Administrators"
)

try {
    Get-ADGroupMember $Group -Recursive | Select-Object name
}
catch {
    Write-Error "Could not retrieve members of group '$Group'. Please ensure the group exists and you have the necessary permissions."
}
