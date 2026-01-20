<#
.SYNOPSIS
Reports on WSUS database health, including database type (WID/SQL), size, disk space, and last cleanup run.
#>
param (
    [string]$WsusServer = "localhost",
    [string]$ExportPath
)

$Result = [PSCustomObject]@{
    WsusServer         = $WsusServer
    DatabaseType       = "N/A"
    DatabaseName       = "N/A"
    DBServerName       = "N/A"
    SUSDBSizeGB        = "N/A"
    DBVolumeFreeSpaceGB = "N/A"
    LastCleanupRun     = "N/A"
    DBGrowthWarning    = "No"
    ErrorDetails       = ""
}

try {
    # 1. Detect Database Type and Server Name
    $WsusService = Get-WmiObject -Class Win32_Service -ComputerName $WsusServer -Filter "Name='WsusService'" -ErrorAction Stop
    $WsusRegKey = "HKLM:\SOFTWARE\Microsoft\Update Services\Server\Setup"
    $SqlInstance = (Invoke-Command -ComputerName $WsusServer -ScriptBlock { Get-ItemProperty -Path $using:WsusRegKey -ErrorAction SilentlyContinue }).SqlServerInstanceName
    
    if ($SqlInstance -like "##WID") {
        $Result.DatabaseType = "Windows Internal Database (WID)"
        $Result.DBServerName = "$WsusServer\##WID"
        $Result.DatabaseName = "SUSDB"
    }
    else {
        $Result.DatabaseType = "SQL Server"
        $Result.DBServerName = $SqlInstance
        $Result.DatabaseName = "SUSDB"
    }

    # 2. Get SUSDB Size
    if (Get-Command -Name Invoke-Sqlcmd -ErrorAction SilentlyContinue) {
        $DbSizeQuery = "SELECT CAST(SUM(size) * 8 / 1024.0 / 1024.0 AS DECIMAL(10, 2)) FROM SUSDB.sys.database_files;"
        $SusdbSize = Invoke-Sqlcmd -ServerInstance $Result.DBServerName -Query $DbSizeQuery -ErrorAction SilentlyContinue
        if ($SusdbSize) { $Result.SUSDBSizeGB = $SusdbSize."Column1" }
    }
    else {
        $Result.ErrorDetails += "Invoke-Sqlcmd not available. Cannot get SUSDB size; "
    }

    # 3. Get Free Disk Space on DB Volume
    $DbFilePath = (Invoke-Command -ComputerName $WsusServer -ScriptBlock { Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Update Services\Server\Setup" -ErrorAction SilentlyContinue }).ContentDir
    if ($DbFilePath) {
        $DbDrive = (Split-Path -Path $DbFilePath -Qualifier)
        $DbVolume = Invoke-Command -ComputerName $WsusServer -ScriptBlock {
            Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $using:DbDrive }
        } -ErrorAction SilentlyContinue
        if ($DbVolume) {
            $Result.DBVolumeFreeSpaceGB = [math]::Round($DbVolume.FreeSpace / 1GB, 2)
        }
    }

    # 4. Last Cleanup Run (from WSUS API)
    Add-Type -Path "$env:ProgramFiles\Update Services\Api\Microsoft.UpdateServices.Administration.dll" -ErrorAction Stop
    $Wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($WsusServer, $false, 8530)
    $CleanupManager = $Wsus.GetCleanupManager()
    $Result.LastCleanupRun = $CleanupManager.LastCleanupTime

    # 5. Warn if SUSDB is "ballooning" (simple heuristic)
    if ($Result.SUSDBSizeGB -gt 40 -and $Result.DatabaseType -eq "Windows Internal Database (WID)") {
        $Result.DBGrowthWarning = "Yes (SUSDB > 40GB on WID)"
    }
}
catch {
    $Result.ErrorDetails = $_.Exception.Message
}

if ($ExportPath) {
    if ($ExportPath.EndsWith(".csv")) {
        $Result | Export-Csv -Path $ExportPath -NoTypeInformation
    }
    elseif ($ExportPath.EndsWith(".html")) {
        $Result | ConvertTo-Html -Title "WSUS Database Health Report" | Out-File -Path $ExportPath
    }
    else {
        Write-Warning "Invalid export path. Please specify a .csv or .html file."
    }
}
else {
    $Result | Format-List
}
