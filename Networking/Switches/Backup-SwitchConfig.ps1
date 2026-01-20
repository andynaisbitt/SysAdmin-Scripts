<#
.SYNOPSIS
Backs up running configurations from network switches via SSH.
#>
param (
    [string]$InputCsvPath, # CSV with columns: ComputerName, Vendor, UserName, Password (optional, requires secure string)
    [string]$OutputBasePath = (Join-Path $PSScriptRoot "..\..\Output\SwitchConfigs"),
    [string]$ExportPath
)

if (-not $InputCsvPath) {
    $InputCsvPath = Read-Host "Enter the path to the CSV file containing switch details (ComputerName, Vendor, UserName, Password)"
}
if (-not (Test-Path -Path $InputCsvPath)) {
    Write-Error "Input CSV file not found at: $InputCsvPath"
    return
}

# Ensure output folder exists
if (-not (Test-Path -Path $OutputBasePath)) {
    New-Item -Path $OutputBasePath -ItemType Directory -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$SwitchList = Import-Csv -Path $InputCsvPath
$Result = @()

foreach ($Switch in $SwitchList) {
    $ComputerName = $Switch.ComputerName
    $Vendor = $Switch.Vendor
    $UserName = $Switch.UserName
    $Password = $Switch.Password # Should be a SecureString in a real scenario, handled outside script
    
    Write-Host "--- Backing up config for $ComputerName ($Vendor) ---"

    $ConfigFileName = Join-Path -Path $OutputBasePath -ChildPath "$ComputerName-$Vendor-Config-$Timestamp.txt"
    $Command = ""

    switch ($Vendor.ToLower()) {
        "cisco" {
            $Command = "show running-config"
        }
        "hp" {
            $Command = "show running-config"
        }
        "dell" {
            $Command = "show running-config"
        }
        default {
            Write-Warning "Unsupported vendor '$Vendor' for $ComputerName. Skipping."
            $Result += [PSCustomObject]@{
                ComputerName = $ComputerName
                Vendor       = $Vendor
                Status       = "Skipped"
                Details      = "Unsupported vendor."
            }
            continue
        }
    }

    try {
        # Using ssh.exe (OpenSSH client)
        $SshArgs = "$UserName@$ComputerName `"$Command`""
        $Output = (ssh.exe $SshArgs 2>&1 | Out-String) # Assuming password-less SSH or manual prompt

        $Output | Out-File -FilePath $ConfigFileName -Encoding UTF8 -ErrorAction Stop
        Write-Host "Config saved to $ConfigFileName."
        
        $Result += [PSCustomObject]@{
            ComputerName = $ComputerName
            Vendor       = $Vendor
            Status       = "Success"
            Details      = "Config saved to $ConfigFileName."
        }
    }
    catch {
        Write-Warning "Failed to backup config for $ComputerName: $($_.Exception.Message)"
        $Result += [PSCustomObject]@{
            ComputerName = $ComputerName
            Vendor       = $Vendor
            Status       = "Failed"
            Details      = $_.Exception.Message
        }
    }
}

if ($ExportPath) {
    if ($ExportPath.EndsWith(".csv")) {
        $Result | Export-Csv -Path $ExportPath -NoTypeInformation
    }
    elseif ($ExportPath.EndsWith(".html")) {
        $Result | ConvertTo-Html -Title "Switch Configuration Backup Report" | Out-File -Path $ExportPath
    }
    else {
        Write-Warning "Invalid export path. Please specify a .csv or .html file."
    }
}
else {
    $Result | Format-Table -AutoSize
}
