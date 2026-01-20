<#
.SYNOPSIS
Checks the readiness for restore by verifying restore points, repository reachability, and last successful job status.
#>
param (
    [string]$ComputerName,
    [string]$BackupRepositoryPath, # E.g., network path to a repository
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = @()

Write-Host "--- Checking Restore Readiness for $ComputerName ---"

# 1. Check if restore points exist (Windows Server Backup example)
Write-Host "Checking for Windows Server Backup restore points..."
try {
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        $RestorePoints = Get-WBBackupSet -ErrorAction SilentlyContinue
        if ($RestorePoints) {
            $using:Result += [PSCustomObject]@{
                ComputerName = $using:ComputerName
                Check        = "Windows Server Backup Restore Points"
                Status       = "OK"
                Details      = "$($RestorePoints.Count) restore points found."
            }
        }
        else {
            $using:Result += [PSCustomObject]@{
                ComputerName = $using:ComputerName
                Check        = "Windows Server Backup Restore Points"
                Status       = "Warning"
                Details      = "No Windows Server Backup restore points found."
            }
        }
    } -ErrorAction SilentlyContinue
}
catch {
    Write-Warning "Failed to check Windows Server Backup restore points on '$ComputerName': $($_.Exception.Message)"
}


# 2. Check Backup Repository Reachability
if ($BackupRepositoryPath) {
    Write-Host "Checking backup repository reachability: $BackupRepositoryPath..."
    try {
        if (Test-Connection -ComputerName (Split-Path -Path $BackupRepositoryPath -Parent) -Quiet -Count 1) {
            if (Test-Path -Path $BackupRepositoryPath) {
                $Result += [PSCustomObject]@{
                    ComputerName = $ComputerName
                    Check        = "Backup Repository Reachability"
                    Status       = "OK"
                    Details      = "Repository path is reachable."
                }
            }
            else {
                $Result += [PSCustomObject]@{
                    ComputerName = $ComputerName
                    Check        = "Backup Repository Reachability"
                    Status       = "Error"
                    Details      = "Repository path exists, but is not accessible."
                }
            }
        }
        else {
            $Result += [PSCustomObject]@{
                ComputerName = $ComputerName
                Check        = "Backup Repository Reachability"
                Status       = "Error"
                Details      = "Backup repository host is not reachable."
            }
        }
    }
    catch {
        Write-Warning "Failed to check backup repository reachability for '$BackupRepositoryPath': $($_.Exception.Message)"
    }
}
else {
    Write-Warning "BackupRepositoryPath not specified, skipping repository reachability check."
}

# 3. Last Successful Backup Job (calls unified health report for now)
Write-Host "Checking last successful backup job status..."
try {
    $BackupHealthScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Get-BackupHealth.ps1"
    if (Test-Path -Path $BackupHealthScriptPath) {
        $UnifiedBackupHealth = & $BackupHealthScriptPath -ErrorAction SilentlyContinue # Assuming this can run without params or has defaults
        $LastSuccessfulJob = $UnifiedBackupHealth | Where-Object {$_.Status -eq "OK"} | Sort-Object LastRunTime -Descending | Select-Object -First 1

        if ($LastSuccessfulJob) {
            $Result += [PSCustomObject]@{
                ComputerName = $ComputerName
                Check        = "Last Successful Backup Job"
                Status       = "OK"
                Details      = "Last successful job: $($LastSuccessfulJob.JobName) on $($LastSuccessfulJob.LastRunTime) (Platform: $($LastSuccessfulJob.Platform))"
            }
        }
        else {
            $Result += [PSCustomObject]@{
                ComputerName = $ComputerName
                Check        = "Last Successful Backup Job"
                Status       = "Error"
                Details      = "No recent successful backup jobs found."
            }
        }
    }
    else {
        Write-Warning "Get-BackupHealth.ps1 script not found, cannot check last successful job status."
    }
}
catch {
    Write-Warning "Failed to check last successful backup job status: $($_.Exception.Message)"
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
