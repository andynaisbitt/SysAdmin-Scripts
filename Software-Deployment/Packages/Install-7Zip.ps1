<#
.SYNOPSIS
Downloads and silently installs 7-Zip, verifies installation.
#>
param (
    [string]$ComputerName,
    [string]$DownloadUrl = "https://www.7-zip.org/a/7z1900-x64.exe" # Example URL, update for latest
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

try {
    Write-Host "Attempting to install 7-Zip on '$ComputerName'..."

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param ($DownloadUrl)
        
        $InstallerPath = Join-Path -Path $env:TEMP -ChildPath "7z_setup.exe"
        Write-Host "Downloading 7-Zip from $DownloadUrl to $InstallerPath..."
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -ErrorAction Stop

        Write-Host "Starting silent installation..."
        # 7-Zip silent install switch is /S
        Start-Process -FilePath $InstallerPath -ArgumentList "/S" -Wait -NoNewWindow -ErrorAction Stop

        Write-Host "Verifying installation..."
        $InstalledPath = Join-Path -Path ${env:ProgramFiles} -ChildPath "7-Zip\7zG.exe"
        if (Test-Path -Path $InstalledPath) {
            Write-Host "7-Zip successfully installed."
        }
        else {
            Write-Warning "7-Zip installation verification failed."
        }
    } -ArgumentList $DownloadUrl
}
catch {
    Write-Error "An error occurred during 7-Zip installation on '$ComputerName': $($_.Exception.Message)"
}
