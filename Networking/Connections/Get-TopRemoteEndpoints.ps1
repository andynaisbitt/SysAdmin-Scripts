<#
.SYNOPSIS
Groups active TCP connections by remote IP/port, showing top talkers and owning processes.
#>
param (
    [string]$ComputerName,
    [int]$TopCount = 10,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = @()
try {
    Write-Host "Getting active TCP connections from $ComputerName..."
    $Connections = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        Get-NetTCPConnection | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess
    } -ErrorAction Stop

    $GroupedConnections = $Connections | Group-Object -Property RemoteAddress, RemotePort | Select-Object Name, Count, Group

    $Result = $GroupedConnections | Sort-Object -Property Count -Descending | Select-Object -First $TopCount | ForEach-Object {
        $SampleConnection = $_.Group | Select-Object -First 1
        $Process = Get-Process -Id $SampleConnection.OwningProcess -ComputerName $ComputerName -ErrorAction SilentlyContinue
        
        [PSCustomObject]@{
            ComputerName  = $ComputerName
            RemoteEndpoint = $_.Name # Combines RemoteAddress:RemotePort
            ConnectionCount = $_.Count
            ProcessName   = if ($Process) { $Process.ProcessName } else { "N/A" }
            PID           = $SampleConnection.OwningProcess
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
}
catch {
    Write-Error "An error occurred while getting top remote endpoints from '$ComputerName': $($_.Exception.Message)"
}
