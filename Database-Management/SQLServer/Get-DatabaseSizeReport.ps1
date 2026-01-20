<#
.SYNOPSIS
Reports on SQL Server database sizes, growth settings, and free space per database.
#>
param (
    [string[]]$SqlServerInstance, # e.g., "SQL01", "SQL01\SQLEXPRESS"
    [string]$ExportPath
)

if (-not $SqlServerInstance) {
    $SqlServerInstance = Read-Host "Enter a comma-separated list of SQL Server instances"
    $SqlServerInstance = $SqlServerInstance.Split(',')
}

$Result = @()
foreach ($Instance in $SqlServerInstance) {
    Write-Verbose "Checking database sizes for SQL instance: $Instance..."
    try {
        if (-not (Get-Command -Name Invoke-Sqlcmd -ErrorAction SilentlyContinue)) {
            Write-Warning "Invoke-Sqlcmd is not available for $Instance. Skipping database size check."
            $Result += [PSCustomObject]@{
                SqlServerInstance = $Instance
                DatabaseName      = "N/A"
                DataSizeMB        = "Skipped"
                LogSizeMB         = "Skipped"
                FreeSpaceMB       = "Skipped"
                AutoGrowth        = "Skipped"
            }
            continue
        }

        # Query to get database sizes, free space, and autogrowth settings
        $Query = @"
            SELECT
                db.name AS DatabaseName,
                SUM(CASE WHEN type_desc = 'ROWS' THEN size * 8 / 1024 END) AS DataSizeMB,
                SUM(CASE WHEN type_desc = 'LOG' THEN size * 8 / 1024 END) AS LogSizeMB,
                SUM(CASE WHEN type_desc = 'ROWS' THEN ((size * 8 / 1024.0) - (FILEPROPERTY(name, 'SpaceUsed') * 8 / 1024.0)) END) AS DataFreeSpaceMB,
                'Autogrowth: ' +
                CASE mf.is_percent_growth
                    WHEN 1 THEN CAST(mf.growth AS VARCHAR(10)) + '%'
                    ELSE CAST(mf.growth * 8 / 1024 AS VARCHAR(10)) + ' MB'
                END AS AutoGrowthSettings
            FROM
                sys.master_files mf
            JOIN
                sys.databases db ON mf.database_id = db.database_id
            WHERE
                db.name NOT IN ('master', 'tempdb', 'model', 'msdb')
            GROUP BY
                db.name, mf.file_id, mf.is_percent_growth, mf.growth
            ORDER BY
                db.name;
"@
        $DbInfo = Invoke-Sqlcmd -ServerInstance $Instance -Query $Query -ErrorAction Stop

        foreach ($Db in $DbInfo) {
            $Result += [PSCustomObject]@{
                SqlServerInstance = $Instance
                DatabaseName      = $Db.DatabaseName
                DataSizeMB        = [math]::Round($Db.DataSizeMB, 2)
                LogSizeMB         = [math]::Round($Db.LogSizeMB, 2)
                DataFreeSpaceMB   = [math]::Round($Db.DataFreeSpaceMB, 2)
                AutoGrowth        = $Db.AutoGrowthSettings
            }
        }
    }
    catch {
        Write-Warning "Failed to check database sizes for SQL instance '$Instance': $($_.Exception.Message)"
        $Result += [PSCustomObject]@{
            SqlServerInstance = $Instance
            DatabaseName      = "N/A"
            DataSizeMB        = "Error"
            LogSizeMB         = "Error"
            DataFreeSpaceMB   = "Error"
            AutoGrowth        = "Error"
        }
    }
}

# Identify top 10 largest databases
$Top10Largest = $Result | Sort-Object -Property DataSizeMB -Descending | Select-Object -First 10

if ($ExportPath) {
    if ($ExportPath.EndsWith(".csv")) {
        $Result | Export-Csv -Path $ExportPath -NoTypeInformation
    }
    elseif ($ExportPath.EndsWith(".html")) {
        $HtmlContent = $Result | ConvertTo-Html -Title "SQL Database Size Report"
        $HtmlContent += "<h2>Top 10 Largest Databases</h2>"
        $HtmlContent += $Top10Largest | ConvertTo-Html -As Table
        $HtmlContent | Out-File -Path $ExportPath
    }
    else {
        Write-Warning "Invalid export path. Please specify a .csv or .html file."
    }
}
else {
    Write-Host "--- All Databases ---"
    $Result | Format-Table -AutoSize
    Write-Host "`n--- Top 10 Largest Databases ---"
    $Top10Largest | Format-Table -AutoSize
}
