Function Wrap-Install-Objects {
  param (
    [object] $datavar,
    [object] $datagen

  )
  write-log -message "Waiting for NTP"

  Wait-POSTPC-Task -datavar $datavar
  sleep 180

  write-log -message "Getting PE subnet object"
  
  $subnet = (REST-Get-PE-Networks -datavar $datavar -datagen $datagen).entities | where {$_.name -eq $datagen.nw1name}
  
  write-log -message "Getting PE cluster object"
  
  $clusters = REST-Query-Cluster -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 

  $cluster = $clusters.entities | where { $_.spec.Resources.network -match "192.168.5"}
  
  
  $count = 0
  do {
    $count ++
    $result = REST-Query-Objects-Store -datagen $datagen -datavar $datavar

    if (!$result.group_results[0].entity_results.entity_id){

      write-log -message "Building Objects store"

      $install = REST-Install-Objects-Store -datagen $datagen -datavar $datavar -subnet $subnet -cluster $cluster

    }

    $percentage = ($result.group_results.Entity_results.data | where {$_.name -eq "Percentage_complete"}).values.values

    $state = ($result.group_results[0].entity_results.data | where {$_.name -eq "state"}).values.values

    #if ($state -eq "ERROR") {
#
    #  write-log -message "Store is in state ERROR, redeploying."
    #  write-log -message "Deleting Store"
#
    #  REST-DELETE-Objects-Store -datagen $datagen -datavar $datavar -storeUUID $result.group_results[0].entity_results.entity_id
#
    #  write-log -message "Sleep after delete."
    #  sleep 90 
    #}

    write-log -message "Current percentage is $percentage"

    sleep 60

  } until ( $percentage -eq 100 -or $count -ge 240 -or $state -eq "ERROR")
  
  if ($percentage -eq 100){

    sleep 60 
  
    write-log -message "Adding Objects to the AD"
  
    REST-Add-Objects-AD -datagen $datagen -datavar $datavar

    $count2 = 0 
    do {
      $count2 ++
      REST-Create-Objects-Bucket -datagen $datagen -datavar $datavar -storeID $result.group_results.Entity_results.entity_id -bucketname "demo$($count2)"
    } until ($count2 -ge 5)
  
    $count3 = 0
    do {
      $count3 ++
      sleep 60
      $result = REST-Query-Objects-Store -datagen $datagen -datavar $datavar
      [int]$bucketcount = ($result.group_results.Entity_results.data | where {$_.name -eq "num_buckets"}).values.values
    } until ($bucketcount -ge 5 -or $count3 -ge 2)
  
    write-log -message "We created $bucketcount buckets."
    sleep 180

    #SSH-Restart-KeepAlived -datavar $datavar -datagen $datagen
    $ADmatch = ((REST-Get-Objects-AD -datagen $datagen -datavar $datavar).entities).metadata.kind -eq "directory_service"
    [int]$adcount = ((REST-Get-Objects-AD -datagen $datagen -datavar $datavar).entities).count
    If ($adcount -lt 1){
      $count4 = 0
      do {
        $count4++
        REST-Add-Objects-AD -datagen $datagen -datavar $datavar
        sleep 60
        write-log -message "AD Connection created."
        $count5 = 0
        do {
          write-log -message "Checking"
          $count5++
          sleep 5
          $ADmatch = ((REST-Get-Objects-AD -datagen $datagen -datavar $datavar).entities).metadata.kind -eq "directory_service"
          [int]$adcount = ((REST-Get-Objects-AD -datagen $datagen -datavar $datavar).entities).count
        } until ($count5 -ge 2 -or $adcount -ge 1)
    
        #If ($adcount -le 1){
        #  write-log -message "Check failed, restarting Keepalives" -sev "WARN"
        #  SSH-Restart-KeepAlived -datavar $datavar -datagen $datagen
        #  sleep 10
        #  $ADmatch = ((REST-Get-Objects-AD -datagen $datagen -datavar $datavar).entities).metadata.kind -eq "directory_service"
        #  [int]$adcount = ((REST-Get-Objects-AD -datagen $datagen -datavar $datavar).entities).count
        #  write-log -message "We created $adcount Directories."
        #  if ($count4 -eq 2){
        #    write-log -message "Sleeping for Objects weirdness" 
        #    sleep 600
        #  }
        #}
      } until ($adcount -ge 1 -or $count4 -ge 3)
    }
  } 
  write-log -message "Objects Base Installation Finished" -slacklevel 1
}
Export-ModuleMember *


