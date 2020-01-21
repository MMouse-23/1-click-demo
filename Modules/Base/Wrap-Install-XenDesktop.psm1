  Function Wrap-Install-XenDesktop {
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $basedir,
    [string] $BlueprintsPath,
    $ServerSysprepfile
  )

  $images = REST-Query-Images -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 
  $image = $images.entities | where {$_.spec.name -eq "Citrix_1912_ISO" }
  sleep 10

  $projects = REST-Query-Projects -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount

  $subnet = (REST-Get-PE-Networks -datavar $datavar -datagen $datagen).entities | where {$_.name -eq $datagen.nw1name}

  $project = $projects.entities | where {$_.spec.name -match "Customer-C"}
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

  write-log -message "Creating BluePrint"

  $blueprint = REST-Import-Generic-Blueprint-Object -datagen $datagen -datavar $datavar -BPfilepath "$($BlueprintsPath)\XenDesktopV1109.json" -Project $project

  write-log -message "Created BluePrint with $($blueprint.metadata.uuid)"
  write-log -message "Getting newly created blueprint"

  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project

  $blueprintdetail = REST-Query-DetailBP -datagen $datagen -datavar $datavar -uuid $($blueprint.metadata.uuid)

  write-log -message "Updating the BP"

  REST-Update-XenDesktopBP -datagen $datagen -datavar $datavar -blueprintdetail $blueprintdetail -subnet $subnet

  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project
 
  if ($datavar.DemoXenDeskT -eq 1 ){

    write-log -message "Launching the BP"

    REST-BluePrint-Launch-XenDesktop -datagen $datagen -datavar $datavar -BPobject $blueprintdetail
  }
   
  write-log -message "XD BluePrint Installation Finished"
  
}

Export-ModuleMember *


