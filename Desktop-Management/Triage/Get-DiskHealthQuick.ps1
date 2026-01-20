<#
.SYNOPSIS
Performs a quick check of physical disk health, free space, and relevant event log warnings, outputting a simple 'replace soon' flag.
#>
param (
    [string]$ComputerName = "localhost"
)

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    OverallDiskStatus = "OK"
    PhysicalDisks = @()
    DiskSpaceSummary = @()
    DiskEventWarnings = "No"
    ReplaceSoonFlag = "No"
    Errors = @()
}

try {
    Write-Host "--- Checking Disk Health on $ComputerName ---"

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # 1. SMART Status (Best Effort via WMI - not all drives/controllers support this reliably)
        $PhysicalDisks = Get-WmiObject -Class Win32_DiskDrive | Select-Object Model, InterfaceType, Size, @{Name="SerialNumber";Expression={$_.SerialNumber.Trim()}}
        $PhysicalDiskStatus = @()
        foreach ($Disk in $PhysicalDisks) {
            $SmartStatus = "N/A"
            try {
                $WmiDisk = Get-WmiObject -Namespace root\wmi -Class MSStorageDriver_FailurePredictStatus -ErrorAction Stop | Where-Object { $_.InstanceName -like "*$($Disk.DeviceID.Replace('\','\\'))*" }
                if ($WmiDisk) {
                    $SmartStatus = if ($WmiDisk.PredictFailure) { "FAIL (SMART PredictFailure)" } else { "OK (SMART)" }
                }
            }
            catch { $SmartStatus = "N/A (SMART WMI Error: $($_.Exception.Message))" }

            $PhysicalDiskStatus += [PSCustomObject]@{
                Model = $Disk.Model
                SizeGB = [math]::Round($Disk.Size / 1GB, 2)
                SerialNumber = $Disk.SerialNumber
                SmartHealth = $SmartStatus
            }
        }
        $using:Result.PhysicalDisks = $PhysicalDiskStatus

        # 2. Free Space on Local Drives
        $LogicalDisks = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object DeviceID, @{N="FreeSpaceGB";E={[math]::Round($_.FreeSpace / 1GB, 2)}}, @{N="SizeGB";E={[math]::Round($_.Size / 1GB, 2)}}, @{N="PercentFree";E={[math]::Round($_.FreeSpace / $_.Size * 100, 2)}}
        $using:Result.DiskSpaceSummary = $LogicalDisks | ForEach-Object { "$($_.DeviceID): $($_.FreeSpaceGB)GB free ($($_.PercentFree)%)" }
        
        # Check for low free space
        if (($LogicalDisks | Where-Object {$_.PercentFree -lt 15}).Count -gt 0) {
            $using:Result.OverallDiskStatus = "WARNING (Low Disk Space)"
            $using:Result.ReplaceSoonFlag = "Yes"
        }

        # 3. Event Log Disk Warnings/Errors
        $DiskEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            ProviderName = 'disk','Ntfs'
            Level = @(1, 2, 3) # Critical, Error, Warning
            StartTime = (Get-Date).AddDays(-7) # Last 7 days
        } -ErrorAction SilentlyContinue | Select-Object TimeCreated, Id, Message -First 10
        if ($DiskEvents) {
            $using:Result.DiskEventWarnings = "Yes"
            $using:Result.Errors += ($DiskEvents | ForEach-Object {"$($_.TimeCreated) [ID:$($_.Id)]: $($_.Message.Substring(0, [System.Math]::Min(100, $_.Message.Length)))"})
            $using:Result.OverallDiskStatus = "WARNING (Disk Errors in Event Log)"
            $using:Result.ReplaceSoonFlag = "Yes"
        } else {
            $using:Result.DiskEventWarnings = "No"
        }

        # Final Replace Soon Flag
        if ($using:Result.PhysicalDisks | Where-Object {$_.SmartHealth -like "FAIL*"}).Count -gt 0) {
            $using:Result.ReplaceSoonFlag = "Yes"
            $using:Result.OverallDiskStatus = "CRITICAL (SMART Failure Predicted)"
        }
        
        $using:Result.OverallStatus = "Success"
    } -ErrorAction Stop

    $Result.OverallStatus = "Success"
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during disk health check: $($_.Exception.Message)"
}

if ($ExportPath) {
    $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
}
else {
    $Result | Format-List
}
