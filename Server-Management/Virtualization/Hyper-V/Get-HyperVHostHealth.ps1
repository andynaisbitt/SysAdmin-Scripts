<#
.SYNOPSIS
Reports on Hyper-V host health, including host resources, VM states, checkpoint details, and replication status.
#>
param (
    [string]$ComputerName = "localhost",
    [string]$ExportPath
)

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    ProcessorCount = "N/A"
    PhysicalMemoryGB = "N/A"
    AvailableMemoryGB = "N/A"
    VMCount = 0
    VMRunningCount = 0
    VMStateSummary = @{}
    ReplicationStatus = "N/A"
    CheckpointCount = 0
    OldestCheckpointDays = 0
    TopWarnings = @()
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "--- Checking Hyper-V Host Health on $ComputerName ---"

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # Host Resources
        $VmHost = Get-VMHost -ErrorAction SilentlyContinue
        if ($VmHost) {
            $using:Result.ProcessorCount = $VmHost.ProcessorCount
            $using:Result.PhysicalMemoryGB = [math]::Round($VmHost.PhysicalMemory / 1GB, 2)
            $using:Result.AvailableMemoryGB = [math]::Round($VmHost.AvailableMemory / 1GB, 2)
        }

        # VM States
        $VMs = Get-VM -ErrorAction SilentlyContinue
        if ($VMs) {
            $using:Result.VMCount = $VMs.Count
            $using:Result.VMRunningCount = ($VMs | Where-Object { $_.State -eq "Running" }).Count
            $using:Result.VMStateSummary = ($VMs | Group-Object State | Select-Object Name, Count | ForEach-Object { "$($_.Name): $($_.Count)" }) -join "; "
        }

        # Checkpoint Count/Age
        $Checkpoints = Get-VMSnapshot -ErrorAction SilentlyContinue
        if ($Checkpoints) {
            $using:Result.CheckpointCount = $Checkpoints.Count
            $OldestCheckpoint = $Checkpoints | Sort-Object CreationTime | Select-Object -First 1
            if ($OldestCheckpoint) {
                $using:Result.OldestCheckpointDays = (New-TimeSpan -Start $OldestCheckpoint.CreationTime).Days
            }
        }

        # Replication Status
        $Replicas = Get-VMReplication -ErrorAction SilentlyContinue
        if ($Replicas) {
            $ReplicationStates = ($Replicas | Group-Object HealthState | Select-Object Name, Count | ForEach-Object { "$($_.Name): $($_.Count)" }) -join "; "
            $using:Result.ReplicationStatus = $ReplicationStates
        }

        # Top Warnings/Errors in Hyper-V Event Logs
        $HyperVLogs = Get-WinEvent -ComputerName $using:ComputerName -FilterHashtable @{
            LogName = 'Microsoft-Windows-Hyper-V-VMMS/Admin', 'Microsoft-Windows-Hyper-V-Worker/Admin'
            Level = @(1, 2, 3) # Critical, Error, Warning
            StartTime = (Get-Date).AddDays(-7) # Last 7 days
        } -ErrorAction SilentlyContinue | Select-Object TimeCreated, Id, Message -First 5
        if ($HyperVLogs) {
            $using:Result.TopWarnings = ($HyperVLogs | ForEach-Object {"$($_.TimeCreated) [ID:$($_.Id)]: $($_.Message.Substring(0, [System.Math]::Min(100, $_.Message.Length)))"})
        }

        $using:Result.OverallStatus = "Success"
    } -ErrorAction Stop

    $Result.OverallStatus = "Success"
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during Hyper-V host health check: $($_.Exception.Message)"
}

if ($ExportPath) {
    $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
}
else {
    $Result | Format-List
}
