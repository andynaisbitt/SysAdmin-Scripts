<#
.SYNOPSIS
Creates a scheduled task from a predefined template, supporting remote registration.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName = "localhost",
    [ValidateSet("HealthPackDaily", "BackupEvidenceWeekly", "DiskReportDaily")]
    [string]$TemplateName,
    [string]$TaskName, # Custom name for the scheduled task
    [string]$ScriptPath, # Path to the script to be run by the task
    [string]$User = "SYSTEM" # User account to run the task as
)

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    TemplateName = $TemplateName
    TaskName     = "N/A"
    CreationStatus = "Failed"
    Errors       = @()
}

try {
    Write-Host "--- Creating Scheduled Task from Template on $ComputerName ---"

    $TaskName = if ($TaskName) { $TaskName } else { "$TemplateName-$ComputerName" }
    $Result.TaskName = $TaskName

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param (
            $TaskName,
            $TemplateName,
            $ScriptPath,
            $User
        )

        $Action = $null
        $Trigger = $null
        $Settings = New-ScheduledTaskSettingsSet -AllowStartOnDemand -Compatibility V2.1 -ErrorAction Stop

        switch ($TemplateName) {
            "HealthPackDaily" {
                $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -File `"$ScriptPath`" -ComputerName $using:ComputerName" -ErrorAction Stop
                $Trigger = New-ScheduledTaskTrigger -Daily -At "3am" -ErrorAction Stop
                $Settings.ExecutionTimeLimit = "PT1H" # 1 hour
            }
            "BackupEvidenceWeekly" {
                $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -File `"$ScriptPath`" -ComputerName $using:ComputerName" -ErrorAction Stop
                $Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Saturday -At "2am" -ErrorAction Stop
                $Settings.ExecutionTimeLimit = "PT3H" # 3 hours
            }
            "DiskReportDaily" {
                $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -File `"$ScriptPath`" -ComputerName $using:ComputerName" -ErrorAction Stop
                $Trigger = New-ScheduledTaskTrigger -Daily -At "4am" -ErrorAction Stop
                $Settings.ExecutionTimeLimit = "PT30M" # 30 minutes
            }
            default {
                throw "Unknown template name: $TemplateName"
            }
        }

        if ($pscmdlet.ShouldProcess("Register scheduled task '$TaskName'", "Create Task")) {
            Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -User $User -Force -ErrorAction Stop
            $using:Result.CreationStatus = "Success"
            Write-Host "Scheduled task '$TaskName' created successfully."
        }
    } -ArgumentList $TaskName, $TemplateName, $ScriptPath, $User -ErrorAction Stop
}
catch {
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during scheduled task creation: $($_.Exception.Message)"
}

if ($ExportPath) {
    $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
}
else {
    $Result | Format-List
}
