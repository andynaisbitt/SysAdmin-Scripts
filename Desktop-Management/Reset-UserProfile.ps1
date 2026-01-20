<#
.SYNOPSIS
Safely renames a user's profile folder, removes the profile registry entry, and optionally prompts for a reboot.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param (
    [string]$ComputerName,
    [string]$UserName,
    [switch]$RebootIfRequired
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}
if (-not $UserName) {
    $UserName = Read-Host "Enter the user's name whose profile needs to be reset"
}

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    UserName = $UserName
    ProfilePathOriginal = "N/A"
    ProfilePathNew = "N/A"
    ProfileRegistryKeyRemoved = "No"
    RebootRequired = "No"
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "Starting user profile reset for '$UserName' on '$ComputerName'..."

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param ($UserName, $RebootIfRequired, $Result)

        # Get the profile path
        $ProfileInfo = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.LocalPath -like "*\$UserName" }
        if (-not $ProfileInfo) {
            throw "User profile for '$UserName' not found on this computer."
        }
        $ProfilePath = $ProfileInfo.LocalPath
        $ProfileSID = $ProfileInfo.SID
        $ProfileRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$ProfileSID"

        $Result.ProfilePathOriginal = $ProfilePath

        # 1. Rename profile folder
        $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $NewProfilePath = "$ProfilePath.old.$Timestamp"

        if ($pscmdlet.ShouldProcess("Rename profile folder '$ProfilePath' to '$NewProfilePath'", "Rename Folder")) {
            Move-Item -Path $ProfilePath -Destination $NewProfilePath -Force -ErrorAction Stop
            $Result.ProfilePathNew = $NewProfilePath
            Write-Host "Profile folder renamed to '$NewProfilePath'."
        }

        # 2. Remove profile registry entry
        if (Test-Path -Path $ProfileRegistryPath) {
            if ($pscmdlet.ShouldProcess("Remove profile registry entry '$ProfileRegistryPath'", "Remove Registry Key")) {
                Remove-Item -Path $ProfileRegistryPath -Recurse -Force -ErrorAction Stop
                $Result.ProfileRegistryKeyRemoved = "Yes"
                Write-Host "Profile registry entry removed."
            }
        }
        else {
            Write-Warning "Profile registry key '$ProfileRegistryPath' not found."
        }

        # 3. Optional Reboot
        if ($RebootIfRequired) {
            $Result.RebootRequired = "Yes"
            if ($pscmdlet.ShouldProcess("Reboot computer '$using:ComputerName'", "Reboot Computer")) {
                Restart-Computer -ComputerName $using:ComputerName -Force -ErrorAction Stop
                Write-Host "Computer '$using:ComputerName' initiated reboot."
            }
        }

        $Result.OverallStatus = "Success"
    } -ArgumentList $UserName, $RebootIfRequired, $Result -ErrorAction Stop

    $Result.OverallStatus = "Success"
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during user profile reset on '$ComputerName': $($_.Exception.Message)"
}

$Result | Format-List
