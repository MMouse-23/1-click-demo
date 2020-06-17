Function Wrap-Create-FS {
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $UrlBase,
    [string] $UrlAnalytics,
    [string] $jsonbase,
    [string] $jsonAna
  )

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
  
    $result = Wait-TaskAnalytics -datagen $datagen -datavar $datavar 

    if ($result -ne "SUCCEEDED"){
      do {

        Write-log -message "Failure detected, lets delete download and retry after 2 minutes."
        REST-Delete-FileAnalyticsDownload -datagen $datagen -datavar $datavar -Anaversion $AnalyticsVersion
        sleep 120
        $countana ++
        REST-Create-FileAnalyticsServer -datagen $datagen -datavar $datavar -network $subnet -container $container -AnalyticsVersion $AnalyticsVersion
        $result = Wait-TaskAnalytics -datagen $datagen -datavar $datavar 
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
  #if ($datavar.DemoXenDeskT -eq 0) {

    write-log -message "XenDesktop is not enabled, generating content" -slacklevel 1

    try{
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
    
  #} else {

    write-log -message "We rely on the BP to do its work, files content generation is disabled." -slacklevel 1

  #}
  write-log -message "Files Installation Finished" -slacklevel 1
  get-sshsession -ea:0 | remove-sshsession -ea:0
}
Export-ModuleMember *





  
  
  