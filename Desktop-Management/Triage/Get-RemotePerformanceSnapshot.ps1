<#
.SYNOPSIS
Takes a sampled snapshot of performance metrics (CPU, RAM, disk queue, network) over a short period.
#>
param (
    [string]$ComputerName,
    [int]$SampleSeconds = 60
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the computer name"
}

try {
    Write-Host "Starting performance snapshot on '$ComputerName' for $SampleSeconds seconds..."

    $CounterSamples = Get-Counter -ComputerName $ComputerName -Counter "\Processor(_Total)\% Processor Time", "\Memory\Available MBytes", "\PhysicalDisk(_Total)\Avg. Disk Queue Length", "\Network Interface(*)\Bytes Total/sec" -SampleInterval 1 -MaxSamples $SampleSeconds

    $Data = $CounterSamples.CounterSamples | ForEach-Object {
        [PSCustomObject]@{
            Timestamp = $_.Timestamp
            Counter   = $_.Path
            Value     = $_.CookedValue
        }
    }

    # Summarize the results
    $Summary = @{
        ComputerName = $ComputerName
        SampleDurationSeconds = $SampleSeconds
        AverageCpuUsage = ($Data | Where-Object { $_.Counter -like "*\% Processor Time" } | Measure-Object -Property Value -Average).Average
        AverageAvailableMemoryMB = ($Data | Where-Object { $_.Counter -like "*\Available MBytes" } | Measure-Object -Property Value -Average).Average
        AverageDiskQueueLength = ($Data | Where-Object { $_.Counter -like "*\Avg. Disk Queue Length" } | Measure-Object -Property Value -Average).Average
        AverageNetworkBytesPerSec = ($Data | Where-Object { $_.Counter -like "*\Bytes Total/sec" } | Measure-Object -Property Value -Average).Average
    }

    Write-Host "`n--- Performance Snapshot Summary for $ComputerName ---"
    $Summary.GetEnumerator() | ForEach-Object {
        Write-Host "$($_.Name): $($_.Value)"
    }
}
catch {
    Write-Error "An error occurred while taking performance snapshot on '$ComputerName': $($_.Exception.Message)"
}
