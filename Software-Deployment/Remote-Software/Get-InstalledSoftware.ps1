<#
.SYNOPSIS
Gets a list of installed software from a local or remote computer.
#>
param (
    [string]$ComputerName
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

try {
    # Query 64-bit applications
    $Software64 = Get-CimInstance -ClassName Win32_Product -ComputerName $ComputerName -ErrorAction SilentlyContinue | Select-Object -Property Name, Version, Vendor, InstallDate

    # Query 32-bit applications (often found in WOW6432Node) - this approach is less reliable due to Win32_Product issues
    # A more robust approach for 32-bit would be to query registry directly via Invoke-Command.
    # For simplicity and common use, Win32_Product is often sufficient, but be aware of its limitations.
    
    # Combined results (for Win32_Product, it usually lists both)
    $Software64
}
catch {
    Write-Error "An error occurred while getting installed software from '$ComputerName': $($_.Exception.Message)"
}
