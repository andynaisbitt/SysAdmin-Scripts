<#
.SYNOPSIS
Reports on Windows Firewall posture, checking profile status, inbound default action, and logging settings for Cyber Essentials compliance.
#>
param (
    [string[]]$ComputerName,
    [string]$AdOuPath,
    [string]$ExportPath
)

# --- Load Core Get-Targets.ps1 ---
. (Join-Path -Path $PSScriptRoot -ChildPath "..\..\Core\Get-Targets.ps1")

try {
    $TargetComputers = Get-Targets -ComputerName $ComputerName -AdOuPath $AdOuPath
    if (-not $TargetComputers) {
        Write-Warning "No target computers found for checks. Exiting."
        return
    }

    $Result = foreach ($Computer in $TargetComputers) {
        Write-Verbose "Checking firewall posture on $Computer..."
        try {
            Invoke-Command -ComputerName $Computer -ScriptBlock {
                $FwProfile = Get-NetFirewallProfile -ErrorAction Stop

                $DomainProfile = $FwProfile | Where-Object { $_.Name -eq "Domain" }
                $PrivateProfile = $FwProfile | Where-Object { $_.Name -eq "Private" }
                $PublicProfile = $FwProfile | Where-Object { $_.Name -eq "Public" }

                $DomainEnabled = if ($DomainProfile) { $DomainProfile.Enabled } else { "N/A" }
                $DomainInboundAction = if ($DomainProfile) { $DomainProfile.DefaultInboundAction } else { "N/A" }
                $DomainLoggingEnabled = if ($DomainProfile) { $DomainProfile.LogFileName -ne "" } else { "N/A" }

                $PrivateEnabled = if ($PrivateProfile) { $PrivateProfile.Enabled } else { "N/A" }
                $PrivateInboundAction = if ($PrivateProfile) { $PrivateProfile.DefaultInboundAction } else { "N/A" }
                $PrivateLoggingEnabled = if ($PrivateProfile) { $PrivateProfile.LogFileName -ne "" } else { "N/A" }

                $PublicEnabled = if ($PublicProfile) { $PublicProfile.Enabled } else { "N/A" }
                $PublicInboundAction = if ($PublicProfile) { $PublicProfile.DefaultInboundAction } else { "N/A" }
                $PublicLoggingEnabled = if ($PublicProfile) { $PublicProfile.LogFileName -ne "" } else { "N/A" }
                
                # Determine Posture
                $PostureStatus = "FAIL"
                $Reason = @()
                if ($DomainEnabled -eq $true -and $DomainInboundAction -ne "Allow") { $PostureStatus = "PASS" } else { $Reason += "Domain Profile not configured correctly." }
                if ($PrivateEnabled -eq $true -and $PrivateInboundAction -ne "Allow") { $PostureStatus = "PASS" } else { $Reason += "Private Profile not configured correctly." }
                if ($PublicEnabled -eq $true -and $PublicInboundAction -ne "Allow") { $PostureStatus = "PASS" } else { $Reason += "Public Profile not configured correctly." }
                if ($DomainLoggingEnabled -ne $true) { $Reason += "Domain Profile Logging not enabled." }
                if ($PrivateLoggingEnabled -ne $true) { $Reason += "Private Profile Logging not enabled." }
                if ($PublicLoggingEnabled -ne $true) { $Reason += "Public Profile Logging not enabled." }

                if ($Reason.Count -eq 0) { $PostureStatus = "PASS" } else { $PostureStatus = "FAIL" }

                [PSCustomObject]@{
                    ComputerName = $using:Computer
                    DomainProfileEnabled = $DomainEnabled
                    DomainInboundAction = $DomainInboundAction
                    DomainLoggingEnabled = $DomainLoggingEnabled
                    PrivateProfileEnabled = $PrivateEnabled
                    PrivateInboundAction = $PrivateInboundAction
                    PrivateLoggingEnabled = $PrivateLoggingEnabled
                    PublicProfileEnabled = $PublicEnabled
                    PublicInboundAction = $PublicInboundAction
                    PublicLoggingEnabled = $PublicLoggingEnabled
                    PostureStatus = $PostureStatus
                    FailureReason = ($Reason -join "; ")
                }
            } -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to get firewall posture from '$Computer'. Error: $($_.Exception.Message)"
            [PSCustomObject]@{
                ComputerName = $Computer
                PostureStatus = "ERROR"
                FailureReason = $_.Exception.Message
            }
        }
    }

    if ($ExportPath) {
        if ($ExportPath.EndsWith(".csv")) {
            $Result | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        elseif ($ExportPath.EndsWith(".html")) {
            $Result | ConvertTo-Html -Title "Firewall Posture Report" | Out-File -Path $ExportPath
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
    Write-Error "An error occurred during firewall posture report generation: $($_.Exception.Message)"
}
