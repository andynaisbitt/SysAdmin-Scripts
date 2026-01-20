<#
.SYNOPSIS
Lists startup applications and scheduled tasks that run at startup, providing a best-effort assessment of their impact.
#>
param (
    [string]$ComputerName = "localhost",
    [string]$ExportPath
)

$Result = @()

try {
    Write-Host "--- Getting Startup Impact Report on $ComputerName ---"

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # 1. Startup Applications (Registry Run Keys)
        $RunKeys = @(
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" # For 32-bit apps on 64-bit OS
        )
        foreach ($KeyPath in $RunKeys) {
            Get-ItemProperty -Path $KeyPath -ErrorAction SilentlyContinue | Select-Object -ExpandProperty * | ForEach-Object {
                if ($_ -is [string]) { # Filter for actual registry values
                    $Name = $_.ToString().Split('=')[0] # Get value name
                    $Value = $_.ToString().Split('=')[1] # Get value data
                    $Path = $Value -replace '".*?"', "" # Strip quotes for path
                    $Impact = "Medium" # Default impact

                    if ($Path -like "*OneDrive.exe*" -or $Path -like "*Teams.exe*") { $Impact = "Low (Common)" }
                    elseif ($Path -like "*Dropbox*" -or $Path -like "*GoogleDrive*") { $Impact = "Medium (Cloud Sync)" }
                    elseif ($Path -match "\.exe$") { $Impact = "High (Executable)" }

                    $using:Result += [PSCustomObject]@{
                        ComputerName = $using:Computer
                        Type = "Registry Run Key"
                        Location = $KeyPath
                        Name = $Name
                        Command = $Value
                        Impact = $Impact
                    }
                }
            }
        }

        # 2. Startup Folder (Common Startup items)
        $StartupFolders = @(
            (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"),
            (Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\Startup")
        )
        foreach ($Folder in $StartupFolders) {
            Get-ChildItem -Path $Folder -ErrorAction SilentlyContinue | ForEach-Object {
                $Impact = "Medium"
                if ($_.Extension -eq ".lnk") { $Impact = "Low (Shortcut)" }
                elseif ($_.Extension -eq ".exe") { $Impact = "High (Executable)" }
                $using:Result += [PSCustomObject]@{
                    ComputerName = $using:Computer
                    Type = "Startup Folder"
                    Location = $Folder
                    Name = $_.Name
                    Command = $_.FullName
                    Impact = $Impact
                }
            }
        }

        # 3. Scheduled Tasks (that trigger at startup/logon)
        Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.Triggers.Enabled -eq $true -and ($_.Triggers.TriggerType -eq "AtLogon" -or $_.Triggers.TriggerType -eq "AtStartup") } | ForEach-Object {
            $Impact = "Medium"
            if ($_.Actions.Exec.Path -like "*powershell.exe*" -or $_.Actions.Exec.Path -like "*cmd.exe*") { $Impact = "High (Script)" }
            $using:Result += [PSCustomObject]@{
                ComputerName = $using:Computer
                Type = "Scheduled Task"
                Location = $_.TaskPath
                Name = $_.TaskName
                Command = $_.Actions.Exec.Path
                Impact = $Impact
            }
        }
    } -ErrorAction Stop
}
catch {
    Write-Error "An error occurred during startup impact report generation: $($_.Exception.Message)"
}

if ($ExportPath) {
    if ($ExportPath.EndsWith(".csv")) {
        $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
    }
    elseif ($ExportPath.EndsWith(".html")) {
        $Result | ConvertTo-Html -Title "Startup Impact Report" | Out-File -Path $ExportPath -Force
    }
    else {
        Write-Warning "Invalid export path. Please specify a .csv or .html file."
    }
}
else {
    $Result | Format-Table -AutoSize
}
