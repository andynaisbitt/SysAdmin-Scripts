<#
.SYNOPSIS
Performs a quick triage of a Windows server, gathering key operational and health metrics.
#>
param (
    [string]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the computer name of the server to triage"
}

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    Uptime = "N/A"
    PendingReboot = "N/A"
    DiskSpaceSummary = "N/A"
    KeyServicesStatus = "N/A"
    LastCriticalEvents = "N/A"
    PatchStatus = "N/A"
    CertExpiryStatus = "N/A"
    RDPSessionsCount = "N/A"
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "Starting server triage on '$ComputerName'..."

    # 1. Uptime and Pending Reboot (Leverage Get-ServerUptimeAndRebootHistory.ps1)
    Write-Verbose "Getting uptime and pending reboot status..."
    $UptimeInfo = & (Join-Path $PSScriptRoot "Get-ServerUptimeAndRebootHistory.ps1") -ComputerName $ComputerName -ErrorAction SilentlyContinue
    if ($UptimeInfo) {
        $Result.Uptime = $UptimeInfo.Uptime
        $Result.PendingReboot = $UptimeInfo.PendingReboot
    } else { $Result.Errors += "Failed to get Uptime/Reboot info." }

    # 2. Disk Space Summary (Leverage Get-ComputerInventory.ps1 logic or Get-CimInstance directly)
    Write-Verbose "Getting disk space summary..."
    $DiskInfo = Invoke-Command -ComputerName $ComputerName -ScriptBlock { Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object DeviceID, @{N="FreeGB";E={[math]::Round($_.FreeSpace / 1GB, 2)}}, @{N="SizeGB";E={[math]::Round($_.Size / 1GB, 2)}} } -ErrorAction SilentlyContinue
    if ($DiskInfo) {
        $Result.DiskSpaceSummary = ($DiskInfo | ForEach-Object { "$($_.DeviceID): $($_.FreeGB)/$($_.SizeGB)GB" }) -join "; "
    } else { $Result.Errors += "Failed to get Disk Space info." }

    # 3. Key Services Status (Leverage Get-ServiceHealthReport.ps1)
    Write-Verbose "Getting key services status..."
    $ServiceHealth = & (Join-Path $PSScriptRoot "Get-ServiceHealthReport.ps1") -ComputerName $ComputerName -ErrorAction SilentlyContinue | Where-Object { $_.StatusMatch -ne "OK" }
    if ($ServiceHealth) {
        $Result.KeyServicesStatus = ($ServiceHealth | ForEach-Object { "$($_.ServiceName): $($_.StatusMatch)" }) -join "; "
    } else { $Result.KeyServicesStatus = "All OK (or N/A)"; $Result.Errors += "Failed to get Service Health info." }

    # 4. Last Critical Events (Leverage Get-RecentCriticalEvents.ps1)
    Write-Verbose "Getting last critical events..."
    $CriticalEvents = & (Join-Path $PSScriptRoot "..\..\Monitoring\Get-RecentCriticalEvents.ps1") -ComputerName $ComputerName -TimeInHours 24 -ErrorAction SilentlyContinue
    if ($CriticalEvents) {
        $Result.LastCriticalEvents = "$($CriticalEvents.Count) critical events in last 24h."
    } else { $Result.Errors += "Failed to get Critical Events." }

    # 5. Patch Status (Leverage Get-WindowsUpdateStatus.ps1)
    Write-Verbose "Getting patch status..."
    $PatchStatus = & (Join-Path $PSScriptRoot "..\..\Patch-Management\Get-WindowsUpdateStatus.ps1") -ComputerName $ComputerName -ErrorAction SilentlyContinue
    if ($PatchStatus) {
        $Result.PatchStatus = "Last Installed: $($PatchStatus.LastInstallDate); Pending Reboot: $($PatchStatus.PendingReboot)"
    } else { $Result.Errors += "Failed to get Patch Status." }

    # 6. Cert Expiry Status (Leverage Get-CertificateExpiryReport.ps1)
    Write-Verbose "Getting certificate expiry status..."
    $CertExpiry = & (Join-Path $PSScriptRoot "..\..\Monitoring\Get-CertificateExpiryReport.ps1") -ComputerName $ComputerName -WarningDays 60 -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne "OK" }
    if ($CertExpiry) {
        $Result.CertExpiryStatus = "$($CertExpiry.Count) certificates expiring soon/expired."
    } else { $Result.Errors += "Failed to get Cert Expiry Status." }

    # 7. RDP Sessions Count (Leverage Get-RDPSessions.ps1)
    Write-Verbose "Getting RDP sessions count..."
    $RDPSessions = & (Join-Path $PSScriptRoot "Get-RDPSessions.ps1") -ComputerName $ComputerName -ErrorAction SilentlyContinue
    if ($RDPSessions) {
        $Result.RDPSessionsCount = $RDPSessions.Count
    } else { $Result.Errors += "Failed to get RDP Sessions Count." }

    $Result.OverallStatus = if ($Result.Errors.Count -eq 0) { "Success" } else { "Completed with Errors" }
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during server triage on '$ComputerName': $($_.Exception.Message)"
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
    $Result | Format-List
}
