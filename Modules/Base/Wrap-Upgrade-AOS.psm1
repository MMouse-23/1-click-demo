Function Wrap-Upgrade-AOS {
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $AvailableAOSVersion,
    [string] $autodetectAOSVersion
  )
  $scancounter = 0
  if ($datavar.UpdateAOS -eq 0){
    #$AOSversions = REST-AOS-InventorySoftware -datagen $datagen -datavar $datavar
    #$secondlast = $AOSversions.entities.version |sort {[version]$_} |select -last 2 | select -first 1
    #if ($secondlast -ne $autodetectAOSVersion){
        #$TargetVersion = $secondlast
      #} else {
        $TargetVersion = $AvailableAOSVersion
     # } 
  } else {
    $TargetVersion = $AvailableAOSVersion
  }
  write-log -message "Upgrading from AOS $($autodetect.AOSVersion) towards AOS $($TargetVersion), this causes a 40 minute delay" -slacklevel 0
  do{
    $scancounter ++
    write-log -message "Executing prescan AOS Upgrade" -sev "Chapter" -slacklevel 1
    write-log -message "Setting DNS to $($datavar.dnsserver)"
    write-log -message "Setting DNS to 1.1.1.1"
    try { 
      $dns = REST-Get-DNS-Servers -datagen $datagen -datavar $datavar
      write-log -message "Removing $($dns.count) DNS servers:"
      write-log -message $dns
    } catch {
      write-log -message "No DNS Servers to remove"
    }
    REST-Remove-DNS-Servers -datagen $datagen -datavar $datavar -DNSArr $dns
    
    write-log -message "Adding DNS servers"
    
    [array]$dns += $datavar.dnsserver
    [array]$dns += "1.1.1.1"
    
    REST-Add-DNS-Servers -datagen $datagen -datavar $datavar -DNSArr $dns
    
    write-log -message "Checking DNS servers"
    
    sleep 10
    REST-Get-DNS-Servers -datagen $datagen -datavar $datavar
  
    write-log -message "NTP Should be resolveable now."
  
    $upgrade = REST-AOS-Upgrade -datavar $datavar -datagen $datagen -AvailableAOSVersion $TargetVersion
    sleep 60
    write-log -message "Checking Prescan status"
    $installcounter = 0
    do{
      $installcounter++
      sleep 60
      try{
        $tasks = REST-Get-AOS-LegacyTask -datagen $datagen -datavar $datavar
  
        write-log -message "We found $($tasks.entities.count) total tasks"
        write-log -message "Waiting $installcounter out of 20 for AOS Prescan."
  
        $task = $tasks.entities | where {$_.operation -eq "ClusterPreUpgradeTask"}
        $task = $task | select -first 1
        if (!$task){
  
          write-log -message "Prepare Task is not running."
  
          if ($installcounter -eq 3 -or $installcounter -eq 6 -or $installcounter -eq 9 -or $installcounter -eq 15){
  
            write-log -message "This is the 3rd time already, kicking it again."
            $upgrade = REST-AOS-Upgrade -datavar $datavar -datagen $datagen -AvailableAOSVersion $TargetVersion
          }
  
  
        } else {
  
          write-log -message "AOS PreScan is $($task.status) at $($task.percentageCompleted) %"
  
        }
      } catch {
  
        write-log -message "I Should not be here, or CVM is restarting" -sev "warn"
      }
    } until (($task -and $task.status -ne "running") -or $installcounter -ge 20)

    write-log -message "$($task.taskTag)"

  } until ($scancounter -ge 3 -or $task.status -eq "succeeded")
  if ($task.status -eq "succeeded"){
    $continue = "Yes"
  }

  sleep 20
  $tasks = REST-Get-AOS-LegacyTask -datagen $datagen -datavar $datavar
  $task = $tasks.entities | where {$_.operation -eq "ClusterUpgradeTask"}
  $installcounter = 0
  if ($continue -eq "Yes"){
    write-log -message "Upgrading AOS" -sev "Chapter" -slacklevel 1
    do{
      $installcounter++
      sleep 60
      try{
        $tasks = REST-Get-AOS-LegacyTask -datagen $datagen -datavar $datavar

        write-log -message "We found $($tasks.entities.count) total tasks"
        write-log -message "Waiting $installcounter out of 120 for AOS upgrade."

        $task = $tasks.entities | where {$_.operation -eq "ClusterUpgradeTask"}
        if (!$task){

          write-log -message "Upgrade Task is not running."

          if ($installcounter -eq 3 -or $installcounter -eq 6 -or $installcounter -eq 9 -or $installcounter -eq 15){

            write-log -message "This is the 3rd time already, kicking it again."
            $upgrade = REST-AOS-Upgrade -datavar $datavar -datagen $datagen -AvailableAOSVersion $TargetVersion
          }

        } else {

          write-log -message "AOS Upgrade is $($task.status) at $($task.percentageCompleted) %"

        }
      } catch {

        write-log -message "I Should not be here, or CVM is restarting" -sev "warn"
      }
    } until (($task -and $task.status -ne "running") -or $installcounter -ge 120)
  } else {

    write-log -message "AOS Pre Upgrade Failed" -sev "ERROR"
    $status = "Failed"

  }
  if ($status -eq "Failed"){
    $status = "Failed"

  } else {
    $status = "Success"
  }
  $resultobject =@{
    Result = $status
  }

  return $resultobject
}

