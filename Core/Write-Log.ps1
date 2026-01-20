<#
.SYNOPSIS
Provides a consistent way to write log messages to a file, including timestamp and severity.
#>
param (
    [string]$Message,
    [ValidateSet("INFO", "WARN", "ERROR", "DEBUG", "CRITICAL")]
    [string]$Level = "INFO",
    [string]$LogFilePath = (Join-Path $PSScriptRoot "script.log")
)

if (-not (Test-Path -Path (Split-Path -Path $LogFilePath))) {
    New-Item -ItemType Directory -Path (Split-Path -Path $LogFilePath) -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$LogEntry = "[$Timestamp] [$Level] $Message"

try {
    Add-Content -Path $LogFilePath -Value $LogEntry -ErrorAction Stop
}
catch {
    Write-Error "Failed to write to log file '$LogFilePath': $($_.Exception.Message)"
}

# Also write to host for immediate feedback
Write-Host $LogEntry
