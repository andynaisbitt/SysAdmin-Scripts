<#
.SYNOPSIS
Tests a user's access to a file share, reporting share permissions, NTFS effective permissions (best effort), and common failure reasons.
#>
param (
    [string]$ComputerName,
    [string]$SharePath,      # Full UNC path to the share (e.g., \\Server\Share)
    [string]$UserPrincipalName, # User to test access for
    [string]$ExportPath
)

if (-not $ComputerName) { $ComputerName = (Split-Path -Path $SharePath -Parent).TrimStart('\').Split('\')[0] }
if (-not $SharePath) { $SharePath = Read-Host "Enter the full UNC path to the share (e.g., \\Server\Share)" }
if (-not $UserPrincipalName) { $UserPrincipalName = Read-Host "Enter the UserPrincipalName (or SamAccountName) of the user to test access for" }

$Result = [PSCustomObject]@{
    SharePath         = $SharePath
    User              = $UserPrincipalName
    ComputerName      = $ComputerName
    ShareAccessStatus = "N/A"
    NTFSAccessStatus  = "N/A"
    EffectiveAccess   = "N/A"
    FailureReason     = "N/A"
    OverallStatus     = "Failed"
    Errors            = @()
}

try {
    Write-Host "--- Testing Share Access for '$UserPrincipalName' on '$SharePath' ---"

    # 1. Test Share Level Access
    Write-Verbose "Checking share level access..."
    try {
        $ShareName = (Split-Path -Path $SharePath -Leaf)
        $SmbShareAccess = Get-SmbShareAccess -ComputerName $ComputerName -Name $ShareName -ErrorAction Stop
        
        $UserShareAccess = $SmbShareAccess | Where-Object { $_.AccountName -like "*$UserPrincipalName*" -or ($_.AccountName -like "*Everyone*" -or $_.AccountName -like "*Authenticated Users*") }
        if ($UserShareAccess) {
            $Result.ShareAccessStatus = "Access Granted (via " + ($UserShareAccess | Select-Object -ExpandProperty AccountName -Unique) -join ", " + ")"
        } else {
            $Result.ShareAccessStatus = "Access Denied (No explicit share permissions)"
            $Result.FailureReason = "No explicit share permissions for user or groups like Everyone/Authenticated Users."
        }
    }
    catch {
        $Result.ShareAccessStatus = "Error"
        $Result.FailureReason = "Error checking share permissions: $($_.Exception.Message)"
        $Result.Errors += "Share Access Check: $($_.Exception.Message)"
    }

    # 2. Test NTFS Level Access (best effort)
    Write-Verbose "Checking NTFS level access..."
    try {
        $LocalPath = (Get-SmbShare -ComputerName $ComputerName -Name $ShareName -ErrorAction Stop).Path
        # Use Get-NTFSPermissionsEffective.ps1 (if available) for better effective access
        $NTFSEffectiveScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Get-NTFSPermissionsEffective.ps1"
        if (Test-Path -Path $NTFSEffectiveScriptPath) {
            $NtfsEffective = & $NTFSEffectiveScriptPath -Path "\\$ComputerName\$($LocalPath.Replace(':','$'))" -PrincipalName $UserPrincipalName -ErrorAction Stop
            $Result.NTFSAccessStatus = "Evaluated"
            $Result.EffectiveAccess = $NtfsEffective.EffectiveAccess
        }
        else {
            $Result.NTFSAccessStatus = "Script Not Found"
            $Result.FailureReason += "Get-NTFSPermissionsEffective.ps1 not found. Cannot determine effective NTFS access."
        }
    }
    catch {
        $Result.NTFSAccessStatus = "Error"
        $Result.FailureReason += "Error checking NTFS permissions: $($_.Exception.Message)"
        $Result.Errors += "NTFS Access Check: $($_.Exception.Message)"
    }

    $Result.OverallStatus = if ($Result.Errors.Count -eq 0 -and $Result.ShareAccessStatus -like "Access Granted*") { "Success" } else { "Review Required" }
}
catch {
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during share access test: $($_.Exception.Message)"
}

if ($ExportPath) {
    $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
}
else {
    $Result | Format-List
}
