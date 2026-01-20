<#
.SYNOPSIS
[DEPRECATED] Logs off a remote user from a terminal server session.
Please use Logoff-RDPSession.ps1 instead.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName,
    [string]$UserName,
    [int]$SessionId
)

Write-Warning "This script is deprecated. Please use 'Logoff-RDPSession.ps1' instead."

# Call the new, standardized script
& (Join-Path $PSScriptRoot "Logoff-RDPSession.ps1") -ComputerName $ComputerName -UserName $UserName -SessionId $SessionId -Confirm:$Confirm -WhatIf:$WhatIf
