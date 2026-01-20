<#
.SYNOPSIS
Tests the connection between a source and a destination computer.
#>
param (
    [string]$Destination,
    [string]$Source,
    [int]$Count = 4
)

if (-not $Destination) {
    $Destination = Read-Host "Enter the destination computer"
}

if (-not $Source) {
    $Source = Read-Host "Enter the source computer"
}

try {
    Test-Connection -ComputerName $Destination -Source $Source -Count $Count
}
catch {
    Write-Error "Failed to test connection between '$Source' and '$Destination'. Please ensure the computer names are correct and you have the necessary permissions."
}
