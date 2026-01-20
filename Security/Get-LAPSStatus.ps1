<#
.SYNOPSIS
Reports on the status and configuration of both legacy LAPS and Windows LAPS.
#>
param (
    [string[]]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    # Default to local machine if no computer names are specified
    $ComputerName = $env:COMPUTERNAME
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Checking LAPS status on $Computer..."
    try {
        Invoke-Command -ComputerName $Computer -ScriptBlock {
            # --- Legacy LAPS ---
            $LegacyLapsStatus = $null
            try {
                # Check for LAPS client-side extension (CSE) registry key
                $LapsCseKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\Notify\LAPS"
                $LapsCseInstalled = Test-Path -Path $LapsCseKey

                # Check for managed passwords
                $ManagedPasswordRegistry = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\LAPS\Config" -ErrorAction SilentlyContinue
                $ManagedPasswordEnabled = if ($ManagedPasswordRegistry) { $ManagedPasswordRegistry.EnableLocalAdminPasswordManagement -eq 1 } else { $false }

                # Check AD for ms-Mcs-AdmPwd attribute presence (requires AD module on execution machine)
                $AdComputer = Get-ADComputer -Identity $using:Computer -Properties "ms-Mcs-AdmPwd" -ErrorAction SilentlyContinue
                $PasswordInAD = if ($AdComputer -and $AdComputer."ms-Mcs-AdmPwd") { "Yes" } else { "No" }

                $LegacyLapsStatus = [PSCustomObject]@{
                    Type                  = "Legacy LAPS"
                    Installed             = $LapsCseInstalled
                    ManagedLocally        = $ManagedPasswordEnabled
                    PasswordInActiveDirectory = $PasswordInAD
                }
            }
            catch {
                $LegacyLapsStatus = [PSCustomObject]@{
                    Type                  = "Legacy LAPS"
                    Installed             = "Error"
                    ManagedLocally        = "Error"
                    PasswordInActiveDirectory = "Error"
                    Error                 = $_.Exception.Message
                }
            }

            # --- Windows LAPS ---
            $WindowsLapsStatus = $null
            try {
                # Check for Windows LAPS policy via GPO (simplistic check for registry key created by GPO)
                $WindowsLapsPolicyKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\LAPS\Policy"
                $WindowsLapsPolicyEnabled = Test-Path -Path $WindowsLapsPolicyKey

                # Check AD for msLAPS-CurrentPassword attribute (requires AD module on execution machine)
                $AdComputer = Get-ADComputer -Identity $using:Computer -Properties "msLAPS-CurrentPassword" -ErrorAction SilentlyContinue
                $WindowsLapsPasswordInAD = if ($AdComputer -and $AdComputer."msLAPS-CurrentPassword") { "Yes" } else { "No" }

                $WindowsLapsStatus = [PSCustomObject]@{
                    Type                  = "Windows LAPS"
                    EnabledViaPolicy      = $WindowsLapsPolicyEnabled
                    PasswordInActiveDirectory = $WindowsLapsPasswordInAD
                }
            }
            catch {
                $WindowsLapsStatus = [PSCustomObject]@{
                    Type                  = "Windows LAPS"
                    EnabledViaPolicy      = "Error"
                    PasswordInActiveDirectory = "Error"
                    Error                 = $_.Exception.Message
                }
            }
            
            [PSCustomObject]@{
                ComputerName = $using:Computer
                LegacyLAPS   = $LegacyLapsStatus
                WindowsLAPS  = $WindowsLapsStatus
            }
        } -ErrorAction Stop | ForEach-Object { $Result += $_ }
    }
    catch {
        Write-Warning "Failed to get LAPS status from '$Computer'. Error: $($_.Exception.Message)"
        $Result += [PSCustomObject]@{
            ComputerName = $Computer
            LegacyLAPS   = [PSCustomObject]@{Type="Legacy LAPS";Installed="Error";Error=$_.Exception.Message}
            WindowsLAPS  = [PSCustomObject]@{Type="Windows LAPS";EnabledViaPolicy="Error";Error=$_.Exception.Message}
        }
    }
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
