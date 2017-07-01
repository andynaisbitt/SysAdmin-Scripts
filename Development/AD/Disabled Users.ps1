 import-module activedirectory
 $date = Get-date
 $outfile = "" + "$(Get-Date -Format dd.MM.yyyy)" + ".txt" 
 get-aduser -filter {Enabled -eq "Disabled"} | select-object UserPrincipalName | Out-file -filepath $outfile
