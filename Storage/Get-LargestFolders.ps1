<#
.SYNOPSIS
Identifies the top N largest folders within a specified path.
#>
param (
    [string]$Path,
    [int]$Depth = 1, # How many sub-levels to scan
    [int]$Top = 10,  # Number of largest folders to return
    [string[]]$ExcludePath, # Paths to exclude (e.g., C:\Windows, C:\Program Files)
    [string]$ExportPath
)

if (-not $Path) {
    $Path = Read-Host "Enter the path to scan (e.g., C:\Shares)"
}
if (-not (Test-Path -Path $Path)) {
    Write-Error "Path not found: $Path"
    return
}

$Result = @()
try {
    Write-Host "Scanning '$Path' for largest folders (Depth: $Depth, Top: $Top)..."
    $Folders = Get-ChildItem -Path $Path -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {
        # Exclude paths if specified
        $Exclude = $false
        foreach ($Excl in $ExcludePath) {
            if ($_.FullName -like "$Excl\*") {
                $Exclude = $true
                break
            }
        }
        -not $Exclude
    }

    foreach ($Folder in $Folders) {
        $FolderDepth = ($Folder.FullName.Split('\').Count - $Path.Split('\').Count)
        if ($FolderDepth -le $Depth) {
            $Size = (Get-ChildItem -Path $Folder.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $Result += [PSCustomObject]@{
                Path = $Folder.FullName
                SizeGB = [math]::Round($Size / 1GB, 2)
            }
        }
    }

    $Result = $Result | Sort-Object -Property SizeGB -Descending | Select-Object -First $Top

    if ($ExportPath) {
        if ($ExportPath.EndsWith(".csv")) {
            $Result | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        elseif ($ExportPath.EndsWith(".html")) {
            $Result | ConvertTo-Html | Out-File -Path $ExportPath
        }
        else {
            Write-Warning "Invalid export path. Please specify a .csv or .html file."
        }
    }
    else {
        $Result | Format-Table -AutoSize
    }
}
catch {
    Write-Error "An error occurred while getting largest folders: $($_.Exception.Message)"
}
