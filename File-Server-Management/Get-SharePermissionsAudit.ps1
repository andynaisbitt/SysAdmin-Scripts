<#
.SYNOPSIS
Audits the NTFS and share permissions of a file share.
#>
param (
    [string]$ComputerName,
    [string]$ShareName
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the computer name"
}
if (-not $ShareName) {
    $ShareName = Read-Host "Enter the share name"
}

try {
    # Get the share
    $Share = Get-SmbShare -ComputerName $ComputerName -Name $ShareName

    # Get the share permissions
    $SharePermissions = Get-SmbShareAccess -ComputerName $ComputerName -Name $ShareName

    # Get the NTFS permissions
    $Acl = Get-Acl -Path $Share.Path
    $NtfsPermissions = $Acl.Access | Select-Object -Property IdentityReference, FileSystemRights, AccessControlType, IsInherited

    # Get the owner
    $Owner = $Acl.Owner

    [PSCustomObject]@{
        ShareName         = $ShareName
        Path              = $Share.Path
        Owner             = $Owner
        SharePermissions  = $SharePermissions
        NtfsPermissions   = $NtfsPermissions
    }
}
catch {
    Write-Error "Failed to audit share permissions. Please ensure the computer and share names are correct, and that you have the necessary permissions."
}
