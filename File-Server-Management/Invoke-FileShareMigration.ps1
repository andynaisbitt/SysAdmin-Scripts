<#
.SYNOPSIS
A robust wrapper for Robocopy specifically tailored for file share migrations.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$SourcePath,
    [string]$DestinationPath,
    [string]$LogFolderPath, # Folder for Robocopy logs
    [switch]$Mirror,        # Use /MIR (includes /E, /PURGE)
    [switch]$CopyEmptyDirectories, # Use /E instead of /MIR
    [int]$RetryCount = 3,
    [int]$RetryDelaySeconds = 30,
    [string[]]$ExcludeFiles,
    [string[]]$ExcludeDirectories,
    [int]$MultiThreadCount = 8 # /MT:n
)

if (-not $SourcePath) {
    $SourcePath = Read-Host "Enter the source path for migration"
}
if (-not $DestinationPath) {
    $DestinationPath = Read-Host "Enter the destination path for migration"
}
if (-not $LogFolderPath) {
    $LogFolderPath = Join-Path $PSScriptRoot "Logs"
}
if (-not (Test-Path -Path $LogFolderPath)) {
    New-Item -Path $LogFolderPath -ItemType Directory -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path -Path $LogFolderPath -ChildPath "Robocopy_Migration_$Timestamp.log"

$RobocopyArgs = @(
    "`"$SourcePath`"",
    "`"$DestinationPath`"",
    "/DCOPY:T",       # Copy directory timestamps
    "/COPY:DATSOU",   # Copy Data, Attributes, Timestamps, Security, Owner, Audit info
    "/SEC",           # Copy security information (ACLs, owner, auditing)
    "/R:$RetryCount", # Number of retries
    "/W:$RetryDelaySeconds", # Wait time between retries
    "/V",             # Verbose output
    "/NP",            # No progress indicator (good for logs)
    "/ETA",           # Show Estimated Time of Arrival
    "/MT:$MultiThreadCount", # Multi-threading
    "/LOG+:$LogFile", # Append output to log file
    "/TEE"            # Output to console and log file
)

if ($Mirror) {
    $RobocopyArgs += "/MIR" # Mirror a directory tree
}
elseif ($CopyEmptyDirectories) {
    $RobocopyArgs += "/E" # Copy subdirectories, including empty ones
}
else {
    $RobocopyArgs += "/S" # Copy subdirectories, excluding empty ones
}

if ($ExcludeFiles) {
    $RobocopyArgs += "/XF"
    $RobocopyArgs += $ExcludeFiles
}
if ($ExcludeDirectories) {
    $RobocopyArgs += "/XD"
    $RobocopyArgs += $ExcludeDirectories
}

Write-Host "Starting file share migration from '$SourcePath' to '$DestinationPath'..."
Write-Host "Log file: $LogFile"
Write-Host "Robocopy command: robocopy $($RobocopyArgs -join ' ')"

if ($pscmdlet.ShouldProcess("Migrate files from '$SourcePath' to '$DestinationPath'", "File Share Migration")) {
    try {
        $RobocopyOutput = (robocopy @RobocopyArgs)
        $RobocopyExitCode = $LASTEXITCODE

        Write-Host "Robocopy finished with exit code: $RobocopyExitCode"

        # Robocopy Exit Codes:
        # 0 - No errors, no files copied.
        # 1 - All files copied successfully.
        # 2 - Some extra files or directories were detected. No copy errors occurred.
        # 3 - Some files were copied. No extra files or copy errors were detected.
        # 4 - Some mismatched files or directories were detected. No copy errors occurred.
        # 5 - Some files were copied, and some mismatched files or directories were detected. No copy errors occurred.
        # 6 - Some extra files or directories were detected, and some mismatched files or directories were detected. No copy errors occurred.
        # 7 - Some files were copied, and some extra files or directories were detected, and some mismatched files or directories were detected. No copy errors occurred.
        # 8 - Some files were not copied (and no other errors occurred).
        # Any other value indicates an error during the copy process.

        switch ($RobocopyExitCode) {
            0 { Write-Host "Migration completed: No changes were made." }
            1 { Write-Host "Migration completed: All files copied successfully." }
            2 { Write-Host "Migration completed: Extra files/dirs detected in destination." }
            3 { Write-Host "Migration completed: Some files copied successfully." }
            4 { Write-Warning "Migration completed: Some files/dirs mismatched." }
            5 { Write-Warning "Migration completed: Some files copied, some mismatched." }
            6 { Write-Warning "Migration completed: Extra files/dirs and mismatches detected." }
            7 { Write-Warning "Migration completed: Files copied, extras, and mismatches detected." }
            default { Write-Error "Migration failed: Robocopy returned exit code $RobocopyExitCode. See log for details." }
        }
    }
    catch {
        Write-Error "An unexpected error occurred during Robocopy execution: $($_.Exception.Message)"
    }
}
