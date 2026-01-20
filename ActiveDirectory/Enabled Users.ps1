<#
.SYNOPSIS
Gets a list of all enabled users in Active Directory and exports them to a text file.
#>
$outfile = "Enabled_Users_$(Get-Date -Format dd.MM.yyyy).txt"

try {
    Get-ADUser -Filter {Enabled -eq $true} | Select-Object UserPrincipalName | Out-File -FilePath $outfile
}
catch {
    Write-Error "Could not retrieve enabled users. Please ensure the Active Directory module is available and you have the necessary permissions."
}
