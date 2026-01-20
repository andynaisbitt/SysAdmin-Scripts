<#
.SYNOPSIS
Stops a running tshark or dumpcap capture process.
#>
try {
    $CaptureProcesses = Get-Process -Name "tshark", "dumpcap" -ErrorAction SilentlyContinue
    if ($CaptureProcesses) {
        foreach ($Process in $CaptureProcesses) {
            Write-Host "Stopping process $($Process.ProcessName) (PID: $($Process.Id))..."
            Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
            Write-Host "Process $($Process.ProcessName) (PID: $($Process.Id)) stopped."
        }
    }
    else {
        Write-Host "No tshark or dumpcap capture processes found running."
    }
}
catch {
    Write-Error "An error occurred while trying to stop capture processes: $($_.Exception.Message)"
}
