<#
.SYNOPSIS
Reports on SQL Server database backup health, including last FULL/DIFF/LOG backup times and flags overdue backups.
#>
param (
    [string[]]$SqlServerInstance, # e.g., "SQL01", "SQL01\SQLEXPRESS"
    [int]$FullBackupThresholdHours = 24, # How old a full backup can be before flagged
    [int]$DiffBackupThresholdHours = 12, # How old a differential backup can be
    [int]$LogBackupThresholdHours = 2,   # How old a log backup can be
    [string]$ExportPath
)

if (-not $SqlServerInstance) {
    $SqlServerInstance = Read-Host "Enter a comma-separated list of SQL Server instances"
    $SqlServerInstance = $SqlServerInstance.Split(',')
}

$Result = @()
foreach ($Instance in $SqlServerInstance) {
    Write-Verbose "Checking backup health for SQL instance: $Instance..."
    try {
        if (-not (Get-Command -Name Invoke-Sqlcmd -ErrorAction SilentlyContinue)) {
            Write-Warning "Invoke-Sqlcmd is not available for $Instance. Skipping backup health check."
            $Result += [PSCustomObject]@{
                SqlServerInstance = $Instance
                DatabaseName      = "N/A"
                BackupType        = "N/A"
                LastBackupTime    = "N/A"
                Status            = "Skipped"
                Reason            = "Invoke-Sqlcmd not found."
            }
            continue
        }

        # Query to get last backup times for all databases
        $Query = @"
            SELECT
                sys.databases.name AS DatabaseName,
                COALESCE(MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date END), 'N/A') AS LastFullBackupTime,
                COALESCE(MAX(CASE WHEN bs.type = 'I' THEN bs.backup_finish_date END), 'N/A') AS LastDifferentialBackupTime,
                COALESCE(MAX(CASE WHEN bs.type = 'L' THEN bs.backup_finish_date END), 'N/A') AS LastLogBackupTime
            FROM
                sys.databases
            LEFT JOIN
                msdb.dbo.backupset bs ON sys.databases.name = bs.database_name
            WHERE
                sys.databases.name NOT IN ('master', 'tempdb', 'model', 'msdb') AND sys.databases.state = 0 -- Online databases
            GROUP BY
                sys.databases.name;
"@
        $BackupInfo = Invoke-Sqlcmd -ServerInstance $Instance -Query $Query -ErrorAction Stop

        foreach ($DbInfo in $BackupInfo) {
            $DatabaseName = $DbInfo.DatabaseName
            $LastFull = $DbInfo.LastFullBackupTime
            $LastDiff = $DbInfo.LastDifferentialBackupTime
            $LastLog = $DbInfo.LastLogBackupTime

            # Evaluate Full Backup Status
            $FullStatus = "OK"
            $FullReason = ""
            if ($LastFull -eq "N/A") {
                $FullStatus = "CRITICAL"
                $FullReason = "No full backup found."
            }
            elseif ($LastFull -lt (Get-Date).AddHours(-$FullBackupThresholdHours)) {
                $FullStatus = "OVERDUE"
                $FullReason = "Last full backup older than $FullBackupThresholdHours hours."
            }
            $Result += [PSCustomObject]@{
                SqlServerInstance = $Instance
                DatabaseName      = $DatabaseName
                BackupType        = "FULL"
                LastBackupTime    = $LastFull
                ThresholdHours    = $FullBackupThresholdHours
                Status            = $FullStatus
                Reason            = $FullReason
            }

            # Evaluate Differential Backup Status (only if full backup exists)
            if ($LastFull -ne "N/A" -and $LastDiff -ne "N/A") {
                $DiffStatus = "OK"
                $DiffReason = ""
                if ($LastDiff -lt (Get-Date).AddHours(-$DiffBackupThresholdHours)) {
                    $DiffStatus = "OVERDUE"
                    $DiffReason = "Last differential backup older than $DiffBackupThresholdHours hours."
                }
                $Result += [PSCustomObject]@{
                    SqlServerInstance = $Instance
                    DatabaseName      = $DatabaseName
                    BackupType        = "DIFF"
                    LastBackupTime    = $LastDiff
                    ThresholdHours    = $DiffBackupThresholdHours
                    Status            = $DiffStatus
                    Reason            = $DiffReason
                }
            }

            # Evaluate Log Backup Status (only if full backup exists and DB is not Simple recovery)
            # This requires checking recovery model, which is a further query. For now, assume if log backup exists.
            if ($LastFull -ne "N/A" -and $LastLog -ne "N/A") {
                $LogStatus = "OK"
                $LogReason = ""
                if ($LastLog -lt (Get-Date).AddHours(-$LogBackupThresholdHours)) {
                    $LogStatus = "OVERDUE"
                    $LogReason = "Last log backup older than $LogBackupThresholdHours hours."
                }
                $Result += [PSCustomObject]@{
                    SqlServerInstance = $Instance
                    DatabaseName      = $DatabaseName
                    BackupType        = "LOG"
                    LastBackupTime    = $LastLog
                    ThresholdHours    = $LogBackupThresholdHours
                    Status            = $LogStatus
                    Reason            = $LogReason
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to check backup health for SQL instance '$Instance': $($_.Exception.Message)"
        $Result += [PSCustomObject]@{
            SqlServerInstance = $Instance
            DatabaseName      = "N/A"
            BackupType        = "N/A"
            LastBackupTime    = "N/A"
            Status            = "ERROR"
            Reason            = $_.Exception.Message
        }
    }
}

if ($ExportPath) {
    if ($ExportPath.EndsWith(".csv")) {
        $Result | Export-Csv -Path $ExportPath -NoTypeInformation
    }
    elseif ($ExportPath.EndsWith(".html")) {
        $Result | ConvertTo-Html -Title "SQL Backup Health Report" | Out-File -Path $ExportPath
    }
    else {
        Write-Warning "Invalid export path. Please specify a .csv or .html file."
    }
}
else {
    $Result | Format-Table -AutoSize
}
