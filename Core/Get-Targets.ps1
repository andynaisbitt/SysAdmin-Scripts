<#
.SYNOPSIS
Retrieves a list of target computer names from various sources (single name, CSV, AD OU, text file).
#>
param (
    [string[]]$ComputerName,     # Single computer name or array
    [string]$CsvPath,            # Path to a CSV file with a 'ComputerName' column
    [string]$AdOuPath,           # Distinguished Name of an AD OU to query for computers
    [string]$TextFilePath        # Path to a text file with one computer name per line
)

$Targets = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

# Add from direct ComputerName parameter
if ($ComputerName) {
    $ComputerName | ForEach-Object { [void]$Targets.Add($_) }
}

# Add from CSV file
if ($CsvPath) {
    if (Test-Path -Path $CsvPath) {
        Import-Csv -Path $CsvPath | ForEach-Object {
            if ($_.PSObject.Properties.Name -contains "ComputerName") {
                [void]$Targets.Add($_.ComputerName)
            }
            else {
                Write-Warning "CSV '$CsvPath' does not contain a 'ComputerName' column. Skipping."
            }
        }
    }
    else {
        Write-Warning "CSV file not found: $CsvPath"
    }
}

# Add from AD OU
if ($AdOuPath) {
    try {
        Get-ADComputer -Filter * -SearchBase $AdOuPath -ErrorAction Stop | ForEach-Object {
            [void]$Targets.Add($_.Name)
        }
    }
    catch {
        Write-Warning "Failed to query AD OU '$AdOuPath': $($_.Exception.Message)"
    }
}

# Add from text file
if ($TextFilePath) {
    if (Test-Path -Path $TextFilePath) {
        Get-Content -Path $TextFilePath | ForEach-Object {
            [void]$Targets.Add($_)
        }
    }
    else {
        Write-Warning "Text file not found: $TextFilePath"
    }
}

$Targets.ToArray() | Sort-Object
