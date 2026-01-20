<#
.SYNOPSIS
Identifies which process is using a specific port.
#>
param (
    [int]$Port
)

if (-not $Port) {
    $Port = Read-Host "Enter the port number to check (e.g., 445)"
}

try {
    $Connection = Get-NetTCPConnection | Where-Object { $_.LocalPort -eq $Port -or $_.RemotePort -eq $Port } | Select-Object -First 1
    
    if ($Connection) {
        $Process = Get-Process -Id $Connection.OwningProcess -ErrorAction SilentlyContinue
        $ServiceName = (Get-WmiObject -Class Win32_Service -Filter "ProcessId = $($Connection.OwningProcess)" -ErrorAction SilentlyContinue).Name
        
        [PSCustomObject]@{
            Port        = $Port
            ProcessName = if ($Process) { $Process.ProcessName } else { "N/A" }
            PID         = $Connection.OwningProcess
            ServiceName = if ($ServiceName) { $ServiceName } else { "N/A" }
            CommandLine = if ($Process) { (Get-WmiObject Win32_Process -Filter "ProcessId = $($Connection.OwningProcess)").CommandLine } else { "N/A" }
        }
    }
    else {
        Write-Host "No active connection or listening process found for port $Port."
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
