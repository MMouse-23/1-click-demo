function Wrap-Install-Runbooks {
  param(
    $datavar,
    $datagen,
    $basedir
  )

  write-log -message "Installing Runbooks in Calm" -sev "Chapter" -slacklevel 1

  $projects = REST-Query-Projects -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount
  
  $project = $projects.entities | where {$_.spec.name -match "Customer-D"}
  
  write-log -message "Using $($project.metadata.uuid)"

  write-log -message "Creating Endpoints" -sev "Chapter" -slacklevel 1

  $endpoints = "DC1;$($datagen.dc1ip)","DC3;$($datagen.dc2ip)"
  
  foreach ($endpoint in $endpoints){
  
    $endpointname = $endpoint.split(";")[0]
    $endpointIP = $endpoint.split(";")[1]
    $username = "Administrator"
    $credname = "$($username)_$($endpointname)"
  
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

  $runbookdetail.spec.resources.default_target_reference.uuid = $endpoint.EndpointUUID
  $runbookdetail.spec.resources.default_target_reference.name = $endpoint.EndpointName
  
  write-log -message "Sending Payload back to Calm" 

  $updateRunbook = REST-Update-Runbook `
    -PCClusterIP $datagen.PCClusterIP `
    -PCClusterUser $datagen.buildaccount `
    -PCClusterPass $datavar.pepass `
    -runbookdetail $runbookdetail

  write-log -message "Runbook Wrapper finished" -sev "Chapter" -slacklevel 1
}