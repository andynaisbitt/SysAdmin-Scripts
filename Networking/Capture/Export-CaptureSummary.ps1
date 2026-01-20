<#
.SYNOPSIS
Reads a pcap file with tshark and outputs a summary report.
Requires Wireshark (which includes tshark) to be installed and tshark to be in the system's PATH.
#>
param (
    [string]$PcapFilePath,
    [string]$ExportPath
)

if (-not $PcapFilePath) {
    $PcapFilePath = Read-Host "Enter the path to the .pcap or .pcapng file"
}
if (-not (Test-Path -Path $PcapFilePath)) {
    Write-Error "The specified pcap file does not exist: $PcapFilePath"
    return
}

try {
    Write-Host "Analyzing capture file: $PcapFilePath"

    # Top Protocols
    $Protocols = (tshark.exe -r "$PcapFilePath" -q -z "io,phs" | Select-String -Pattern "(\S+)\s+(\d+\.\d+)%\s+(\d+)\s+(\d+)" -AllMatches).Matches | ForEach-Object {
        [PSCustomObject]@{
            Protocol = $_.Groups[1].Value
            Percentage = $_.Groups[2].Value
            Packets = $_.Groups[3].Value
            Bytes = $_.Groups[4].Value
        }
    } | Select-Object -First 10

    # Top Talkers (IP addresses)
    $Talkers = (tshark.exe -r "$PcapFilePath" -q -z "ip_src,ip_dst" | Select-String -Pattern "(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+(\d+)" -AllMatches).Matches | ForEach-Object {
        [PSCustomObject]@{
            IPAddress = $_.Groups[1].Value
            Packets = $_.Groups[2].Value
        }
    } | Group-Object IPAddress | ForEach-Object {
        [PSCustomObject]@{
            IPAddress = $_.Name
            TotalPackets = ($_.Group | Measure-Object -Property Packets -Sum).Sum
        }
    } | Sort-Object TotalPackets -Descending | Select-Object -First 10

    # DNS Queries
    $DnsQueries = (tshark.exe -r "$PcapFilePath" -Y "dns.qry.name" -T fields -e "dns.qry.name" | Group-Object | Select-Object Name, Count | Sort-Object Count -Descending | Select-Object -First 10)

    # HTTP Hostnames
    $HttpHostnames = (tshark.exe -r "$PcapFilePath" -Y "http.host" -T fields -e "http.host" | Group-Object | Select-Object Name, Count | Sort-Object Count -Descending | Select-Object -First 10)

    $Summary = [PSCustomObject]@{
        PcapFile = $PcapFilePath
        TopProtocols = $Protocols
        TopTalkers = $Talkers
        TopDnsQueries = $DnsQueries
        TopHttpHostnames = $HttpHostnames
    }

    if ($ExportPath) {
        if ($ExportPath.EndsWith(".csv")) {
            $Summary | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        elseif ($ExportPath.EndsWith(".html")) {
            $Summary | ConvertTo-Html | Out-File -Path $ExportPath
        }
        else {
            Write-Warning "Invalid export path. Please specify a .csv or .html file."
        }
    }
    else {
        $Summary | Format-List
    }
}
catch {
    Write-Error "An error occurred during capture analysis. Please ensure tshark is installed and in your system's PATH: $($_.Exception.Message)"
}
