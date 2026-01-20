<#
.SYNOPSIS
Detects backup platforms (Veeam/Backup Exec/Windows Server Backup) and outputs a unified backup health report.
#>
param (
    [string]$VeeamServer,
    [pscredential]$VeeamCredential,
    [string]$ExportPath
)

$Result = @()

Write-Host "--- Gathering Backup Health Report ---"

# --- Check for Veeam ---
Write-Host "Checking for Veeam backup status..."
try {
    # Assuming Get-VeeamJobStatus.ps1 is in Backup\Veeam\
    $VeeamScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Veeam\Get-VeeamJobStatus.ps1"
    if (Test-Path -Path $VeeamScriptPath) {
        $VeeamStatus = & $VeeamScriptPath -VeeamServer $VeeamServer -Credential $VeeamCredential -ErrorAction SilentlyContinue
        if ($VeeamStatus) {
            foreach ($Job in $VeeamStatus) {
                $Result += [PSCustomObject]@{
                    Platform     = "Veeam"
                    JobName      = $Job.JobName
                    LastRunResult = $Job.LastResult
                    LastRunTime  = $Job.LastRun
                    Status       = if ($Job.LastResult -eq "Success") { "OK" } else { "Error" }
                    Details      = ""
                }
            }
        }
        else {
            Write-Verbose "No Veeam job status retrieved (or no Veeam jobs configured)."
        }
    }
    else {
        Write-Verbose "Veeam script not found at $VeeamScriptPath."
    }
}
catch {
    Write-Warning "Failed to get Veeam job status: $($_.Exception.Message)"
}

# --- Check for Backup Exec ---
Write-Host "Checking for Backup Exec job history..."
try {
    # Assuming Get-BEJobHistory.ps1 is in Backup\Backup-Exec\
    $BEScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Backup-Exec\Get-BEJobHistory.ps1"
    if (Test-Path -Path $BEScriptPath) {
        $BEStatus = & $BEScriptPath -ErrorAction SilentlyContinue # Assuming default parameters are fine or can be passed
        if ($BEStatus) {
            foreach ($Job in $BEStatus) {
                $Result += [PSCustomObject]@{
                    Platform     = "Backup Exec"
                    JobName      = $Job.JobName
                    LastRunResult = $Job.JobStatus
                    LastRunTime  = $Job.StartTime
                    Status       = if ($Job.JobStatus -eq "Succeeded") { "OK" } else { "Error" }
                    Details      = $Job.JobDetail
                }
            }
        }
        else {
            Write-Verbose "No Backup Exec job history retrieved (or no BE jobs configured)."
        }
    }
    else {
        Write-Verbose "Backup Exec script not found at $BEScriptPath."
    }
}
catch {
    Write-Warning "Failed to get Backup Exec job history: $($_.Exception.Message)"
}

# --- Check for Windows Server Backup ---
Write-Host "Checking for Windows Server Backup status..."
try {
    # This checks local server's Windows Server Backup. Could be extended to remote.
    $Wsbs = Get-WBJob -ErrorAction SilentlyContinue | Select-Object -First 5
    if ($Wsbs) {
        foreach ($WsbJob in $Wsbs) {
            $Result += [PSCustomObject]@{
                Platform     = "Windows Server Backup"
                JobName      = $WsbJob.Policy.Name
                LastRunResult = $WsbJob.Result
                LastRunTime  = $WsbJob.EndTime
                Status       = if ($WsbJob.Result -eq "Success") { "OK" } else { "Error" }
                Details      = $WsbJob.VerboseMessage
            }
        }
    }
    else {
        Write-Verbose "No Windows Server Backup jobs found."
    }
}
catch {
    Write-Warning "Failed to get Windows Server Backup status: $($_.Exception.Message)"
}


if ($Result.Count -gt 0) {
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
else {
    Write-Host "No backup status found from any configured platform."
}
