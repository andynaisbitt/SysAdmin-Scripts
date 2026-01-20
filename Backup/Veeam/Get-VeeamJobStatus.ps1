<#
.SYNOPSIS
Generates a report of the status of all Veeam backup jobs.
#>
param (
    [string]$VeeamServer,
    [pscredential]$Credential
)

if (-not $VeeamServer) {
    $VeeamServer = Read-Host "Enter the Veeam server name"
}

try {
    # Connect to the Veeam server
    Connect-VBRServer -Server $VeeamServer -Credential $Credential

    # Get the status of all backup jobs
    $Jobs = Get-VBRJob
    $Result = foreach ($Job in $Jobs) {
        [PSCustomObject]@{
            JobName      = $Job.Name
            LastResult   = $Job.LastResult
            LastRun      = $Job.LastRun
            NextRun      = $Job.NextRun
            Schedule     = $Job.Schedule
            State        = $Job.State
        }
    }

    # Disconnect from the Veeam server
    Disconnect-VBRServer

    $Result
}
catch {
    Write-Error "Failed to get Veeam job status. Please ensure the Veeam server name and credentials are correct, and that the Veeam PowerShell Toolkit is installed."
}
