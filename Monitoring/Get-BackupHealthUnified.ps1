<#
.SYNOPSIS
Calls existing Veeam and Backup Exec job status scripts and combines their output into a unified backup health report.
#>
param (
    [string]$VeeamServer,
    [pscredential]$VeeamCredential,
    [string]$ExportPath
)

$Result = @()

# --- Get Veeam Job Status ---
Write-Host "Collecting Veeam backup job status..."
try {
    # Assuming Get-VeeamJobStatus.ps1 is in Backup\Veeam\
    $VeeamScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "..\Backup\Veeam\Get-VeeamJobStatus.ps1"
    if (Test-Path -Path $VeeamScriptPath) {
        $VeeamStatus = & $VeeamScriptPath -VeeamServer $VeeamServer -Credential $VeeamCredential -ErrorAction Stop
        foreach ($Job in $VeeamStatus) {
            $Result += [PSCustomObject]@{
                BackupPlatform = "Veeam"
                JobName        = $Job.JobName
                LastRunResult  = $Job.LastResult
                LastRunTime    = $Job.LastRun
                Status         = if ($Job.LastResult -eq "Success") { "OK" } else { "Error" }
                Details        = ""
            }
        }
    }
    else {
        Write-Warning "Veeam script not found: $VeeamScriptPath"
    }
}
catch {
    Write-Warning "Failed to get Veeam job status: $($_.Exception.Message)"
}

# --- Get Backup Exec Job History ---
Write-Host "Collecting Backup Exec job history..."
try {
    # Assuming Get-BEJobHistory.ps1 is in Backup\Backup-Exec\
    $BEScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "..\Backup\Backup-Exec\Get-BEJobHistory.ps1"
    if (Test-Path -Path $BEScriptPath) {
        $BEStatus = & $BEScriptPath -ErrorAction Stop # Assuming default parameters are fine or can be passed
        foreach ($Job in $BEStatus) {
            $Result += [PSCustomObject]@{
                BackupPlatform = "Backup Exec"
                JobName        = $Job.JobName
                LastRunResult  = $Job.JobStatus
                LastRunTime    = $Job.StartTime
                Status         = if ($Job.JobStatus -eq "Succeeded") { "OK" } else { "Error" }
                Details        = $Job.JobDetail
            }
        }
    }
    else {
        Write-Warning "Backup Exec script not found: $BEScriptPath"
    }
}
catch {
    Write-Warning "Failed to get Backup Exec job history: $($_.Exception.Message)"
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
