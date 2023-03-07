# Sypnosis: Looks for an active Remote Desktop session across a list of servers 

$UsernameToLogoff = Read-host -Prompt "Enter Username to logoff"

$USERNAME = 0
$SESSIONNAME = 1
$ID = 2

Get-Content -path "C:\Scripts\serverstologoff.txt" |
    ForEach-Object{
        $x = quser /server:$_
        for ($i = 1; $i -lt $x.count; $i++){    # skip the header
            $y = $x[$i].split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)[$USERNAME..$ID]  # get the 1st 3 columns of data
            if ($y[$USERNAME] -eq $USernameToLogoff){
                logoff $y[$ID] /server:$_           # log off the session id
            }
    }
}
