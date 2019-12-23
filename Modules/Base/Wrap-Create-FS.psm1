Function Wrap-Create-FS {
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $UrlBase,
    [string] $UrlAnalytics,
    [string] $jsonbase,
    [string] $jsonAna
  )

# Side load Anaytics disabled since 2.0
  #write-log -message "Building Credential for SSH session";
  #$hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
  #$Securepass = ConvertTo-SecureString $datavar.pepass -AsPlainText -Force;
  #$credential = New-Object System.Management.Automation.PSCredential ("nutanix", $Securepass);
  #$session = New-SSHSession -ComputerName $datavar.peclusterip -Credential $credential -AcceptKey;
#
  #write-log -message "JSON Analytics $jsonAna"
  #write-log -message "URL Analytics $UrlAnalytics"
 #
  #do {;
  #  $count1++
  #    
  #  try{
  #    $binaryAnashort = $UrlAnalytics -split "/" | select -last 1
  #    $jsonAnashort = $jsonAna -split "\\" | select -last 1
#
  #    $session = New-SSHSession -ComputerName $datavar.peclusterip -Credential $credential -AcceptKey
#
  #    $check2 = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=File_Analytics name=2.0.0" -EnsureConnection
  #    if ($check2.output -match "completed") {
#
  #      write-log -message "Already Done"
#
  #    } else {
#
  #      write-log -message "$($check1.output) Current status"
  #      write-log -message "Uploading the Analytics Binaries"
  #      write-log -message "To Its destination /home/nutanix/tmp/$($jsonAnashort)"
  #      write-log -message "and /home/nutanix/tmp/$($binaryAnashort)"
#
  #      $Clean4 = Invoke-SSHCommand -SSHSession $session -command "sudo rm /home/nutanix/tmp/$binaryAnashort" 
  #      $upload1 = Set-SCPFile -LocalFile $jsonAna -RemotePath "/home/nutanix/tmp" -ComputerName $datavar.peclusterip -Credential $credential -AcceptKey $true
  #      sleep 4
  #      $Upload2 = Invoke-SSHCommand -SSHSession $session -command "cd /home/nutanix/tmp/;wget $($UrlAnalytics)" -timeout 999 -EnsureConnection
  #        
  #      write-log -message "Uploading Software in NCLI";
  #        
  #      sleep 2
  #      $NCLI2 = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software upload software-type=file_analytics file-path=/home/nutanix/tmp/$binaryAnashort meta-file-path=/home/nutanix/tmp/$jsonAnashort" -timeout 999 -EnsureConnection  
  #      sleep 2
#
  #      write-log -message "Cleaning, NCLI Output was $($NCLI2.output)"
  #        
  #      $Clean4 = Invoke-SSHCommand -SSHSession $session -command "sudo rm /home/nutanix/tmp/$binaryAnashort" 
  #      sleep 2
  #      $check2 = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=File_Analytics name=2.0.0" -timeout 999 -EnsureConnection
#
  #    }
  #  } catch {
  #
  #    write-log -message "Failure during upload or execute";
  #
  #  }
  #
  #} until ($check2.output -match "completed" -or $count1 -ge 8)
