<#
.SYNOPSIS
Deploys the ManageEngine SelfScan utility.
#>
param (
    [string]$SelfScanUrl = "https://example.com/SelfScan.exe",
    [string]$ScheduleUrl = "https://example.com/schedule.xml",
    [string]$InstallPath = "C:\ProgramData\ManageEngine"
)

try {
    if (-not (Test-Path -Path $InstallPath)) {
        New-Item -Path $InstallPath -ItemType Directory
    }

    $SelfScanPath = Join-Path -Path $InstallPath -ChildPath "selfscan.exe"
    $SchedulePath = Join-Path -Path $InstallPath -ChildPath "schedule.xml"

    $client = New-Object System.Net.WebClient
    $client.DownloadFile($SelfScanUrl, $SelfScanPath)
    $client.DownloadFile($ScheduleUrl, $SchedulePath)

    Register-ScheduledTask -Xml $SchedulePath -TaskName "ManageEngine SelfScan Task"
}
catch {
    Write-Error "Failed to deploy ManageEngine SelfScan. Please ensure the URLs are correct and you have administrative privileges."
}
