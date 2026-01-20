<#
.SYNOPSIS
Lists available Wireshark capture interfaces and their status.
Requires Wireshark (which includes tshark) to be installed and tshark to be in the system's PATH.
#>
try {
    Write-Host "Listing available capture interfaces..."
    $TsharkOutput = (tshark.exe -D 2>&1)
    
    $Result = @()
    foreach ($Line in $TsharkOutput) {
        if ($Line -match "^(\d+)\. (.+) \((.+)\)$") {
            $Id = $matches[1]
            $Name = $matches[2]
            $Description = $matches[3]
            $IsUp = ($Description -notmatch "disconnected|loopback") # Simple heuristic for 'up'
            
            $Result += [PSCustomObject]@{
                Id          = $Id
                Name        = $Name
                Description = $Description
                IsUp        = $IsUp
            }
        }
    }
    $Result | Format-Table -AutoSize
}
catch {
    Write-Error "An error occurred while getting Wireshark interfaces. Please ensure tshark is installed and in your system's PATH: $($_.Exception.Message)"
}
