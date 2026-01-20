<#
.SYNOPSIS
Reports on Windows Firewall status, including profile status, key inbound rules, and RDP exposure.
#>
param (
    [string[]]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Checking local firewall status on $Computer..."
    try {
        Invoke-Command -ComputerName $Computer -ScriptBlock {
            $FwProfile = Get-NetFirewallProfile -ErrorAction SilentlyContinue

            # RDP Exposure (reusing logic from Get-RDPExposureReport.ps1 for consistency)
            $RdpEnabled = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -ErrorAction SilentlyContinue).fDenyTSConnections -ne 1
            $NlaEnabled = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name UserAuthentication -ErrorAction SilentlyContinue).UserAuthentication -eq 1
            $RdpFirewallRules = Get-NetFirewallRule -DisplayName "Remote Desktop (TCP-In)" -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $true }
            $FirewallRdpEnabled = if ($RdpFirewallRules) { "Yes" } else { "No" }
            $FirewallRdpProfiles = ($RdpFirewallRules | Select-Object -ExpandProperty Profile | Select-Object -Unique) -join ", "
            $FirewallRdpRemoteAddresses = ($RdpFirewallRules | Select-Object -ExpandProperty RemoteAddress | Select-Object -Unique) -join ", "

            [PSCustomObject]@{
                ComputerName = $using:Computer
                DomainProfileStatus = if ($FwProfile | Where-Object { $_.Name -eq "Domain" }) { ($FwProfile | Where-Object { $_.Name -eq "Domain" }).Enabled } else { "N/A" }
                PublicProfileStatus = if ($FwProfile | Where-Object { $_.Name -eq "Public" }) { ($FwProfile | Where-Object { $_.Name -eq "Public" }).Enabled } else { "N/A" }
                PrivateProfileStatus = if ($FwProfile | Where-Object { $_.Name -eq "Private" }) { ($FwProfile | Where-Object { $_.Name -eq "Private" }).Enabled } else { "N/A" }
                RDPServiceEnabled = $RdpEnabled
                RDPServicesNLAEnabled = $NlaEnabled
                RDPFirewallRuleEnabled = $FirewallRdpEnabled
                RDPFirewallProfiles = $FirewallRdpProfiles
                RDPFirewallRemoteAddresses = $FirewallRdpRemoteAddresses
            }
        } -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to get local firewall status from '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName = $Computer
            DomainProfileStatus = "Error"
            PublicProfileStatus = "Error"
            PrivateProfileStatus = "Error"
            RDPServiceEnabled = "Error"
            RDPServicesNLAEnabled = "Error"
            RDPFirewallRuleEnabled = "Error"
            RDPFirewallProfiles = "Error"
            RDPFirewallRemoteAddresses = "Error"
            Error        = $_.Exception.Message
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
