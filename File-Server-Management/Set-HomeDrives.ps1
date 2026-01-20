<#
.SYNOPSIS
Creates home drives for a list of users.
#>
param (
    [string[]]$UserName,
    [string]$BasePath,
    [switch]$CreateShare
)

if (-not $UserName) {
    $UserName = Read-Host "Enter a comma-separated list of user names"
    $UserName = $UserName.Split(',')
}
if (-not $BasePath) {
    $BasePath = Read-Host "Enter the base path for the home drives"
}

foreach ($User in $UserName) {
    try {
        $HomeDrivePath = Join-Path -Path $BasePath -ChildPath $User
        if (-not (Test-Path -Path $HomeDrivePath)) {
            New-Item -Path $HomeDrivePath -ItemType Directory
        }

        $Acl = Get-Acl -Path $HomeDrivePath
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($User, "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
        $Acl.SetAccessRule($AccessRule)
        Set-Acl -Path $HomeDrivePath -AclObject $Acl

        if ($CreateShare) {
            New-SmbShare -Name "$User`$" -Path $HomeDrivePath -FullAccess $User
        }
    }
    catch {
        Write-Warning "Failed to create home drive for user '$User'."
    }
}
