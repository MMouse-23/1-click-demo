Function Wrap-Create-MarketPlace {
  param (
    [object] $datavar,
    [object] $datagen
  )

  write-log -message "Publishing Market Place" -slacklevel 1

  $marketplace = REST-Get-Calm-GlobalMarketPlaceItems -datavar $datavar -datagen $datagen

  write-log -message "We found $($marketplace.group_results.entity_results.entity_ID.count) Marketplace items."
  
  $GroupUUIDS = ($marketplace.group_results.entity_results.data | where {$_.name -eq "app_group_uuid"}).values.values | select -unique
  $AllUUIDs   = $marketplace.group_results.entity_results.entity_ID
  
  write-log -message "We found $($GroupUUIDS.count) Unique Marketplace items."
  $LatestMarketPlaceBPs = $null
  foreach ($group in $GroupUUIDS){
    $Last = (($marketplace.group_results.entity_results | where {$_.data.values.values -eq $group}) | where {$_.data.name -eq "version"}) | select -last 1
    $Entity = [PSCustomObject]@{
      Version     = ($last.data | where {$_.name -eq "version"}).values.values
      UUID       = $last.entity_id
      Name        = ($last.data | where {$_.name -eq "name"}).values.values
    }
    [array]$LatestMarketPlaceBPs += $entity     
  }  

  write-log -message "Waiting for SSP Base to complete."

  $projects = REST-Query-Projects -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.PEPass -clusername $datagen.BuildAccount

  if ($projects.entities.count -lt 5){

    write-log -message "Projects are not created yet, waiting for SSP Base to finish."
    write-log -message "Projects are required for the MarketPlace Items."

    $count = 0
    do {
      $count++

      write-log -message "Sleeping $count out of 25"

      sleep 110
      $projects = REST-Query-Projects -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 
    } until ($projects.entities.count -ge 5 -or $count -ge 25)
  }

  foreach ($marketplacelatest in $LatestMarketPlaceBPs){
  
    Write-log -message "Working on Blueprint $($marketplacelatest.name) with Version $($marketplacelatest.version)"
    $bpdetail = REST-Get-Calm-GlobalMarketPlaceItem-Detail -datagen $datagen -datavar $datavar -bpuuid $marketplacelatest.uuid
    $bpupdate = REST-Publish-CalmMarketPlaceBP -datagen $datagen -datavar $datavar -BPobject $bpdetail -projects $projects
  
  }
  write-log -message "Publishing Market Place Finished" -slacklevel 1

}

