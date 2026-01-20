<#
.SYNOPSIS
Downloads and silently installs TeamViewer, verifies installation, and supports remote deployment.
#>
param (
    [string]$ComputerName,
    [string]$DownloadUrl = "https://download.teamviewer.com/download/TeamViewer_Setup.exe",
    [string]$LogPath = "$env:TEMP\TeamViewer_Install.log"
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

try {
    Write-Host "Attempting to install TeamViewer on '$ComputerName'..."

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param ($DownloadUrl, $LogPath)
        
        $InstallerPath = Join-Path -Path $env:TEMP -ChildPath "TeamViewer_Setup.exe"
        Write-Host "Downloading TeamViewer from $DownloadUrl to $InstallerPath..."
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -ErrorAction Stop

        Write-Host "Starting silent installation..."
        Start-Process -FilePath $InstallerPath -ArgumentList "/S /qn /norestart" -Wait -NoNewWindow -ErrorAction Stop

        Write-Host "Verifying installation..."
        $InstalledVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\TeamViewer" -ErrorAction SilentlyContinue).Version
        if ($InstalledVersion) {
            Write-Host "TeamViewer version $InstalledVersion successfully installed."
        }
        else {
            Write-Warning "TeamViewer installation verification failed."
        }
    } -ArgumentList $DownloadUrl, $LogPath
}
catch {
    Write-Error "An error occurred during TeamViewer installation on '$ComputerName': $($_.Exception.Message)"
}
