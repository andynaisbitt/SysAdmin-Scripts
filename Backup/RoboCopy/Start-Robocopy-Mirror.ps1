<#
.SYNOPSIS
Creates a mirrored backup of a directory using Robocopy.
#>
param (
    [string]$SourcePath,
    [string]$DestinationPath,
    [string]$LogPath
)

if (-not $SourcePath) {
    $SourcePath = Read-Host "Enter the source path"
}
if (-not $DestinationPath) {
    $DestinationPath = Read-Host "Enter the destination path"
}
if (-not $LogPath) {
    $LogPath = Read-Host "Enter the log path"
}

$RobocopyArgs = @(
    $SourcePath,
    $DestinationPath,
    "/mir",
    "/log:$LogPath"
)

try {
    robocopy @RobocopyArgs
    if ($LASTEXITCODE -ge 8) {
        throw "Robocopy failed with exit code $LASTEXITCODE. Check the log file for details: $LogPath"
    }
}
catch {
    Write-Error $_
}
