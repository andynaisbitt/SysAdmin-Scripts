<#
.SYNOPSIS
Generates a comprehensive report including disk space usage and (optionally) the largest folders within specified paths.
#>
param (
    [string]$ComputerName = "localhost",
    [string[]]$PathsForLargestFolders, # Paths to scan for largest folders
    [int]$DepthForLargestFolders = 1,
    [int]$TopCountForLargestFolders = 10,
    [string]$ExportPath
)

# --- Load Core Export-Report.ps1 ---
. (Join-Path -Path $PSScriptRoot -ChildPath "..\Core\Export-Report.ps1")

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    DiskSpaceSummary = @()
    LargestFoldersReport = @()
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "--- Generating Disk and Top Folders Report on $ComputerName ---"

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # 1. Disk Space Summary
        Write-Host "Collecting disk space summary..."
        $LogicalDisks = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object DeviceID, @{N="FreeSpaceGB";E={[math]::Round($_.FreeSpace / 1GB, 2)}}, @{N="SizeGB";E={[math]::Round($_.Size / 1GB, 2)}}, @{N="PercentFree";E={[math]::Round($_.FreeSpace / $_.Size * 100, 2)}}
        $using:Result.DiskSpaceSummary = $LogicalDisks

        # 2. Largest Folders Report (if paths are provided)
        if ($using:PathsForLargestFolders) {
            Write-Host "Collecting largest folders report..."
            # Assuming Get-LargestFolders.ps1 is in Storage folder
            $LargestFoldersScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Get-LargestFolders.ps1"
            if (Test-Path -Path $LargestFoldersScriptPath) {
                foreach ($Path in $using:PathsForLargestFolders) {
                    $using:Result.LargestFoldersReport += & $LargestFoldersScriptPath -Path $Path -Depth $using:DepthForLargestFolders -Top $using:TopCountForLargestFolders -ErrorAction SilentlyContinue
                }
            }
            else {
                Write-Warning "Get-LargestFolders.ps1 script not found. Skipping largest folders report."
                $using:Result.Errors += "Get-LargestFolders.ps1 script not found."
            }
        }
        $using:Result.OverallStatus = "Success"
    } -ErrorAction Stop

    $Result.OverallStatus = "Success"
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during disk and top folders report generation: $($_.Exception.Message)"
}

if ($ExportPath) {
    if ($ExportPath.EndsWith(".csv")) {
        $Result.DiskSpaceSummary | Export-Csv -Path (Join-Path (Split-Path $ExportPath) "DiskSpaceSummary.csv") -NoTypeInformation -Force
        $Result.LargestFoldersReport | Export-Csv -Path (Join-Path (Split-Path $ExportPath) "LargestFoldersReport.csv") -NoTypeInformation -Force
        Write-Host "Reports exported to CSV."
    }
    elseif ($ExportPath.EndsWith(".html")) {
        $HtmlContent = "<h1>Disk and Top Folders Report for $ComputerName</h1>"
        $HtmlContent += "<h2>Disk Space Summary</h2>"
        $HtmlContent += $Result.DiskSpaceSummary | ConvertTo-Html -Fragment
        if ($Result.LargestFoldersReport.Count -gt 0) {
            $HtmlContent += "<h2>Largest Folders Report</h2>"
            $HtmlContent += $Result.LargestFoldersReport | ConvertTo-Html -Fragment
        }
        $HtmlContent | Out-File -FilePath $ExportPath -Force
        Write-Host "Report exported to HTML: $ExportPath"
    }
    else {
        Write-Warning "Invalid export path. Please specify a .csv or .html file."
    }
}
else {
    Write-Host "--- Disk Space Summary ---"
    $Result.DiskSpaceSummary | Format-Table -AutoSize
    if ($Result.LargestFoldersReport.Count -gt 0) {
        Write-Host "`n--- Largest Folders Report ---"
        $Result.LargestFoldersReport | Format-Table -AutoSize
    }
}
