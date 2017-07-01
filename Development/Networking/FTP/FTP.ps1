#ftp server 
    $ftp = "" 
    $user = "" 
    $pass = ""
    $SetType = "bin"  
    $remotePickupDir = Get-ChildItem 'c:\ChinaFTP\' -recurse #set directory
    $webclient = New-Object System.Net.WebClient 

    $webclient.Credentials = New-Object System.Net.NetworkCredential($user,$pass)  
    foreach($item in $remotePickupDir){ 
        $uri = New-Object System.Uri($ftp+$item.Name) 
        #$webclient.UploadFile($uri,$item.FullName)
        $webclient.DownloadFile($uri,$item.FullName)
    } 
