<#
.SYNOPSIS
Starts a tshark capture, then runs a summary report, and organizes all output into a dated incident pack folder.
Requires Wireshark (which includes tshark) to be installed and tshark to be in the system's PATH.
#>
param (
    [string]$Interface,
    [int]$DurationSeconds = 60,
    [string]$CaptureFilter,
    [string]$OutputBasePath = (Join-Path $PSScriptRoot "..\..\Output\CapturePack"), # Relative to script
    [switch]$NoAutoOpen
)

if (-not $Interface) {
    $Interface = Read-Host "Enter the interface to capture on (e.g., 'Ethernet', 'Wi-Fi' or interface number from Get-WiresharkInterfaces)"
}

$Hostname = $env:COMPUTERNAME
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$IncidentPackFolder = Join-Path -Path $OutputBasePath -ChildPath "${Hostname}_${Timestamp}"

if (-not (Test-Path -Path $OutputBasePath)) {
    New-Item -Path $OutputBasePath -ItemType Directory -Force | Out-Null
}
New-Item -Path $IncidentPackFolder -ItemType Directory -Force | Out-Null

Write-Host "Creating incident pack in: $IncidentPackFolder"

$PcapFilePath = Join-Path -Path $IncidentPackFolder -ChildPath "capture_${Hostname}_${Timestamp}.pcapng"
$SummaryCsvPath = Join-Path -Path $IncidentPackFolder -ChildPath "summary_${Hostname}_${Timestamp}.csv"
$SummaryHtmlPath = Join-Path -Path $IncidentPackFolder -ChildPath "summary_${Hostname}_${Timestamp}.html"

try {
    Write-Host "Starting tshark capture on interface '$Interface' for $DurationSeconds seconds..."

    $TsharkArgs = @(
        "-i", "`"$Interface`"",
        "-w", "`"$PcapFilePath`""
    )

    if ($DurationSeconds) {
        $TsharkArgs += "-a", "duration:$DurationSeconds"
    }
    if ($CaptureFilter) {
        $TsharkArgs += "-f", "`"$CaptureFilter`""
    }

    $TsharkProcess = Start-Process -FilePath tshark.exe -ArgumentList $TsharkArgs -PassThru -NoNewWindow
    $TsharkProcess | Wait-Process

    if ($TsharkProcess.ExitCode -eq 0) {
        Write-Host "Capture complete. Analyzing pcap file..."
        # Run Export-CaptureSummary.ps1
        $ExportSummaryScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Export-CaptureSummary.ps1"
        if (Test-Path -Path $ExportSummaryScriptPath) {
            & $ExportSummaryScriptPath -PcapFilePath $PcapFilePath -ExportPath $SummaryCsvPath
            & $ExportSummaryScriptPath -PcapFilePath $PcapFilePath -ExportPath $SummaryHtmlPath
            Write-Host "Capture summary exported."
        }
        else {
            Write-Warning "Export-CaptureSummary.ps1 script not found. Skipping summary generation."
        }
    }
    else {
        Write-Error "Tshark capture failed with exit code $($TsharkProcess.ExitCode)."
    }

    Write-Host "Incident pack generated at: $IncidentPackFolder"
    if (-not $NoAutoOpen) {
        Invoke-Item -Path $IncidentPackFolder
    }
}
catch {
    Write-Error "An error occurred during incident pack creation: $($_.Exception.Message)"
}
