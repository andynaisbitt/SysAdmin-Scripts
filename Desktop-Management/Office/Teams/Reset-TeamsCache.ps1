<#
.SYNOPSIS
Safely closes Microsoft Teams, clears its cache directories, and relaunches it.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName = "localhost"
)

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    TeamsClosed  = "No"
    CacheCleared = "No"
    TeamsRelaunched = "No"
    OverallStatus = "Failed"
    Errors       = @()
}

try {
    Write-Host "--- Resetting Teams Cache on $ComputerName ---"

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # 1. Close Teams (if running)
        Write-Host "Attempting to close Microsoft Teams..."
        Get-Process Teams -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2 # Give Teams a moment to fully shut down
        $TeamsProcess = Get-Process Teams -ErrorAction SilentlyContinue
        if ($TeamsProcess) {
            # If still running, try harder
            Stop-Process -Id $TeamsProcess.Id -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
        $using:Result.TeamsClosed = "Yes"
        Write-Host "Microsoft Teams process closed."

        # 2. Clear Cache Directories
        Write-Host "Clearing Teams cache directories..."
        $TeamsCachePaths = @(
            (Join-Path $env:APPDATA "Microsoft\Teams\Cache"),
            (Join-Path $env:APPDATA "Microsoft\Teams\blob_storage"),
            (Join-Path $env:APPDATA "Microsoft\Teams\databases"),
            (Join-Path $env:APPDATA "Microsoft\Teams\GPUCache"),
            (Join-Path $env:APPDATA "Microsoft\Teams\IndexedDB"),
            (Join-Path $env:APPDATA "Microsoft\Teams\Local Storage"),
            (Join-Path $env:APPDATA "Microsoft\Teams\tmp")
        )

        foreach ($Path in $TeamsCachePaths) {
            if (Test-Path -Path $Path) {
                if ($pscmdlet.ShouldProcess("Remove Teams cache folder: $Path", "Clear Cache")) {
                    Remove-Item -Path "$Path\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "Cleared: $Path"
                }
            }
        }
        $using:Result.CacheCleared = "Yes"
        Write-Host "Teams cache directories cleared."

        # 3. Relaunch Teams
        if ($pscmdlet.ShouldProcess("Relaunch Microsoft Teams", "Relaunch App")) {
            Start-Process -FilePath (Get-Item (Join-Path $env:LOCALAPPDATA "Microsoft\Teams\Update.exe")).FullName -ArgumentList "--processStart Teams.exe" -ErrorAction SilentlyContinue
            $using:Result.TeamsRelaunched = "Yes"
            Write-Host "Microsoft Teams relaunched."
        }
        $using:Result.OverallStatus = "Success"
    } -ErrorAction Stop

    $Result.OverallStatus = "Success"
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during Teams cache reset: $($_.Exception.Message)"
}

if ($ExportPath) {
    $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
}
else {
    $Result | Format-List
}
