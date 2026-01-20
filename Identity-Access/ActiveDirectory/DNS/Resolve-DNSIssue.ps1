<#
.SYNOPSIS
Diagnoses DNS resolution issues for a given hostname by checking A records, PTR records, ping, and nslookup against DNS servers.
#>
param (
    [string]$Hostname,
    [string[]]$DnsServers, # Optional: Specific DNS servers to query against
    [string]$ExportPath
)

if (-not $Hostname) {
    $Hostname = Read-Host "Enter the hostname to resolve"
}
if (-not $DnsServers) {
    Write-Host "No specific DNS servers provided. Attempting to discover..."
    try {
        $DnsServers = (Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses)
    }
    catch {
        Write-Warning "Could not automatically determine DNS servers. Using default system resolvers."
        $DnsServers = @("8.8.8.8", "1.1.1.1") # Fallback to public DNS
    }
}

$Result = @()
foreach ($DnsServer in $DnsServers) {
    Write-Host "--- Querying DNS Server: $DnsServer ---"
    try {
        # A Record lookup
        $ARecord = Resolve-DnsName -Name $Hostname -Server $DnsServer -Type A -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IPAddress
        
        # PTR Record lookup (requires IP, so resolve A record first if possible)
        $PtrRecord = $null
        if ($ARecord) {
            $PtrRecord = Resolve-DnsName -Name $ARecord[0] -Server $DnsServer -Type PTR -ErrorAction SilentlyContinue | Select-Object -ExpandProperty NameHost
        }

        # Ping
        $PingStatus = (Test-Connection -ComputerName $Hostname -Count 1 -ErrorAction SilentlyContinue).StatusCode

        # Nslookup (raw output can be useful)
        $NslookupOutput = (nslookup $Hostname $DnsServer 2>&1 | Out-String).Trim()

        $Result += [PSCustomObject]@{
            DnsServer      = $DnsServer
            Hostname       = $Hostname
            ARecord        = ($ARecord -join ", ")
            PtrRecord      = ($PtrRecord -join ", ")
            PingSuccessful = if ($PingStatus -eq 0) { "Yes" } else { "No" }
            NslookupOutput = $NslookupOutput
        }
    }
    catch {
        Write-Warning "Failed to query DNS server '$DnsServer'. Error: $($_.Exception.Message)"
        $Result += [PSCustomObject]@{
            DnsServer      = $DnsServer
            Hostname       = $Hostname
            ARecord        = "Error"
            PtrRecord      = "Error"
            PingSuccessful = "Error"
            NslookupOutput = $_.Exception.Message
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
