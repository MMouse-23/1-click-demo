function Wrap-Install-Runbooks {
  param(
    $datavar,
    $datagen,
    $basedir
  )

  write-log -message "Installing Runbooks in Calm" -sev "Chapter" -slacklevel 1


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

    }until ($project -or $count -ge 45)
  }
  sleep 90
  
  write-log -message "Using $($project.metadata.uuid)"

  write-log -message "Creating Endpoints" -sev "Chapter" -slacklevel 1

  $endpoints = "$($datagen.dc1name);$($datagen.dc1ip)","$($datagen.dc2name);$($datagen.dc2ip)"
  
  foreach ($endpoint in $endpoints){
  
    $endpointname = $endpoint.split(";")[0]
    $endpointIP = $endpoint.split(";")[1]
    $username = "Administrator"
    $credname = "$($username)_$(get-random)"
  
    write-log -message "Creating Endpoint $endpointname"
    write-log -message "Using IP $endpointIP"
  
    $endpoint = REST-Add-Endpoint-Windows `
      -PCClusterIP $datagen.PCClusterIP `
      -PCClusterUser $datagen.buildaccount `
      -PCClusterPass $datavar.pepass `
      -IP $endpointIP `
      -username $username `
      -password $datavar.pepass `
      -credname $credname `
      -endpname $endpointname `
      -project $project
  
  }
  write-log -message "Inserting Windows Patching Playbook" -sev "Chapter"

  write-log -message "Loading Runbook Payload" 

  $json = get-content "$($basedir)\Runbooks\Windows Patching.json"
  
  write-log -message "Importing Runbook" 

  $importRunbook = REST-Runbook-Import-Blob `
    -PCClusterIP $datagen.PCClusterIP `
    -PCClusterUser $datagen.buildaccount `
    -PCClusterPass $datavar.pepass `
    -Json $json `
    -project_uuid $($project.metadata.uuid) `
    -name "Windows Patching"
  
  write-log -message "Getting All Runbooks" 

  $Runbooks = REST-Get-Runbooks `
    -PCClusterIP $datagen.PCClusterIP `
    -PCClusterUser $datagen.buildaccount `
    -PCClusterPass $datavar.pepass

  write-log -message "Getting All Runbooks" 
  
  $runbook = $Runbooks.entities |where {$_.status.name -eq "Windows Patching" }

  write-log -message "Getting Runbook detail for $($runbook.metadata.uuid)" 
  
  $runbookdetail = REST-Get-Runbook-Detailed `
    -PCClusterIP $datagen.PCClusterIP `
    -PCClusterUser $datagen.buildaccount `
    -PCClusterPass $datavar.pepass `
    -uuid $runbook.metadata.uuid
  
  write-log -message "Updating Runbook Endpoint" 
  
  $default_target_reference = @{
    uuid = $endpoint.EndpointUUID
    name = $endpoint.EndpointName
  }

  $runbookdetail.spec.resources | add-member noteproperty default_target_reference $default_target_reference -force

  
  write-log -message "Sending Payload back to Calm" 

  $updateRunbook = REST-Update-Runbook `
    -PCClusterIP $datagen.PCClusterIP `
    -PCClusterUser $datagen.buildaccount `
    -PCClusterPass $datavar.pepass `
    -runbookdetail $runbookdetail

  write-log -message "Runbook Wrapper finished" -sev "Chapter" -slacklevel 1
}