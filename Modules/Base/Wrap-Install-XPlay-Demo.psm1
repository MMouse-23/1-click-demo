Function Wrap-Install-XPlay-Demo{
   param (
    [object] $datagen,
    [object] $datavar,
    [string] $BlueprintsPath,
    [string] $basedir
   ) 
  
  $subnet = (REST-Get-PE-Networks -datavar $datavar -datagen $datagen).entities | where {$_.name -eq $datagen.nw1name}
  sleep 10
  $cluster = REST-Query-Cluster -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -targetIP $datagen.PCClusterIP
  sleep 10
  
  write-log -message "Wait for 2012 Image(s)"  -slacklevel 1
  
  if ($datavar.Hypervisor -match "ESX") {

    Wait-Templates-Task -datavar $datavar
    $accounts = REST-List-SSP-Account -datagen $datagen -datavar $datavar
    $account = $accounts.entities | where {$_.Status.resources.type -eq "vmware"} | select -first 1
    $Templates =REST-LIST-SSP-VMwareImages -datagen $datagen -datavar $datavar -Accountuuid $account.metadata.uuid

    write-log -message "We found $($Templates.entities.status.resources.count) VMware Templates"

    $winimage = $Templates.entities.status.resources | where {$_.name -eq "Windows 2012"}

  } else {

    REST-Wait-ImageUpload -imagename "Windows 2012" -datavar $datavar -datagen $datagen

  }    
  
  if ($datavar.hypervisor -match "nutanix|ahv"){
    
    sleep 60
    $images = REST-Query-Images -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 
    $image = $images.entities | where {$_.spec.name -match "Windows 2012"}
    sleep 10
  
  }

  
  write-log -message "Query Alert Trigger type"

  $AlertTriggerTypes = REST-XPlay-Query-AlertTriggerType -datagen $datagen -datavar $datavar
  $alertTriggerType = $AlertTriggerTypes.group_results.entity_results | where {$_.data.values.values -eq "alert_trigger"}

  write-log -message "Using Trigger Type $($alertTriggerType.entity_id)"

  write-log -message "Query Alert Action type"
  
  $AlertActiontype = REST-XPlay-Query-ActionTypes -ClusterPC_IP $datagen.PCClusterIP -clusername $datagen.buildaccount -clpassword $Datavar.pepass 
  
  write-log -message "Query Alert Type UUID"
  
  $AlertTypeUUID = REST-XPlay-Query-AlertUUID -datagen $datagen -datavar $datavar
 
  write-log -message "Using Alert Type $($AlertTypeUUID.group_results.entity_results.entity_id)"
  write-log -message "Query VM Group" 
  
  $groups = REST-Query-Groups -datagen $datagen -datavar $datavar
  $group = $groups.group_results.entity_results | where {$_.data.values.values -match "DevOps"}

  write-log -message "We are using $($group.entity_id)" 
  write-log -message "Creating Alert Policy"

  $Policy = REST-Create-Alert-Policy -datagen $datagen -datavar $datavar -group $group
  sleep 10
  try {
    $projects = REST-Query-Projects -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount
    $project = $projects.entities | where {$_.spec.name -match "Customer-A"}
  } catch {

    write-log -message "It seems PC is having a bad install day"
    
  }
  if (!$project){

    write-log -message "XPlay Demo Project is not created yet, waiting for Karbon to finish." -sev "Chapter"
    write-log -message "Waiting for the last steps in the core to finish."
    write-log -message "Blueprints and Projects are required for the next step."

    $count = 0
    do {
      $count++

      write-log -message "Sleeping $count out of 150"
      try {
        sleep 110
        $projects = REST-Query-Projects -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 
        $project = $projects.entities | where {$_.spec.name -match "Customer-B"}
      } catch {

        write-log -message "PC Install delay, waiting for PC Post install."

      }
    }until ($project -or $count -ge 150)
  }

  write-log -message "Using Cluster $($cluster.metadata.uuid)"
  write-log -message "Using Subnet $($subnet.uuid)"
  write-log -message "Project UUID is $($project.metadata.uuid)"
  write-log -message "Image UUID is $($image.metfadata.uuid)"
  write-log -message "Creating BluePrint"  -sev "Chapter"

  $blueprint = REST-Import-Generic-Blueprint-Object -datagen $datagen -datavar $datavar -BPfilepath "$($BlueprintsPath)\IIS Customer Horizontal Scale.json" -Project $project

  write-log -message "Retrieving Detailed BP"

  $blueprintdetail = REST-Query-DetailBP -datagen $datagen -datavar $datavar -uuid $($blueprint.metadata.uuid)

  write-log -message "Updating XPlay Variables"

  $update = REST-Update-Xplay-Blueprint -datagen $datagen -datavar $datavar -BPObject $blueprintdetail -image $image -subnet $subnet

  if ($datavar.hypervisor -match "ESX|VMware"){

    write-log -message "Doing VMware Magic"

    $update = REST-Update-Xplay-Blueprint-Image -datagen $datagen -datavar $datavar -bpobject $blueprintdetail -winimage $winimage -account $account
    sleep 2
    REST-Verify-SSP-Account -datagen $datagen -datavar $datavar -Account $account
  }

  write-log -message "Blueprint Ready"
  write-log -message "Firing BluePrint" -slacklevel 1

  $Launch = REST-XPlay-BluePrint-Launch -datagen $datagen -datavar $datavar -BPUUID $($blueprint.metadata.uuid) -taskUUID ($blueprintdetail.spec.resources.app_profile_list | where {$_.name -eq "IIS"}).uuid
  
  $AlertTypeUUID = REST-XPlay-Query-AlertUUID -datagen $datagen -datavar $datavar  
  if ($AlertTypeUUID.group_results.entity_results.entity_id -eq $null){

    write-log -message "0? let me try that again."

    $count = 0
    do {
      sleep 30
      $count ++

      write-log -message "Cycle $count of of 5"
      write-log -message "Current value is $($AlertTypeUUID.group_results.entity_results.entity_id)"

      $AlertTypeUUID = REST-XPlay-Query-AlertUUID -datagen $datagen -datavar $datavar
    } until ($AlertTypeUUID.group_results.entity_results.entity_id -ne $null -or $count -ge 5)
  }  
  write-log -message "Create Playbook" -slacklevel 1

  $playbook = REST-XPlay-Create-Playbook -datagen $datagen -datavar $datavar -AlertTriggerObject $AlertTriggerType -AlertActiontypeObject $AlertActiontype -AlertTypeObject $AlertTypeUUID -BluePrintObject $blueprintdetail

  write-log -message "XPlay Demo Finished" -slacklevel 1
}
Export-ModuleMember *