<#
.SYNOPSIS
Downloads approved tools to Software/Toolbox, validates hash, and stores versions in a manifest.
#>
param (
    [string]$ToolName, # Can be "Sysinternals", "Tcping", "Psping" or a custom tool name
    [string]$DownloadUrl, # Required for custom tools, optional for pre-defined
    [string]$ExpectedHash, # Required for custom tools, pre-defined for others
    [string]$Platform = "Windows", # Currently only "Windows" is fully supported
    [switch]$Force # Force re-download and overwrite if exists
)

$ManifestPath = Join-Path -Path $PSScriptRoot -ChildPath "_manifest.json"
$ToolboxPath = Join-Path -Path $PSScriptRoot -ChildPath $Platform

# Ensure ToolboxPath exists
if (-not (Test-Path -Path $ToolboxPath)) {
    New-Item -Path $ToolboxPath -ItemType Directory -Force | Out-Null
}

# --- Pre-defined Tool Configurations ---
$ToolConfigs = @{
    "Sysinternals" = @{
        DownloadUrl = "https://download.sysinternals.com/files/SysinternalsSuite.zip"
        # Hash needs to be updated periodically from Sysinternals site
        ExpectedHash = "A2B8C9D0E1F2A3B4C5D6E7F8A9B0C1D2E3F4A5B6C7D8E9F0A1B2C3D4E5F6A7B8" # Placeholder: **UPDATE THIS HASH**
        FileName = "SysinternalsSuite.zip"
        Extract = $true
        VersionSource = "README.txt" # Look inside the zip for version info
    }
    "Tcping" = @{
        DownloadUrl = "https://www.elifulkerson.com/projects/tcping.zip"
        ExpectedHash = "B8C9D0E1F2A3B4C5D6E7F8A9B0C1D2E3F4A5B6C7D8E9F0A1B2C3D4E5F6A7B89" # Placeholder: **UPDATE THIS HASH**
        FileName = "tcping.zip"
        Extract = $true
        ExtractTargetFile = "tcping.exe"
    }
    "Psping" = @{
        DownloadUrl = "https://download.sysinternals.com/files/Psping.zip"
        ExpectedHash = "C9D0E1F2A3B4C5D6E7F8A9B0C1D2E3F4A5B6C7D8E9F0A1B2C3D4E5F6A7B890" # Placeholder: **UPDATE THIS HASH**
        FileName = "psping.zip"
        Extract = $true
        ExtractTargetFile = "psping.exe"
    }
    # Add more tools here
}

try {
    # Load manifest
    $Manifest = if (Test-Path -Path $ManifestPath) {
        Get-Content -Raw -Path $ManifestPath | ConvertFrom-Json
    } else {
        @{Tools = @()}
    }

    $CurrentToolConfig = $null
    if ($ToolConfigs.ContainsKey($ToolName)) {
        $CurrentToolConfig = $ToolConfigs[$ToolName]
        $DownloadUrl = $CurrentToolConfig.DownloadUrl
        $ExpectedHash = $CurrentToolConfig.ExpectedHash
        $FileName = $CurrentToolConfig.FileName
    }
    elseif (-not $DownloadUrl -or -not $ExpectedHash) {
        Write-Error "For custom tools, DownloadUrl and ExpectedHash parameters are required."
        return
    }
    else {
        # Custom tool, determine filename from URL
        $FileName = (Split-Path -Path $DownloadUrl -Leaf)
    }

    $DownloadPath = Join-Path -Path $ToolboxPath -ChildPath $FileName
    
    # Check if tool already exists and is valid
    $ToolExists = Test-Path -Path $DownloadPath
    $ManifestEntry = $Manifest.Tools | Where-Object { $_.Name -eq $ToolName }

    if ($ToolExists -and $ManifestEntry -and ($ManifestEntry.Hash -eq $ExpectedHash) -and -not $Force) {
        Write-Host "$ToolName already exists and hash is valid. Skipping download (use -Force to re-download)."
        return $ManifestEntry # Return the existing manifest entry
    }

    Write-Host "Downloading $ToolName from $DownloadUrl..."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $DownloadPath -ErrorAction Stop
    
    # Validate hash
    $ActualHash = (Get-FileHash -Path $DownloadPath -Algorithm SHA256).Hash
    if ($ActualHash -ne $ExpectedHash) {
        Write-Error "Hash mismatch for $ToolName. Expected $ExpectedHash, but got $ActualHash. Deleting downloaded file."
        Remove-Item -Path $DownloadPath -ErrorAction SilentlyContinue
        return $null
    }
    Write-Host "Hash validated successfully for $ToolName."

    # Handle extraction for zip files
    $ToolVersion = "Unknown"
    $ToolActualPath = $DownloadPath
    if ($CurrentToolConfig -and $CurrentToolConfig.Extract -eq $true) {
        Write-Host "Extracting $FileName..."
        $ExtractFolder = Join-Path -Path $ToolboxPath -ChildPath (Split-Path -Path $FileName -BaseName)
        Expand-Archive -Path $DownloadPath -DestinationPath $ExtractFolder -Force
        Remove-Item -Path $DownloadPath # Remove the zip file after extraction
        $ToolActualPath = $ExtractFolder
        Write-Host "Tool extracted to $ExtractFolder."

        # Attempt to get version from extracted files
        if ($CurrentToolConfig.VersionSource -eq "README.txt") {
            $ReadmeFile = Join-Path -Path $ExtractFolder -ChildPath "README.txt"
            if (Test-Path -Path $ReadmeFile) {
                $VersionLine = Get-Content -Path $ReadmeFile | Select-String -Pattern "Version: " -ErrorAction SilentlyContinue
                if ($VersionLine) {
                    $ToolVersion = ($VersionLine.ToString() -split "Version: ")[-1].Trim()
                }
            }
        }
        elseif ($CurrentToolConfig.ExtractTargetFile) {
            $TargetExePath = Join-Path -Path $ExtractFolder -ChildPath $CurrentToolConfig.ExtractTargetFile
            if (Test-Path -Path $TargetExePath) {
                $ToolVersion = (Get-Item -Path $TargetExePath).VersionInfo.FileVersion
            }
        }
    }
    
    # Update or add manifest entry
    if ($ManifestEntry) {
        $ManifestEntry.Path = $ToolActualPath
        $ManifestEntry.Version = $ToolVersion
        $ManifestEntry.Hash = $ActualHash
        $ManifestEntry.DownloadDate = (Get-Date).ToString()
    } else {
        $Manifest.Tools += @{
            Name = $ToolName
            FileName = $FileName
            Path = $ToolActualPath
            Version = $ToolVersion
            Hash = $ActualHash
            DownloadDate = (Get-Date).ToString()
        }
    }
    $Manifest | ConvertTo-Json -Depth 100 -Compress | Set-Content -Path $ManifestPath -Force
    
    Write-Host "$ToolName downloaded, validated, and manifest updated successfully."
    return ($Manifest.Tools | Where-Object { $_.Name -eq $ToolName })
}
catch {
    Write-Error "An error occurred while downloading or validating $ToolName: $($_.Exception.Message)"
    return $null
}
