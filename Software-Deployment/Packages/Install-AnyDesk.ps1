<#
.SYNOPSIS
Downloads and silently installs AnyDesk, verifies installation, and optionally sets unattended access.
#>
param (
    [string]$ComputerName,
    [string]$DownloadUrl = "https://download.anydesk.com/AnyDesk.exe",
    [securestring]$UnattendedPassword
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

try {
    Write-Host "Attempting to install AnyDesk on '$ComputerName'..."

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param ($DownloadUrl, $UnattendedPassword)
        
        $InstallerPath = Join-Path -Path $env:TEMP -ChildPath "AnyDesk.exe"
        Write-Host "Downloading AnyDesk from $DownloadUrl to $InstallerPath..."
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -ErrorAction Stop

        Write-Host "Starting silent installation..."
        # AnyDesk silent install usually involves running the downloaded executable directly
        # and then setting the password. The exact switches may vary by version.
        Start-Process -FilePath $InstallerPath -ArgumentList "--install C:\Program Files (x86)\AnyDesk --silent" -Wait -NoNewWindow -ErrorAction Stop

        Write-Host "Verifying installation..."
        $InstalledPath = "C:\Program Files (x86)\AnyDesk\AnyDesk.exe"
        if (Test-Path -Path $InstalledPath) {
            Write-Host "AnyDesk successfully installed."
            
            if ($UnattendedPassword) {
                Write-Host "Setting unattended access password..."
                # Convert secure string back to plain text for command line (use with caution)
                $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($UnattendedPassword))
                Start-Process -FilePath $InstalledPath -ArgumentList "--set-password $Password" -NoNewWindow -Wait -ErrorAction Stop
                Write-Host "Unattended access password set."
            }
        }
        else {
            Write-Warning "AnyDesk installation verification failed."
        }
    } -ArgumentList $DownloadUrl, $UnattendedPassword
}
catch {
    Write-Error "An error occurred during AnyDesk installation on '$ComputerName': $($_.Exception.Message)"
}
