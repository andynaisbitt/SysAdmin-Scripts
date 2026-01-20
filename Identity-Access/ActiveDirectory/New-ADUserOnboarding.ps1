<#
.SYNOPSIS
Automates the onboarding process for a new Active Directory user.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$SamAccountName,
    [string]$FirstName,
    [string]$LastName,
    [string]$UserPrincipalName,
    [string]$Password,
    [string]$OrganizationalUnit,
    [string]$TemplateUserName, # For copying group memberships and other attributes
    [string]$ManagerSamAccountName,
    [string]$Department,
    [string]$Title,
    [string]$HomeDrivePath,    # UNC path to create home drive (e.g., \\fileserver\users\)
    [string]$SharedMailboxEmailAddress, # Optional: Email of shared mailbox to grant access
    [switch]$ForcePasswordChangeAtLogon = $true,
    [switch]$EnableAccount = $true,
    [switch]$CreateHomeDriveShare = $true
)

# --- Input Validation ---
if (-not $SamAccountName) { $SamAccountName = Read-Host "Enter the new user's SamAccountName" }
if (-not $FirstName) { $FirstName = Read-Host "Enter the new user's first name" }
if (-not $LastName) { $LastName = Read-Host "Enter the new user's last name" }
if (-not $UserPrincipalName) { $UserPrincipalName = Read-Host "Enter the new user's UserPrincipalName" }
if (-not $Password) { $Password = Read-Host "Enter the new user's password" -AsSecureString }
if (-not $OrganizationalUnit) { $OrganizationalUnit = Read-Host "Enter the full distinguished name of the target OU (e.g., OU=Users,DC=contoso,DC=com)" }
if (-not $TemplateUserName) { $TemplateUserName = Read-Host "Enter the SamAccountName of the template user to copy groups/attributes from" }

try {
    Write-Host "--- Starting Onboarding for User: $SamAccountName ---"

    # 1. Get Template User for Copying Attributes
    $TemplateUser = Get-ADUser -Identity $TemplateUserName -Properties MemberOf, Description, Department, Title, Company, Manager, physicalDeliveryOfficeName -ErrorAction Stop

    # 2. Create New AD User
    if ($pscmdlet.ShouldProcess("Create AD user '$SamAccountName'", "Create User")) {
        $ManagerDN = if ($ManagerSamAccountName) { (Get-ADUser -Identity $ManagerSamAccountName).DistinguishedName } else { $null }

        $NewUserParams = @{
            SamAccountName        = $SamAccountName
            UserPrincipalName     = $UserPrincipalName
            GivenName             = $FirstName
            Surname               = $LastName
            DisplayName           = "$FirstName $LastName"
            Path                  = $OrganizationalUnit
            AccountPassword       = (ConvertTo-SecureString $Password -AsPlainText -Force)
            Enabled               = $EnableAccount
            ChangePasswordAtLogon = $ForcePasswordChangeAtLogon
            Description           = $TemplateUser.Description
            Department            = ($Department -ne "" ? $Department : $TemplateUser.Department)
            Title                 = ($Title -ne "" ? $Title : $TemplateUser.Title)
            Company               = $TemplateUser.Company
            Manager               = $ManagerDN
            Office                = $TemplateUser.physicalDeliveryOfficeName
        }
        New-ADUser @NewUserParams -ErrorAction Stop
        Write-Host "AD user '$SamAccountName' created successfully in '$OrganizationalUnit'."
    }

    # 3. Copy Group Memberships from Template User
    if ($pscmdlet.ShouldProcess("Copy group memberships from template user '$TemplateUserName' to '$SamAccountName'", "Copy Groups")) {
        $TemplateUser.MemberOf | ForEach-Object {
            Add-ADGroupMember -Identity $_ -Members $SamAccountName -ErrorAction SilentlyContinue
        }
        Write-Host "Group memberships copied from template user."
    }

    # 4. Create Home Drive and Set ACLs
    if ($HomeDrivePath) {
        if ($pscmdlet.ShouldProcess("Create home drive for user '$SamAccountName' at '$HomeDrivePath$SamAccountName'", "Create Home Drive")) {
            $UserHomeDriveLocation = Join-Path -Path $HomeDrivePath -ChildPath $SamAccountName
            if (-not (Test-Path -Path $UserHomeDriveLocation)) {
                New-Item -Path $UserHomeDriveLocation -ItemType Directory -Force
                # Set ACLs: User has Full Control, Administrators have Full Control
                $Acl = Get-Acl $UserHomeDriveLocation
                $AccessRuleUser = New-Object System.Security.AccessControl.FileSystemAccessRule($SamAccountName, "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
                $AccessRuleAdmins = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
                $Acl.AddAccessRule($AccessRuleUser)
                $Acl.AddAccessRule($AccessRuleAdmins)
                Set-Acl -Path $UserHomeDriveLocation -AclObject $Acl
                Write-Host "Home drive folder '$UserHomeDriveLocation' created and ACLs set."

                # Update AD user with home drive path
                Set-ADUser -Identity $SamAccountName -HomeDirectory "$UserHomeDriveLocation" -HomeDrive "H:" -ErrorAction Stop
                Write-Host "Home drive configured in AD for '$SamAccountName'."

                # Optionally create an SMB share for the home drive
                if ($CreateHomeDriveShare) {
                    $ShareName = "$SamAccountName`$"
                    New-SmbShare -Name $ShareName -Path $UserHomeDriveLocation -FullAccess $SamAccountName -ErrorAction SilentlyContinue
                    Write-Host "SMB share '$ShareName' created for home drive."
                }
            }
            else {
                Write-Warning "Home drive path '$UserHomeDriveLocation' already exists. Skipping folder creation."
            }
        }
    }

    # 5. Add to Shared Mailbox Access List (assuming Exchange Online connectivity is established by user)
    if ($SharedMailboxEmailAddress) {
        if ($pscmdlet.ShouldProcess("Grant FullAccess and SendAs to '$SharedMailboxEmailAddress' for user '$SamAccountName'", "Grant Shared Mailbox Access")) {
            # This requires Exchange Online connection, typically handled by calling script or prior setup
            # You may need to run Connect-ExchangeOnline first
            Add-MailboxPermission -Identity $SharedMailboxEmailAddress -User $SamAccountName -AccessRights FullAccess -ErrorAction Stop
            Add-RecipientPermission -Identity $SharedMailboxEmailAddress -Trustee $SamAccountName -AccessRights SendAs -ErrorAction Stop
            Write-Host "Access to shared mailbox '$SharedMailboxEmailAddress' granted to '$SamAccountName'."
        }
    }

    Write-Host "--- Onboarding for User: $SamAccountName Complete ---"

    # Output a summary of actions
    Get-ADUser -Identity $SamAccountName -Properties MemberOf, Manager, Department, Title, physicalDeliveryOfficeName, HomeDirectory, HomeDrive | Select-Object SamAccountName, DisplayName, UserPrincipalName, Enabled, @{N='Groups';E={($_.MemberOf | Get-ADGroup | Select-Object -ExpandProperty Name) -join ", "}}, Manager, Department, Title, physicalDeliveryOfficeName, HomeDirectory, HomeDrive

}
catch {
    Write-Error "An error occurred during user onboarding: $($_.Exception.Message)"
}
