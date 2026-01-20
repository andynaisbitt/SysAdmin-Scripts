<#
.SYNOPSIS
Checks WinRM, WMI, and SMB reachability on a given host, providing a quick way to diagnose remoting issues.
#>
param (
    [string]$ComputerName
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the computer name to test"
}

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    WinRMReady   = $false
    WMIReady     = $false
    SMBReady     = $false
    Error        = $null
}

try {
    Write-Host "--- Testing Remoting Readiness for $ComputerName ---"

    # Test WinRM
    Write-Host "Testing WinRM..."
    try {
        Test-WsMan -ComputerName $ComputerName -ErrorAction Stop | Out-Null
        $Result.WinRMReady = $true
        Write-Host "WinRM: OK"
    }
    catch {
        $Result.WinRMReady = $false
        $Result.Error += "WinRM: $($_.Exception.Message); "
        Write-Warning "WinRM: Failed - $($_.Exception.Message)"
    }

    # Test WMI
    Write-Host "Testing WMI..."
    try {
        Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $ComputerName -ErrorAction Stop | Out-Null
        $Result.WMIReady = $true
        Write-Host "WMI: OK"
    }
    catch {
        $Result.WMIReady = $false
        $Result.Error += "WMI: $($_.Exception.Message); "
        Write-Warning "WMI: Failed - $($_.Exception.Message)"
    }

    # Test SMB
    Write-Host "Testing SMB..."
    try {
        # Attempt to access a default admin share like IPC$
        Test-Path -Path "\\$ComputerName\IPC$" -ErrorAction Stop | Out-Null
        $Result.SMBReady = $true
        Write-Host "SMB: OK"
    }
    catch {
        $Result.SMBReady = $false
        $Result.Error += "SMB: $($_.Exception.Message); "
        Write-Warning "SMB: Failed - $($_.Exception.Message)"
    }

    $Result | Format-List
}
catch {
    Write-Error "An unexpected error occurred: $($_.Exception.Message)"
    $Result.Error = $_.Exception.Message
}

$Result
