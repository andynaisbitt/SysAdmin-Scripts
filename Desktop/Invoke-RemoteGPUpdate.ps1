<#
.SYNOPSIS
Remotely updates the Group Policy on a computer.
#>
param (
    [string]$ComputerName
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the computer name"
}

try {
    Invoke-GPUpdate -Computer $ComputerName -Force
}
catch {
    Write-Error "Failed to update Group Policy on '$ComputerName'. Please ensure the computer name is correct and you have the necessary permissions."
}
