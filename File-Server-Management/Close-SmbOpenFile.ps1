<#
.SYNOPSIS
Closes an open SMB file on a server.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName,
    [string]$Path,
    [string[]]$AllowListPaths
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the computer name"
}
if (-not $Path) {
    $Path = Read-Host "Enter the path of the file to close"
}

if ($AllowListPaths -and ($AllowListPaths -notcontains $Path)) {
    Write-Error "The specified path is not in the allow list."
    return
}

try {
    $OpenFile = Get-SmbOpenFile -ComputerName $ComputerName | Where-Object { $_.Path -eq $Path }
    if ($OpenFile) {
        if ($pscmdlet.ShouldProcess("'$($OpenFile.Path)' on '$ComputerName'", "Close File")) {
            Close-SmbOpenFile -InputObject $OpenFile -Force
        }
    }
    else {
        Write-Warning "Could not find an open file with the specified path on '$ComputerName'."
    }
}
catch {
    Write-Error "Failed to close open file. Please ensure the path and computer name are correct, and that you have the necessary permissions."
}
