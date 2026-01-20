<#
.SYNOPSIS
Detects duplicate or stale A/PTR record mismatches in DNS.
#>
param (
    [string]$DnsServer, # Optional: Specific DNS server to query
    [string]$ExportPath
)

if (-not $DnsServer) {
    $DnsServer = Read-Host "Enter the DNS server to query (e.g., DC01.contoso.com)"
}

try {
    Write-Host "Getting DNS zones from $DnsServer..."
    $Zones = Get-DnsServerZone -ComputerName $DnsServer -ErrorAction Stop

    $Result = @()
    foreach ($Zone in $Zones) {
        if ($Zone.ZoneType -eq "Primary") { # Only check primary zones for full control
            Write-Verbose "Checking zone: $($Zone.ZoneName)"
            $Records = Get-DnsServerResourceRecord -ComputerName $DnsServer -ZoneName $Zone.ZoneName -ErrorAction SilentlyContinue

            # --- Detect Duplicate A Records ---
            $ARecords = $Records | Where-Object { $_.RecordType -eq "A" }
            $DuplicateARecords = $ARecords | Group-Object HostName, RecordData | Where-Object { $_.Count -gt 1 }
            foreach ($Duplicate in $DuplicateARecords) {
                $Result += [PSCustomObject]@{
                    DnsServer    = $DnsServer
                    ZoneName     = $Zone.ZoneName
                    RecordType   = "A"
                    HostName     = $Duplicate.Name.Split(',')[0]
                    IPAddress    = $Duplicate.Name.Split(',')[1]
                    Issue        = "Duplicate A Record"
                    Details      = "$($Duplicate.Count) records found for $($Duplicate.Name.Split(',')[0]) with IP $($Duplicate.Name.Split(',')[1])"
                }
            }

            # --- Detect A/PTR Mismatches ---
            foreach ($ARec in $ARecords) {
                if ($ARec.HostName -ne "@") { # Skip zone apex for PTR checks
                    try {
                        $PtrLookup = Resolve-DnsName -Name $ARec.IPAddress -Server $DnsServer -Type PTR -ErrorAction SilentlyContinue
                        $MatchingPtr = $PtrLookup | Where-Object { $_.NameHost -like "$($ARec.HostName).*" }

                        if (-not $MatchingPtr) {
                            $Result += [PSCustomObject]@{
                                DnsServer    = $DnsServer
                                ZoneName     = $Zone.ZoneName
                                RecordType   = "A/PTR"
                                HostName     = $ARec.HostName
                                IPAddress    = $ARec.IPAddress
                                Issue        = "A/PTR Mismatch (No Matching PTR)"
                                Details      = "A record for $($ARec.HostName) ($($ARec.IPAddress)) has no matching PTR record."
                            }
                        }
                    }
                    catch {
                        $Result += [PSCustomObject]@{
                            DnsServer    = $DnsServer
                            ZoneName     = $Zone.ZoneName
                            RecordType   = "A/PTR"
                            HostName     = $ARec.HostName
                            IPAddress    = $ARec.IPAddress
                            Issue        = "A/PTR Mismatch (PTR Lookup Error)"
                            Details      = "Error resolving PTR for $($ARec.IPAddress): $($_.Exception.Message)"
                        }
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to check DNS zone $($Zone.ZoneName) on '$DnsServer'. Error: $($_.Exception.Message)"
    }
}

if ($Result) {
    Write-Host "Found $($Result.Count) potential duplicate or stale DNS records."
    $Result | Format-Table -AutoSize
}
else {
    Write-Host "No duplicate or stale DNS records found."
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
