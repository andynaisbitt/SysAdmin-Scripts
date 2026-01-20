<#
.SYNOPSIS
Reports on certificate expiry for local machine and IIS. (Can be expanded for RDS and file shares).
#>
param (
    [string[]]$ComputerName,
    [int]$WarningDays = 30,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Checking certificate expiry on $Computer..."
    try {
        # Local Machine Certificates
        Invoke-Command -ComputerName $Computer -ScriptBlock {
            Get-ChildItem -Path Cert:\LocalMachine\My -Recurse | ForEach-Object {
                if ($_.NotAfter -lt (Get-Date).AddDays($using:WarningDays)) {
                    [PSCustomObject]@{
                        ComputerName = $using:Computer
                        StoreLocation = "LocalMachine"
                        StoreName = "My"
                        Subject = $_.Subject
                        Issuer = $_.Issuer
                        NotBefore = $_.NotBefore
                        NotAfter = $_.NotAfter
                        Thumbprint = $_.Thumbprint
                        ExpiresInDays = ($_.NotAfter - (Get-Date)).Days
                        Status = if ($_.NotAfter -lt (Get-Date)) { "Expired" } elseif ($_.NotAfter -lt (Get-Date).AddDays($using:WarningDays)) { "Warning" } else { "OK" }
                    }
                }
            }
        } -ErrorAction SilentlyContinue

        # IIS Certificates (requires IIS module)
        try {
            Invoke-Command -ComputerName $Computer -ScriptBlock {
                Import-Module WebAdministration -ErrorAction SilentlyContinue
                Get-ChildItem IIS:\SslBindings | ForEach-Object {
                    $Cert = Get-Item $_.Sites[0].Ssl.StoreName + ":\" + $_.Thumbprint
                    if ($Cert.NotAfter -lt (Get-Date).AddDays($using:WarningDays)) {
                        [PSCustomObject]@{
                            ComputerName = $using:Computer
                            StoreLocation = "IIS"
                            StoreName = $_.Sites[0].Ssl.StoreName
                            Subject = $Cert.Subject
                            Issuer = $Cert.Issuer
                            NotBefore = $Cert.NotBefore
                            NotAfter = $Cert.NotAfter
                            Thumbprint = $Cert.Thumbprint
                            ExpiresInDays = ($Cert.NotAfter - (Get-Date)).Days
                            Status = if ($Cert.NotAfter -lt (Get-Date)) { "Expired" } elseif ($Cert.NotAfter -lt (Get-Date).AddDays($using:WarningDays)) { "Warning" } else { "OK" }
                        }
                    }
                }
            } -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "Failed to check IIS certificates on '$Computer'. IIS module might not be available or an error occurred: $($_.Exception.Message)"
        }
    }
    catch {
        Write-Warning "Failed to check certificates on '$Computer'. Error: $($_.Exception.Message)"
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
