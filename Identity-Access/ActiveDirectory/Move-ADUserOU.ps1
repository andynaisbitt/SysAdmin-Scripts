<#
.SYNOPSIS
Moves an Active Directory user to a new Organizational Unit (OU) and optionally updates user attributes.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$SamAccountName,
    [string]$NewOrganizationalUnit,
    [string]$Department, # Optional: Update Department attribute
    [string]$Office,     # Optional: Update Office attribute
    [switch]$UpdateAttributes # Whether to update Department/Office attributes
)

if (-not $SamAccountName) { $SamAccountName = Read-Host "Enter the user's SamAccountName to move" }
if (-not $NewOrganizationalUnit) { $NewOrganizationalUnit = Read-Host "Enter the full distinguished name of the new OU" }

try {
    # Get the user
    $User = Get-ADUser -Identity $SamAccountName -ErrorAction Stop

    # Move the user
    if ($pscmdlet.ShouldProcess("Move user '$SamAccountName' to OU '$NewOrganizationalUnit'", "Move User")) {
        Move-ADObject -Identity $User -TargetPath $NewOrganizationalUnit -ErrorAction Stop
        Write-Host "User '$SamAccountName' moved to OU '$NewOrganizationalUnit' successfully."
    }

    # Update attributes
    if ($UpdateAttributes) {
        if ($pscmdlet.ShouldProcess("Update attributes for user '$SamAccountName'", "Update Attributes")) {
            $SetParams = @{}
            if ($Department) { $SetParams.Add("Department", $Department) }
            if ($Office) { $SetParams.Add("Office", $Office) }

            if ($SetParams.Count -gt 0) {
                Set-ADUser -Identity $User -Server $User.Server -OtherAttributes $SetParams -ErrorAction Stop # Using -OtherAttributes for dynamic updates
                Write-Host "Attributes updated for user '$SamAccountName'."
            }
            else {
                Write-Warning "No attributes specified for update."
            }
        }
    }
}
catch {
    Write-Error "An error occurred while moving AD user or updating attributes: $($_.Exception.Message)"
}
