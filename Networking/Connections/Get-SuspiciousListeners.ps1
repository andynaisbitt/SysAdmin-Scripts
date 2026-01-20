<#
.SYNOPSIS
Lists listening ports, process path, and signed status, highlighting non-standard ports for common services and unsigned binaries.
#>
param (
    [string]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

# Define common ports for quick lookup
$CommonPorts = @{
    21 = "FTP"
    22 = "SSH"
    23 = "Telnet"
    25 = "SMTP"
    53 = "DNS"
    80 = "HTTP"
    110 = "POP3"
    135 = "RPC"
    139 = "NetBIOS Session Service"
    143 = "IMAP"
    389 = "LDAP"
    443 = "HTTPS"
    445 = "SMB/CIFS"
    3389 = "RDP"
    5985 = "WinRM HTTP"
    5986 = "WinRM HTTPS"
}

$Result = @()
try {
    Write-Host "Getting listening ports from $ComputerName..."
    $Connections = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        Get-NetTCPConnection | Where-Object { $_.State -eq "Listen" } | Select-Object LocalAddress, LocalPort, OwningProcess
    } -ErrorAction Stop

    foreach ($Connection in $Connections) {
        $Process = Get-Process -Id $Connection.OwningProcess -ComputerName $ComputerName -ErrorAction SilentlyContinue
        $BinaryPath = if ($Process) { $Process.Path } else { "N/A" }
        $IsSigned = "N/A"
        $Reason = @()

        if ($BinaryPath -ne "N/A" -and (Test-Path -Path $BinaryPath)) {
            try {
                $Signature = Get-AuthenticodeSignature -FilePath $BinaryPath -ErrorAction SilentlyContinue
                $IsSigned = if ($Signature.Status -eq "Valid") { "Yes" } else { "No" }
            }
            catch { $IsSigned = "Error: $($_.Exception.Message)" }
        }

        # Check for non-standard port for common service
        if ($CommonPorts.ContainsKey($Connection.LocalPort)) {
            $ExpectedService = $CommonPorts[$Connection.LocalPort]
            # Further checks would be needed to compare the actual process to the expected service
            # For this script, we'll just flag if the process name doesn't match a very common pattern
            if ($Process -and ($Process.ProcessName -notlike "*$ExpectedService*" -and $Process.ProcessName -notlike "*http*" -and $Process.ProcessName -notlike "*svchost*")) {
                $Reason += "Non-standard process for common port ($ExpectedService)"
            }
        }
        
        # Flag unsigned binaries
        if ($IsSigned -eq "No") {
            $Reason += "Unsigned binary"
        }
        elseif ($IsSigned -eq "Error: File not found for signature check") {
            $Reason += "Binary not found for signature check"
        }

        if ($Reason.Count -eq 0) {
            $Reason += "None apparent"
        }

        $Result += [PSCustomObject]@{
            ComputerName = $ComputerName
            LocalAddress = $Connection.LocalAddress
            LocalPort    = $Connection.LocalPort
            ProcessName  = if ($Process) { $Process.ProcessName } else { "N/A" }
            PID          = $Connection.OwningProcess
            BinaryPath   = $BinaryPath
            IsSigned     = $IsSigned
            Reason       = ($Reason -join "; ")
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
}
catch {
    Write-Error "An error occurred while getting suspicious listeners from '$ComputerName': $($_.Exception.Message)"
}
