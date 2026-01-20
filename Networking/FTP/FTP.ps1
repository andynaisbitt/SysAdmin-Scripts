<#
.SYNOPSIS
Uploads or downloads files from an FTP server.
#>
param (
    [string]$FtpServer,
    [string]$UserName,
    [string]$Password,
    [string]$LocalDirectory,
    [string]$RemoteDirectory,
    [ValidateSet("Upload", "Download")]
    [string]$Direction
)

if (-not $FtpServer) {
    $FtpServer = Read-Host "Enter the FTP server"
}
if (-not $UserName) {
    $UserName = Read-Host "Enter the user name"
}
if (-not $Password) {
    $Password = Read-Host "Enter the password" -AsSecureString
    $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
}
if (-not $LocalDirectory) {
    $LocalDirectory = Read-Host "Enter the local directory"
}
if (-not $RemoteDirectory) {
    $RemoteDirectory = Read-Host "Enter the remote directory"
}
if (-not $Direction) {
    $Direction = Read-Host "Enter the direction (Upload/Download)"
}

try {
    $webclient = New-Object System.Net.WebClient
    $webclient.Credentials = New-Object System.Net.NetworkCredential($UserName, $Password)

    if ($Direction -eq "Upload") {
        $files = Get-ChildItem -Path $LocalDirectory
        foreach ($file in $files) {
            $uri = New-Object System.Uri("ftp://$FtpServer/$RemoteDirectory/" + $file.Name)
            $webclient.UploadFile($uri, $file.FullName)
        }
    }
    elseif ($Direction -eq "Download") {
        $files = Get-ChildItem -Path $RemoteDirectory
        foreach ($file in $files) {
            $uri = New-Object System.Uri("ftp://$FtpServer/$RemoteDirectory/" + $file.Name)
            $webclient.DownloadFile($uri, (Join-Path -Path $LocalDirectory -ChildPath $file.Name))
        }
    }
}
catch {
    Write-Error "Failed to transfer files. Please ensure the FTP server, credentials, and paths are correct."
}
