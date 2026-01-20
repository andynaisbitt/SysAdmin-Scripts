<#
.SYNOPSIS
Gets the job history from Backup Exec.
#>
param (
    [string]$JobStatus = "Error",
    [int]$Hours = 12
)

try {
    Get-BEJobHistory -JobStatus $JobStatus -FromStartTime (Get-Date).AddHours(-$Hours)
}
catch {
    Write-Error "Could not retrieve Backup Exec job history. Please ensure the Backup Exec module is available and you have the necessary permissions."
}
