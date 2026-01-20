<#
.SYNOPSIS
Reports on Remote Desktop Protocol (RDP) exposure, including enabled RDP, NLA status, and firewall allow rules.
#>
param (
    [string[]]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Checking RDP exposure on $Computer..."
    try {
        Invoke-Command -ComputerName $Computer -ScriptBlock {
            # Check if RDP is enabled
            $RdpRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
            $RdpEnabled = (Get-ItemProperty -Path $RdpRegistryPath -Name fDenyTSConnections -ErrorAction SilentlyContinue).fDenyTSConnections -ne 1

            # Check NLA status
            $NlaRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
            $NlaEnabled = (Get-ItemProperty -Path $NlaRegistryPath -Name UserAuthentication -ErrorAction SilentlyContinue).UserAuthentication -eq 1

            # Check Firewall Rules for RDP (Port 3389)
            $RdpFirewallRules = Get-NetFirewallRule -DisplayName "Remote Desktop (TCP-In)" -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $true }
            $FirewallEnabled = if ($RdpFirewallRules) { "Yes" } else { "No" }
            $FirewallProfiles = ($RdpFirewallRules | Select-Object -ExpandProperty Profile | Select-Object -Unique) -join ", "
            $FirewallRemoteAddresses = ($RdpFirewallRules | Select-Object -ExpandProperty RemoteAddress | Select-Object -Unique) -join ", "

            [PSCustomObject]@{
                ComputerName = $using:Computer
                RDPEnabled   = $RdpEnabled
                NLAEnabled   = $NlaEnabled
                FirewallRuleEnabled = $FirewallEnabled
                FirewallProfiles = $FirewallProfiles
                FirewallRemoteAddresses = $FirewallRemoteAddresses
            }
        } -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to get RDP exposure report from '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName            = $Computer
            RDPEnabled              = "Error"
            NLAEnabled              = "Error"
            FirewallRuleEnabled     = "Error"
            FirewallProfiles        = "Error"
            FirewallRemoteAddresses = "Error"
            Error                   = $_.Exception.Message
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
