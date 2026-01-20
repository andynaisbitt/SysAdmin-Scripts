<#
.SYNOPSIS
Runs DISM/SFC, collects specified event logs, and zips the results from remote computers.
#>
param (
    [string[]]$ComputerName,
    [string]$DestinationPath, # Path on the local machine to store zipped results
    [string[]]$LogNames = @("System", "Application") # Event logs to collect
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter a comma-separated list of computer names"
    $ComputerName = $ComputerName.Split(',')
}
if (-not $DestinationPath) {
    $DestinationPath = Read-Host "Enter the local path to save the zipped results"
}
if (-not (Test-Path -Path $DestinationPath)) {
    New-Item -Path $DestinationPath -ItemType Directory -Force
}

foreach ($Computer in $ComputerName) {
    Write-Host "Starting remote repair operations on '$Computer'..."
    try {
        Invoke-Command -ComputerName $Computer -ScriptBlock {
            param ($DestinationPath, $LogNames)

            $TempDir = Join-Path -Path $env:TEMP -ChildPath "RemoteRepair-$($using:Computer)-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            New-Item -Path $TempDir -ItemType Directory -Force

            # Run DISM /RestoreHealth
            Write-Host "Running DISM /RestoreHealth..."
            $DismLog = Join-Path -Path $TempDir -ChildPath "DismLog.txt"
            Start-Process -FilePath dism.exe -ArgumentList "/Online /Cleanup-Image /RestoreHealth /NoRestart /log:$DismLog" -Wait -NoNewWindow -ErrorAction SilentlyContinue

            # Run SFC /scannow
            Write-Host "Running SFC /scannow..."
            $SfcLog = Join-Path -Path $TempDir -ChildPath "SfcLog.txt"
            Start-Process -FilePath sfc.exe -ArgumentList "/scannow /offbootdir=C:\ /offwindir=C:\Windows /log:$SfcLog" -Wait -NoNewWindow -ErrorAction SilentlyContinue # /offbootdir and /offwindir might be needed if not running on target OS directly

            # Collect Event Logs
            Write-Host "Collecting event logs: $($LogNames -join ', ')..."
            foreach ($LogName in $LogNames) {
                $EventLogFile = Join-Path -Path $TempDir -ChildPath "$LogName.evtx"
                Get-WinEvent -LogName $LogName -FilterXPath "*[System[(Level=1 or Level=2 or Level=3)]]" | Export-WinEvent -Path $EventLogFile -ErrorAction SilentlyContinue
            }

            # Zip results
            Write-Host "Zipping results..."
            $ZipFilePath = Join-Path -Path $env:TEMP -ChildPath "RepairResults-$($using:Computer)-$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
            Compress-Archive -Path $TempDir -DestinationPath $ZipFilePath -Force -ErrorAction Stop

            # Copy zip to local destination
            Copy-Item -Path $ZipFilePath -Destination "$DestinationPath" -Force -ErrorAction Stop

            # Clean up remote temp files
            Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $ZipFilePath -Force -ErrorAction SilentlyContinue
            
            Write-Host "Remote repair operations completed for '$($using:Computer)'. Results saved to '$DestinationPath'."
        } -ArgumentList $DestinationPath, $LogNames
    }
    catch {
        Write-Error "Failed remote repair operations on '$Computer'. Error: $($_.Exception.Message)"
    }
}
