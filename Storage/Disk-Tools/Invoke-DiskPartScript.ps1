<#
.SYNOPSIS
Executes a DiskPart script file on a local or remote computer, capturing its output.
Requires explicit -Execute switch to perform changes, otherwise operates in a -WhatIf mode.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName = "localhost",
    [string]$DiskPartScriptFilePath, # Path to the .txt script file containing DiskPart commands
    [switch]$Execute, # If present, DiskPart commands are actually executed
    [string]$ExportOutputToPath
)

if (-not $DiskPartScriptFilePath) {
    $DiskPartScriptFilePath = Read-Host "Enter the path to the DiskPart script file (e.g., C:\Scripts\diskpart.txt)"
}
if (-not (Test-Path -Path $DiskPartScriptFilePath)) {
    Write-Error "DiskPart script file not found at: $DiskPartScriptFilePath"
    return
}

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    DiskPartScript = $DiskPartScriptFilePath
    ExecutionMode = if ($Execute) { "Execute" } else { "WhatIf (Report Only)" }
    ActionTaken = "None"
    DiskPartOutput = "N/A"
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "--- Running DiskPart Script on $ComputerName ---"

    # Copy script to remote temporary location if remote
    $RemoteScriptPath = $DiskPartScriptFilePath
    if ($ComputerName -ne "localhost") {
        $RemoteTempDir = "\\$ComputerName\C$\Windows\Temp"
        $RemoteScriptPath = Join-Path -Path $RemoteTempDir -ChildPath (Split-Path -Path $DiskPartScriptFilePath -Leaf)
        Write-Host "Copying script to remote temp: $RemoteScriptPath"
        Copy-Item -Path $DiskPartScriptFilePath -Destination $RemoteTempDir -Force -ErrorAction Stop
        $Result.ActionsTaken += "Script copied to $RemoteScriptPath"
    }

    if ($Execute) {
        Write-Host "EXECUTE MODE: DiskPart commands will be run."
        if ($pscmdlet.ShouldProcess("Execute DiskPart script '$DiskPartScriptFilePath' on '$ComputerName'", "Run DiskPart")) {
            $Command = "diskpart.exe /s `"$RemoteScriptPath`""
            Write-Host "Executing: $Command"
            $DiskPartOutput = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                cmd.exe /c $using:Command 2>&1
            } -ErrorAction Stop | Out-String
            $Result.ActionTaken += "DiskPart script executed."
            $Result.DiskPartOutput = $DiskPartOutput
            Write-Host "DiskPart script completed. Check output for details."
        }
    }
    else {
        Write-Host "WHATIF MODE: DiskPart commands will NOT be run. Showing script content and expected command."
        $Result.ActionTaken = "Script previewed (WhatIf)"
        $Result.DiskPartOutput = Get-Content -Path $DiskPartScriptFilePath | Out-String
        Write-Host "DiskPart Script Content:"
        Write-Host "------------------------"
        Write-Host $Result.DiskPartOutput
        Write-Host "------------------------"
        Write-Host "If executed, the command would be: diskpart.exe /s `"$RemoteScriptPath`""
    }
    
    $Result.OverallStatus = "Success"
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during DiskPart script execution: $($_.Exception.Message)"
}
finally {
    # Clean up remote script
    if ($ComputerName -ne "localhost" -and (Test-Path -Path $RemoteScriptPath -ComputerName $ComputerName -ErrorAction SilentlyContinue)) {
        Remove-Item -Path $RemoteScriptPath -Force -ErrorAction SilentlyContinue
        Write-Host "Cleaned up remote script file: $RemoteScriptPath"
    }

    if ($ExportOutputToPath) {
        $Result | Export-Csv -Path $ExportOutputToPath -NoTypeInformation -Force
    }
    else {
        $Result | Format-List
    }
}
