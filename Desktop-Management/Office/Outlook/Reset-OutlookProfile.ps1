<#
.SYNOPSIS
Manages Outlook profiles: lists existing, creates new, sets default, and optionally renames old OST files.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName = "localhost",
    [string]$NewProfileName,
    [string]$EmailAddress, # For creating a new profile
    [switch]$SetAsDefault,
    [switch]$RenameOldOst
)

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    ActionTaken  = "None"
    Details      = ""
    OverallStatus = "Failed"
    Errors       = @()
}

try {
    # This script typically needs to be run in the user's context or with elevated privileges on the local machine
    # Remote execution of Outlook profile management is highly complex due to UI interaction and user context
    if ($ComputerName -ne "localhost") {
        Write-Warning "Remote Outlook profile management is complex and may require user interaction or advanced remoting techniques. This script is designed for local execution or via tools like TeamViewer."
        $Result.Errors += "Remote execution is complex for Outlook profiles."
        # return # uncomment to prevent execution on remote
    }

    Write-Host "--- Outlook Profile Management on $ComputerName ---"

    # List Existing Profiles
    $Profiles = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Office\*\Outlook\Profiles\*" -ErrorAction SilentlyContinue | Select-Object PSChildName
    if ($Profiles) {
        Write-Host "Existing Outlook Profiles:"
        $Profiles | Format-Table -AutoSize
        $Result.Details += "Existing Profiles: $($Profiles.PSChildName -join ', '); "
    }
    else {
        Write-Host "No Outlook profiles found."
        $Result.Details += "No Outlook profiles found; "
    }

    if ($NewProfileName) {
        if (-not $EmailAddress) { $EmailAddress = Read-Host "Enter the email address for the new profile" }

        if ($pscmdlet.ShouldProcess("Create new Outlook profile '$NewProfileName'", "Create Profile")) {
            # Outlook profile creation is complex and often requires COM objects or MAPI.
            # A simple way is to use the Outlook.Application COM object if Outlook is running,
            # or rely on command-line switches to launch the profile wizard.
            # This is a placeholder for a more robust solution.
            Write-Host "Attempting to create profile '$NewProfileName' for '$EmailAddress'."
            
            # --- Using Outlook command line for profile creation ---
            # This will launch Outlook if not running, and bring up a wizard.
            # Requires user interaction, so not fully automated.
            # A more advanced method would use Redemption or extended MAPI.
            Start-Process -FilePath "outlook.exe" -ArgumentList "/profiles `"$NewProfileName`"" -Wait -ErrorAction SilentlyContinue
            Start-Process -FilePath "outlook.exe" -ArgumentList "/importprf `"%APPDATA%\Microsoft\Outlook\Outlook.prf`"" # If a PRF file is available
            
            $Result.ActionTaken = "Profile Creation Attempted"
            $Result.Details += "Attempted to create profile '$NewProfileName' for '$EmailAddress'; "
            Write-Host "Please manually configure the new profile '$NewProfileName' in Outlook."
        }
    }

    if ($SetAsDefault -and $NewProfileName) {
        if ($pscmdlet.ShouldProcess("Set '$NewProfileName' as default Outlook profile", "Set Default Profile")) {
            # Setting default profile via registry
            Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Office\*\Outlook" -Name "DefaultProfile" -Value $NewProfileName -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Office\*\Outlook\Profiles" -Name "DefaultProfile" -Value $NewProfileName -Force -ErrorAction SilentlyContinue # For some versions
            $Result.ActionTaken = "Set Default Profile"
            $Result.Details += "Set '$NewProfileName' as default profile; "
            Write-Host "'$NewProfileName' set as default Outlook profile."
        }
    }
    elseif ($SetAsDefault -and -not $NewProfileName) {
        Write-Warning "Cannot set default profile: NewProfileName is required."
    }

    if ($RenameOldOst) {
        if ($pscmdlet.ShouldProcess("Rename old OST files", "Rename Files")) {
            Write-Host "Searching for OST files to rename..."
            $OutlookDataPath = Join-Path $env:LOCALAPPDATA "Microsoft\Outlook"
            $OstFiles = Get-ChildItem -Path $OutlookDataPath -Filter "*.ost" -Recurse -ErrorAction SilentlyContinue
            foreach ($Ost in $OstFiles) {
                $OldOstPath = $Ost.FullName
                $NewOstPath = "$($OldOstPath).old.$Timestamp"
                Rename-Item -Path $OldOstPath -NewName $NewOstPath -Force -ErrorAction SilentlyContinue
                Write-Host "Renamed OST: $OldOstPath to $NewOstPath."
                $Result.Details += "Renamed OST: $($OldOstPath) to $($NewOstPath); "
            }
            $Result.ActionTaken = "Renamed Old OSTs"
        }
    }

    $Result.OverallStatus = "Success"
}
catch {
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during Outlook profile management: $($_.Exception.Message)"
}

if ($ExportPath) {
    $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
}
else {
    $Result | Format-List
}
