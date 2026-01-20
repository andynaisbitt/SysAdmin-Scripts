<#
.SYNOPSIS
Performs a series of common fixes for printer issues on a workstation.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName,
    [string]$PrinterShareName, # Optional: Name of the network printer to remove/re-add
    [switch]$RemoveReaddPrinter, # Remove and re-add printer connection
    [switch]$TestPrint,         # Attempt a test print to XPS/PDF
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the computer name of the workstation"
}

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    SpoolerRestarted = "No"
    QueueCleared = "No"
    PrinterRemovedReadded = "No"
    DnsFlushed = "No"
    TestPrintStatus = "N/A"
    OverallStatus = "Failed"
    Errors = @()
}

try {
    # 1. Restart Spooler
    Write-Host "Attempting to restart Print Spooler on $ComputerName..."
    if ($pscmdlet.ShouldProcess("Restart Print Spooler on $ComputerName", "Restart Service")) {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Stop-Service -Name Spooler -Force -ErrorAction Stop
            Start-Service -Name Spooler -ErrorAction Stop
        } -ErrorAction Stop
        $Result.SpoolerRestarted = "Yes"
        Write-Host "Print Spooler restarted."
    }

    # 2. Clear Spool Folder
    Write-Host "Attempting to clear print spool folder on $ComputerName..."
    if ($pscmdlet.ShouldProcess("Clear print spool folder on $ComputerName", "Clear Folder")) {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            $SpoolFolderPath = Join-Path -Path $env:windir -ChildPath "System32\spool\PRINTERS"
            if (Test-Path -Path $SpoolFolderPath) {
                Remove-Item -Path "$SpoolFolderPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "Spool folder cleared."
            }
            else {
                Write-Warning "Spool folder not found: $SpoolFolderPath"
            }
        } -ErrorAction Stop
        $Result.QueueCleared = "Yes"
        Write-Host "Print queue cleared."
    }

    # 3. Remove and Re-add Printer Connection
    if ($RemoveReaddPrinter -and $PrinterShareName) {
        Write-Host "Attempting to remove and re-add printer '$PrinterShareName' on $ComputerName..."
        if ($pscmdlet.ShouldProcess("Remove and re-add printer '$PrinterShareName' on $ComputerName", "Printer Reinstall")) {
            Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                $PrinterPath = "\\$using:ComputerName\$using:PrinterShareName" # Assuming printer is shared from this server
                # Find local connection to this network printer
                $Printer = Get-Printer | Where-Object { $_.PortName -like "*$PrinterPath*" -or $_.ShareName -eq $using:PrinterShareName}
                if ($Printer) {
                    Remove-Printer -InputObject $Printer -ErrorAction Stop
                    Write-Host "Printer '$PrinterShareName' removed."
                    Add-Printer -ConnectionName $PrinterPath -ErrorAction Stop
                    Write-Host "Printer '$PrinterShareName' re-added."
                    $Result.PrinterRemovedReadded = "Yes"
                }
                else {
                    Write-Warning "Printer '$PrinterShareName' not found as a local connection on $using:ComputerName."
                }
            } -ErrorAction Stop
        }
    }
    elseif ($RemoveReaddPrinter -and -not $PrinterShareName) {
        Write-Warning "Cannot remove/re-add printer: PrinterShareName not specified."
    }

    # 4. Flush DNS
    Write-Host "Attempting to flush DNS cache on $ComputerName..."
    if ($pscmdlet.ShouldProcess("Flush DNS cache on $ComputerName", "Flush DNS")) {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock { ipconfig /flushdns } -ErrorAction Stop
        $Result.DnsFlushed = "Yes"
        Write-Host "DNS cache flushed."
    }

    # 5. Test Print to XPS/PDF
    if ($TestPrint) {
        Write-Host "Attempting test print on $ComputerName..."
        if ($pscmdlet.ShouldProcess("Perform test print on $ComputerName", "Test Print")) {
            try {
                Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                    # This is a complex step, typically requires GUI interaction or specific print drivers.
                    # A robust test print would involve sending a small document to a known test printer (e.g., Microsoft Print to PDF)
                    # For a simple check, we can just indicate the intent.
                    $TestFile = Join-Path -Path $env:TEMP -ChildPath "test_print.txt"
                    "This is a test print from PowerShell script." | Out-File -FilePath $TestFile
                    Start-Process -FilePath $TestFile -Verb Print -ErrorAction Stop
                    Start-Sleep -Seconds 5 # Give time for spooling
                    Remove-Item -Path $TestFile -Force -ErrorAction SilentlyContinue
                } -ErrorAction Stop
                $Result.TestPrintStatus = "Attempted"
                Write-Host "Test print attempted."
            }
            catch {
                $Result.TestPrintStatus = "Failed"
                Write-Warning "Test print failed on $ComputerName: $($_.Exception.Message)"
            }
        }
    }

    $Result.OverallStatus = "Success"
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during print client fix on '$ComputerName': $($_.Exception.Message)"
}

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
