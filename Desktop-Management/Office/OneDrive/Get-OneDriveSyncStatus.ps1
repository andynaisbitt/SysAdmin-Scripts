<#
.SYNOPSIS
Checks OneDrive process status, sync client health, and common error codes from logs, providing a simple pass/fail and hints.
#>
param (
    [string]$ComputerName = "localhost"
)

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    OneDriveProcessRunning = "No"
    SyncClientHealthy = "N/A"
    KnownErrorsInLogs = "No"
    ErrorHints = @()
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "--- Checking OneDrive Sync Status on $ComputerName ---"

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # 1. Check OneDrive Process
        $OneDriveProcess = Get-Process OneDrive -ErrorAction SilentlyContinue
        if ($OneDriveProcess) {
            $using:Result.OneDriveProcessRunning = "Yes"
            Write-Host "OneDrive process is running (PID: $($OneDriveProcess.Id))."
        } else {
            Write-Warning "OneDrive process is not running."
            $using:Result.ErrorHints += "OneDrive process not running. User might be logged out or app crashed."
        }

        # 2. Check Sync Client Health (via registry) - Best effort
        # OneDrive stores sync health info in registry, but exact keys/values can vary.
        # This checks a common key for known folder moves.
        $KnownFoldersRoot = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
        $KnownFolders = Get-ItemProperty -Path $KnownFoldersRoot -ErrorAction SilentlyContinue
        $DesktopRedirected = ($KnownFolders.Desktop -notlike "%USERPROFILE%\Desktop")
        $DocumentsRedirected = ($KnownFolders.Documents -notlike "%USERPROFILE%\Documents")
        $PicturesRedirected = ($KnownFolders.Pictures -notlike "%USERPROFILE%\Pictures")
        
        if ($DesktopRedirected -or $DocumentsRedirected -or $PicturesRedirected) {
            $using:Result.SyncClientHealthy = "Potentially Healthy (Known Folders Redirected)"
        } else {
            $using:Result.SyncClientHealthy = "Unknown / Not Redirected"
            $using:Result.ErrorHints += "Known folders (Desktop, Documents, Pictures) might not be syncing via OneDrive."
        }

        # 3. Known Error Codes in Logs (Best-effort parsing)
        # OneDrive logs are typically in %LOCALAPPDATA%\Microsoft\OneDrive\logs
        # Parsing these can be complex. This is a simple check for known error events.
        $OneDriveEventLog = Get-WinEvent -FilterHashtable @{
            LogName = 'OneDriveSync'
            Level = @(1, 2) # Critical, Error
            StartTime = (Get-Date).AddDays(-1) # Last 24 hours
        } -ErrorAction SilentlyContinue
        
        if ($OneDriveEventLog) {
            $using:Result.KnownErrorsInLogs = "Yes"
            foreach ($Event in $OneDriveEventLog) {
                $using:Result.ErrorHints += "OneDrive Log Error (ID: $($Event.Id), Source: $($Event.ProviderName)): $($Event.Message.Substring(0, [System.Math]::Min(100, $Event.Message.Length)))"
            }
        } else {
            $using:Result.KnownErrorsInLogs = "No"
        }

        $using:Result.OverallStatus = "Success"
    } -ErrorAction Stop

    $Result.OverallStatus = "Success"
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during OneDrive sync status check: $($_.Exception.Message)"
}

if ($ExportPath) {
    $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
}
else {
    $Result | Format-List
}
