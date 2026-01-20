<#
.SYNOPSIS
Uninstalls software by display name or product code, handling MSI and EXE uninstalls.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$DisplayName,
    [string]$ProductCode,
    [string]$ComputerName
)

if (-not $DisplayName -and -not $ProductCode) {
    Write-Error "Please specify either DisplayName or ProductCode."
    return
}
if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

try {
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param ($DisplayName, $ProductCode)

        $FoundSoftware = $null
        if ($DisplayName) {
            $FoundSoftware = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$DisplayName*" }
        }
        elseif ($ProductCode) {
            $FoundSoftware = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq $ProductCode }
        }

        if ($FoundSoftware) {
            foreach ($Software in $FoundSoftware) {
                $UninstallString = $Software.UninstallString
                if ($UninstallString) {
                    if ($Software.PSChildName -match "^\{[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}\}$") {
                        # MSI uninstall
                        Write-Host "Attempting MSI uninstall for '$($Software.DisplayName)'..."
                        $Arguments = "/qn /x $($Software.PSChildName)"
                        Start-Process -FilePath msiexec.exe -ArgumentList $Arguments -Wait -NoNewWindow -ErrorAction Stop
                    }
                    else {
                        # EXE uninstall
                        Write-Host "Attempting EXE uninstall for '$($Software.DisplayName)'..."
                        # Extract executable and arguments, then execute
                        # This is a simplification; real-world might need more parsing
                        Start-Process -FilePath powershell.exe -ArgumentList "-Command `"$UninstallString /S`"" -Wait -NoNewWindow -ErrorAction Stop
                    }
                    Write-Host "Uninstallation of '$($Software.DisplayName)' completed."
                }
                else {
                    Write-Warning "No uninstall string found for '$($Software.DisplayName)'."
                }
            }
        }
        else {
            Write-Warning "Software '$DisplayName$ProductCode' not found on this computer."
        }
    } -ArgumentList $DisplayName, $ProductCode -WhatIf:$pscmdlet.WhatIf -Confirm:$pscmdlet.Confirm
}
catch {
    Write-Error "An error occurred during software uninstallation on '$ComputerName': $($_.Exception.Message)"
}