#
  #write-log -message "File_Analytics Upload Success"
  write-log -message "Wait for Forest Task"

  do {
    $Looper++
    [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^Forest" }

    write-log -message "We found $($tasks.count) task";

    [array] $allready = $null

    if ($looper % 4 -eq 0){

      write-log "Cycle $looper out of 300"
    
    }
    if ($tasks){
      Foreach ($task in $tasks){
        if ($task.state -eq "ready"){
          
          write-log -message "Task $($task.taskname) is ready."
    
          $allReady += 1
    
        } else {
    
          $allReady += 0

          if ($looper % 4 -eq 0){
            write-log -message "Task $($task.taskname) is $($task.state)."
          }
        };
      };
      sleep 60
    } else {
      $allReady = 0

      if ($looper % 4 -eq 0){
        Write-log -message "There are no jobs to process."
      }
    }
  } until ($Looper -ge 300 -or $allReady -notcontains 0)

  Function Wait-Task{
    do {
      try{

        $counter++
        write-log -message "Wait for File Server Install Cycle $counter out of 25(minutes)."
    
        $PCtasks = REST-Task-List -ClusterPC_IP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 
        $FileServer = $PCtasks.entities | where {$_.operation_type -eq "FileServerAdd"}
        if (!$FileServer){
          write-log -message "Task does not exist yet"
          do {
            $counterinstall++
            sleep 60
            $PCtasks = REST-Task-List -ClusterPC_IP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 
            $FileServer = $PCtasks.entities | where {$_.operation_type -eq "FileServerAdd"}
          } until ($FileServer -or $counterinstall -ge 5)
        }
        $Inventorycount = 0
        [array]$Results = $null
        foreach ($item in $FileServer){
          if ( $item.percentage_complete -eq 100) {
            $Results += "Done"
     
            write-log -message "FS Install $($item.uuid) is completed."
          } elseif ($item.percentage_complete -ne 100){
            $Inventorycount ++
    
            write-log -message "FS Install $($item.uuid) is still running."
            write-log -message "We found 1 task $($item.status) and is $($item.percentage_complete) % complete"
    
            $Results += "BUSY"
    
          }
        }
        if ($Results -notcontains "BUSY" -or !$FileServer){

          write-log -message "FS Install is done."
     
          $InstallCheck = "Success"
     
        } else{
          sleep 60
        }
    
      }catch{
        write-log -message "Error caught in loop."
      }
    } until ($InstallCheck -eq "Success" -or $counter -ge 40)
    return $item.status
  }

Function Wait-TaskAnalytics{
    do {
      try{

        $counter++
        write-log -message "Wait for File Server Analytics Install Cycle $counter out of 25(minutes)."
    
        $PCtasks = REST-Task-List -ClusterPC_IP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 
        $FileServer = $PCtasks.entities | where {$_.operation_type -eq "DeployFileAnalytics"}
        if (!$FileServer){
          write-log -message "Task does not exist yet"
          do {
            $counterinstall++
            sleep 60
            $PCtasks = REST-Task-List -ClusterPC_IP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 
            $FileServer = $PCtasks.entities | where {$_.operation_type -eq "DeployFileAnalytics"}
          } until ($FileServer -or $counterinstall -ge 5)
        }
        $Inventorycount = 0
        [array]$Results = $null
        foreach ($item in $FileServer){
          if ( $item.percentage_complete -eq 100) {
            $Results += "Done"
     
            write-log -message "Analytics Install $($item.uuid) is completed."
          } elseif ($item.percentage_complete -ne 100){
            $Inventorycount ++
    
            write-log -message "Analytics Install $($item.uuid) is still running."
            write-log -message "We found 1 task $($item.status) and is $($item.percentage_complete) % complete"
    
            $Results += "BUSY"
    
          }
        }
        if ($Results -notcontains "BUSY" -or !$FileServer){

          write-log -message "Analytics Install is done."
     
          $InstallCheck = "Success"
     
        } else{
          sleep 60
        }
    
      }catch{
        write-log -message "Error caught in loop."
      }
    } until ($InstallCheck -eq "Success" -or $counter -ge 40)
    return $item.status
  }

  write-log -message "Checking Downloaded Files"
  
  $versions = REST-AFS-Get-Download-Status -datagen $datagen -datavar $datavar
  $AFSStatus = $versions.entities | where {$_.version -eq $datagen.Filesversion}
  if ($AFSStatus.status -eq "COMPLETED"){
  
    write-log -message "All Ready to go sir"
    
  } else {
  
    write-log -message "Captain the internet has been broken, this download has status $($AFSStatus.status)" -sev "WARN"
    write-log -message "Repairing"
  
    REST-AFS-Start-Download -datagen $datagen -datavar $datavar -afs $AFSStatus
    sleep 30
    $count = 0
    do {
      $count++
      $versions = REST-AFS-Get-Download-Status -datagen $datagen -datavar $datavar
      $AFSStatus = $versions.entities | where {$_.version -eq $datagen.Filesversion}
      if ($AFSStatus.status -ne "INPROGRESS"){
  
        write-log -message "Download has status $($AFSStatus.status) is this it?"
  
      } else {
  
        write-log -message "Download has status $($AFSStatus.status), sleeping"
  
        sleep 30
      }
    } until ($AFSStatus.status -eq "COMPLETED" -or $count -ge 15)
  }

  write-log -message "Installing Files" -slacklevel 1
  write-log -message "Getting Files Network" 

  $subnet = (REST-Get-PE-Networks -datavar $datavar -datagen $datagen).entities | where {$_.name -eq $datagen.nw1name}
  
  write-log -message "Using Subnet $($subnet.uuid)"
  write-log -message "Creating File server"

  if ([version]$datagen.Filesversion -le [version]"3.5.0.1"){
    $filesversion = "3.5.0.1"
  } else {
    $filesversion = $datagen.Filesversion
  }
  write-log -message "Using Version $filesversion"
  $hosts = REST-PE-Get-Hosts -datavar $datavar -datagen $datagen
  foreach ($Box in $hosts.entities){
    [decimal]$totalrambytescap += $Box.memoryCapacityInBytes
    [int]$CoreCap += $Box.numCpuThreads
  }
  $totalGBcap = (($totalrambytescap /1024) /1024) /1024
  $totalGBcap = [math]::Round($totalGBcap)
 
  if ($hosts.entities.count -ge 3 -and $totalGBcap -gt 400){

    write-log -message "Using 3 Node FS, at $totalGBcap of RAM"

    $nodecount = 3

  } else {

    write-log -message "Using 1 Node FS, at $totalGBcap of RAM"

    $nodecount = 1
  }
  
  sleep 119

  $looper = 0
  do {
    $looper++
    $createFS = REST-Create-FileServer -datagen $datagen -datavar $datavar -network $subnet -filesversion $filesversion -nodecount $nodecount
    $task = Wait-Task
    $vfiler = REST-Query-FileServer -datagen $datagen -datavar $datavar
  } until ($vfiler.entities.uuid.length -ge 5 -or $looper -ge 5)

  sleep 119 

  $vfiler = REST-Query-FileServer -datagen $datagen -datavar $datavar
  
  write-log -message "Using VFiler $($vfiler.entities.uuid)"

  write-log -message "Creating shares"

  try {
    REST-Add-FileServerShares -datagen $datagen -datavar $datavar -vfiler $vfiler -nodecount $nodecount
  } catch {

    write-log -message "Cornercases...." 

    sleep 60 
    REST-Add-FileServerDomain -datagen $datagen -datavar $datavar -vfiler $vfiler
    sleep 110
    try {
      REST-Add-FileServerShares -datagen $datagen -datavar $datavar -vfiler $vfiler
    } catch {
      sleep 110
      write-log -message "Upon FS creation 1/15 the FS server does not join......" 
      sleep 119
      try {
        REST-Add-FileServerShares -datagen $datagen -datavar $datavar -vfiler $vfiler
      } catch {

      }
    }
  }
  ## the above fails due to a timing issue, below after ana there iis a retry
  Write-log -message "Starting Analytics Server Prereq Gathering" -slacklevel 1
  $countana = 0
  do{
    $countana ++
    write-log -message "Getting Files Network" 
  
    $subnet = (REST-Get-PE-Networks -datavar $datavar -datagen $datagen).entities | where {$_.name -eq $datagen.nw1name}

    $containers = REST-Get-Containers -clusername $datagen.buildaccount -clpassword $datavar.pepass -PEClusterIP $datavar.PEClusterIP
    $container  = $containers.entities | where {$_.name -match "^Nutanix_FS"}
    
    write-log -message "Using container $($container.name) with UUID $($container.containerUuid)"
    Write-log -message "Getting File Analytics Version"
    
    $AnalyticsVersionobj = REST-Get-FilesAnalyticsVersion -clusername $datagen.buildaccount -clpassword $datavar.pepass -PEClusterIP $datavar.PEClusterIP
    
    foreach ($version in $AnalyticsVersionobj.entities){
      [array] $versions += [version]$version.version
    }
    [string]$AnalyticsVersion = $versions | sort | select -last 1
    
    Write-log -message "Using version $AnalyticsVersion"
    Write-log -message "Building Analytics Server" -slacklevel 1
    
    REST-Create-FileAnalyticsServer -datagen $datagen -datavar $datavar -network $subnet -container $container -AnalyticsVersion $AnalyticsVersion
  
    $result = Wait-TaskAnalytics

    if ($result -ne "SUCCEEDED"){
      do {

        Write-log -message "Failure detected, lets delete download and retry after 2 minutes."
        REST-Delete-FileAnalyticsDownload -datagen $datagen -datavar $datavar -Anaversion $AnalyticsVersion
        sleep 120
        $countana ++
        REST-Create-FileAnalyticsServer -datagen $datagen -datavar $datavar -network $subnet -container $container -AnalyticsVersion $AnalyticsVersion
        $result = Wait-TaskAnalytics
      } until ($result -eq "SUCCEEDED" -or $countana -ge 3)
    }
  
    $Ana =REST-Query-Fileanalytics -datagen $datagen -datavar $datavar

    [string] $Anaip = $ana.ip
    try {
      $register = REST-Register-FileAnalyticsServer -datagen $datagen -datavar $datavar -vfiler $vfiler -anaIP $Anaip
      $success = 1
    } catch {
      $success = 0
    }
  } until ($success -eq 1 -or $countana -ge 3)


  Write-log -message "Sleeping for AD Weirdness since 2016"
  sleep 300

  Write-log -message "Let me try to add shares now..."
  Write-log -message "Adding FS Admins"

  try {

    REST-Add-FileServerAdmin -datagen $datagen -datavar $datavar -vfiler $vfiler
    
    Write-log -message "If you can read this there is no timing issue with the FS admins.."

  } catch {

    write-log -message "Cornercases...." 

    sleep 60 
    REST-Add-FileServerDomain -datagen $datagen -datavar $datavar -vfiler $vfiler
    sleep 60
    REST-Add-FileServerShares -datagen $datagen -datavar $datavar -vfiler $vfiler -nodecount $nodecount
    sleep 20
    REST-Add-FileServerShares -datagen $datagen -datavar $datavar -vfiler $vfiler -nodecount $nodecount
    sleep 20
    REST-Add-FileServerShares -datagen $datagen -datavar $datavar -vfiler $vfiler -nodecount $nodecount
    sleep 110
    try {
      REST-Add-FileServerAdmin -datagen $datagen -datavar $datavar -vfiler $vfiler
      
    } catch {
      sleep 110
      write-log -message "Upon FS creation 1/15 the FS server does not join......" 
      sleep 119
      try {
        REST-Add-FileServerAdmin -datagen $datagen -datavar $datavar -vfiler $vfiler
        
      } catch {}
    }
  }
  try {
    sleep 60
    PSR-Generate-FilesContent -datavar $datavar -datagen $datagen -dc $datagen.dc1ip
    sleep 10
    PSR-Generate-FilesContent -datavar $datavar -datagen $datagen -dc $datagen.dc2ip
  } catch {
    sleep 500
    PSR-Generate-FilesContent -datavar $datavar -datagen $datagen -dc $datagen.dc1ip
    sleep 10
    PSR-Generate-FilesContent -datavar $datavar -datagen $datagen -dc $datagen.dc2ip
  }
  write-log -message "Files Installation Finished" -slacklevel 1
  get-sshsession -ea:0 | remove-sshsession -ea:0
}
Export-ModuleMember *





  
  
  