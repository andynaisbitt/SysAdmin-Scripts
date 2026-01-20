<#
.SYNOPSIS
Resets Windows Search and Outlook index components, providing before/after status.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName = "localhost"
)

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    BeforeSearchServiceStatus = "N/A"
    BeforeOutlookIndexStatus = "N/A"
    ActionTaken = "None"
    AfterSearchServiceStatus = "N/A"
    AfterOutlookIndexStatus = "N/A"
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "--- Starting Outlook Search Index Repair on $ComputerName ---"

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # --- Before Status ---
        $SearchServiceBefore = Get-Service -Name wsearch -ErrorAction SilentlyContinue
        if ($SearchServiceBefore) {
            $using:Result.BeforeSearchServiceStatus = $SearchServiceBefore.Status
            Write-Host "Before: Windows Search Service Status: $($SearchServiceBefore.Status)"
        } else {
            Write-Warning "Windows Search Service not found."
            $using:Result.BeforeSearchServiceStatus = "Not Found"
        }

        # Outlook Index Status (difficult to get programmatically without COM, best to check after restart)
        Write-Host "Before: Outlook index status cannot be accurately retrieved programmatically without Outlook running."
        $using:Result.BeforeOutlookIndexStatus = "Check manually after Outlook restart"

        # 1. Stop Outlook (if running)
        Write-Host "Attempting to close Outlook..."
        Get-Process outlook -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        # 2. Stop Windows Search Service
        if ($pscmdlet.ShouldProcess("Stop Windows Search Service", "Stop Service")) {
            try {
                Stop-Service wsearch -Force -ErrorAction Stop
                Write-Host "Windows Search Service stopped."
                $using:Result.ActionTaken += "Stopped Search Service; "
            }
            catch {
                Write-Warning "Failed to stop Windows Search Service: $($_.Exception.Message)"
                $using:Result.Errors += "Stop Search Service Failed: $($_.Exception.Message)"
            }
        }

        # 3. Rebuild Search Index (by deleting index files)
        if ($pscmdlet.ShouldProcess("Rebuild Windows Search Index", "Rebuild Index")) {
            try {
                $IndexDataPath = Join-Path $env:ProgramData "Microsoft\Search\Data\Applications\Windows"
                if (Test-Path -Path $IndexDataPath) {
                    Remove-Item -Path "$IndexDataPath\*" -Recurse -Force -ErrorAction Stop
                    Write-Host "Windows Search Index files removed. Index will be rebuilt."
                    $using:Result.ActionTaken += "Removed Index Files; "
                } else {
                    Write-Warning "Windows Search Index path not found: $IndexDataPath"
                    $using:Result.Errors += "Index Path Not Found: $IndexDataPath; "
                }
            }
            catch {
                Write-Warning "Failed to remove index files: $($_.Exception.Message)"
                $using:Result.Errors += "Remove Index Files Failed: $($_.Exception.Message)"
            }
        }

        # 4. Start Windows Search Service
        if ($pscmdlet.ShouldProcess("Start Windows Search Service", "Start Service")) {
            try {
                Start-Service wsearch -ErrorAction Stop
                Write-Host "Windows Search Service started."
                $using:Result.ActionTaken += "Started Search Service; "
            }
            catch {
                Write-Warning "Failed to start Windows Search Service: $($_.Exception.Message)"
                $using:Result.Errors += "Start Search Service Failed: $($_.Exception.Message)"
            }
        }

        # --- After Status ---
        $SearchServiceAfter = Get-Service -Name wsearch -ErrorAction SilentlyContinue
        if ($SearchServiceAfter) {
            $using:Result.AfterSearchServiceStatus = $SearchServiceAfter.Status
            Write-Host "After: Windows Search Service Status: $($SearchServiceAfter.Status)"
        }
        $using:Result.AfterOutlookIndexStatus = "Index rebuild initiated. Outlook will rebuild index on next launch."
        
        Write-Host "Please relaunch Outlook to allow index rebuilding to complete."
        $using:Result.OverallStatus = "Success"
    } -ErrorAction Stop

    $Result.OverallStatus = "Success"
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during Outlook search index repair: $($_.Exception.Message)"
}

if ($ExportPath) {
    $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
}
else {
    $Result | Format-List
}
