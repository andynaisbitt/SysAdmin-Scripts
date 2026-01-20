<#
.SYNOPSIS
Backs up a print server's configuration using PrintBRM.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName,
    [string]$BackupPath
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the print server name"
}
if (-not $BackupPath) {
    $BackupPath = Read-Host "Enter the path to save the backup (e.g., C:\PrintBackups)"
}

try {
    # Ensure the backup path exists
    if (-not (Test-Path -Path $BackupPath)) {
        New-Item -Path $BackupPath -ItemType Directory -Force
    }

    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $BackupFileName = "PrintServerConfig_$ComputerName_$Timestamp.brm"
    $FullBackupPath = Join-Path -Path $BackupPath -ChildPath $BackupFileName

    # Construct the PrintBRM command
    $PrintBrmCommand = "PrintBrm.exe -B -S $ComputerName -F `"$FullBackupPath`" -O quiet"

    Write-Host "Starting backup of print server configuration for '$ComputerName' to '$FullBackupPath'..."

    if ($pscmdlet.ShouldProcess("Backup print server configuration on '$ComputerName'", "Backup")) {
        # Execute PrintBRM
        $Process = Start-Process -FilePath PrintBrm.exe -ArgumentList "-B -S $ComputerName -F `"$FullBackupPath`" -O quiet" -PassThru -NoNewWindow
        $Process | Wait-Process

        if ($Process.ExitCode -eq 0) {
            Write-Host "Print server configuration backup completed successfully."
            Write-Host "To restore, use: PrintBrm.exe -R -S $ComputerName -F `"$FullBackupPath`" -O quiet"
        }
        else {
            Write-Error "Print server configuration backup failed with exit code $($Process.ExitCode)."
        }
    }
}
catch {
    Write-Error "An error occurred during print server configuration backup: $($_.Exception.Message)"
}
