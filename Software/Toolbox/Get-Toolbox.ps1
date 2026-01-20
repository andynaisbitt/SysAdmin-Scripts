<#
.SYNOPSIS
Downloads approved tools to Software/Toolbox, validates hash, and stores versions in a manifest.
#>
param (
    [string]$ToolName,
    [string]$DownloadUrl,
    [string]$ExpectedHash,
    [string]$Platform = "Windows" # or "Linux"
)

$ManifestPath = Join-Path -Path $PSScriptRoot -ChildPath "_manifest.json"
$ToolboxPath = Join-Path -Path $PSScriptRoot -ChildPath $Platform

# Ensure ToolboxPath exists
if (-not (Test-Path -Path $ToolboxPath)) {
    New-Item -Path $ToolboxPath -ItemType Directory -Force
}

try {
    # Load manifest
    $Manifest = Get-Content -Raw -Path $ManifestPath | ConvertFrom-Json
    
    # Download tool
    $FileName = (Get-Item -Path $DownloadUrl).Name
    $DownloadPath = Join-Path -Path $ToolboxPath -ChildPath $FileName
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $DownloadPath
    
    # Validate hash
    $ActualHash = (Get-FileHash -Path $DownloadPath -Algorithm SHA256).Hash
    if ($ActualHash -ne $ExpectedHash) {
        Write-Error "Hash mismatch for $ToolName. Expected $ExpectedHash, but got $ActualHash."
        Remove-Item -Path $DownloadPath -ErrorAction SilentlyContinue
        return
    }
    
    # Update manifest
    $Manifest.Tools += @{
        Name = $ToolName
        FileName = $FileName
        Path = $DownloadPath
        Version = "Unknown" # Need to figure out how to get version for each tool
        Hash = $ActualHash
        DownloadDate = (Get-Date).ToString()
    }
    $Manifest | ConvertTo-Json -Depth 100 | Set-Content -Path $ManifestPath
    
    Write-Host "$ToolName downloaded and validated successfully."
}
catch {
    Write-Error "An error occurred while downloading or validating $ToolName: $($_.Exception.Message)"
}
