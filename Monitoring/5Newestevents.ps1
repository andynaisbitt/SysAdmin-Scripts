<#
.SYNOPSIS
Gets the newest events from a specified event log.
#>
param (
    [string]$LogName = "System",
    [int]$Newest = 5
)

try {
    Get-EventLog -LogName $LogName -Newest $Newest | Select-Object -Property EventID, TimeWritten, Message | Sort-Object -Property TimeWritten
}
catch {
    Write-Error "Failed to get events from log '$LogName'. Please ensure the log name is correct and you have the necessary permissions."
}
