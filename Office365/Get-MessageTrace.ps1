<#
.SYNOPSIS
Gets the message trace details for a specific message in Exchange Online.
This script should be run in an Exchange Online PowerShell session.
#>
param (
    [string]$MessageID
)

if (-not $MessageID) {
    $MessageID = Read-Host "Enter the Message ID"
}

try {
    Get-MessageTrace -MessageId $MessageID | Get-MessageTraceDetail | Select-Object -Property MessageID, Date, Event, Action, Detail, Data
}
catch {
    Write-Error "Failed to get message trace details for message '$MessageID'. Please ensure the Message ID is correct and you are running this script in an Exchange Online PowerShell session."
}
