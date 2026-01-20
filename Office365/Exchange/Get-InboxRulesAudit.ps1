<#
.SYNOPSIS
Audits suspicious inbox rules (e.g., those that delete, forward, or redirect messages) across Exchange Online mailboxes.
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
        Write-Verbose "Auditing inbox rules for $($Mailbox.UserPrincipalName)..."
        try {
            $Rules = Get-InboxRule -Mailbox $Mailbox.UserPrincipalName -ErrorAction Stop

            foreach ($Rule in $Rules) {
                $IsSuspicious = $false
                $SuspicionReason = @()

                # Check for delete actions
                if ($Rule.DeleteMessage -eq $true) {
                    $IsSuspicious = $true
                    $SuspicionReason += "Deletes messages"
                }
                # Check for forwarding/redirection actions
                if ($Rule.ForwardTo -or $Rule.RedirectTo) {
                    $IsSuspicious = $true
                    $SuspicionReason += "Forwards/Redirects messages"
                    # Could add more logic to check if forwarding to external domains
                }
                # Check for moving to Junk or other non-standard folders
                if ($Rule.MoveToFolder -and $Rule.MoveToFolder.ToString() -ne "Junk E-mail") {
                    # This might be legitimate, but worth flagging if not to known safe folders
                    $IsSuspicious = $true
                    $SuspicionReason += "Moves messages to non-standard folder"
                }

                if ($IsSuspicious) {
                    $Result += [PSCustomObject]@{
                        Mailbox           = $Mailbox.UserPrincipalName
                        RuleName          = $Rule.Name
                        Enabled           = $Rule.Enabled
                        Description       = $Rule.Description
                        Action            = ($Rule.Actions | Out-String).Trim() # Summarize actions
                        IsSuspicious      = "Yes"
                        SuspicionReason   = ($SuspicionReason -join "; ")
                    }
                }
            }
        }
        catch {
            Write-Warning "Failed to audit inbox rules for $($Mailbox.UserPrincipalName): $($_.Exception.Message)"
            $Result += [PSCustomObject]@{
                Mailbox           = $Mailbox.UserPrincipalName
                RuleName          = "Error"
                Enabled           = "Error"
                Description       = "Error"
                Action            = "Error"
                IsSuspicious      = "Yes"
                SuspicionReason   = "Error retrieving rules: $($_.Exception.Message)"
            }
        }
    }

    if ($ExportPath) {
        if ($ExportPath.EndsWith(".csv")) {
            $Result | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        elseif ($ExportPath.EndsWith(".html")) {
            $Result | ConvertTo-Html -Title "Inbox Rules Audit Report" | Out-File -Path $ExportPath
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
    Write-Error "An error occurred during inbox rules audit: $($_.Exception.Message)"
}
