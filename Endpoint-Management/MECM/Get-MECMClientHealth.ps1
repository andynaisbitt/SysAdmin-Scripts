<#
.SYNOPSIS
Checks MECM (SCCM) client health by verifying CCM services, client version, and last hardware/software inventory times.
#>
param (
    [string]$ComputerName = "localhost"
)

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    OverallStatus = "Failed"
    CcmExecService = "N/A"
    CcmHostService = "N/A"
    ClientVersion = "N/A"
    LastHardwareInventory = "N/A"
    LastSoftwareInventory = "N/A"
    LastPolicyRequest = "N/A"
    Errors = @()
}

try {
    Write-Host "--- Checking MECM Client Health on $ComputerName ---"

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # 1. Check CCM Services
        $CcmExec = Get-Service -Name CcmExec -ErrorAction SilentlyContinue
        if ($CcmExec) { $using:Result.CcmExecService = $CcmExec.Status }
        $CcmHost = Get-Service -Name CcmHost -ErrorAction SilentlyContinue # May not exist on all clients
        if ($CcmHost) { $using:Result.CcmHostService = $CcmHost.Status }

        if ($using:Result.CcmExecService -ne "Running") {
            $using:Result.Errors += "CcmExec service not running."
        }
        
        # 2. Get Client Version
        $CcmClientVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\SMS\Client\Configuration\Client Properties" -ErrorAction SilentlyContinue).ClientVersion
        if ($CcmClientVersion) { $using:Result.ClientVersion = $CcmClientVersion } else { $using:Result.Errors += "Client version not found." }

        # 3. Last Hardware/Software Inventory & Policy Request
        $CcmAgent = Get-WmiObject -Namespace "root\ccm\invagt" -Class "CCM_RecentAction" -ErrorAction SilentlyContinue
        if ($CcmAgent) {
            $HwInv = $CcmAgent | Where-Object { $_.ActionType -eq "HardwareInventory" } | Sort-Object -Property ActionTime -Descending | Select-Object -ExpandProperty ActionTime -First 1
            if ($HwInv) { $using:Result.LastHardwareInventory = $HwInv }
            
            $SwInv = $CcmAgent | Where-Object { $_.ActionType -eq "SoftwareInventory" } | Sort-Object -Property ActionTime -Descending | Select-Object -ExpandProperty ActionTime -First 1
            if ($SwInv) { $using:Result.LastSoftwareInventory = $SwInv }
            
            $PolicyRequest = $CcmAgent | Where-Object { $_.ActionType -eq "RequestPolicy" } | Sort-Object -Property ActionTime -Descending | Select-Object -ExpandProperty ActionTime -First 1
            if ($PolicyRequest) { $using:Result.LastPolicyRequest = $PolicyRequest }
        } else { $using:Result.Errors += "WMI class for inventory actions not found." }

        $using:Result.OverallStatus = if ($using:Result.Errors.Count -eq 0) { "Healthy" } else { "Unhealthy" }
    } -ErrorAction Stop

    $Result.OverallStatus = if ($Result.Errors.Count -eq 0) { "Healthy" } else { "Unhealthy" }
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during MECM client health check: $($_.Exception.Message)"
}

if ($ExportPath) {
    $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
}
else {
    $Result | Format-List
}
