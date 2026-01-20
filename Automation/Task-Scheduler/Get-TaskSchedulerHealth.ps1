<#
.SYNOPSIS
Reports on the health of scheduled tasks, listing recently failed tasks, their last run results, and potential missing runs.
#>
param (
    [string]$ComputerName = "localhost",
    [int]$LookbackDays = 7, # How many days back to check for failed runs
    [string]$ExportPath
)

$Result = @()

try {
    Write-Host "--- Checking Scheduled Task Health on $ComputerName ---"

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        $Tasks = Get-ScheduledTask -ErrorAction SilentlyContinue

        foreach ($Task in $Tasks) {
            $TaskResult = [PSCustomObject]@{
                ComputerName = $using:Computer
                TaskPath     = $Task.TaskPath
                TaskName     = $Task.TaskName
                State        = $Task.State
                LastRunTime  = $Task.LastRunTime
                LastTaskResult = $Task.LastTaskResult
                Status       = "N/A" # Custom status
                Details      = @()
            }

            # Check for failed runs
            if ($Task.LastTaskResult -ne 0 -and $Task.LastTaskResult -ne $null) {
                $TaskResult.Status = "Failed"
                $TaskResult.Details += "Last run failed with result code: $($Task.LastTaskResult)."
            }

            # Check for missing runs (more complex, requires knowing expected schedule)
            # For simplicity, we'll check if a task that should have run recently hasn't
            if ($Task.Triggers) {
                foreach ($Trigger in $Task.Triggers) {
                    if ($Trigger.Enabled -and $Task.Enabled) {
                        # Simple check: if last run was outside lookback days AND trigger implies recent run
                        if ($Task.LastRunTime -lt (Get-Date).AddDays(-$using:LookbackDays) -and $Task.State -eq "Ready") {
                             $TaskResult.Status = if ($TaskResult.Status -eq "N/A") { "Warning" } else { $TaskResult.Status }
                             $TaskResult.Details += "Task hasn't run in the last $using:LookbackDays days despite being enabled."
                        }
                    }
                }
            }
            
            $TaskResult.Status = if ($TaskResult.Status -eq "N/A") { "OK" } else { $TaskResult.Status }
            $Result += $TaskResult
        }
    } -ErrorAction Stop
}
catch {
    Write-Error "An error occurred during scheduled task health check: $($_.Exception.Message)"
}

if ($ExportPath) {
    if ($ExportPath.EndsWith(".csv")) {
        $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
    }
    elseif ($ExportPath.EndsWith(".html")) {
        $Result | ConvertTo-Html -Title "Scheduled Task Health Report" | Out-File -Path $ExportPath -Force
    }
    else {
        Write-Warning "Invalid export path. Please specify a .csv or .html file."
    }
}
else {
    $Result | Format-Table -AutoSize
}
