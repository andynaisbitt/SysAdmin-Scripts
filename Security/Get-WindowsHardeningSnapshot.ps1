<#
.SYNOPSIS
Collects various Windows hardening settings as a snapshot, exported as JSON for diffing.
#>
param (
    [string]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Snapshot = [PSCustomObject]@{
    ComputerName = $ComputerName
    Timestamp    = Get-Date
    Settings     = @{}
}

try {
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # --- NLA Status ---
        $NlaPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
        $NlaEnabled = (Get-ItemProperty -Path $NlaPath -Name UserAuthentication -ErrorAction SilentlyContinue).UserAuthentication -eq 1
        $using:Snapshot.Settings.Add("NLAEnabled", $NlaEnabled)

        # --- SMBv1 Status ---
        $Smb1ClientPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
        $Smb1ClientEnabled = (Get-ItemProperty -Path $Smb1ClientPath -Name EnableSMB1P rotocol -ErrorAction SilentlyContinue).EnableSMB1Protocol -ne 0
        $using:Snapshot.Settings.Add("SMBv1ClientEnabled", $Smb1ClientEnabled)

        $Smb1ServerPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
        $Smb1ServerEnabled = (Get-ItemProperty -Path $Smb1ServerPath -Name SMB1 -ErrorAction SilentlyContinue).SMB1 -ne 0
        $using:Snapshot.Settings.Add("SMBv1ServerEnabled", $Smb1ServerEnabled)

        # --- LLMNR Status ---
        $LlmPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DnsClient"
        $LlmEnabled = (Get-ItemProperty -Path $LlmPath -Name EnableMulticast -ErrorAction SilentlyContinue).EnableMulticast -ne 0
        $using:Snapshot.Settings.Add("LLMNREnabled", $LlmEnabled)

        # --- NTLM Audit Setting ---
        # This is more complex, typically found in audit policies
        # For simplicity, checking a common registry setting if present (e.g., via Group Policy)
        $NtLmAuditPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        $NtLmAuditValue = (Get-ItemProperty -Path $NtLmAuditPath -Name LmCompatibilityLevel -ErrorAction SilentlyContinue).LmCompatibilityLevel
        $using:Snapshot.Settings.Add("NTLMAuditLevel", $NtLmAuditValue)

        # --- TLS Versions (Best Effort) ---
        $Tls10Client = (Test-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client\Enabled")
        $Tls11Client = (Test-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client\Enabled")
        $Tls12Client = (Test-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client\Enabled")
        $using:Snapshot.Settings.Add("TLS10ClientEnabled", $Tls10Client)
        $using:Snapshot.Settings.Add("TLS11ClientEnabled", $Tls11Client)
        $using:Snapshot.Settings.Add("TLS12ClientEnabled", $Tls12Client)

        # And for Server roles
        $Tls10Server = (Test-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server\Enabled")
        $Tls11Server = (Test-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server\Enabled")
        $Tls12Server = (Test-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server\Enabled")
        $using:Snapshot.Settings.Add("TLS10ServerEnabled", $Tls10Server)
        $using:Snapshot.Settings.Add("TLS11ServerEnabled", $Tls11Server)
        $using:Snapshot.Settings.Add("TLS12ServerEnabled", $Tls12Server)

        # Export the snapshot object (as JSON)
        $using:Snapshot | ConvertTo-Json -Depth 10 | Out-File -FilePath "$($using:ExportPath)\$($using:ComputerName)_HardeningSnapshot.json"
    } -ErrorAction Stop
}
catch {
    Write-Error "An error occurred while collecting hardening snapshot from '$ComputerName': $($_.Exception.Message)"
}
