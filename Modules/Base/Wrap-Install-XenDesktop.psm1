  Function Wrap-Install-1CD {
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $basedir,
    [string] $BlueprintsPath,
    $ServerSysprepfile
  )
  
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

  $blueprint = REST-Import-Generic-Blueprint-Object -datagen $datagen -datavar $datavar -BPfilepath "$($BlueprintsPath)\XenDesktopV1103.json" -Project $project

  write-log -message "Created BluePrint with $($blueprint.metadata.uuid)"
  write-log -message "Getting newly created blueprint"

  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project

  $blueprintdetail = REST-Query-DetailBP -datagen $datagen -datavar $datavar -uuid $($blueprint.metadata.uuid)

  write-log -message "Updating the BP"

  REST-Update-XenDesktopBP -datagen $datagen -datavar $datavar -blueprintdetail $blueprintdetail -subnet $subnet

  write-log -message "Launching the XD BP for Customer D"
  $adminaccounts = $($datagen.SENAME.replace(" ", '.'))

  $varlist = @"
{
  "name": "AdminAccounts",
  "value": "$adminaccounts"
},
{
  "name": "WindowsDomain",
  "value": "$($datagen.Domainname)"
},
{
  "name": "AdminPassword",
  "value": "$($datavar.pepass)",
  "attrs": {
    "is_secret_modified":  true,
    "secret_reference":  "",
    "type":  ""
  },
},
{
  "name": "UserPasswordPassword",
  "value": "$($datavar.pepass)",
  "attrs": {
    "is_secret_modified":  true,
    "secret_reference":  "",
    "type":  ""
  },
},
{
  "name": "FileServer",
  "value": "$($datagen.FS1_IntName)"
},
{
  "name": "StorageContainerName",
  "value": "$($datagen.DisksContainerName)"
},
{
  "name": "VLanName",
  "value": "$($datagen.Nw1name)"
},
{
  "name": "VLanName",
  "value": "$($datagen.Nw1name)"
},
"@

  $Launch = REST-Generic-BluePrint-Launch -datagen $datagen -datavar $datavar -BPUUID $($blueprint.metadata.uuid) -TaskObject ($blueprintdetail.spec.resources.app_profile_list | where {$_.name -eq "HiX Deployment"}) -appname "XenDestkop" -varlist $varlist

  write-log -message "XD BluePrint Installation Finished"
}

Export-ModuleMember *


