<#
.SYNOPSIS
Resolves effective NTFS permissions for a specified path and user/group (best effort).
#>
param (
    [string]$Path,
    [string]$PrincipalName, # User or Group name (e.g., 'Domain Users', 'Administrator')
    [string]$ExportPath
)

if (-not $Path) {
    $Path = Read-Host "Enter the file or folder path"
}
if (-not (Test-Path -Path $Path)) {
    Write-Error "Path not found: $Path"
    return
}
if (-not $PrincipalName) {
    $PrincipalName = Read-Host "Enter the user or group name (e.g., 'Domain Users', 'Administrator')"
}

try {
    $Acl = Get-Acl -Path $Path
    $FileSystemRights = @()

    # Get the SecurityIdentifier for the principal
    $Principal = New-Object System.Security.Principal.NTAccount($PrincipalName)
    $PrincipalSID = $Principal.Translate([System.Security.Principal.SecurityIdentifier])

    # Attempt to resolve effective access. This is a complex operation and PowerShell
    # doesn't have a direct cmdlet for true effective permissions like Windows UI.
    # This approach is a "best effort" by iterating rules.
    
    # Permissions to check
    $PermissionsToCheck = @(
        "ReadData", "WriteData", "AppendData", "ReadExtendedAttributes", "WriteExtendedAttributes",
        "ExecuteFile", "Delete", "ReadPermissions", "ChangePermissions", "TakeOwnership",
        "Synchronize", "ReadAndExecute", "Modify", "FullControl"
    )

    $EffectiveAccess = [System.Collections.Generic.HashSet[string]]::new()

    # Get all access rules that apply to the principal (direct or group membership)
    foreach ($AccessRule in $Acl.Access) {
        if ($AccessRule.IdentityReference -eq $PrincipalSID -or
            (Get-ADPrincipalGroupMembership -Identity $PrincipalName -ErrorAction SilentlyContinue | Where-Object {$_.SID -eq $AccessRule.IdentityReference.Value}) )
        {
            if ($AccessRule.AccessControlType -eq "Allow") {
                foreach ($Perm in $PermissionsToCheck) {
                    if ($AccessRule.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::$Perm) {
                        $EffectiveAccess.Add($Perm)
                    }
                }
            }
            elseif ($AccessRule.AccessControlType -eq "Deny") {
                # Deny rules take precedence, remove them from effective access
                foreach ($Perm in $PermissionsToCheck) {
                    if ($AccessRule.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::$Perm) {
                        $EffectiveAccess.Remove($Perm)
                    }
                }
            }
        }
    }

    $Result = [PSCustomObject]@{
        Path             = $Path
        PrincipalName    = $PrincipalName
        EffectiveAccess  = ($EffectiveAccess | Sort-Object) -join ", "
        InheritanceChain = ($Acl.Path -split "\\") # Simplistic, full chain requires deeper AD/GPO analysis
    }

    if ($ExportPath) {
        if ($ExportPath.EndsWith(".csv")) {
            $Result | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        elseif ($ExportPath.EndsWith(".html")) {
            $Result | ConvertTo-Html | Out-File -Path $ExportPath
        }
        else {
            Write-Warning "Invalid export path. Please specify a .csv or .html file."
        }
    }
    else {
        $Result | Format-Table -AutoSize
    }
}
catch {
    Write-Error "An error occurred while getting effective NTFS permissions: $($_.Exception.Message)"
}
