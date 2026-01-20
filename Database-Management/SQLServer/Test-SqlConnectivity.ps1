<#
.SYNOPSIS
Checks SQL Server connectivity, including DNS resolution, TCP port, instance reachability, and authentication mode.
#>
param (
    [string[]]$SqlServerInstance, # e.g., "SQL01", "SQL01\SQLEXPRESS"
    [int]$Port = 1433,
    [string]$ExportPath
)

if (-not $SqlServerInstance) {
    $SqlServerInstance = Read-Host "Enter a comma-separated list of SQL Server instances"
    $SqlServerInstance = $SqlServerInstance.Split(',')
}

$Result = foreach ($Instance in $SqlServerInstance) {
    $ServerName = $Instance.Split('\')[0]
    Write-Verbose "Testing connectivity to $Instance..."
    
    $DnsResult = $null
    $TcpResult = $null
    $SqlConnection = $null
    $AuthMode = "N/A"
    $ErrorStatus = $null

    try {
        # 1. DNS Resolve
        $DnsResult = Resolve-DnsName -Name $ServerName -ErrorAction Stop
        
        # 2. TCP Port Test
        $TcpResult = Test-NetConnection -ComputerName $ServerName -Port $Port -InformationLevel Quiet -ErrorAction Stop
        
        # 3. Instance Reachable & Auth Mode (requires SqlServer module or .NET)
        try {
            # Attempt to connect using Windows Authentication
            $ConnectionString = "Server=$Instance;Database=master;Integrated Security=True;Connection Timeout=5"
            $SqlConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
            $SqlConnection.Open()
            
            # Get Authentication Mode
            $Query = "SELECT SERVERPROPERTY('IsIntegratedSecurityOnly') AS IsIntegratedSecurityOnly;"
            $SqlCommand = New-Object System.Data.SqlClient.SqlCommand($Query, $SqlConnection)
            $Reader = $SqlCommand.ExecuteReader()
            if ($Reader.Read()) {
                $IsIntegratedSecurityOnly = $Reader.GetValue(0)
                $AuthMode = if ($IsIntegratedSecurityOnly -eq 1) { "Windows Authentication Only" } else { "SQL Server and Windows Authentication mode" }
            }
            $Reader.Close()
        }
        catch {
            $ErrorStatus = "Instance Unreachable or Auth Failed: $($_.Exception.Message)"
        }
        finally {
            if ($SqlConnection -and $SqlConnection.State -eq 'Open') {
                $SqlConnection.Close()
            }
        }
    }
    catch {
        $ErrorStatus = "DNS or Port Test Failed: $($_.Exception.Message)"
    }

    [PSCustomObject]@{
        SqlServerInstance = $Instance
        DnsResolvedIP     = if ($DnsResult) { ($DnsResult.IPAddress -join ", ") } else { "Failed" }
        TcpPortReachable  = if ($TcpResult) { $TcpResult.TcpTestSucceeded } else { "Failed" }
        InstanceReachable = if ($SqlConnection -and $SqlConnection.State -eq 'Closed' -and -not $ErrorStatus) { "Yes" } else { "No" }
        AuthenticationMode = $AuthMode
        Status            = if ($ErrorStatus) { "Error" } else { "OK" }
        ErrorDetails      = $ErrorStatus
    }
}

if ($ExportPath) {
    if ($ExportPath.EndsWith(".csv")) {
        $Result | Export-Csv -Path $ExportPath -NoTypeInformation
    }
    elseif ($ExportPath.EndsWith(".html")) {
        $Result | ConvertTo-Html | Out-File -Path $ExportPath
    }
    else {
        Write-Warning "Invalid export path. Please specify a .csv or .html file."
    }
}
else {
    $Result | Format-Table -AutoSize
}
