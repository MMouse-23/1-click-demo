  Function Wrap-Install-HashiCorpVault {
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $basedir,
    [string] $BlueprintsPath,
    $ServerSysprepfile
  )
  $subnet = (REST-Get-PE-Networks -datavar $datavar -datagen $datagen).entities | where {$_.name -eq $datagen.nw1name}
  sleep 10
  $images = REST-Query-Images -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 
  $image = $images.entities | where {$_.spec.name -eq "CentOS_1CD" }
  sleep 10

  $projects = REST-Query-Projects -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount
  $project = $projects.entities | where {$_.spec.name -match "Customer-D"}
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

  $blueprint = REST-Import-Generic-Blueprint -datagen $datagen -datavar $datavar -BPfilepath "$($BlueprintsPath)\HasiCorpVault.json" -ProjectUUID $project.metadata.uuid

  write-log -message "Created BluePrint with $($blueprint.metadata.uuid)"
  write-log -message "Getting newly created blueprint"

  $blueprintdetail = REST-Query-DetailBP -datagen $datagen -datavar $datavar -uuid $($blueprint.metadata.uuid)

  write-log -message "Updating the BP"

  $UpdateBP = REST-Update-HasiCorp-Blueprint -datagen $datagen -datavar $datavar -BPObject $blueprintdetail -snapID $operation.id -BlueprintUUID $blueprint.metadata.uuid -ProjectUUID $project.metadata.uuid -subnet $subnet -image $image

  write-log -message "Launching the HashiCorpVault BP for Customer D" -slacklevel 1

  $Launch = REST-Generic-BluePrint-Launch -datagen $datagen -datavar $datavar -BPUUID $($blueprint.metadata.uuid) -TaskObject ($blueprintdetail.spec.resources.app_profile_list | where {$_.name -eq "Default"}) -appname "HashiCorpVault"

  write-log -message "HashiCorpVault BluePrint Installation and Launch Finished" -slacklevel 1
}

Export-ModuleMember *


