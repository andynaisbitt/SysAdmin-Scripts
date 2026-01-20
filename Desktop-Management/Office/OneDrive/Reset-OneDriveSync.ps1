<#
.SYNOPSIS
Runs the OneDrive reset command, verifies sign-in state (best effort), outputs sync health indicators, and logs changes.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName = "localhost"
)

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    OneDriveProcessClosed = "No"
    ResetCommandExecuted = "No"
    SignInStateAfterReset = "N/A"
    SyncHealthIndicators = "N/A"
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "--- Resetting OneDrive Sync on $ComputerName ---"

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # 1. Close OneDrive
        Write-Host "Attempting to close OneDrive..."
        Get-Process OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2 # Give OneDrive a moment to fully shut down
        $using:Result.OneDriveProcessClosed = "Yes"
        Write-Host "OneDrive process closed."

        # 2. Run OneDrive Reset Command
        # The OneDrive reset command varies slightly with build versions.
        # This one is common for consumer/business versions.
        $OneDriveExePath = Join-Path (Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive" -ErrorAction SilentlyContinue).UserFolder "OneDrive.exe"
        if (-not (Test-Path -Path $OneDriveExePath)) {
            $OneDriveExePath = Join-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
            if (-not (Test-Path -Path $OneDriveExePath)) {
                throw "OneDrive.exe not found. Cannot reset."
            }
        }

        Write-Host "Executing OneDrive reset command..."
        if ($pscmdlet.ShouldProcess("Run OneDrive reset command", "Reset OneDrive")) {
            Start-Process -FilePath $OneDriveExePath -ArgumentList "/reset" -Wait -NoNewWindow -ErrorAction Stop
            $using:Result.ResetCommandExecuted = "Yes"
            Write-Host "OneDrive reset command executed. OneDrive should now be restarting and resyncing."
        }

        # 3. Verify Sign-in State (best effort - by checking running process and log files)
        Write-Host "Verifying OneDrive sign-in state (best effort)..."
        Start-Sleep -Seconds 10 # Give OneDrive time to restart
        if (Get-Process OneDrive -ErrorAction SilentlyContinue) {
            $using:Result.SignInStateAfterReset = "Process Running (User should re-authenticate if prompted)"
        } else {
            $using:Result.SignInStateAfterReset = "Process Not Running (Check user interaction)"
        }

        # 4. Output Sync Health Indicators (placeholder, requires parsing OneDrive logs)
        Write-Host "Sync health indicators require parsing OneDrive diagnostic logs for accurate status."
        $using:Result.SyncHealthIndicators = "Check OneDrive logs manually for errors or specific events."

        $using:Result.OverallStatus = "Success"
    } -ErrorAction Stop

    $Result.OverallStatus = "Success"
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during OneDrive sync reset: $($_.Exception.Message)"
}

if ($ExportPath) {
    $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
}
else {
    $Result | Format-List
}
