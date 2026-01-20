<#
.SYNOPSIS
Creates a new file share with the specified permissions.
#>
param (
    [string]$Path,
    [string]$Name,
    [string]$FullAccess,
    [string]$ReadAccess,
    [switch]$EnableABE
)

if (-not $Path) {
    $Path = Read-Host "Enter the path for the new share"
}
if (-not $Name) {
    $Name = Read-Host "Enter the name of the new share"
}

try {
    # Create the folder if it doesn't exist
    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory
    }

    # Set NTFS permissions
    $Acl = Get-Acl -Path $Path
    if ($FullAccess) {
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($FullAccess, "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
        $Acl.SetAccessRule($AccessRule)
    }
    if ($ReadAccess) {
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($ReadAccess, "Read", "ContainerInherit, ObjectInherit", "None", "Allow")
        $Acl.SetAccessRule($AccessRule)
    }
    Set-Acl -Path $Path -AclObject $Acl

    # Create the SMB share
    New-SmbShare -Name $Name -Path $Path -FullAccess $FullAccess -ReadAccess $ReadAccess

    # Enable Access-Based Enumeration
    if ($EnableABE) {
        Set-SmbShare -Name $Name -FolderEnumerationMode AccessBased
    }
}
catch {
    Write-Error "Failed to create file share. Please ensure the path and share name are correct, and that you have the necessary permissions."
}
