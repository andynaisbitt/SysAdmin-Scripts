<#
.SYNOPSIS
Runs read-only SQL Server maintenance checks by default, and optionally executes safe maintenance steps like updating statistics and reorganizing indexes. Always generates a report pack.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$SqlServerInstance, # e.g., "SQL01", "SQL01\SQLEXPRESS"
    [switch]$Execute,          # If present, execute maintenance tasks; otherwise, report-only
    [string]$OutputBasePath = (Join-Path $PSScriptRoot "..\..\Output\SqlMaintenancePacks")
)

if (-not $SqlServerInstance) {
    $SqlServerInstance = Read-Host "Enter the SQL Server instance name"
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ReportFolder = Join-Path -Path $OutputBasePath -ChildPath "$($SqlServerInstance)_MaintenancePack_$Timestamp"

if (-not (Test-Path -Path $OutputBasePath)) {
    New-Item -Path $OutputBasePath -ItemType Directory -Force | Out-Null
}
New-Item -Path $ReportFolder -ItemType Directory -Force | Out-Null
Write-Host "Maintenance report pack will be stored in: $ReportFolder"

$LogFile = Join-Path -Path $ReportFolder -ChildPath "MaintenanceLog.txt"
function Write-MaintenanceLog ([string]$Message) {
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Time - $Message" | Add-Content -Path $LogFile
    Write-Host $Message
}

try {
    if (-not (Get-Command -Name Invoke-Sqlcmd -ErrorAction SilentlyContinue)) {
        throw "Invoke-Sqlcmd is not available. Please install SQL Server Management Studio or SQL Server PowerShell module."
    }

    Write-MaintenanceLog "--- SQL Maintenance Pack for $SqlServerInstance (Execute: $Execute) ---"

    # 1. Check Index Fragmentation and report
    Write-MaintenanceLog "Checking index fragmentation..."
    $IndexFragQuery = @"
        SELECT
            DB_NAME(ips.database_id) AS DatabaseName,
            OBJECT_NAME(ips.object_id) AS ObjectName,
            i.name AS IndexName,
            ips.avg_fragmentation_in_percent
        FROM
            sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
        INNER JOIN
            sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
        WHERE
            ips.avg_fragmentation_in_percent > 10 AND ips.index_id > 0
        ORDER BY
            ips.avg_fragmentation_in_percent DESC;
"@
    $IndexFragmentation = Invoke-Sqlcmd -ServerInstance $SqlServerInstance -Query $IndexFragQuery -ErrorAction Stop
    $IndexFragmentation | Export-Csv -Path (Join-Path $ReportFolder "IndexFragmentationReport.csv") -NoTypeInformation -Force
    Write-MaintenanceLog "Index fragmentation report saved."

    # 2. Check Stale Statistics and report
    Write-MaintenanceLog "Checking stale statistics (estimated)..."
    $StaleStatsQuery = @"
        SELECT
            DB_NAME(s.database_id) AS DatabaseName,
            OBJECT_NAME(s.object_id) AS TableName,
            s.name AS StatisticsName,
            STATS_DATE(s.object_id, s.stats_id) AS LastUpdated
        FROM
            sys.stats s
        WHERE
            STATS_DATE(s.object_id, s.stats_id) < DATEADD(month, -1, GETDATE())
        ORDER BY LastUpdated ASC;
"@
    $StaleStatistics = Invoke-Sqlcmd -ServerInstance $SqlServerInstance -Query $StaleStatsQuery -ErrorAction Stop
    $StaleStatistics | Export-Csv -Path (Join-Path $ReportFolder "StaleStatisticsReport.csv") -NoTypeInformation -Force
    Write-MaintenanceLog "Stale statistics report saved."


    if ($Execute) {
        Write-MaintenanceLog "--- EXECUTE MODE ENABLED ---"
        if ($pscmdlet.ShouldProcess("Execute maintenance tasks on $SqlServerInstance", "Execute Maintenance")) {
            # Execute: Index Reorganization/Rebuild
            $IndexFragmentation | ForEach-Object {
                if ($_.avg_fragmentation_in_percent -gt 30) { # Rebuild threshold
                    $Action = "REBUILD"
                    $Sql = "ALTER INDEX `"$($_.IndexName)`" ON `"$($_.ObjectName)`" REBUILD WITH (ONLINE = ON (WAIT_AT_LOW_PRIORITY (MAX_DURATION = 1 MINUTES, ABORT_AFTER_WAIT = NONE)), SORT_IN_TEMPDB = ON, DATA_COMPRESSION = NONE);"
                }
                elseif ($_.avg_fragmentation_in_percent -gt 10) { # Reorganize threshold
                    $Action = "REORGANIZE"
                    $Sql = "ALTER INDEX `"$($_.IndexName)`" ON `"$($_.ObjectName)`" REORGANIZE;"
                }
                
                if ($Sql) {
                    Write-MaintenanceLog "Executing index $Action for $($_.ObjectName).$($_.IndexName) (Frag: $($_.avg_fragmentation_in_percent)%)."
                    Invoke-Sqlcmd -ServerInstance $SqlServerInstance -Query $Sql -ErrorAction SilentlyContinue
                }
            }

            # Execute: Update Stale Statistics
            $StaleStatistics | ForEach-Object {
                Write-MaintenanceLog "Updating statistics for $($_.DatabaseName).$($_.TableName).$($_.StatisticsName)."
                $Sql = "USE `"$($_.DatabaseName)`"; UPDATE STATISTICS `"$($_.TableName)`"(`"$($_.StatisticsName)`") WITH FULLSCAN;"
                Invoke-Sqlcmd -ServerInstance $SqlServerInstance -Query $Sql -ErrorAction SilentlyContinue
            }
        }
    }
    else {
        Write-MaintenanceLog "--- REPORT ONLY MODE --- No changes were made. Use -Execute to perform maintenance."
    }

    Write-MaintenanceLog "--- SQL Maintenance Pack for $SqlServerInstance Complete ---"
}
catch {
    Write-MaintenanceLog "An error occurred during SQL Maintenance Pack execution: $($_.Exception.Message)"
    Write-Error "An error occurred during SQL Maintenance Pack execution: $($_.Exception.Message)"
}
finally {
    # Open the report folder
    Invoke-Item -Path $ReportFolder -ErrorAction SilentlyContinue
}
