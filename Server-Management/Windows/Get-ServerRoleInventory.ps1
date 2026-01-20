<#
.SYNOPSIS
Retrieves installed Windows features/roles and key service status from one or more servers.
#>
param (
    [string[]]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Getting server role inventory from $Computer..."
    try {
        Invoke-Command -ComputerName $Computer -ScriptBlock {
            # Get Installed Windows Features/Roles
            # On Server OS, Get-WindowsFeature is typically used. For workstations, DISM.
            # We'll use Get-WindowsFeature if available.
            $Features = $null
            try {
                if (Get-Command -Name Get-WindowsFeature -ErrorAction SilentlyContinue) {
                    $Features = Get-WindowsFeature | Where-Object { $_.Installed -eq $true } | Select-Object -ExpandProperty DisplayName
                }
                else {
                    # Fallback for client OS or older servers
                    $DismFeatures = (dism.exe /online /Get-Features /format:table | Select-String -Pattern "Enabled" | ForEach-Object { ($_.ToString().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries))[0] })
                    $Features = $DismFeatures
                }
            }
            catch {
                $Features = "Error: $($_.Exception.Message)"
            }

            # Get Key Services (configurable list, or check services related to installed features)
            # For simplicity, we'll check a few common critical services.
            $CriticalServicesToCheck = @("Spooler", "W3SVC", "LanmanServer", "SQLSERVER", "SQLBrowser", "Netlogon", "DNS", "TermService")
            $ServiceStatus = @()
            foreach ($SvcName in $CriticalServicesToCheck) {
                try {
                    $Svc = Get-Service -Name $SvcName -ErrorAction SilentlyContinue
                    if ($Svc) {
                        $ServiceStatus += "$($Svc.DisplayName): $($Svc.Status)"
                    }
                }
                catch {} # Service might not exist
            }

            [PSCustomObject]@{
                ComputerName      = $using:Computer
                InstalledFeatures = ($Features -join "; ")
                KeyServiceStatus  = ($ServiceStatus -join "; ")
                # Could add more details like IP, OS, etc.
            }
        } -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to get server role inventory from '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName      = $Computer
            InstalledFeatures = "Error"
            KeyServiceStatus  = "Error"
            Error             = $_.Exception.Message
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
