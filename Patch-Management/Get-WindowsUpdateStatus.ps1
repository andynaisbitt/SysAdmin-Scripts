<#
.SYNOPSIS
Reports on Windows Update status for servers, including last installed updates and pending reboots.
#>
param (
    [string[]]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Checking Windows Update status on $Computer..."
    try {
        Invoke-Command -ComputerName $Computer -ScriptBlock {
            $LastInstallDate = (Get-WmiObject -Class Win32_QuickFixEngineering | Sort-Object -Property InstalledOn -Descending | Select-Object -ExpandProperty InstalledOn -First 1)

            # Check for pending reboot (simplified - can be more comprehensive)
            $PendingReboot = $false
            if (Test-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations") {
                $PendingReboot = $true
            }
            if (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
                $PendingReboot = $true
            }

            [PSCustomObject]@{
                ComputerName    = $using:Computer
                LastInstallDate = $LastInstallDate
                PendingReboot   = $PendingReboot
                # Additional update details could be gathered using COM objects (Microsoft.Update.Session)
            }
        } -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to get Windows Update status from '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName    = $Computer
            LastInstallDate = "Error"
            PendingReboot   = "Error"
            Error           = $_.Exception.Message
        }
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
