  Function Wrap-Install-3TierLamp {
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $basedir,
    [string] $BlueprintsPath,
    $ServerSysprepfile
  )
  write-log -message "Prepping Blueprint for 3TierLamp." -sev "Chapter"

  $cluster = REST-Query-Cluster -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -targetIP $datagen.PCClusterIP
  sleep 10
  $images = REST-Query-Images -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 
  $image = $images.entities | where {$_.spec.name -eq "CentOS_1CD" }
  sleep 10

  $projects = REST-Query-Projects -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount
  $project = $projects.entities | where {$_.spec.name -match "Customer-A"}
  if (!$project){

    write-log -message "Project is not created yet, waiting for LCM to finish."
    write-log -message "Waiting for the last steps in the core to finish."
    write-log -message "Blueprints are required for the next step."

    $count = 0
    do {
      $count++

      write-log -message "Sleeping $count out of 25"

      sleep 110
      $projects = REST-Query-Projects -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 
      $project = $projects.entities | where {$_.spec.name -match "Customer-D"}
    }until ($project -or $count -ge 25)
  }
  sleep 90
  
  write-log -message "Project UUID is $($project.metadata.uuid)"

  write-log -message "Creating BluePrint" -slacklevel 1

  $blueprint = REST-Import-Generic-Blueprint -datagen $datagen -datavar $datavar -BPfilepath "$($BlueprintsPath)\3TierLamp.json" -ProjectUUID $project.metadata.uuid

  write-log -message "Created BluePrint with $($blueprint.metadata.uuid)"
  write-log -message "Getting newly created blueprint"

  $blueprintdetail = REST-Query-DetailBP -datagen $datagen -datavar $datavar -uuid $($blueprint.metadata.uuid)

  write-log -message "Updating the BP"

  $UpdateBP = REST-Update-Splunk-Blueprint -datagen $datagen -datavar $datavar -BPObject $blueprintdetail -snapID $operation.id -BlueprintUUID $blueprint.metadata.uuid -ProjectUUID $project.metadata.uuid -SERVER_NAME "Splunk01-$($datavar.pocname)" -subnet $subnet -image $image

  write-log -message "Launching the BP Splunk for Customer D" -slacklevel 1

  $Launch = REST-Generic-BluePrint-Launch -datagen $datagen -datavar $datavar -BPUUID $($blueprint.metadata.uuid) -TaskObject ($blueprintdetail.spec.resources.app_profile_list | where {$_.name -eq "Splunk_App_Profile"}) -appname "Splunk Instance"
  
  write-log -message "Splunk BP Install Finished" -slacklevel 1
}

Export-ModuleMember *


