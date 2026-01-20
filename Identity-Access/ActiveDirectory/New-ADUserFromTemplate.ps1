<#
.SYNOPSIS
Creates a new Active Directory user based on a template user.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$TemplateUserName,
    [string]$NewUserName,
    [string]$FirstName,
    [string]$LastName,
    [string]$Password,
    [string]$UserPrincipalName,
    [string]$Path,
    [switch]$CopyGroups,
    [switch]$CreateHomeDrive,
    [string]$HomeDriveBasePath # Base path for home drive (e.g., \\fileserver\users)
)

if (-not $TemplateUserName) {
    $TemplateUserName = Read-Host "Enter the name of the template user"
}
if (-not $NewUserName) {
    $NewUserName = Read-Host "Enter the new user's SAMAccountName"
}
if (-not $FirstName) {
    $FirstName = Read-Host "Enter the new user's first name"
}
if (-not $LastName) {
    $LastName = Read-Host "Enter the new user's last name"
}
if (-not $Password) {
    $Password = Read-Host "Enter the new user's password" -AsSecureString
}
if (-not $UserPrincipalName) {
    $UserPrincipalName = Read-Host "Enter the new user's UserPrincipalName"
}
if (-not $Path) {
    $Path = Read-Host "Enter the OU path for the new user (e.g., OU=Users,DC=contoso,DC=com)"
}

try {
    # Get template user
    $TemplateUser = Get-ADUser -Identity $TemplateUserName -Properties MemberOf, Description, Department, Title, Company, Manager -ErrorAction Stop

    # Create new user
    if ($pscmdlet.ShouldProcess("Creating new user '$NewUserName' based on template '$TemplateUserName'", "Create User")) {
        $NewUserParams = @{
            SamAccountName        = $NewUserName
            UserPrincipalName     = $UserPrincipalName
            GivenName             = $FirstName
            Surname               = $LastName
            DisplayName           = "$FirstName $LastName"
            Path                  = $Path
            AccountPassword       = (ConvertTo-SecureString $Password -AsPlainText -Force)
            Enabled               = $true
            ChangePasswordAtLogon = $true
            Description           = $TemplateUser.Description
            Department            = $TemplateUser.Department
            Title                 = $TemplateUser.Title
            Company               = $TemplateUser.Company
            Manager               = $TemplateUser.Manager
        }
        New-ADUser @NewUserParams -ErrorAction Stop
        Write-Host "New user '$NewUserName' created."
    }

    # Copy group memberships
    if ($CopyGroups) {
        if ($pscmdlet.ShouldProcess("Copying group memberships from template user '$TemplateUserName' to new user '$NewUserName'", "Copy Groups")) {
            $TemplateUser.MemberOf | ForEach-Object {
                Add-ADGroupMember -Identity $_ -Members $NewUserName -ErrorAction SilentlyContinue
            }
            Write-Host "Group memberships copied."
        }
    }

    # Create Home Drive
    if ($CreateHomeDrive -and $HomeDriveBasePath) {
        if ($pscmdlet.ShouldProcess("Creating home drive for user '$NewUserName' at '$HomeDriveBasePath'", "Create Home Drive")) {
            $HomeDrivePath = Join-Path -Path $HomeDriveBasePath -ChildPath $NewUserName
            if (-not (Test-Path -Path $HomeDrivePath)) {
                New-Item -Path $HomeDrivePath -ItemType Directory -Force
            }
            # Set basic ACLs (Full Control for user, others read/traverse)
            $Acl = Get-Acl -Path $HomeDrivePath
            $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($NewUserName, "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
            $Acl.AddAccessRule($AccessRule)
            Set-Acl -Path $HomeDrivePath -AclObject $Acl

            Set-ADUser -Identity $NewUserName -HomeDirectory "$HomeDriveBasePath\$NewUserName" -HomeDrive "H:" -ErrorAction Stop
            Write-Host "Home drive created and configured for '$NewUserName'."
        }
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
