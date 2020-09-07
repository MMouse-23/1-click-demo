  Function Wrap-Install-BPApps {
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $basedir,
    [string] $BlueprintsPath,
    $ServerSysprepfile
  )

  write-log -message "Installing GitLab"

  $images = REST-Query-Images -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 
  $image = $images.entities | where {$_.spec.name -eq "CentOS_1CD" }
  sleep 10

  $projects = REST-Query-Projects -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount

  $subnet = (REST-Get-PE-Networks -datavar $datavar -datagen $datagen).entities | where {$_.name -eq $datagen.nw1name}

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
      $project = $projects.entities | where {$_.spec.name -match "Customer-C"}
    }until ($project -or $count -ge 25)
  }

  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project
  
  write-log -message "Project UUID is $($project.metadata.uuid)"

  #write-log -message "Creating BluePrint"

  #$blueprint = REST-Import-Generic-Blueprint-Object -datagen $datagen -datavar $datavar -BPfilepath "$($BlueprintsPath)\GitLab.json" -Project $project
#
  #write-log -message "Created BluePrint with $($blueprint.metadata.uuid)"
  #write-log -message "Getting newly created blueprint"
#
  #Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project
#
  #$blueprintdetail = REST-Query-DetailBP -datagen $datagen -datavar $datavar -uuid $($blueprint.metadata.uuid)
#
  #write-log -message "Updating the BP"
#
  #REST-Update-Generic-MarketPlace-Blueprint -datagen $datagen -datavar $datavar -blueprintdetail $blueprintdetail -subnet $subnet -image $image -vmname "Gitlab-$($datavar.pocname)"

  #Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project
 
  #$Launch = REST-Generic-BluePrint-Launch -datagen $datagen -datavar $datavar -BPUUID $($blueprint.metadata.uuid) -TaskObject ($blueprintdetail.spec.resources.app_profile_list | where {$_.name -eq "Nutanix"}) -appname "Microsoft GitLab"

  #write-log -message "GitLab BluePrint Installation Finished"

  write-log -message "Rabbit MQ BluePrint Installation Started" -sev "CHAPTER"

  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project
  
  write-log -message "Project UUID is $($project.metadata.uuid)"

  write-log -message "Creating BluePrint"

  $blueprint = REST-Import-Generic-Blueprint-Object -datagen $datagen -datavar $datavar -BPfilepath "$($BlueprintsPath)\Rabit MQ.json" -Project $project

  write-log -message "Created BluePrint with $($blueprint.metadata.uuid)"
  write-log -message "Getting newly created blueprint"

  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project

  $blueprintdetail = REST-Query-DetailBP -datagen $datagen -datavar $datavar -uuid $($blueprint.metadata.uuid)

  write-log -message "Updating the BP"

  REST-Update-Generic-MarketPlace-Blueprint -datagen $datagen -datavar $datavar -blueprintdetail $blueprintdetail -subnet $subnet -image $image -VMname "Rabbit-$($datavar.pocname)"

  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project
 
  $Launch = REST-Generic-BluePrint-Launch -datagen $datagen -datavar $datavar -BPUUID $($blueprint.metadata.uuid) -TaskObject ($blueprintdetail.spec.resources.app_profile_list | where {$_.name -eq "Nutanix"}) -appname "Rabbit MQ"

  write-log -message "Rabbit MQ BluePrint Installation Finished"

  write-log -message "Elastic Search BluePrint Installation Started" -sev "CHAPTER"

  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project
  
  write-log -message "Project UUID is $($project.metadata.uuid)"

  write-log -message "Creating BluePrint"

  $blueprint = REST-Import-Generic-Blueprint-Object -datagen $datagen -datavar $datavar -BPfilepath "$($BlueprintsPath)\Elastic Search.json" -Project $project

  write-log -message "Created BluePrint with $($blueprint.metadata.uuid)"
  write-log -message "Getting newly created blueprint"

  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project

  $blueprintdetail = REST-Query-DetailBP -datagen $datagen -datavar $datavar -uuid $($blueprint.metadata.uuid)

  write-log -message "Updating the BP"

  REST-Update-Generic-MarketPlace-Blueprint -datagen $datagen -datavar $datavar -blueprintdetail $blueprintdetail -subnet $subnet -image $image -VMname "Elastic-$($datavar.pocname)"

  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project
 
  $Launch = REST-Generic-BluePrint-Launch -datagen $datagen -datavar $datavar -BPUUID $($blueprint.metadata.uuid) -TaskObject ($blueprintdetail.spec.resources.app_profile_list | where {$_.name -eq "Nutanix"}) -appname "Elastic Search"

  write-log -message "Elastic Search BluePrint Installation Finished" 

  write-log -message "Puppet Open Source BluePrint Installation Started" -sev "CHAPTER"

  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project
  
  write-log -message "Project UUID is $($project.metadata.uuid)"

  write-log -message "Creating BluePrint"

  $blueprint = REST-Import-Generic-Blueprint-Object -datagen $datagen -datavar $datavar -BPfilepath "$($BlueprintsPath)\Puppet.json" -Project $project

  write-log -message "Created BluePrint with $($blueprint.metadata.uuid)"
  write-log -message "Getting newly created blueprint"

  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project

  $blueprintdetail = REST-Query-DetailBP -datagen $datagen -datavar $datavar -uuid $($blueprint.metadata.uuid)

  write-log -message "Updating the BP"

  REST-Update-Generic-MarketPlace-Blueprint -datagen $datagen -datavar $datavar -blueprintdetail $blueprintdetail -subnet $subnet -image $image -VMname "Puppet-$($datavar.pocname)"

  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project
 
  $Launch = REST-Generic-BluePrint-Launch -datagen $datagen -datavar $datavar -BPUUID $($blueprint.metadata.uuid) -TaskObject ($blueprintdetail.spec.resources.app_profile_list | where {$_.name -eq "Nutanix"}) -appname "Puppet Open Source"

  write-log -message "Puppet Open Source BluePrint Installation Finished" 

  write-log -message "Hadoop BluePrint Installation Started" -sev "CHAPTER"

  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project
  
  write-log -message "Project UUID is $($project.metadata.uuid)"

  write-log -message "Creating BluePrint"

  $blueprint = REST-Import-Generic-Blueprint-Object -datagen $datagen -datavar $datavar -BPfilepath "$($BlueprintsPath)\Hadoop.json" -Project $project

  write-log -message "Created BluePrint with $($blueprint.metadata.uuid)"
  write-log -message "Getting newly created blueprint"

  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project

  $blueprintdetail = REST-Query-DetailBP -datagen $datagen -datavar $datavar -uuid $($blueprint.metadata.uuid)

  write-log -message "Updating the BP"

  REST-Update-Generic-MarketPlace-Blueprint -datagen $datagen -datavar $datavar -blueprintdetail $blueprintdetail -subnet $subnet -image $image -VMname "Puppet-$($datavar.pocname)"

  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project
 
  $Launch = REST-Generic-BluePrint-Launch -datagen $datagen -datavar $datavar -BPUUID $($blueprint.metadata.uuid) -TaskObject ($blueprintdetail.spec.resources.app_profile_list | where {$_.name -eq "Nutanix"}) -appname "Hadoop"

  write-log -message "Hadoop BluePrint Installation Finished" 
}

Export-ModuleMember *


