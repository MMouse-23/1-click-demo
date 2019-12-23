Function Wrap-AOS-Fubar-Test {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $AvailableAOSVersion
  )

  write-log -message "Launching AOS Preupgrade Scan"
  write-log -message "Checking $AvailableAOSVersion"
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
  
  REST-Get-DNS-Servers -datagen $datagen -datavar $datavar

  write-log -message "NTP Should be resolveable now."

  $tasks = REST-Get-AOS-Upgrade -datagen $datagen -datavar $datavar
  sleep 60
  $installcounter = 0
  $counter2 = 0
  do{
    $installcounter++
    sleep 60
    try{
      $tasks = REST-Get-AOS-Upgrade -datagen $datagen -datavar $datavar

      write-log -message "We found $($tasks.entities.count) total tasks"
      write-log -message "Waiting $installcounter out of 20 for AOS Prescan."

      $task = $tasks.entities | where {$_.operation -eq "ClusterPreUpgradeTask"}
      $task = $task | select -first 1
      if (!$task){

        write-log -message "Task is not running."

      } else {

        write-log -message "AOS PreScan is $($task.status) at $($task.percentageCompleted) %"

      }
    } catch {

      write-log -message "I Should not be here, or CVM is restarting" -sev "warn"
    }
  } until (($task -and $task.status -ne "running") -or $installcounter -ge 20)


  if ($task.percentageCompleted -gt 29){

    $status = "Success"

    write-log -message "This system is healthy, lets give her a spin"

  } elseif ($counter1 -ge 40) {

    $status = "UNKNOWN"

    write-log -message "We dont know if this is a healthy system at this stage, lets try anyway" -sev "WARN"

  } else {

    write-log -message "This system is fubar, we cannot proceed. Contact 1CD support or whipe the cluster." -sev "ERROR"

    $status = "Failed"

  }

  $resultobject =@{
    Result = $status
  }
  return $resultobject
};
Export-ModuleMember *