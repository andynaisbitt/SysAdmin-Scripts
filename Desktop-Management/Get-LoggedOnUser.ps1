<#
.SYNOPSIS
Gets the users currently logged on to a remote computer.
#>
param (
    [string]$ComputerName
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the computer name"
}

try {
    qwinsta /server:$ComputerName
}
catch {
    Write-Error "Failed to get logged on users from '$ComputerName'. Please ensure the computer name is correct and you have the necessary permissions."
}
