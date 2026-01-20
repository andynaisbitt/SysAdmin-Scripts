<#
.SYNOPSIS
Performs a light network reset, including flushing DNS, renewing/registering IP, and optionally resetting Winsock.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName,
    [switch]$WinsockReset
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    FlushDnsStatus = "N/A"
    RenewIpStatus = "N/A"
    RegisterDnsStatus = "N/A"
    WinsockResetStatus = "N/A"
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "Starting network reset lite on '$ComputerName'..."
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # 1. Flush DNS
        if ($pscmdlet.ShouldProcess("Flush DNS cache", "Flush DNS")) {
            $DnsFlushOutput = ipconfig /flushdns 2>&1 | Out-String
            Write-Host "DNS Flush Output: $DnsFlushOutput"
            $using:Result.FlushDnsStatus = "Success"
        }

        # 2. Renew IP
        if ($pscmdlet.ShouldProcess("Renew IP address", "Renew IP")) {
            $IpRenewOutput = ipconfig /renew 2>&1 | Out-String
            Write-Host "IP Renew Output: $IpRenewOutput"
            $using:Result.RenewIpStatus = "Success"
        }

        # 3. Register DNS
        if ($pscmdlet.ShouldProcess("Register DNS", "Register DNS")) {
            $DnsRegisterOutput = ipconfig /registerdns 2>&1 | Out-String
            Write-Host "DNS Register Output: $DnsRegisterOutput"
            $using:Result.RegisterDnsStatus = "Success"
        }

        # 4. Winsock Reset (Optional)
        if ($using:WinsockReset) {
            if ($pscmdlet.ShouldProcess("Reset Winsock Catalog", "Winsock Reset")) {
                $WinsockResetOutput = netsh winsock reset 2>&1 | Out-String
                Write-Host "Winsock Reset Output: $WinsockResetOutput"
                $using:Result.WinsockResetStatus = "Success"
                Write-Warning "Winsock reset requires a reboot to take full effect."
            }
        }
    } -ErrorAction Stop

    $Result.OverallStatus = "Success"
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during network reset on '$ComputerName': $($_.Exception.Message)"
}

$Result | Format-List
