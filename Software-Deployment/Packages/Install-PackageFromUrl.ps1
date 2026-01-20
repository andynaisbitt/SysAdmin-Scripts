<#
.SYNOPSIS
A generic helper script to download and install a package from a URL.
#>
param (
    [string]$ComputerName,
    [string]$DownloadUrl,
    [string]$SilentArgs,
    [string]$DetectionRule # PowerShell script block as string for detection
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

if (-not $DownloadUrl) {
    $DownloadUrl = Read-Host "Enter the URL of the installer"
}
if (-not $SilentArgs) {
    $SilentArgs = Read-Host "Enter the silent installation arguments (e.g., /S)"
}
if (-not $DetectionRule) {
    $DetectionRule = Read-Host "Enter a PowerShell script block (as a string) to detect successful installation (e.g., 'Test-Path \"C:\\Program Files\\MySoftware\"')"
}

try {
    Write-Host "Attempting to install package from URL on '$ComputerName'..."

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param ($DownloadUrl, $SilentArgs, $DetectionRule)
        
        $InstallerPath = Join-Path -Path $env:TEMP -ChildPath (Split-Path -Path $DownloadUrl -Leaf)
        Write-Host "Downloading installer from $DownloadUrl to $InstallerPath..."
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -ErrorAction Stop

        Write-Host "Starting silent installation..."
        Start-Process -FilePath $InstallerPath -ArgumentList $SilentArgs -Wait -NoNewWindow -ErrorAction Stop

        Write-Host "Verifying installation with detection rule: $DetectionRule"
        if (Invoke-Expression -Command $DetectionRule) {
            Write-Host "Package successfully installed and detected."
        }
        else {
            Write-Warning "Package installation verification failed."
        }
    } -ArgumentList $DownloadUrl, $SilentArgs, $DetectionRule
}
catch {
    Write-Error "An error occurred during package installation on '$ComputerName': $($_.Exception.Message)"
}
