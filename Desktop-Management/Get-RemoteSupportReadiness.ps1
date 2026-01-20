<#
.SYNOPSIS
Checks a computer's readiness for remote support by verifying WinRM, RDP enabled status, and firewall rules.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName = "localhost",
    [switch]$EnableRemoteSupport, # If present, attempts to enable WinRM, RDP, and firewall rules
    [string]$ExportPath
)

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    WinRMStatus = "N/A"
    RDPStatus = "N/A"
    FirewallStatus = "N/A"
    NeedsEnabling = "No"
    ActionsTaken = @()
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "--- Checking Remote Support Readiness on $ComputerName ---"

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # 1. Check WinRM Status
        $WinRMService = Get-Service -Name WinRM -ErrorAction SilentlyContinue
        $WinRMListener = Get-Item -Path WSMan:\localhost\Listener\* -ErrorAction SilentlyContinue | Where-Object { $_.Keys -contains "Port" }
        $WinRMFirewallRule = Get-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $true }

        if ($WinRMService -and $WinRMService.Status -eq "Running" -and $WinRMListener -and $WinRMFirewallRule) {
            $using:Result.WinRMStatus = "Ready"
        }
        else {
            $using:Result.WinRMStatus = "Not Ready"
            $using:Result.NeedsEnabling = "Yes"
            if (-not $WinRMService -or $WinRMService.Status -ne "Running") { $using:Result.Errors += "WinRM service not running." }
            if (-not $WinRMListener) { $using:Result.Errors += "WinRM listener not configured." }
            if (-not $WinRMFirewallRule) { $using:Result.Errors += "WinRM firewall rule not enabled." }
        }

        # 2. Check RDP Status
        $RdpEnabled = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -ErrorAction SilentlyContinue).fDenyTSConnections -ne 1
        $NlaEnabled = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name UserAuthentication -ErrorAction SilentlyContinue).UserAuthentication -eq 1
        $RdpFirewallRule = Get-NetFirewallRule -DisplayName "Remote Desktop (TCP-In)" -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $true }

        if ($RdpEnabled -and $NlaEnabled -and $RdpFirewallRule) {
            $using:Result.RDPStatus = "Ready"
        }
        else {
            $using:Result.RDPStatus = "Not Ready"
            $using:Result.NeedsEnabling = "Yes"
            if (-not $RdpEnabled) { $using:Result.Errors += "RDP not enabled." }
            if (-not $NlaEnabled) { $using:Result.Errors += "NLA not enabled for RDP." }
            if (-not $RdpFirewallRule) { $using:Result.Errors += "RDP firewall rule not enabled." }
        }

        # 3. Enable if requested
        if ($using:EnableRemoteSupport -and $using:Result.NeedsEnabling -eq "Yes") {
            if ($pscmdlet.ShouldProcess("Enable remote support features on '$using:ComputerName'", "Enable Remote Support")) {
                # Enable WinRM
                try {
                    Enable-PSRemoting -Force -ErrorAction Stop
                    Set-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -Enabled True -ErrorAction Stop
                    $using:Result.ActionsTaken += "WinRM Enabled."
                } catch { $using:Result.Errors += "Failed to enable WinRM: $($_.Exception.Message)" }

                # Enable RDP
                try {
                    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0 -ErrorAction Stop
                    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name UserAuthentication -Value 1 -ErrorAction Stop
                    Set-NetFirewallRule -DisplayName "Remote Desktop (TCP-In)" -Enabled True -ErrorAction Stop
                    $using:Result.ActionsTaken += "RDP Enabled."
                } catch { $using:Result.Errors += "Failed to enable RDP: $($_.Exception.Message)" }
                $using:Result.NeedsEnabling = "No" # Attempted to enable
            }
        }

        $using:Result.OverallStatus = "Success"
    } -ErrorAction Stop

    $Result.OverallStatus = "Success"
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during remote support readiness check: $($_.Exception.Message)"
}

if ($ExportPath) {
    $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
}
else {
    $Result | Format-List
}
