<#
.SYNOPSIS
Audits mailbox forwarding rules and flags external forwarding configurations.
#>
param (
    [string[]]$UserPrincipalName, # Optional: Specific user(s) to check
    [string]$ExportPath
)

try {
    # Connect to Exchange Online
    Connect-ExchangeOnline -ShowProgress $true -ErrorAction Stop

    $Mailboxes = if ($UserPrincipalName) {
        Get-Mailbox -Identity $UserPrincipalName -ErrorAction Stop
    } else {
        Get-Mailbox -ResultSize Unlimited -ErrorAction Stop
    }

    $Result = @()
    foreach ($Mailbox in $Mailboxes) {
        Write-Verbose "Checking forwarding for $($Mailbox.UserPrincipalName)..."
        
        # Check Mailbox-level forwarding
        if ($Mailbox.DeliverToMailboxAndForward -eq $true -or $Mailbox.ForwardingAddress) {
            $ForwardingType = if ($Mailbox.DeliverToMailboxAndForward -eq $true) { "DeliverToMailboxAndForward" } else { "ForwardOnly" }
            $ForwardingAddress = if ($Mailbox.ForwardingAddress) { $Mailbox.ForwardingAddress.PrimarySMTPAddress } else { "N/A" }
            $IsExternal = ($ForwardingAddress -notlike "*$((Get-AcceptedDomain | Where-Object { $_.DomainType -eq 'Authoritative' }).Name -join "*")*")

            $Result += [PSCustomObject]@{
                Mailbox             = $Mailbox.UserPrincipalName
                ForwardingEnabled   = "Yes"
                ForwardingType      = $ForwardingType
                ForwardingAddress   = $ForwardingAddress
                IsExternalForwarding = $IsExternal
                RuleSource          = "Mailbox Setting"
            }
        }

        # Check Inbox Rules for forwarding (requires more permissions or delegated access)
        # This is more complex to check directly and usually requires connecting as the user or having specific audit permissions.
        # For a high-level audit, this part might be omitted or done with specific audit logs.
        # Example (conceptual): Get-InboxRule -Mailbox $Mailbox.UserPrincipalName | Where-Object {$_.ForwardTo -or $_.RedirectTo}
        # Given limitations, we'll focus on Mailbox-level forwarding directly.
    }

    if ($ExportPath) {
        if ($ExportPath.EndsWith(".csv")) {
            $Result | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        elseif ($ExportPath.EndsWith(".html")) {
            $Result | ConvertTo-Html -Title "Mailbox Forwarding Audit Report" | Out-File -Path $ExportPath
        }
        else {
            Write-Warning "Invalid export path. Please specify a .csv or .html file."
        }
    }
    else {
        $Result | Format-Table -AutoSize
    }

    Disconnect-ExchangeOnline -Confirm:$false
}
catch {
    Write-Error "An error occurred during mailbox forwarding audit: $($_.Exception.Message)"
}
