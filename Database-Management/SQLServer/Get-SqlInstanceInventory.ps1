<#
.SYNOPSIS
Gathers inventory details for SQL Server instances, including version, edition, collation, memory, core count, and database list.
#>
param (
    [string[]]$SqlServerInstance, # e.g., "SQL01", "SQL01\SQLEXPRESS"
    [string]$ExportPath
)

if (-not $SqlServerInstance) {
    $SqlServerInstance = Read-Host "Enter a comma-separated list of SQL Server instances"
    $SqlServerInstance = $SqlServerInstance.Split(',')
}

$Result = foreach ($Instance in $SqlServerInstance) {
    Write-Verbose "Getting inventory for SQL instance: $Instance..."
    $InstanceDetails = [PSCustomObject]@{
        SqlServerInstance  = $Instance
        Version            = "N/A"
        Edition            = "N/A"
        Collation          = "N/A"
        MaxServerMemoryMB  = "N/A"
        CoreCount          = "N/A"
        DatabaseCount      = "N/A"
        BackupPath         = "N/A"
        LastFullBackupDate = "N/A"
        Status             = "Failed"
        ErrorDetails       = ""
    }

    try {
        # Check if Invoke-Sqlcmd is available
        if (Get-Command -Name Invoke-Sqlcmd -ErrorAction SilentlyContinue) {
            Write-Verbose "Using Invoke-Sqlcmd for $Instance."
            $SqlConnection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection
            $SqlConnection.ServerInstance = $Instance
            $SqlConnection.LoginSecure = $true # Use Windows Authentication
            $SqlConnection.Connect()

            $SqlInstance = New-Object Microsoft.SqlServer.Management.Smo.Server($SqlConnection)
            
            # Basic Instance Info
            $InstanceDetails.Version = $SqlInstance.VersionString
            $InstanceDetails.Edition = $SqlInstance.Edition
            $InstanceDetails.Collation = $SqlInstance.Collation
            $InstanceDetails.CoreCount = $SqlInstance.ProcessorCount

            # Max Server Memory (from SQL config)
            $Config = $SqlInstance.Configuration.Properties | Where-Object { $_.Name -eq "max server memory (MB)" }
            if ($Config) { $InstanceDetails.MaxServerMemoryMB = $Config.RunValue }

            # Database Count
            $InstanceDetails.DatabaseCount = $SqlInstance.Databases.Count

            # Backup Path (can be discovered from a typical backup history query)
            $BackupQuery = "
                SELECT top 1 mf.physical_device_name
                FROM msdb.dbo.backupset bs
                JOIN msdb.dbo.backupmediafamily mf ON bs.media_set_id = mf.media_set_id
                WHERE bs.type = 'D' -- D for full backup
                ORDER BY bs.backup_start_date DESC;
            "
            $BackupPathResult = Invoke-Sqlcmd -ServerInstance $Instance -Query $BackupQuery -ErrorAction SilentlyContinue
            if ($BackupPathResult) { $InstanceDetails.BackupPath = $BackupPathResult.physical_device_name }

            # Last Full Backup Date (for a sample database or system DBs)
            $LastBackupQuery = "
                SELECT TOP 1 bs.database_name, bs.backup_finish_date
                FROM msdb.dbo.backupset bs
                WHERE bs.type = 'D' -- D for full backup
                ORDER BY bs.backup_finish_date DESC;
            "
            $LastBackupResult = Invoke-Sqlcmd -ServerInstance $Instance -Query $LastBackupQuery -ErrorAction SilentlyContinue
            if ($LastBackupResult) { $InstanceDetails.LastFullBackupDate = $LastBackupResult.backup_finish_date }

            $InstanceDetails.Status = "OK"
            $SqlConnection.Disconnect()
        }
        else {
            # Fallback for WMI/Registry if Invoke-Sqlcmd not available
            Write-Warning "Invoke-Sqlcmd not found. Falling back to WMI/Registry for $Instance."
            $ServerNameOnly = $Instance.Split('\')[0]
            $WmiSql = Get-CimInstance -ClassName "Win32_Service" -ComputerName $ServerNameOnly -Filter "Name LIKE 'MSSQL$($Instance.Split('\')[1])%' OR Name = 'MSSQLSERVER'" -ErrorAction SilentlyContinue
            if ($WmiSql) {
                $InstanceDetails.Version = $WmiSql.DisplayName
                $InstanceDetails.Status = "Partial (WMI)"
            }
            else {
                $InstanceDetails.ErrorDetails = "Instance not found via WMI."
            }
        }
    }
    catch {
        $InstanceDetails.ErrorDetails = $_.Exception.Message
    }
    $InstanceDetails
}

if ($ExportPath) {
    if ($ExportPath.EndsWith(".csv")) {
        $Result | Export-Csv -Path $ExportPath -NoTypeInformation
    }
    elseif ($ExportPath.EndsWith(".json")) {
        $Result | ConvertTo-Json -Depth 5 | Out-File -Path $ExportPath
    }
    else {
        Write-Warning "Invalid export path. Please specify a .csv or .json file."
    }
}
else {
    $Result | Format-Table -AutoSize
}
