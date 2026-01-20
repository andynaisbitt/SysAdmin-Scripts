<#
.SYNOPSIS
Runs restore readiness checks and compiles a dated evidence folder (CSV, HTML, command output) for audits.
#>
param (
    [string]$EvidenceBasePath, # Base path to save the evidence folder
    [string]$ComputerName,     # Target computer for restore readiness
    [string]$BackupRepositoryPath # Required for Test-RestoreReadiness.ps1
)

if (-not $EvidenceBasePath) {
    $EvidenceBasePath = Read-Host "Enter the base path to save the evidence folder (e.g., C:\AuditEvidence)"
}
if (-not (Test-Path -Path $EvidenceBasePath)) {
    New-Item -Path $EvidenceBasePath -ItemType Directory -Force
}
if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the computer name to test restore readiness for"
}
if (-not $BackupRepositoryPath) {
    $BackupRepositoryPath = Read-Host "Enter the path to the backup repository (e.g., \\fileserver\backups)"
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$EvidenceFolder = Join-Path -Path $EvidenceBasePath -ChildPath "RestoreEvidence-$ComputerName-$Timestamp"
New-Item -Path $EvidenceFolder -ItemType Directory -Force

Write-Host "Compiling restore test evidence in: $EvidenceFolder"

try {
    # 1. Run Test-RestoreReadiness.ps1 and export results
    Write-Host "Running Test-RestoreReadiness.ps1..."
    $RestoreReadinessCsv = Join-Path -Path $EvidenceFolder -ChildPath "RestoreReadinessReport.csv"
    $RestoreReadinessHtml = Join-Path -Path $EvidenceFolder -ChildPath "RestoreReadinessReport.html"

    $RestoreReadinessScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Test-RestoreReadiness.ps1"
    if (Test-Path -Path $RestoreReadinessScriptPath) {
        $RestoreReadinessResults = & $RestoreReadinessScriptPath -ComputerName $ComputerName -BackupRepositoryPath $BackupRepositoryPath -ExportPath $RestoreReadinessCsv
        $RestoreReadinessResults | ConvertTo-Html | Out-File -FilePath $RestoreReadinessHtml
        Write-Host "Restore readiness report saved."
    }
    else {
        Write-Warning "Test-RestoreReadiness.ps1 script not found at $RestoreReadinessScriptPath. Skipping."
    }

    # 2. Add other relevant command outputs
    Write-Host "Collecting additional system information..."
    $CommandsToRun = @(
        "hostname",
        "ipconfig /all",
        "systeminfo",
        "powercfg /list"
    )

    foreach ($Cmd in $CommandsToRun) {
        $CmdFileName = ($Cmd -replace "[^a-zA-Z0-9]") + ".txt"
        $CmdOutputPath = Join-Path -Path $EvidenceFolder -ChildPath $CmdFileName
        Write-Host "Executing '$Cmd'..."
        Invoke-Command -ComputerName $ComputerName -ScriptBlock { cmd.exe /c $using:Cmd } -ErrorAction SilentlyContinue | Out-File -FilePath $CmdOutputPath
    }

    Write-Host "Restore test evidence package created successfully at: $EvidenceFolder"
}
catch {
    Write-Error "An error occurred during evidence package creation: $($_.Exception.Message)"
}
