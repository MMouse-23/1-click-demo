Function Lib-Generate-SSHKey {
  Param (
    [string] $basedir,
    [object] $datavar
  )

  $unixbasedir = $basedir -replace ('\\','/')
  write-log -message "Generating SSHKey"
  $string = 
  Set-Content "$($basedir)\System\Temp\$($datavar.queueuuid).bat" "c:\progra~1\Git\git-bash.exe -c 'ssh-keygen -t rsa -b 4096 -C `"$($datavar.SenderEMail)`" -f $($unixbasedir)/System/temp/$($datavar.queueuuid).key -q -P `"`";'" -Encoding ASCII
  start-process "$($basedir)\System\temp\$($datavar.queueuuid).bat"
  sleep 60
  try {
    $PrivateKey = get-content "$($basedir)\System\temp\$($datavar.queueuuid).key"
    [string]$Public     = get-content "$($basedir)\System\temp\$($datavar.queueuuid).key.pub"
    $resultobject =@{
      Private = $PrivateKey
      Public  = $Public
    };
  } catch {
    sleep 180
    $PrivateKey = get-content "$($basedir)\System\temp\$($datavar.queueuuid).key"
    [string]$Public     = get-content "$($basedir)\System\temp\$($datavar.queueuuid).key.pub"
    $resultobject =@{
      Private = $PrivateKey
      Public  = $Public
    };
  }
  return $resultobject  
} 