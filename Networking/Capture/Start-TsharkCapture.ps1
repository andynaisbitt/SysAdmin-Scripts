<#
.SYNOPSIS
Starts a network capture using tshark on a chosen interface.
Requires Wireshark (which includes tshark) to be installed and tshark to be in the system's PATH.
#>
param (
    [string]$Interface,
    [int]$DurationSeconds,
    [string]$CaptureFilter,
    [string]$OutputPath
)

if (-not $Interface) {
    $Interface = Read-Host "Enter the interface to capture on (e.g., 'Ethernet', 'Wi-Fi' or interface number from Get-WiresharkInterfaces)"
}
if (-not $OutputPath) {
    $OutputPath = Read-Host "Enter the path to save the capture file (e.g., C:\Captures)"
    if (-not (Test-Path -Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force
    }
}

try {
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $HostName = $env:COMPUTERNAME
    $CaptureFileName = Join-Path -Path $OutputPath -ChildPath "Capture_${HostName}_${Timestamp}.pcapng"

    $TsharkArgs = @(
        "-i", "`"$Interface`"",
        "-w", "`"$CaptureFileName`""
    )

    if ($DurationSeconds) {
        $TsharkArgs += "-a", "duration:$DurationSeconds"
    }
    if ($CaptureFilter) {
        $TsharkArgs += "-f", "`"$CaptureFilter`""
    }

    Write-Host "Starting tshark capture on interface '$Interface'. Output will be saved to '$CaptureFileName'."
    Write-Host "To stop manually, press Ctrl+C."

    Start-Process -FilePath tshark.exe -ArgumentList $TsharkArgs -NoNewWindow
}
catch {
    Write-Error "An error occurred while starting the tshark capture. Please ensure tshark is installed and in your system's PATH: $($_.Exception.Message)"
}
