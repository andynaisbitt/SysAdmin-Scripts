<#
.SYNOPSIS
Reports on Office Click-to-Run installation status, including version, channel, activation state, last update, and installed applications.
#>
param (
    [string]$ComputerName = "localhost",
    [string]$ExportPath
)

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    OfficeVersion = "N/A"
    UpdateChannel = "N/A"
    ActivationStatus = "N/A"
    LastUpdateTime = "N/A"
    InstalledApplications = "N/A"
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "--- Getting Office Install Status on $ComputerName ---"

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # Office Version and Update Channel
        $OfficeClient = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -ErrorAction SilentlyContinue
        if ($OfficeClient) {
            $using:Result.OfficeVersion = $OfficeClient.VersionToReport
            $using:Result.UpdateChannel = $OfficeClient.CDNBaseUrl -replace "https://officecdn.microsoft.com/pr/([^/]+)/" , "" -replace "/C2RReleaseRetail/" , ""
        }

        # Activation Status (Best Effort) - requires ospp.vbs
        $OsppPath = Join-Path $env:ProgramFiles "Microsoft Office\Office*\ospp.vbs"
        $OsppScript = Get-ChildItem -Path $OsppPath -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName -First 1
        if ($OsppScript) {
            $ActivationOutput = (cscript "$OsppScript" /dstatusall 2>&1 | Out-String)
            if ($ActivationOutput -match "LICENSE STATUS:  LICENSED") {
                $using:Result.ActivationStatus = "LICENSED"
            }
            elseif ($ActivationOutput -match "LICENSE STATUS:  ---OOB_GRACE---") {
                $using:Result.ActivationStatus = "OOB_GRACE (Trial)"
            }
            elseif ($ActivationOutput -match "LICENSE STATUS:  ---UNLICENSED---") {
                $using:Result.ActivationStatus = "UNLICENSED"
            }
            else {
                $using:Result.ActivationStatus = "Unknown"
            }
        } else {
            $using:Result.ActivationStatus = "ospp.vbs not found"
        }

        # Last Update Time
        $LastUpdateReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Updates" -ErrorAction SilentlyContinue
        if ($LastUpdateReg) {
            $using:Result.LastUpdateTime = $LastUpdateReg.LastUpdateTime
        }

        # Installed Applications (basic check via registry)
        $InstalledApps = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "Microsoft Office*" -or $_.DisplayName -like "Microsoft Word*" } |
            Select-Object -ExpandProperty DisplayName -Unique
        $using:Result.InstalledApplications = ($InstalledApps -join ", ")

        $using:Result.OverallStatus = "Success"
    } -ErrorAction Stop
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during Office install status retrieval: $($_.Exception.Message)"
}

if ($ExportPath) {
    $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
}
else {
    $Result | Format-List
}
