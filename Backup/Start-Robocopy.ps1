<#
.SYNOPSIS
A PowerShell wrapper for the Robocopy command.
#>
param (
    [string]$SourcePath,
    [string]$DestinationPath,
    [string]$LogPath,
    [switch]$Mirror,
    [switch]$Move,
    [string[]]$ExcludeFiles,
    [string[]]$ExcludeDirs,
    [switch]$MultiThread
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
    "/log:$LogPath"
)

if ($Mirror) {
    $RobocopyArgs += "/mir"
}
if ($Move) {
    $RobocopyArgs += "/move"
}
if ($ExcludeFiles) {
    $RobocopyArgs += "/xf", $ExcludeFiles
}
if ($ExcludeDirs) {
    $RobocopyArgs += "/xd", $ExcludeDirs
}
if ($MultiThread) {
    $RobocopyArgs += "/mt"
}

try {
    robocopy @RobocopyArgs
    if ($LASTEXITCODE -ge 8) {
        throw "Robocopy failed with exit code $LASTEXITCODE. Check the log file for details: $LogPath"
    }
}
catch {
    Write-Error $_
}
