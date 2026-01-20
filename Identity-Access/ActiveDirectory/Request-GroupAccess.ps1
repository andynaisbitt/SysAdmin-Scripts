<#
.SYNOPSIS
Generates a request pack for Active Directory group access and optionally adds users to groups if approved.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$UserName,          # User to add to groups
    [string[]]$GroupsRequested, # Array of group names
    [string]$Justification,     # Reason for the request
    [string]$TicketReference,   # Service Desk ticket reference
    [switch]$Approve,          # If present, actually add the user to the groups
    [string]$OutputFolder = (Join-Path $PSScriptRoot "..\..\Output\GroupAccessRequests")
)

if (-not $UserName) { $UserName = Read-Host "Enter the user's SamAccountName" }
if (-not $GroupsRequested) { $GroupsRequested = (Read-Host "Enter comma-separated group names").Split(',') }
if (-not $Justification) { $Justification = Read-Host "Enter justification for the group access" }
if (-not $TicketReference) { $TicketReference = Read-Host "Enter service desk ticket reference" }

# Ensure output folder exists
if (-not (Test-Path -Path $OutputFolder)) {
    New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$RequestFileName = "GroupAccessRequest_$UserName_$Timestamp.json"
$RequestFilePath = Join-Path -Path $OutputFolder -ChildPath $RequestFileName

$RequestData = [PSCustomObject]@{
    Requestor           = $env:USERNAME
    Timestamp           = Get-Date
    UserName            = $UserName
    GroupsRequested     = $GroupsRequested -join ", "
    Justification       = $Justification
    TicketReference     = $TicketReference
    ApprovalStatus      = if ($Approve) { "Approved (Action Taken)" } else { "Pending Approval" }
    ApprovalTimestamp   = if ($Approve) { Get-Date } else { $null }
    ActionsTaken        = @()
    Errors              = @()
}

try {
    # Check if user exists
    $UserExists = Get-ADUser -Identity $UserName -ErrorAction SilentlyContinue
    if (-not $UserExists) {
        throw "User '$UserName' not found in Active Directory."
    }

    # Check if groups exist
    $AllGroupsExist = $true
    foreach ($Group in $GroupsRequested) {
        if (-not (Get-ADGroup -Identity $Group -ErrorAction SilentlyContinue)) {
            Write-Warning "Group '$Group' not found in Active Directory."
            $RequestData.Errors += "Group '$Group' not found."
            $AllGroupsExist = $false
        }
    }
    if (-not $AllGroupsExist) {
        throw "One or more requested groups were not found. Please review warnings."
    }

    if ($Approve) {
        foreach ($Group in $GroupsRequested) {
            if ($pscmdlet.ShouldProcess("Add user '$UserName' to group '$Group'", "Add User to Group")) {
                try {
                    Add-ADGroupMember -Identity $Group -Members $UserName -ErrorAction Stop
                    $RequestData.ActionsTaken += "Added $UserName to $Group."
                    Write-Host "User '$UserName' added to group '$Group'."
                }
                catch {
                    $RequestData.Errors += "Failed to add $UserName to $Group: $($_.Exception.Message)."
                    Write-Warning "Failed to add user '$UserName' to group '$Group': $($_.Exception.Message)"
                }
            }
        }
    }
    else {
        Write-Host "Request pack generated. No groups added. Use -Approve switch to add groups."
    }

    $RequestData | ConvertTo-Json -Depth 5 | Out-File -FilePath $RequestFilePath -Force
    Write-Host "Group access request pack saved to: $RequestFilePath"
}
catch {
    Write-Error "An error occurred during group access request: $($_.Exception.Message)"
    $RequestData.Errors += "Overall Error: $($_.Exception.Message)."
    $RequestData | ConvertTo-Json -Depth 5 | Out-File -FilePath $RequestFilePath -Force # Save with errors
}
