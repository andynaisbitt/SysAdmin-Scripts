$host.ui.RawUI.WindowTitle = "Set Local PW Expiry" 

CD C:\Scripts\Sysinternals\PSTools\
Write-Host -BackgroundColor 000 Local Admin User Accounts:
(net localgroup administrators).where({$_ -match '-{79}'},'skipuntil') -notmatch '-{79}|The command completed'

Set-Variable -name User -value (read-host -prompt "Which user?")

Write-Host Enabling Password Expiry...
wmic UserAccount where Name=$User set PasswordExpires=True

Write-host Setting Local PW Expiry to 60 Days...
net accounts /maxpwage:60

Function Start-Countdown 
{  
Param(
        [Int32]$Seconds = 5,
        [string]$Message = "Pausing for 5 seconds..."
    )
    ForEach ($Count in (1..$Seconds))
    {   Write-Progress -Id 1 -Activity $Message -Status "Waiting for $Seconds seconds, $($Seconds - $Count) left" -PercentComplete (($Count / $Seconds) * 100)
        Start-Sleep -Seconds 1
    }
    Write-Progress -Id 1 -Activity $Message -Status "Completed" -PercentComplete 100 -Completed
}

Start-Countdown -Seconds 5 -Message "Report complete.. closing window." #Task Scheduling message

EXIT
