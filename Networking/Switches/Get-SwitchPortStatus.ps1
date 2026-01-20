<#
.SYNOPSIS
Collects interface status, errors, and speed/duplex from network switches via SSH.
#>
param (
    [string]$InputCsvPath, # CSV with columns: ComputerName, Vendor, UserName, Password
    [string]$ExportPath
)

if (-not $InputCsvPath) {
    $InputCsvPath = Read-Host "Enter the path to the CSV file containing switch details (ComputerName, Vendor, UserName, Password)"
}
if (-not (Test-Path -Path $InputCsvPath)) {
    Write-Error "Input CSV file not found at: $InputCsvPath"
    return
}

$SwitchList = Import-Csv -Path $InputCsvPath
$Result = @()

foreach ($Switch in $SwitchList) {
    $ComputerName = $Switch.ComputerName
    $Vendor = $Switch.Vendor
    $UserName = $Switch.UserName
    $Password = $Switch.Password # Should be a SecureString in a real scenario
    
    Write-Host "--- Getting port status for $ComputerName ($Vendor) ---"

    $Command = ""
    switch ($Vendor.ToLower()) {
        "cisco" {
            $Command = "show interfaces status" # Or "show interfaces" for more detail
        }
        "hp" {
            $Command = "display interface brief"
        }
        "dell" {
            $Command = "show interfaces status"
        }
        default {
            Write-Warning "Unsupported vendor '$Vendor' for $ComputerName. Skipping."
            $Result += [PSCustomObject]@{
                ComputerName = $ComputerName
                Vendor       = $Vendor
                Interface    = "N/A"
                Status       = "Skipped"
                Details      = "Unsupported vendor."
            }
            continue
        }
    }

    try {
        # Using ssh.exe (OpenSSH client)
        $SshArgs = "$UserName@$ComputerName `"$Command`""
        $Output = (ssh.exe $SshArgs 2>&1 | Out-String)
        
        # --- Parse Cisco-like 'show interfaces status' output (example) ---
        # This parsing will be highly dependent on the exact output format
        $OutputLines = $Output -split "`r`n"
        $HeaderFound = $false
        foreach ($Line in $OutputLines) {
            if ($Line -match "Port\s+Name\s+Status\s+Vlan\s+Duplex\s+Speed\s+Type") {
                $HeaderFound = $true
                continue
            }
            if ($HeaderFound -and ($Line -match "^(\S+)\s+(.*?)\s+(up|down|disabled|err-disabled)\s+(\S+)\s+(a-full|full|a-half|half|auto)\s+(\S+)\s+(.*)")) {
                $InterfaceName = $matches[1]
                $Status = $matches[3]
                $Vlan = $matches[4]
                $Duplex = $matches[5]
                $Speed = $matches[6]

                $Result += [PSCustomObject]@{
                    ComputerName = $ComputerName
                    Vendor       = $Vendor
                    Interface    = $InterfaceName
                    Status       = $Status
                    Vlan         = $Vlan
                    Duplex       = $Duplex
                    Speed        = $Speed
                    Errors       = "N/A" # More detailed parsing needed for errors
                }
            }
        }

        if ($Result.Count -eq 0) {
            Write-Warning "No interface status parsed for $ComputerName. Output might be in an unexpected format."
            $Result += [PSCustomObject]@{
                ComputerName = $ComputerName
                Vendor       = $Vendor
                Interface    = "N/A"
                Status       = "Parsing Failed"
                Details      = "See raw output for details."
            }
        }
    }
    catch {
        Write-Warning "Failed to get port status for $ComputerName: $($_.Exception.Message)"
        $Result += [PSCustomObject]@{
            ComputerName = $ComputerName
            Vendor       = $Vendor
            Interface    = "N/A"
            Status       = "Failed"
            Details      = $_.Exception.Message
        }
    }
}

if ($ExportPath) {
    if ($ExportPath.EndsWith(".csv")) {
        $Result | Export-Csv -Path $ExportPath -NoTypeInformation
    }
    elseif ($ExportPath.EndsWith(".html")) {
        $Result | ConvertTo-Html -Title "Switch Port Status Report" | Out-File -Path $ExportPath
    }
    else {
        Write-Warning "Invalid export path. Please specify a .csv or .html file."
    }
}
else {
    $Result | Format-Table -AutoSize
}
