Function REST-Query-ADGroups {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building UserGroup Query JSON"

  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/user_groups/list"
  $Payload= @{
    kind="user_group"
    offset=0
    length=999
  } 

  $JSON = $Payload | convertto-json
  try { 
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

  }

  Return $task
}

Function REST-Get-Containers {
  Param (
    [string] $PEClusterIP,
    [string] $clpassword,
    [string] $clusername
  )

  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing Container List"

  $URL = "https://$($PEClusterIP):9440/PrismGateway/services/rest/v1/containers"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }
  write-log -message "We found $($task.entities.count) items."

  Return $task
} 
Function REST-PE-Get-MultiCluster {
  Param (
    [object] $datavar,
    [object] $datagen
  )

  $clusterip = $datavar.PEClusterIP
  $credPair = "$($DATAVAR.PEADMIN):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  write-log -message "Connecting to $clusterip"

  $URL = "https://$($clusterip):9440//PrismGateway/services/rest/v1/multicluster/cluster_external_state"

  try{
    $Inventory = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  
    write-log -message "MultiCluster Status Retrieved"
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $Inventory = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }
  Return $Inventory

} 


Function REST-PE-Add-MultiCluster {
  Param (
    [object] $datavar,
    [object] $datagen
  )

  $clusterip = $datavar.PEClusterIP
  $credPair = "$($datagen.buildaccount):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  write-log -message "Connecting to $clusterip"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/multicluster/prism_central/register"
  $json1 = @"
{
    "ipAddresses": ["$($Datagen.pcclusterip)"],
    "username": "$($datagen.buildaccount)",
    "password": "$($datavar.pepass)",
    "port": 9440
}
"@

  try{
    $Inventory = Invoke-RestMethod -Uri $URL -method "post" -body $json1 -ContentType 'application/json' -headers $headers;
  
    write-log -message "MultiCluster Join Request sent"
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $Inventory = Invoke-RestMethod -Uri $URL -method "post" -body $json1 -ContentType 'application/json' -headers $headers;
  }
  Return $Inventory

} 

Function REST-Get-PE-Networks {
  Param (
    [object] $datavar,
    [object] $datagen
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($datavar.peadmin):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Query PE Networks"

  $URL = "https://$($datavar.peclusterip):9440/PrismGateway/services/rest/v2.0/networks"

  write-log -message "Using URL $URL"
  write-log -message "Using IP $($datavar.peclusterip)"

  try {
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }  
  Return $task
} 

Function REST-Get-PE-Hosts {
  Param (
    [object] $datavar,
    [string] $username
  )
  $credPair = "$($username):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing Get Hosts Query"

  $URL = "https://$($datavar.PEClusterIP):9440/PrismGateway/services/rest/v1/hosts"

  write-log -message "Using URL $URL"


  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }

  Return $task
} 


Function REST-Enable-Calm {
  Param (
    [string] $PCClusterIP,
    [string] $clpassword,
    [string] $clusername
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $countcalm = 0 
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building CALM JSON"

  $CALMURL = "https://$($PCClusterIP):9440/api/nutanix/v3/services/nucalm"
  $CALMPayload= @{
    state="ENABLE"
    enable_nutanix_apps=$true
  } 
  $CalmJSON = $CALMPayload | convertto-json

  write-log -message "Enabling Calm"
  do {;
    $countcalm++;
    $successCLAM = $false;
    try {;
      $task = Invoke-RestMethod -Uri $CALMURL -method "post" -body $CalmJSON -ContentType 'application/json' -headers $headers;
      
    }catch {;

      write-log -message "Enabling CALM Failed, retry attempt $countcalm out of 5" -sev "WARN";

      sleep 2
       $successCLAM = $false;
    }
    try {
      sleep 90 
      $task = Invoke-RestMethod -Uri $CALMURL -method "post" -body $CalmJSON -ContentType 'application/json' -headers $headers;

      write-log -message "Just Checking" 
      
      $successCLAM = $true;

    } catch {
      $successCLAM = $true

      write-log -message "Calm was propperly enabled"
    }
  } until ($successCLAM -eq $true -or $countcalm -eq 5);



  if ($countcalm -eq 5){;
  
    write-log -message "Registration failed after $countEULA attempts" -sev "WARN";
  
  };
  if ($successCLAM -eq $true){
    write-log -message "Enabling Calm success"
    $status = "Success"
  } else {
    $status = "Failed"
  }
  $resultobject =@{
    Result = $status
    TaskUUID = $task.task_uuid
  }
  return $resultobject
};


Function REST-Enable-Flow {
  Param (
    [object] $datavar,
    [object] $datagen,
    [string] $mode = $full
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $countflow = 0 
  $credPair = "$($datagen.buildaccount):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  $FlowURL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/services/microseg"
  $TestURL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/services/microseg/status"

  $FlowPayload= @{
    state="ENABLE"
  } 

  $FlowJSON = $FlowPayload | convertto-json

  do {;
    $countFlow++;
    $successflow = $false;
    try {;
      if ($mode -eq "Full"){

        write-log -message "Enabling Flow"

        $task = Invoke-RestMethod -Uri $FlowURL -method "post" -body $FlowJSON -ContentType 'application/json' -headers $headers;
      }
      $testercount = 0
      do {
        write-log -message "Checking Flow Enabled status"

        $testercount++
        $testtask = Invoke-RestMethod -Uri $TestURL -method "GET" -headers $headers;
        sleep 10
      } until ($testtask.service_enablement_status -eq "ENABLED" -or $testercount -ge 8)
      if ($testtask.service_enablement_status -eq "ENABLED"){
        $successflow = $true
      } else {

        write-log -message "Enabling Flow Failed, retry attempt $countFlow out of 5" -sev "WARN";
        
      }
      
    }catch {;

      $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
      $task
      sleep 2
      $successflow = $false;
    }

  } until ($successflow -eq $true -or $countFlow -eq 5);
  if ($countFlow -eq 5){;
  
    write-log -message "Enabling Flow failed after $countEULA attempts" -sev "WARN";
  
  };
  if ($successflow -eq $true){
    write-log -message "Enabling Flow success"
    $status = "Success"
  } else {
    $status = "Failed"
  }
  $resultobject =@{
    Result = $status
    TaskUUID = $task.task_uuid
  }
  return $resultobject
};

Function REST-Enable-Karbon-PC {
  Param (
    [object] $datagen,
    [object] $datavar
  )
  $clusterIP = $datagen.PCClusterIP

  $credPair = "$($datagen.Buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Enabling Karbon"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/genesis"

  write-log -message "Using URL $URL"

  $SET = '{"value":"{\".oid\":\"ClusterManager\",\".method\":\"enable_service_with_prechecks\",\".kwargs\":{\"service_list_json\":\"{\\\"service_list\\\":[\\\"KarbonUIService\\\",\\\"KarbonCoreService\\\"]}\"}}"}'
  $CHECK = '{"value":"{\".oid\":\"ClusterManager\",\".method\":\"is_service_enabled\",\".kwargs\":{\"service_name\":\"KarbonUIService\"}}"}'
  
  try{
    $Checktask1 = Invoke-RestMethod -Uri $URL -method "post" -body $CHECK -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    write-log -message "Going once"

    $Checktask1 = Invoke-RestMethod -Uri $URL -method "post" -body $CHECK -ContentType 'application/json' -headers $headers;
    $result = $Checktask1 
  }
  if ($Checktask1 -notmatch "true"){

    write-log -message "Karbon is not enabled yet."

    try{
      $SETtask = Invoke-RestMethod -Uri $URL -method "post" -body $SET -ContentType 'application/json' -headers $headers;
    } catch {
      sleep 10

      write-log -message "Going once"
  
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $SET -ContentType 'application/json' -headers $headers;
    }
  
    sleep 5 
  
    try{
      $Checktask2 = Invoke-RestMethod -Uri $URL -method "post" -body $CHECK -ContentType 'application/json' -headers $headers;
    } catch {
      sleep 10

      write-log -message "Going once"
  
      $Checktask2 = Invoke-RestMethod -Uri $URL -method "post" -body $CHECK -ContentType 'application/json' -headers $headers;
    }
    $result = $Checktask2 
  } else {

    write-log -message "Karbon is already enabled."
    $result = "true"

  }
  if ($result -match "true"){
    $status = "Success"

    write-log -message "All Done here, ready for K8 Cluster";

  } else {
    $status = "Failed"
    write-log -message "Danger Will Robbinson." -sev "ERROR";
  }
  $resultobject =@{
    Result = $status
    Output = $result
  };
  return $resultobject
} 

Function REST-ERA-ResetPass {
  Param (
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername
  )

  write-log -message "Executing ERA Portal Pass reset"
  write-log -message "Executing using default pass"
  $defaultpass = "Nutanix/4u"

  $URL = "https://$($EraIP):8443/era/v0.8/auth/update"
  $URL1 = "https://$($EraIP):8443/era/v0.8/auth/validate?token=true&expire=15"

  do {
    write-log -message "Using URL $URL"

    $Json = @"
{ "password": "$($clpassword)" }
"@ 

    $credPair = "$($clusername):$($defaultpass)"
    $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
    $headers = @{ Authorization = "Basic $encodedCredentials" }
    try {
      $task = Invoke-RestMethod -Uri $URL1 -method "post" -body $JSON -ContentType 'application/json' -headers $headers; 
    } catch {

      write-log -message "Password is expired"
      try {
        $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers; 
      } catch {
        $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
      }
    }

    write-log -message "Password change Success"
    if ($debug -ge 1){
      $json | out-file c:\temp\erapass.json
    }
    $passreset = $true
  

  } until ($passreset -eq $true)

  if ($passreset -eq $true){
    $status = "Success"

    write-log -message "ERA Portal Password has been reset"

  } else {

    write-log -message "ERA Portal Password reset failure." -sev "ERROR"

    $status = "Failed"
  }
  $resultobject =@{
    Result = $status
  }
  Return $resultobject
} 


Function REST-Finalize-Px {
  Param (
    [string] $ClusterPx_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $SENAME,
    [string] $SECompany,
    [string] $SEROLE,
    [string] $EnablePulse
  )

  ###https://pallabpain.wordpress.com/2016/09/14/rest-api-call-with-basic-authentication-in-powershell/

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"

  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building EULA JSON"

  $EULAURL = "https://$($ClusterPx_IP):9440/PrismGateway/services/rest/v1/eulas/accept"
  $EULATURL = "https://$($ClusterPx_IP):9440/PrismGateway/services/rest/v1/eulas"
  $EULAPayload= @{
    username="$($SENAME)"
    companyName="$($SECompany)"
    jobTitle="$($SEROLE)"
  } 
  $EULAJson = $EULAPayload | convertto-json

  write-log -message "Registering Px"
  try {
    $registration = (Invoke-RestMethod -Uri $EULATURL -method "get" -headers $headers).entities.userdetailslist;
  
  } catch {;
    write-log -message "We Could not query Px for existing registration" -sev "WARN";
  };
  if ($registration.username -eq $SENAME ){;

    write-log -message "Px $ClusterPx_IP is already registrered";

    $successEULA = $true;
    $registration
  } else {;
    do {;
      $countEULA++;
      $successEULA = $false;
      try {;
        Invoke-RestMethod -Uri $EULAURL -method "post" -body $EULAJson -ContentType 'application/json' -headers $headers;
        $successEULA = $true;
      }catch {;
  
        write-log -message "Registration failed, retry attempt $countEULA out of 5" -sev "WARN";
        sleep 2
        $successEULA = $false;
      }
    } until ($successEULA -eq $true -or $countEULA -eq 5);
    if ($countEULA -eq 5){;
  
      write-log -message "Registration failed after $countEULA attempts" -sev "WARN";

    };
  };

  
  if ($EnablePulse -eq 0){

    write-log -message "Building Pulse JSON"  

    $PulseURL = "https://$($ClusterPx_IP):9440/PrismGateway/services/rest/v1/pulse"
    $PulsePayload=@{
        enable="false"
        enableDefaultNutanixEmail="false"
        isPulsePromptNeeded="false"
    }
    $PulseJson = $PulsePayload | convertto-json

    write-log -message "Disabling Pulse"

    do {
      $countPulse++
      $Pulsestatus = $false
      try {
        Invoke-RestMethod -Uri $PulseURL -method "put" -body $PulseJson -ContentType 'application/json' -headers $headers;
        $Pulsestatus = $true

      }catch {
        
        write-log -message "Disabling pulse failed, retry attempt $countPulse out of 5" -sev "WARN"

        $Pulsestatus = $false
        sleep 2
      }
    } until ($Pulsestatus -eq $true -or $countPulse -eq 5)
    if ($countPulse -eq 5){

      write-log -message "Disabling Pulse failed after $countEULA attempts" -sev "WARN"

    };
  } else {
    $Pulsestatus -eq $true
  }
  if ($successEULA -eq $true -and $Pulsestatus -eq $true){
    $status = "Success"
  } else {
    $status = "Failed"
  }
  $resultobject =@{
    Result = $status
  }
  return $resultobject
};

Function REST-Image-Import-PC {
  Param (
    [string] $PCClusterIP,
    [string] $clpassword,
    [string] $clusername,
    [string] $failsilent
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $countflow = 0 
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building Cluster JSON" 
  $clusterurl = "https://$($PCClusterIP):9440//api/nutanix/v3/clusters/list"
  $ClusterJSON = @"
{
  "kind": "cluster"
}
"@

  write-log -message "Importing Images into PC"
  if ($failsilent -eq 1){
    $failcount = 1
  } else {
    $failcount = 5
  }

  do {;
    write-log -message "Gathering Cluster UUID"
    try {
      $Clusters = (Invoke-RestMethod -Uri $clusterurl -method "POST" -headers $headers -body $ClusterJSON -ContentType 'application/json').entities
      $cluster = $clusters | where {$_.status.name -notmatch "unnamed|^PC"}
      write-log -message "PE Cluster UUID is $($cluster.metadata.uuid)"
    } catch {;
      write-log -message "We Could not query Px for existing storage containers" -sev "ERROR";
    };
    write-log -message "Building Image Import JSON" 
    $ImageURL = "https://$($PCClusterIP):9440/api/nutanix/v3/images/migrate"  
    $ImageJSON = @"
{
  "image_reference_list":[],
  "cluster_reference":{
    "uuid":"$($cluster.metadata.uuid)",
    "kind":"cluster",
    "name":"string"}
}
"@
    $countimport++;
    $successImport = $false;
    try {;
      $task = Invoke-RestMethod -Uri $ImageURL -method "post" -body $ImageJSON -ContentType 'application/json' -headers $headers;
      $successImport = $true
    } catch {;

      write-log -message "Importing Images into PC Failed, retry attempt $countimport out of $failcount" -sev "WARN";

      sleep 60
      $successImport = $false;
    }
  } until ($successImport -eq $true -or $countimport -eq $failcount);
  if ($countimport -eq $failcount){;
  
    write-log -message "Importing Images into PC after $countimport attempts" -sev "WARN";
  
  };
  if ($successImport -eq $true){
    write-log -message "Importing Images into PC success"
    $status = "Success"
  } else {
    $status = "Failed"
  }
  $resultobject =@{
    Result = $status
    TaskUUID = $task.task_uuid
  }
  return $resultobject
};

Function REST-Install-PC {
  Param (
    [string] $ClusterPE_IP,
    [string] $PCClusterIP,
    [string] $clusername,
    [string] $clpassword,
    [string] $InfraSubnetmask,
    [string] $InfraGateway,
    [string] $DNSServer,
    [string] $PC1_Name,
    [string] $PC2_Name,
    [string] $PC3_Name,
    [string] $PC1_IP,
    [string] $PC2_IP,
    [string] $PC3_IP,
    [string] $AOSVersion,
    [string] $NetworkName,
    [string] $DisksContainerName,
    [string] $PCmode,
    [string] $PCVersion

  )
  $PCinstallcount = 0 
  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  do {
    $PCinstallcount++
    $credPair = "$($clusername):$($clpassword)"
    $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
    $headers = @{ Authorization = "Basic $encodedCredentials" }
    $containerURL = "https://$($ClusterPE_IP):9440/PrismGateway/services/rest/v2.0/storage_containers"
    $networksURL = "https://$($ClusterPE_IP):9440/PrismGateway/services/rest/v2.0/networks"
    $queryURL = "https://$($ClusterPE_IP):9440/PrismGateway/services/rest/v1/upgrade/prism_central_deploy/softwares"
    $installURL = "https://$($ClusterPE_IP):9440/api/nutanix/v3/prism_central"


   try {
      $Version = (Invoke-RestMethod -Uri $queryURL -method "get" -headers $headers).entities.version | sort { [Version]$_} | select -last 1
      write-log -message "Latest Version is $Version"
      write-log -message "Specified version is $pcVersion"


      if ($pcversion -match "Latest|Auto" -or $pcversion -eq $null){

        write-log -message "Using PC Version $Version"

      } else {
        $Version = $pcVersion
      }
      write-log -message "Using PC Version ->$($Version)<-"

    } catch {;
      write-log -message "Could not query PE for PC version" -sev "ERROR";
    };

    $Object = (Invoke-RestMethod -Uri $queryURL -method "get" -headers $headers).entities | where {$_.version -eq $Version}
    $sizeL = $object.prismCentralSizes | where {$_.pcvmformfactor -eq "large"}
    sleep 1
    if (!$sizeL.diskSizeInGib){

      write-log -message "Hmm, yeah sideloading does not give me image sizes, let me get the second last one"

      $last2Versions = (Invoke-RestMethod -Uri $queryURL -method "get" -headers $headers).entities.version | sort { [Version]$_} | select -last 2 
      $SecondLastVersion = $last2Versions | sort { [Version]$_} | select -first 1
      $Object = (Invoke-RestMethod -Uri $queryURL -method "get" -headers $headers).entities | where {$_.version -eq $SecondLastVersion}
      $sizeL = $object.prismCentralSizes | where {$_.pcvmformfactor -eq "large"}
      sleep 1
      if (!$sizeL.diskSizeInGib){

        write-log -message "This should work. $sizeL"

      } else {

        write-log -message "This will not work, we cannot build a dynamic PC size JSON Without PC Sizing."

      }

    }

    $disksizebytes = $sizeL.diskSizeInGib * 1024 * 1024 * 1024
    $memorysizebytes = $sizeL.memorySizeInGib * 1024 * 1024 * 1024

    write-log -message "Deploying Large PC"
    write-log -message "Using Memory Bytes: $memorysizebytes"
    write-log -message "Using Disk Bytes: $disksizebytes"
    write-log -message "Using $($sizeL.vcpus) vCPUs"

    write-log -message "Gathering Storage UUID"
    write-log -message "Searching containers matching $DisksContainerName"

    try {
      $StorageContainer = (Invoke-RestMethod -Uri $containerURL -method "get" -headers $headers).entities | where {$_.name -eq $DisksContainerName}
      write-log -message "Storage UUID is $($StorageContainer.storage_container_uuid)"
    } catch {;
      write-log -message "We Could not query Px for existing storage containers" -sev "ERROR";
    };

    write-log -message "Gathering Network UUID"

    try {
      $Network = (Invoke-RestMethod -Uri $networksURL -method "get" -headers $headers).entities | where {$_.name -eq "$($NetworkName)"}

      if (!$network){
  
        write-log -message "This is not a blanc cluster, someone did not read the ffing manual." -sev "ERROR"
  
      } 

      write-log -message "Network UUID is $($Network.uuid)"

    } catch {;

      write-log -message "We Could not query Px for existing networks" -sev "ERROR";

    };
    if ($pcmode -ne 1){
      $PCJSON = @"
{
  "resources": {
    "should_auto_register":false,
    "version":"$($Version)",
    "virtual_ip":"$($PCClusterIP)",
    "pc_vm_list":[{
      "data_disk_size_bytes":$disksizebytes,
      "nic_list":[{
        "network_configuration":{
          "subnet_mask":"$($InfraSubnetmask)",
          "network_uuid":"$($Network.uuid)",
          "default_gateway":"$($InfraGateway)"
        },
        "ip_list":["$($PC1_IP)"]
      }],
      "dns_server_ip_list":["$DNSServer"],
      "container_uuid":"$($StorageContainer.storage_container_uuid)",
      "num_sockets":$($sizeL.vcpus),
      "memory_size_bytes":$memorysizebytes,
      "vm_name":"$($PC1_Name)"
    },
    {
      "data_disk_size_bytes":$disksizebytes,
      "nic_list":[{
        "network_configuration":{
          "subnet_mask":"$($InfraSubnetmask)",
          "network_uuid":"$($Network.uuid)",
          "default_gateway":"$($InfraGateway)"
        },
        "ip_list":["$($PC2_IP)"]
      }],
      "dns_server_ip_list":["$($DNSServer)"],
      "container_uuid":"$($StorageContainer.storage_container_uuid)",
      "num_sockets":$($sizeL.vcpus),
      "memory_size_bytes":$memorysizebytes,
      "vm_name":"$($PC2_Name)"
    },
    {
      "data_disk_size_bytes":$disksizebytes,
      "nic_list":[{
        "network_configuration":{
          "subnet_mask":"$($InfraSubnetmask)",
          "network_uuid":"$($Network.uuid)",
          "default_gateway":"$($InfraGateway)"
        },
        "ip_list":["$($PC3_IP)"]
      }],
      "dns_server_ip_list":["$($DNSServer)"],
      "container_uuid":"$($StorageContainer.storage_container_uuid)",
      "num_sockets":$($sizeL.vcpus),
      "memory_size_bytes":$memorysizebytes,
      "vm_name":"$($PC3_Name)"
    }]    
  }
}
"@
    } else {
      $PCJSON = @"
{
  "resources": {
    "should_auto_register":false,
    "version":"$($Version)",
    "pc_vm_list":[{
      "data_disk_size_bytes":$disksizebytes,
      "nic_list":[{
        "network_configuration":{
          "subnet_mask":"$($InfraSubnetmask)",
          "network_uuid":"$($Network.uuid)",
          "default_gateway":"$($InfraGateway)"
        },
        "ip_list":["$($PCClusterIP)"]
      }],
      "dns_server_ip_list":["$DNSServer"],
      "container_uuid":"$($StorageContainer.storage_container_uuid)",
      "num_sockets":$($sizeL.vcpus),
      "memory_size_bytes":$memorysizebytes,
      "vm_name":"$($PC1_Name)"
    }]   
  }
}
"@  }

    write-log -message "Installing Prism Central"

    try { 
      $task = Invoke-RestMethod -Uri $installURL -method "Post" -headers $headers -body $PCJSON -ContentType 'application/json'
      $taskid = $task.task_uuid
      if ($debug -ge 1){
        $task 
        write-host $PCJSON
      }
    } catch {
      
      write-log -message "Failure installing Prism Central, retry $PCinstallcount out of 5" -sev "WARN"
      sleep 60
      if ($debug -ge 1){
        $task 
        write-host $PCJSON
        $task = Invoke-RestMethod -Uri $installURL -method "Post" -headers $headers -body $PCJSON -ContentType 'application/json'
      
      }
    }
  } Until ($taskid -match "[0-9]" -or $PCinstallcount -eq 5)
  if ($taskid -match "[0-9]"){
    $status = "Success"

    write-log -message "Prism Central is installing in $PCmode node mode, we are done."

  } else {
    $status = "Failed"
    write-log -message "Failure installing Prism Central after 5 tries" -sev "ERROR"
  }
  $resultobject =@{
    Result = $status
    TaskID = $taskid
  }
  return $resultobject
};

Function REST-WorkShopConfig-Px {
  Param (
    [string] $ClusterPx_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $POCName,  
    [string] $VERSION,
    [object] $datavar,
    [string] $Mode
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $count = 0 
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building JSON Array" 

  [array]$JSONA += @"
{"type":"custom_login_screen","key":"color_in","value":"#ADD100"}
"@
  [array]$JSONA += @"
{"type":"custom_login_screen","key":"color_out","value":"#11A3D7"}
"@
  if ($mode -eq "PC"){
  [array]$JSONA += @"
{"type":"custom_login_screen","key":"product_title","value":"$($POCName),Prism-Central-$($VERSION)"}
"@
  } else {
  [array]$JSONA += @"
{"type":"custom_login_screen","key":"product_title","value":"$($POCName),Prism-Element-$($datavar.aosversion)"}
"@    
  }
  [array]$JSONA += @"
{"type":"custom_login_screen","key":"title","value":"1-Click-Demo"}
"@
  [array]$JSONA += @"
{"type":"UI_CONFIG","username":"system_data","key":"disable_2048","value":true}
"@
  [array]$JSONA += @"
{"type":"UI_CONFIG","key":"autoLogoutGlobal","value":7200000}
"@
  [array]$JSONA += @"
{"type":"UI_CONFIG","key":"autoLogoutOverride","value":0}
"@
  [array]$JSONA += @"
{"type":"UI_CONFIG","key":"welcome_banner","value":"1-Click-Demo"}
"@
  $URL = "https://$($ClusterPx_IP):9440/PrismGateway/services/rest/v1/application/system_data"
  
  write-log -message "Importing $($JSONA.count) JSONs"

  foreach ($json in $JSONA){
    try {
      Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers -ea:0;
    } catch {;
  
      write-log -message "JSON Already Applied"

    }
  };
  ## Some error out, ignoring
  $resultobject =@{
    Result = "Success"

  }
  return $resultobject
};



Function REST-ADD-Nic-VMware {
  Param (
    [object]  $datavar,
    [object]  $datagen,
    [string]  $vmuuid,
    [string]  $networkuuid,
    [string]  $adapter_type = "Vmxnet3"
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($datavar.peadmin):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Adding a nic."

  $URL1 = "https://$($datavar.PEClusterIP):9440/PrismGateway/services/rest/v2.0/vms/$($vmuuid)/nics"

  $Json1 = @"
{
  "spec_list": [{
    "network_uuid": "$($networkuuid)",
    "adapter_type": "Vmxnet3",
    "is_connected": true,
    "vlan_id": ""
  }]
}
"@ 

  try {

    $task1 = Invoke-RestMethod -Uri $URL1 -method "POST" -body $JSON1 -ContentType 'application/json' -headers $headers;

    write-log -message "VMCreated, getting uuid"


  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 60
   
    $task1 = Invoke-RestMethod -Uri $URL1 -method "POST" -body $JSON1 -ContentType 'application/json' -headers $headers;

    write-log -message "VMCreated, getting uuid"
    sleep 10
    $vm = (REST-Get-VMs -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.PEPass -clusername $datavar.peadmin).entities | where {$_.vmName -eq $VMname}

  }
  return $task1
} 

Function REST-Create-VM-VMware {
  Param (
    [object]  $datavar,
    [object]  $datagen,
    [string]  $VMname,
    [decimal]   $CPU = 4,
    [decimal]   $RAM = 8192,
    [decimal]   $DiskSizeGB = 80,
    [decimal]   $cores = 1,
    [string]  $guestOS,
    [array]  $NDFSSource,
    [String]  $network_uuid

  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($datavar.peadmin):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Creating VMware VM using Nutanix Rest API"

  $URL1 = "https://$($datavar.PEClusterIP):9440/PrismGateway/services/rest/v2.0/vms/"

  $Json1 = @"
{
  "name": "$VMname",
  "memory_mb": "$($RAM)",
  "num_vcpus": "$($CPU)",
  "description": "",
  "num_cores_per_vcpu": $($cores),
  "timezone": "UTC",
  "guest_os": "$($guestOS)",
  "vm_disks": [{
    "disk_address": {
      "vmdisk_uuid": "",
      "device_bus": "ide",
      "device_index": 0
    },
    "is_cdrom": true,
    "is_empty": true
  }],
  "vm_nics": [{
    "network_uuid": "$($network_uuid)",
    "adapter_type": "E1000e",
    "is_connected": true
  }],
  "hypervisor_type": "VMWARE",
  "affinity": null,
  "clear_affinity": true
}
"@ 



    write-log -message "$($NDFSSource.count) Sources, updating JSON."

    $object = $Json1 | convertfrom-json
    foreach ($disk in $NDFSSource){

        $json2 = @"
{
    "disk_address": {
      "device_bus": "scsi",
      "vmdisk_uuid": ""
    },
    "is_cdrom": false,
    "vm_disk_clone": {
      "disk_address": {
        "ndfs_filepath": "$($disk)"
      }
    }
  }
"@ 

      $template = $json2 | convertfrom-json
      $object.vm_disks += $template
    }
    write-log -message "result object:"
    $object
    $json1 = $object | convertto-json -depth 100
  


      $json1
    
  try {
    $vm = (REST-Get-VMs -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.PEPass -clusername $datavar.peadmin).entities | where {$_.vmName -eq $VMname}
    if ($vm){

      write-log -message "Cleaning First"

      $URL2 = "https://$($datavar.PEClusterIP):9440/PrismGateway/services/rest/v2.0/vms/$($VM.uuid)?delete_snapshots=true"
      $task2 = Invoke-RestMethod -Uri $URL2 -method "DELETE" -headers $headers;
      sleep 30
    } 

    $task1 = Invoke-RestMethod -Uri $URL1 -method "POST" -body $JSON1 -ContentType 'application/json' -headers $headers;

    write-log -message "VMCreated, getting uuid"
    sleep 10
    $vm = (REST-Get-VMs -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.PEPass -clusername $datavar.peadmin).entities | where {$_.vmName -eq $VMname}

    write-log -message "VM uuid is $($vm.uuid)"

  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 60
    if ($vm){

      write-log -message "Cleaning First"

      $URL2 = "https://$($datavar.PEClusterIP):9440/PrismGateway/services/rest/v2.0/vms/$($VM.uuid)?delete_snapshots=true"
      $task2 = Invoke-RestMethod -Uri $URL2 -method "DELETE" -headers $headers;

    }
    $task1 = Invoke-RestMethod -Uri $URL1 -method "POST" -body $JSON1 -ContentType 'application/json' -headers $headers;

    write-log -message "VMCreated, getting uuid"
    sleep 10
    $vm = (REST-Get-VMs -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.PEPass -clusername $datavar.peadmin).entities | where {$_.vmName -eq $VMname}

  }
  return $vm
} 

Function REST-Set-VM-Power-State {
  Param (
    [object] $datavar,
    [object] $datagen,
    [string] $VMuuid,
    [string] $State
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($datavar.peadmin):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Sending Power State $State to $VMuuid"

  $URL = "https://$($datavar.PEClusterIP):9440/PrismGateway/services/rest/v2.0/vms/$($VMuuid)/set_power_state"

  $Json = @"
{"transition":"$($State)"}
"@ 
  write-log -message $url
  try {

    $task1 = Invoke-RestMethod -Uri $URL -method "POST" -body $JSON -ContentType 'application/json' -headers $headers;
    sleep 30

  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 60
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $JSON -ContentType 'application/json' -headers $headers;

  }
  return $task 
} 

Function REST-Get-VM-Detail {
  Param (
    [object] $datavar,
    [object] $datagen,
    [string] $uuid

  )

  $credPair = "$($datagen.buildaccount):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing VM Detail Query using VM "

  $URL = "https://$($datavar.PEClusterIP):9440/PrismGateway/services/rest/v2.0/vms/$($uuid)?include_vm_disk_config=true&include_vm_nic_config=true&includeVMDiskSizes=true&includeAddressAssignments=true"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }
  write-log -message "We found a VM called $($task.name)"

  Return $task
} 

Function REST-Unmount-CDRom {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $uuid,
    [object] $cdrom
  )

  $clusterip = $datavar.PEClusterIP  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Unmounting CD for VM with ID $uuid"
  write-log -message "Using Drivelabel $drivelabel"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v2.0/vms/$($uuid)/disks/update"

  write-log -message "Using URL $URL"

$Payload= @"
{
  "vm_disks": [{
    "disk_address": {
      "vmdisk_uuid": "$($cdrom.disk_address.vmdisk_uuid)",
      "device_index": $($cdrom.disk_address.device_index),
      "device_bus": "$($cdrom.disk_address.device_bus)"
    },
    "flash_mode_enabled": false,
    "is_cdrom": true,
    "is_empty": true
  }]
}
"@ 
  if ($debug -ge 2){
    $Payload
  }
  try{
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $Payload -ContentType 'application/json' -headers $headers;

    write-log -message "CDROM Unmounted" 

  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $Payload -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 


Function REST-Set-PE-Network{
  Param (
    [object] $datavar,
    [object] $datagen,
    [object] $network
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($datavar.peadmin):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "SET PE Network $($network.name)"
  write-log -message "SET PE Network $($network.uuid)"
  write-log -message "SET PE Network $($network.ip_config.dhcp_options.domain_name_servers)"
  

  $URL = "https://$($datavar.peclusterip):9440/api/nutanix/v0.8/networks/$($network.uuid)"

  write-log -message "Using URL $URL"

  $Payload = $network | convertto-json -depth 100

  if ($debug -ge 2){
    $Payload
  }

  try {
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $Payload -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $Payload -ContentType 'application/json' -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }  
  Return $task
} 



Function REST-Mount-NGT {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $VMUUID
  )

  $clusterip = $datavar.PEClusterIP  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Mounting NGT For $VMUUID"

  $URL1 = "https://$($clusterip):9440/PrismGateway/services/rest/v1/vms/$($VMUUID)/guest_tools/mount"
  $URL2 = "https://$($clusterip):9440/PrismGateway/services/rest/v1/vms/$($VMUUID)/guest_tools"

  write-log -message "Using URL $URL1"
  write-log -message "Using URL $URL2"

$Payload1 = "{}"


$Payload2= @"
{
  "vmId": "$($VMUUID)",
  "enabled": true,
  "applications": {
    "file_level_restore": true,
    "vss_snapshot": true
  }
}
"@ 

  try{
    write-log -message "Executing Part 1"
  
    $task = Invoke-RestMethod -Uri $URL1 -method "post" -body $Payload1 -ContentType 'application/json' -headers $headers;
  
    sleep 10
    write-log -message "Executing Part 2"
    $task = Invoke-RestMethod -Uri $URL2 -method "post" -body $Payload2 -ContentType 'application/json' -headers $headers;

    write-log -message "Guest Tools Mounted" 

  } catch {
    sleep 10
    #$FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    write-log -message "Executing Part 1"
    try {
      $task = Invoke-RestMethod -Uri $URL1 -method "post" -body $Payload1 -ContentType 'application/json' -headers $headers;
    } catch {}
    sleep 10
    write-log -message "Executing Part 2"
    $task = Invoke-RestMethod -Uri $URL2 -method "post" -body $Payload2 -ContentType 'application/json' -headers $headers;

    write-log -message "Guest Tools Mounted" 
  }

  Return $task
} 


Function REST-AOS-PreUpgradeTest {
  Param (
    [object] $datagen,
    [object] $datavar,
    $AOSVer
  )
  $clusterip = $datavar.PEClusterIP
 
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing LCM Prescan for $AOSVer"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/genesis"

  write-log -message "Using URL $URL"

  $Start = '{"value":"{\".oid\":\"ClusterManager\",\".method\":\"cluster_upgrade\",\".kwargs\":{\"nos_version\":\"'

  $End = '\",\"manual_upgrade\":false,\"ignore_preupgrade_tests\":false,\"skip_upgrade\":true}}"}'
  
  [string]$json = $start + $AOSVer + $end
  
  write-log -message "Using JSON $json"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-AOS-Reboot {
  Param (
    [object] $datagen,
    [object] $datavar,
    [Array] $CVMs
  )
  $clusterip = $datavar.PEClusterIP
 
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing AOS Reboot for $($CVMs.count) hosts"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/genesis"

  write-log -message "Using URL $URL"

  $jsonP1 = '{ "value": "{\".oid\":\"ClusterManager\",\".method\":\"host_rolling_reboot\",\".kwargs\":{\"svm_ips\":[\"'
  Foreach ($ip in $CVMs){
    $JSONP2 += $ip + '\",\"'
  }
  $JSONP3 = $JSONP2.subString(0, $JSONP2.Length -5) 

  $JSONP4 = $jsonP1 + $JSONP3 + '\"]}}"}'
  
  write-log -message "Using JSON $JSONP4"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSONP4 -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSONP4 -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 


Function REST-AHV-InventorySoftware {
  Param (
    [object] $datagen,
    [object] $datavar
  )
  $clusterip = $datavar.PEClusterIP
 
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Scanning AHV Available Versions"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/upgrade/hypervisor/softwares"

  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }

  Return $task
} 


Function REST-AHV-Upgrade {
  Param (
    [object] $datagen,
    [object] $datavar,
    [Object] $AHV
  )
  $clusterip = $datavar.PEClusterIP
 
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing AHV Upgrade to version $($AHV.version)"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/genesis"

  write-log -message "Using URL $URL"
  $json = @"
{
"value":"{\".oid\":\"ClusterManager\",\".method\":\"cluster_hypervisor_upgrade\",\".kwargs\":{\"version\":\"$($AHV.version)\",\"manual_upgrade\":false,\"ignore_preupgrade_tests\":false,\"skip_upgrade\":false,\"username\":null,\"password\":null,\"host_ip\":null,\"md5sum\":\"$($AHV.md5Sum)\"}}"
}
"@
  write-log -message "Using JSON $json"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-PE-ProgressMonitor {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $mode
  )
  if ($mode -eq "PC"){
    $clusterip = $datagen.PCClusterIP
  } else {

    $clusterip = $datavar.PEClusterIP
  }
  
 
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Getting Progress Monitor Tasks"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/progress_monitors"

  write-log -message "Using URL $URL"


  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }

  write-log -message "There are $($task.entities.count) Tasks"
  [array]$rtasks =  $task.entities | where {$_.status -eq "Running"}
  write-log -message "There are $($rtasks.count) Running Tasks"

  Return $task
} 


Function REST-AOS-InventorySoftware {
  Param (
    [object] $datagen,
    [object] $datavar
  )
  $clusterip = $datavar.PEClusterIP
 
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Scanning AOS Available Versions"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/upgrade/nos/softwares"

  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }

  Return $task
} 


Function REST-AOS-Upgrade {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $AvailableAOSVersion
  )
  $clusterip = $datavar.PEClusterIP
 
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing LCM List Query"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/genesis"

  write-log -message "Using URL $URL"

  $Start= '{"value":"{\".oid\":\"ClusterManager\",\".method\":\"cluster_upgrade\",\".kwargs\":{\"nos_version\":\"'

  $End = '\",\"manual_upgrade\":false,\"ignore_preupgrade_tests\":false,\"skip_upgrade\":false}}"}'
  
  [string]$json = $start + $AvailableAOSVersion + $end
  
  write-log -message "Using URL $json"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-Delete-Image {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $UUID

  )

  $clusterip = $datavar.PEClusterIP
 
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Deleting Image $UUID"

  $URL = "https://$($clusterip):9440/api/nutanix/v0.8/images/$($UUID)"

  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "DELETE" -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "DELETE" -headers $headers;
  }

  Return $task
} 

Function REST-Upload-Image {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $ImageURL,
    [string] $ImageName,
    [string] $imageContainerUUID
  )

  $clusterip = $datavar.PEClusterIP
 
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Adding Image $ImageName"

  $URL = "https://$($clusterip):9440/api/nutanix/v0.8/images"

  write-log -message "Using URL $URL"

  if ($ImageName -match "ISO"){
    $type = "ISO_IMAGE"
  } else {
    $type = "DISK_IMAGE"
  }

  $var = @"
{
  "name": "$($ImageName)",
  "annotation": "$($ImageName)",
  "imageType": "$($type)",
  "imageImportSpec": {
    "containerUuid": "$($imageContainerUUID)",
    "url": "$($ImageURL)"
  }
}
"@

  if ($debug -ge 2){
    Write-log -message "Image JSON: $var"
  } 

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $var -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $var -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-Wait-ImageUpload {
  param (
    [string] $imagename,
    [Object] $datavar,
    [Object] $datagen
  )

  $maxloops = 8000
  $images = REST-Query-Images -ClusterPC_IP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -silent 1
  $imageobj = $images.entities | where {$_.spec.name -eq $imagename }
  if (!$imageobj){

    write-log -message "Image is not there yet, checking image tasks."
    write-log -message "This is the image wait module, so guess what, where waiting..."
    write-log -message "Checking every 15sec, max $maxloops times"

    $count = 0
    do {
      $count ++
      if ($count % 4 -eq 0){  
        write-log -message "cycle $count out of $maxloops"
      }
      $images = REST-Query-Images -ClusterPC_IP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -silent 1
      $imageobj = $images.entities | where {$_.spec.name -eq $imagename }
      $tasks = REST-Get-AOS-LegacyTask -datagen $datagen -datavar $datavar
      $uploadstatus = $tasks.entities | where {$_.operation -eq "ImageCreate" -and $_.status -eq "Running" }
      
      if ($uploadstatus.percentagecompleted -ne 100 -and $uploadstatus){
        sleep 10 
        if ($count % 4 -eq 0){
          write-log -message "An image is still being uploaded. $($uploadstatus.percentagecompleted) % Status is $($uploadstatus.status)"
        }
      } else {

        write-log -message "Job completed"
        write-log -message "Checking if this is me..."

        $images = REST-Query-Images -ClusterPC_IP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 
        $imageobj = $images.entities | where {$_.spec.name -eq $imagename }

        if ($imageobj){

          write-log -message "Image is present $($imageobj.status.name)"
          write-log -message "Image was granted UUID $($imageobj.metadata.uuid)"
        
        } else {

          write-log -message "Thats not it..."
          write-log -message "$imagename is not present and there are no running upload tasks, this is a temp thing."
          
          sleep 30

        }
      }
    } until ($imageobj -or $count -ge $maxloops )

  } else {

    write-log -message "Image is present $($imageobj.status.name)"
    write-log -message "Image was granted UUID $($imageobj.metadata.uuid)"
    write-log -message "Here we go!!"

  }
  $resultobject =@{
    Result = $imageobj.metadata.uuid
  };
  return $resultobject
};


Function REST-Get-Image-Sizes {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $silent =0
  )

  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  if ($silent -ne 1){

    write-log -message "Executing Images List Query With Size"

  }
  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v0.8/images?includeVmDiskSizes=true"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }

  Return $task
} 



Function REST-Get-AOS-LegacyTask {
  Param (
    [object] $datagen,
    [object] $datavar
  )
  $clusterip = $datavar.PEClusterIP
 
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  #output suppressed for task loopers
  #write-log -message "Executing LCM List Query"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/progress_monitors"

   # write-log -message "Using URL $URL"


  try{
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "get"  -headers $headers;
  }

  Return $task
} 


Function REST-LCM-BuildPlan {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode,
    [object] $Updates
  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing LCM List Query"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/genesis"

  write-log -message "Using URL $URL"

  $Start= '{"value":"{\".oid\":\"LifeCycleManager\",\".method\":\"lcm_framework_rpc\",\".kwargs\":{\"method_class\":\"LcmFramework\",\"method\":\"generate_plan\",\"args\":[\"http://download.nutanix.com/lcm/2.0\",['
  $End = ']]}}"}'
  
  foreach ($item in $updates){
    $update = "[\`"$($item.SoftwareUUID)\`",\`"$($item.version)\`"],"
    $start = $start + $update
  }
  $start = $start.Substring(0,$start.Length-1)
  $start = $start + $end
  [string]$json = $start
  write-log -message "Using URL $json"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-Import-Karbon-Blueprint {
  Param (
    [string] $BPfilepath,
    [object] $datagen,
    [object] $datavar,
    [string] $subnetUUID,
    [string] $ProjectUUID
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Loading Json"

  $jsonstring = get-content $BPfilepath

  write-log -message "Replacing JSON String Variables"

  #$jsonstring = $jsonstring -replace "--SSHPrivateKEYREF---", $($datagen.PrivateKey)
  $jsonstring = $jsonstring -replace "---PUBLICKKEYREF---", $($datagen.PublicKey)
  $jsonstring = $jsonstring -replace "---SUBNETREF---", $($subnetUUID)
  $jsonstring = $jsonstring -replace "---PCIPREF---", $($datagen.PCClusterIP)
  $jsonstring = $jsonstring -replace "---PROJECTREF---", $($ProjectUUID)
  $jsonstring = $jsonstring -replace "---PECLUSTERNAMEREF---", $($datavar.POCNAME)
  $jsonstring = $jsonstring -replace "---NETWORKNAMEREF---", $($datagen.NW1Name)
  $jsonstring = $jsonstring -replace "---KARBONIPRANGEREF---", $($datagen.KarbonIPRange)
  $jsonstring = $jsonstring -replace "---CONTAINERNAMEREF---", $($datagen.KarbonContainerName)
  $jsonstring = $jsonstring -replace '---PCPASSREF---', ''
  $jsonstring = $jsonstring -replace '---INSTANCEPASSWORD---', ''
  $jsonstring = $jsonstring -replace '---PCUSERNAMEREF---', $($datagen.buildaccount)
  $jsonstring = $jsonstring -replace '"value": "---SSHPrivateKEYREF---"', ''
  $jsonstring = $jsonstring -replace '"is_secret_modified": true },', '"is_secret_modified": false }'

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/import_json"

  if ($debug -eq 2){
    $jsonstring | out-file "C:\temp\Karbon.json"
  }

  write-log -message "Executing Import"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $jsonstring -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $jsonstring -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 



Function REST-Update-Karbon-Blueprint {
  Param (
    [object] $BPObject,
    [string] $BlueprintUUID,
    [object] $datagen,
    [object] $Keyobject,
    [object] $DomainObject,
    [object] $instancePWobject,
    [object] $PCPassObject,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Loading Json"

foreach ($line in $datagen.PrivateKey){
  [string]$Keystring += $line + '\n' 
}
$Keystring = $Keystring.Substring(0,$Keystring.Length-2)
$JSON1 = @"
{
 "credential_definition_list":  [
    {
    "username":  "centos",
    "description":  "",
    "uuid":  "$($Keyobject.uuid)",
    "secret":  {
                   "attrs":  {
                                 "is_secret_modified":  true,
                                 "secret_reference":  "$($Keyobject.secret.attrs.secret_reference.uuid)"
                             },
                   "value": "$Keystring" 
               },
    "editables":  {
                      "username":  true
                  },
    "type":  "KEY",
    "name":  "SSH_KEY"
   }
  ]
}
"@

$JSON2 = @"
{
    "val_type":  "STRING",
    "description":  "",
    "uuid":  "$($instancePWobject.uuid)",
    "label":  "",
    "attrs":  {
                  "is_secret_modified":  true,
                  "secret_reference":  {
                                           "uuid":  "$($instancePWobject.secret.attrs.secret_reference.uuid)"
                                       }
              },
    "type":  "SECRET",
    "name":  "INSTANCE_PASSWORD",
    "value" : "$($datavar.PEPass)"
}
"@
$JSON3 = @"
{
    "val_type":  "STRING",
    "description":  "",
    "uuid":  "$($PCPassObject.uuid)",
    "label":  "",
    "attrs":  {
                  "is_secret_modified":  true,
                  "secret_reference":  {
                                           "uuid":  "$($PCPassObject.secret.attrs.secret_reference.uuid)"
                                       }
              },
    "type":  "SECRET",
    "name":  "PC_PASSWORD",
    "value" : "$($datavar.PEPass)"
}
"@
  $json
  $newBPObject = $BPObject
  $newBPObject.psobject.members.remove("Status")
  $newBPObject.spec.resources.credential_definition_list = ($JSON1 | convertfrom-json).credential_definition_list

  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "PC_PASSWORD"}) | add-member noteproperty value $datavar.pepass
  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "INSTANCE_PASSWORD"}) | add-member noteproperty value $datavar.pepass


  $json = $newBPObject | convertto-json -depth 100
  $json = $json -replace '"---REPLACEME---"', $Keystring

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($BlueprintUUID)"

  if ($debug -eq 2){
    $json | out-file "C:\temp\Karbon3.json"
  }
  write-log -message "Updating Import with Creds for $BlueprintUUID"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $json -ContentType 'application/json' -headers $headers
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $json -ContentType 'application/json' -headers $headers
    Return $RespErr
  }

  Return $task
} 

Function REST-Import-Move-Blueprint {
  Param (
    [string] $BPfilepath,
    [object] $datagen,
    [object] $datavar,
    [string] $subnetUUID,
    [object] $image,
    [string] $ProjectUUID
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Loading Json"

  $jsonstring = get-content $BPfilepath

  write-log -message "Replacing JSON String Variables"

  $jsonstring = $jsonstring -replace "---IMAGEUUIDREF---", $($image.metadata.uuid)
  $jsonstring = $jsonstring -replace "---IMAGENAMEREF---", $($datagen.Move_ImageName)
  $jsonstring = $jsonstring -replace "---SUBNETREF---", $($subnetUUID)
  $jsonstring = $jsonstring -replace "---PROJECTREF---", $($ProjectUUID)
  $jsonstring = $jsonstring -replace "---MOVEVMNAME---", $($datagen.Move_VMName)
  $jsonstring = $jsonstring -replace "---MOVEVMIP---", $($datagen.MoveIP)

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/import_json"

  if ($debug -eq 2){
    $jsonstring | out-file "C:\temp\Move1.json"
  }

  write-log -message "Executing Import"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $jsonstring -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $jsonstring -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 



Function REST-Update-Move-Blueprint {
  Param (
    [object] $BPObject,
    [string] $BlueprintUUID,
    [object] $datagen,
    [object] $Keyobject,
    [object] $DomainObject,
    [object] $instancePWobject,
    [object] $PCPassObject,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Loading Json"

  $newBPObject = $BPObject
  $newBPObject.psobject.members.remove("Status")
  ($newBPObject.spec.resources.credential_definition_list | where {$_.name -eq "LOCAL"}).secret | add-member noteproperty value $datavar.pepass
  ($newBPObject.spec.resources.credential_definition_list | where {$_.name -eq "LOCAL"}).secret.attrs.is_secret_modified = 'true'
  ($newBPObject.spec.resources.credential_definition_list | where {$_.name -eq "move"}).secret | add-member noteproperty value $datavar.pepass
  ($newBPObject.spec.resources.credential_definition_list | where {$_.name -eq "move"}).secret.attrs.is_secret_modified = 'true'
  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "move_password"}) | add-member noteproperty value $datavar.pepass
  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "move_password"}).attrs.is_secret_modified = 'true'


  $json = $newBPObject | convertto-json -depth 100

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($BlueprintUUID)"

  if ($debug -eq 2){
    $json | out-file "C:\temp\Move2.json"
  }
  write-log -message "Updating Import with Creds for $BlueprintUUID"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $json -ContentType 'application/json' -headers $headers
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $json -ContentType 'application/json' -headers $headers
    Return $RespErr
  }

  Return $task
} 



Function REST-LCM-Install {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode,
    [object] $Updates
  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing LCM List Query"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/genesis"

  write-log -message "Using URL $URL"

  $Start= '{"value":"{\".oid\":\"LifeCycleManager\",\".method\":\"lcm_framework_rpc\",\".kwargs\":{\"method_class\":\"LcmFramework\",\"method\":\"perform_update\",\"args\":[\"http://download.nutanix.com/lcm/2.0\",['
  $End = ']]}}"}'
  
  foreach ($item in $updates){
    $update = "[\`"$($item.SoftwareUUID)\`",\`"$($item.version)\`"],"
    $start = $start + $update
  }
  $start = $start.Substring(0,$start.Length-1)
  $start = $start + $end
  [string]$json = $start
  write-log -message "Using URL $json"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }

  Return $task
}


Function REST-LCMV2-Query-Versions {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode,
    [bool] $silent = $false
  )
  if ($mode -eq "PC"){
    $class =  "PC"
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $class =  "PE"
    $clusterip = $datavar.PEClusterIP
  }  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  $URL = "https://$($clusterip):9440/api/nutanix/v3/groups"

$Payload= @"
{
  "entity_type": "lcm_entity_v2",
  "group_member_count": 500,
  "group_member_attributes": [{
    "attribute": "id"
  }, {
    "attribute": "uuid"
  }, {
    "attribute": "entity_model"
  }, {
    "attribute": "version"
  }, {
    "attribute": "location_id"
  }, {
    "attribute": "entity_class"
  }, {
    "attribute": "description"
  }, {
    "attribute": "last_updated_time_usecs"
  }, {
    "attribute": "request_version"
  }, {
    "attribute": "_master_cluster_uuid_"
  }, {
    "attribute": "entity_type"
  }, {
    "attribute": "single_group_uuid"
  }],
  "query_name": "lcm:EntityGroupModel",
  "grouping_attribute": "location_id",
  "filter_criteria": "entity_type==software;_master_cluster_uuid_==[no_val]"
}
"@ 

  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    if ($silent -eq $false){
      sleep 10
      $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
    }  
  }
  if ($debug -ge 2){
    write-log -message "We found $($task.group_results.entity_results.count) items."
  }
  Return $task
} 

Function REST-Diable-PCSearch-Tutorial {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

$Json = @"
{
  "type": "UI_CONFIG",
  "key": "hasViewedSearchTutorial",
  "value": true
}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/PrismGateway/services/rest/v1/application/user_data"

  write-log -message "Disabling Search Tutorial"
  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-LCMV2-Query-Updates {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode,
    [bool] $silent = $false
  )
  if ($mode -eq "PC"){
    $class =  "PC"
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $class =  "PE"
    $clusterip = $datavar.PEClusterIP
  }  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  $URL = "https://$($clusterip):9440/api/nutanix/v3/groups"


$Payload= @"
{
  "entity_type": "lcm_available_version_v2",
  "group_member_count": 500,
  "group_member_attributes": [{
    "attribute": "uuid"
  }, {
    "attribute": "entity_uuid"
  }, {
    "attribute": "entity_class"
  }, {
    "attribute": "status"
  }, {
    "attribute": "version"
  }, {
    "attribute": "dependencies"
  }, {
    "attribute": "single_group_uuid"
  }, {
    "attribute": "_master_cluster_uuid_"
  }, {
    "attribute": "order"
  }],
  "query_name": "lcm:VersionModel",
  "filter_criteria": "_master_cluster_uuid_==[no_val]"
}
"@ 

  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    if ($silent -eq $false){
      sleep 10
      $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
    }  
  }
  if ($debug -ge 2){
    write-log -message "We found $($task.group_results.entity_results.count) items."
  }

  Return $task
} 


Function REST-LCM-Query-Groups-Names {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode
  )
  if ($mode -eq "PC"){
    $class =  "PC"
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $class =  "PE"
    $clusterip = $datavar.PEClusterIP
  }  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing LCM List Query"

  $URL = "https://$($clusterip):9440/api/nutanix/v3/groups"

  write-log -message "Using URL $URL"

$Payload= @"
{
  "entity_type": "lcm_entity",
  "grouping_attribute": "entity_class",
  "group_member_count": 1000,
  "group_member_attributes": [{
    "attribute": "id"
  }, {
    "attribute": "uuid"
  }, {
    "attribute": "entity_model"
  }, {
    "attribute": "version"
  }, {
    "attribute": "location_id"
  }, {
    "attribute": "entity_class"
  }, {
    "attribute": "description"
  }, {
    "attribute": "last_updated_time_usecs"
  }, {
    "attribute": "request_version"
  }, {
    "attribute": "_master_cluster_uuid_"
  }],
  "query_name": "prism:LCMQueryModel",
  "filter_criteria": "_master_cluster_uuid_==[no_val]"
}
"@ 

  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }
  write-log -message "We found $($task.group_results.entity_results.count) items."

  Return $task
} 

Function REST-LCM-Query-Groups-Versions {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode
  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing LCM List Query"

  $URL = "https://$($clusterip):9440/api/nutanix/v3/groups"

  write-log -message "Using URL $URL"

$Payload= @"
{
  "entity_type": "lcm_available_version",
  "grouping_attribute": "entity_uuid",
  "group_member_count": 1000,
  "group_member_attributes": [
    {
      "attribute": "uuid"
    },
    {
      "attribute": "entity_uuid"
    },
    {
      "attribute": "entity_class"
    },
    {
      "attribute": "status"
    },
    {
      "attribute": "version"
    },
    {
      "attribute": "dependencies"
    },
    {
      "attribute": "order"
    }
  ]
}
"@ 

  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }
  write-log -message "We found $($task.group_results.entity_results.count) items."

  Return $task
} 

Function REST-Px-Get-Versions {
  Param (
    [object] $datavar,
    [object] $datagen,
    [string] $mode
  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
  $credPair = "$($datagen.buildaccount):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  write-log -message "Connecting to $clusterip"
  write-log -message "Mode is $mode"
  write-log -message "SE Name is $($datagen.sename)"
  
  $URL1 = "https://$($clusterip):9440/PrismGateway/services/rest/v1/cluster/version"

  try{
    $GetVersion = Invoke-RestMethod -Uri $URL1 -method "get" -headers $headers;
   
  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 10
    
    $GetVersion = Invoke-RestMethod -Uri $URL1 -method "get" -headers $headers;
   
  }
  Return $GetVersion
}

Function REST-Px-Update-NCC {
  Param (
    [object] $datavar,
    [object] $datagen,
    [string] $mode,
    [version] $target
  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
  $credPair = "$($datagen.buildaccount):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  write-log -message "Connecting to $clusterip"
  write-log -message "Mode is $mode"
  write-log -message "SE Name is $($datagen.sename)"
  
  $URL1 = "https://$($clusterip):9440/PrismGateway/services/rest/v1/cluster/version"
  $URL2 = "https://$($clusterip):9440/PrismGateway/services/rest/v1/genesis"
  $json = @"
{
    "value":"{\".oid\":\"ClusterManager\",\".method\":\"ncc_upgrade\",\".kwargs\":{\"ncc_version\":\"$($target)\"}}"
}
"@
  try{
    $GetNCCVersion = Invoke-RestMethod -Uri $URL1 -method "get" -headers $headers;
    if ($GetNCCVersion.nccVersion -eq $target){

      write-log -message "NCC is already running the latest version $($GetNCCVersion.nccVersion)"

    } else {

      $Upgrade = Invoke-RestMethod -Uri $URL2 -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
      write-log -message "NCC Upgrade started using payload $json"

    }

    

  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 10
    
    $GetNCCVersion = Invoke-RestMethod -Uri $URL1 -method "get" -headers $headers;
    if ($GetNCCVersion.nccVersion -eq $datagen.nccversion){

      write-log -message "NCC is already running the latest version $($GetNCCVersion.nccVersion)"

    } else {
      $Upgrade = Invoke-RestMethod -Uri $URL2 -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
      write-log -message "NCC Upgrade started using payload $json"
    }
  }
  Return $Upgrade

} 

Function REST-PC-Download-NCC {
  Param (
    [object] $datavar,
    [object] $datagen,
    [string] $mode
  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
  $credPair = "$($datagen.buildaccount):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  write-log -message "Connecting to $clusterip"
  write-log -message "Mode is $mode"
  write-log -message "SE Name is $($datagen.sename)"
  $URL1 = "https://$($clusterip):9440/PrismGateway/services/rest/v1/upgrade/ncc/softwares"
  

  try{

    $Payloads = Invoke-RestMethod -Uri $URL1 -method "get" -headers $headers;
    $payload = $payloads.entities | where {$_.version -eq $datagen.nccversion}

    write-log -message "Using Payload $JSON"
    if ($payload.status -eq "Available"){

      write-log -message "I am working here!"

      $payload.compatibleVersions = $null
      $payload.transferType = "Download"
      $payload.status = "QUEUED"
      $payload.psobject.members.remove("minNosVersion")
      $payload.psobject.members.remove("minPCVersion")
      $payload.url = $null
      $URL2 = "https://$($clusterip):9440/PrismGateway/services/rest/v1/upgrade/ncc/softwares/$($datagen.nccversion)/download"
      $JSON = $payload  | convertto-json -depth 100

      write-log -message "Using URL $URL2"

      $Download = Invoke-RestMethod -Uri $URL2 -method "post" -body $JSON -ContentType 'application/json' -headers $headers;

    } elseif ($payload.status -eq "COMPLETED"){
     
      write-log -message "Already done boss."


    } elseif ($payload.status -match "INPROG|queue"){

      write-log -message "Almost there!!"

    } else {
      if ($debug -ge 2){
        $payloads
      }
      $Payloads
      write-log -message "Who am i?"

    }

  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 5

    $Payloads = Invoke-RestMethod -Uri $URL1 -method "get" -headers $headers;
    $payload = $payloads.entities | where {$_.version -eq $datagen.nccversion}

    write-log -message "Using Payload $JSON"
    if ($payload.status -eq "Available"){

      write-log -message "I am working here!"

      $payload.compatibleVersions = $null
      $payload.transferType = "Download"
      $payload.status = "QUEUED"
      $payload.psobject.members.remove("minNosVersion")
      $payload.psobject.members.remove("minPCVersion")
      $payload.url = $null
      $URL2 = "https://$($clusterip):9440/PrismGateway/services/rest/v1/upgrade/ncc/softwares/$($datagen.nccversion)/download"
      $JSON = $payload  | convertto-json -depth 100
      $Download = Invoke-RestMethod -Uri $URL2 -method "post" -body $JSON -ContentType 'application/json' -headers $headers;

    } elseif ($payload.status -eq "COMPLETED"){
     
      write-log -message "Already done boss."

    } elseif ($payload.status -match "INPROG|queue"){

      write-log -message "Almost there!!"

    } else {
      if ($debug -ge 2){
        $payload.status
      }
      write-log -message "Who am i?"

    }

  }
  Return $payload
}

Function REST-LCM-Perform-Inventory {
  Param (
    [object] $datavar,
    [object] $datagen,
    [string] $mode
  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
  $credPair = "$($datagen.buildaccount):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  write-log -message "Connecting to $clusterip"
  write-log -message "Mode is $mode"
  write-log -message "SE Name is $($datagen.sename)"
  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/genesis"
  $json1 = @"
{
    "value":"{\".oid\":\"LifeCycleManager\",\".method\":\"lcm_framework_rpc\",\".kwargs\":{\"method_class\":\"LcmFramework\",\"method\":\"configure\",\"args\":[\"http://download.nutanix.com/lcm/2.0\",null,null,true]}}"
}
"@
  $json2 = @"
{
    "value":"{\".oid\":\"LifeCycleManager\",\".method\":\"lcm_framework_rpc\",\".kwargs\":{\"method_class\":\"LcmFramework\",\"method\":\"perform_inventory\",\"args\":[\"http://download.nutanix.com/lcm/2.0\"]}}"
}
"@
  try{
    $setAutoUpdate = Invoke-RestMethod -Uri $URL -method "post" -body $JSON1 -ContentType 'application/json' -headers $headers;
    $Inventory = Invoke-RestMethod -Uri $URL -method "post" -body $JSON2 -ContentType 'application/json' -headers $headers;
  
    write-log -message "AutoUpdated set and Inventory started"
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
    $setAutoUpdate = Invoke-RestMethod -Uri $URL -method "post" -body $JSON1 -ContentType 'application/json' -headers $headers;
    $Inventory = Invoke-RestMethod -Uri $URL -method "post" -body $JSON2 -ContentType 'application/json' -headers $headers;
  }
  Return $Inventory

} 

Function REST-LCM-Get-Version {
  Param (
    [object] $datavar,
    [object] $datagen,
    [string] $mode
  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
  $credPair = "$($datagen.buildaccount):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  write-log -message "Connecting to $clusterip"
  write-log -message "Mode is $mode"
  write-log -message "SE Name is $($datagen.sename)"
  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/genesis"
  $json1 = @"
{
  "value": "{\".oid\":\"LifeCycleManager\",\".method\":\"lcm_framework_rpc\",\".kwargs\":{\"method_class\":\"LcmFramework\",\"method\":\"get_config\"}}"
}
"@

  try{

    $GetConfig = Invoke-RestMethod -Uri $URL -method "post" -body $JSON1 -ContentType 'application/json' -headers $headers;

    write-log -message "Config Retrieved"

  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
    $GetConfig = Invoke-RestMethod -Uri $URL -method "post" -body $JSON1 -ContentType 'application/json' -headers $headers;

  }
  try {
    $trueresult = $GetConfig.value | convertfrom-json -ea:0
    Return $trueresult.".return"
  } catch {
    Return $result
  }
} 

Function REST-Task-List {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername
  )
  ## This is silent on purpose
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/tasks/list"
  $Payload= @{
    kind="task"
    offset=0
    length=999
  } 

  $JSON = $Payload | convertto-json
  try { 
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

  }
  Return $task
} 


Function REST-Add-DNS-Servers {
  Param (
    [object] $datagen,
    [object] $datavar,
    [array] $DNSArr,
    [string] $mode

  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
 
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Adding DNS Servers"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/cluster/name_servers/add_list"

  write-log -message "Using URL $URL"

  $json = $DNSArr | convertto-json

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-Remove-DNS-Servers {
  Param (
    [object] $datagen,
    [object] $datavar,
    [array] $DNSArr,
    [string] $mode

  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
 
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Removing DNS Servers"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/cluster/name_servers/remove_list"

  write-log -message "Using URL $URL"
  if ($DNSArr.count -eq 1){
    $json = '["'+$DNSArr+'"]'
  } else {
    $json = $DNSArr | convertto-json
  }

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 


Function REST-Get-DNS-Servers {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode

  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
 
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing DNS List Query"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/cluster/name_servers"

  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }

  Return $task
}



Function REST-Query-ADGroup {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $uuid
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building UserGroup Query JSON"

  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/user_groups/$($uuid)"

  try {
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

  }

  Return $task
} 

Function REST-Query-Subnet {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $networkname
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building Subnet Query JSON"

  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/subnets/list"
  $Payload= @{
    kind="subnet"
    offset=0
    length=999
  } 

  $JSON = $Payload | convertto-json

  try {
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;  
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
    
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

  }
  if ($task.entities.count -eq 0){

    write-log -message "0? Let me try that again after a small nap."

    do {
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
      sleep 30
      $count++

      write-log -message "Cycle $count Getting Subnets, current items found is $($task.entities.count)"
    } until ($count -ge 10 -or $task.entities.count -ge 1)
  }
  write-log -message "We found $($task.entities.count) items."
  $result = $task.entities | where {$_.spec.name -eq $networkname}
  Return $result
} 

Function REST-Create-UserGroup {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $customer,
    [string] $domainname,
    [string] $grouptype
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $domainparts = $domainname.split(".")
  write-log -message "Building UserGroup Create JSON"

  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/user_groups"
  $json = @"
{
  "spec": {
    "resources": {
      "directory_service_user_group": {
        "distinguished_name":"cn=$($customer)-$($grouptype),ou=groups,ou=$($customer),ou=customers,DC=$($($DomainParts)[0]),DC=$($($DomainParts)[1]),DC=$($($DomainParts)[2])"
      }
    }
  },
  "api_version": "3.1.0",
  "metadata": {
    "kind": "user_group",
    "categories": {},
    "name": "$($customer)-$($grouptype)"
  }
}
"@
  try {
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  }catch{

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  }
  Return $task
} 

Function REST-Create-AdninGroup {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $customer,
    [string] $domainname,
    [string] $grouptype
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $domainparts = $domainname.split(".")
  write-log -message "Building UserGroup Create JSON"
  write-log -message "Using DN CN=Domain Admins,CN=Users,DC=$($($DomainParts)[0]),DC=$($($DomainParts)[1]),DC=$($($DomainParts)[2])"

  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/user_groups"
  $json = @"
{
  "spec": {
    "resources": {
      "directory_service_user_group": {
        "distinguished_name":"CN=Domain Admins,CN=Users,DC=$($($DomainParts)[0]),DC=$($($DomainParts)[1]),DC=$($($DomainParts)[2])"
      }
    }
  },
  "api_version": "3.1.0",
  "metadata": {
    "kind": "user_group",
    "categories": {},
    "name": "Default-$($grouptype)"
  }
}
"@
  try {
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  }catch{

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  }
  Return $task
} 


Function REST-Query-Cluster {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $targetIP
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building Cluster Query JSON"

  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/clusters/list"
  $Payload= @{
    kind="cluster"
    offset=0
    length=999
  } 

  $JSON = $Payload | convertto-json
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }
  if ($task.entities.count -eq 0){

    write-log -message "0? Let me try that again after a small nap."

    do {
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
      sleep 30
      $count++

      write-log -message "Cycle $count Getting Clusters, current items found is $($task.entities.count)"
    } until ($count -ge 10 -or $task.entities.count -ge 1)
  }
  write-log -message "We found $($task.entities.count) clusters, filtering."

  #$filter = $task.entities | where {$_.spec.resources.network.external_ip -eq $targetIP -or $_.spec.resources.network.external_ip }
  Return $task
} 

Function REST-Query-DetailCluster {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $uuid
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building Cluster Query JSON"

  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/clusters/$($uuid)"
  try {
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }  
  Return $task
} 




Function REST-GET-PC-Install-State {
  Param (
    [object] $datavar,
    [object] $datagen
  )

  $credPair = "$($datagen.buildaccount):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Checking PC install Status"

  $URL = "https://$($datavar.PEClusterIP):9440/PrismGateway/services/rest/v1/multicluster/cluster_external_state"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;

  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }
  If ($task.clusterDetails.multicluster -eq $true){

    Return $true

  } else {

    Return $false

  }
} 


Function REST-Px-SMTP-Setup {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode
  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
  $credPair = "$($datagen.SEUPN):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing SMTP Setup"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/alerts/configuration"

  write-log -message "Using URL $URL"

$Payload= @"
{
  "emailContactList": ["$($datavar.SenderEMail)"],
  "enable": false,
  "enableDefaultNutanixEmail": false,
  "enableEmailDigest": true,
  "skipEmptyAlertEmailDigest": true,
  "defaultNutanixEmail": "nos-alerts@nutanix.com",
  "smtpServer": {
    "address": "$($datagen.smtpServer)",
    "port": $($datagen.smtpport),
    "username": null,
    "password": null,
    "secureMode": "NONE",
    "fromEmailAddress": "$($datagen.smtpsender)",
    "emailStatus": {
      "status": "UNKNOWN",
      "message": null
    }
  },
  "tunnelDetails": {
    "httpProxy": null,
    "serviceCenter": null,
    "connectionStatus": {
      "lastCheckedTimeStampUsecs": 0,
      "status": "DISABLED",
      "message": {
        "message": ""
      }
    },
    "transportStatus": {
      "status": "UNKNOWN",
      "message": null
    }
  },
  "emailConfigRules": null,
  "emailTemplate": {
    "subjectPrefix": null,
    "bodySuffix": null
  }
}
"@ 

  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $JSON -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-PE-Get-Hosts {
  Param (
    [object] $datagen,
    [object] $datavar
  )
  $clusterip = $datavar.PEClusterIP
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing Get Hosts Query"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/hosts"

  write-log -message "Using URL $URL"


  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }

  Return $task
} 

Function REST-Px-Run-Full-NCC {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode
  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
  $credPair = "$($datagen.SEUPN):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing NCC on $mode"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/ncc/checks"

  write-log -message "Using URL $URL"
  $Payload= @"
{
  "sendEmail":false
}
"@ 
  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 


Function REST-Px-Query-Alerts {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode,
    [string] $prejoin = $false
  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }
  if ($prejoin -eq $true){ 
    $credPair = "$($datavar.peadmin):$($datavar.PEPass)"
  } else {
    $credPair = "$($datagen.SEUPN):$($datavar.PEPass)"
  }
  
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing Alert Query"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/groups"

  write-log -message "Using URL $URL"

$Payload= @"
{
  "entity_type": "alert",
  "query_name": "eb:data-$([int](Get-Date -UFormat %s -Millisecond 0))",
  "grouping_attribute": "",
  "group_count": 3,
  "group_offset": 0,
  "group_attributes": [],
  "group_member_count": 50,
  "group_member_offset": 0,
  "group_member_attributes": [{
    "attribute": "alert_title"
  }, {
    "attribute": "affected_entities"
  }, {
    "attribute": "impact_type"
  }, {
    "attribute": "severity"
  }, {
    "attribute": "resolved"
  }, {
    "attribute": "acknowledged"
  }, {
    "attribute": "created_time_stamp"
  }, {
    "attribute": "clusterName"
  }, {
    "attribute": "auto_resolved"
  }],
  "filter_criteria": "resolved==false"
}
"@ 

  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-Px-Resolve-Alerts {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode,
    [array] $uuids
  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing Alert Purge"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/alerts/resolve_list"

  write-log -message "Using URL $URL"

  $JSON = [array]$Uuids | convertto-json
  if ($uuids.count -eq 1){
    $json = "[ " + $json + " ]"
  } 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 




Function REST-Query-Projects {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername
  )

  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing Project List Query"

  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/projects/list"
  $Payload= @{
    kind="project"
    offset=0
    length=999
  } 

  $JSON = $Payload | convertto-json
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }
  write-log -message "We found $($task.entities.count) items."

  Return $task
} 


Function REST-Query-Calm-Apps {
  Param (
    [object] $datavar,
    [object] $datagen
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($datagen.buildaccount):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Query Calm Apps"

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/apps/list"

  write-log -message "Using URL $URL"
  write-log -message "Using IP $($datagen.PCClusterIP)"

  $Payload= @{
    kind="app"
    offset=0
    length=250
  } 

  $JSON = $Payload | convertto-json
  write-host  $JSON
  try {
    $task = Invoke-RestMethod -Uri $URL -method "POST" -Body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "POST" -Body $JSON -ContentType 'application/json' -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }  
  Return $task
} 

Function REST-Query-Calm-BluePrints {
  Param (
    [object] $datavar,
    [object] $datagen
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($datagen.buildaccount):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Query Calm BluePrints"

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/list"

  write-log -message "Using URL $URL"
  write-log -message "Using IP $($datagen.PCClusterIP)"

  $Payload= @{
    kind="blueprint"
    offset=0
    length=250
  } 

  $JSON = $Payload | convertto-json
  write-host  $JSON
  try {
    $task = Invoke-RestMethod -Uri $URL -method "POST" -Body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "POST" -Body $JSON -ContentType 'application/json' -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }  
  Return $task
} 

Function REST-Get-AuthConfig {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode

  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Retrieving AuthConfig"


  $URL   = "https://$($clusterip):9440/PrismGateway/services/rest/v1/authconfig"

  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }

  Return $task
} 

Function REST-Get-Objects-AD {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $URL = "https://$($datagen.PCClusterIP):9440/oss/iam_proxy/directory_services"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }

  Return $task
}

Function REST-Reset-Px-Password {
  Param (
    [string] $oldPassword,
    [string] $NewPassword,
    [string] $Cluster,
    [string] $username
  )

  $credPair = "$($datagen.PEadmin):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $netbios = $datagen.Domainname.split(".")[0];
$Json = @"
{
  "oldPassword": "$($oldPassword)",
  "newPassword": "$($datavar.pepass)"
}
"@ 
  $URL = "https://$($datavar.PEClusterIP):9440/PrismGateway/services/rest/v1/utils/change_default_system_password"

  write-log -message "Query Object Services"
  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-Add-AuthConfig {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode

  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
  $netbios = $datagen.Domainname.split(".")[0];
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Configuring AuthConfig"

  $json = @"
{
  "name": "$netbios",
  "domain": "$($datagen.Domainname)",
  "directoryUrl": "ldap://$($datagen.DC1Name).$($datagen.domainname):3268",
  "groupSearchType": "RECURSIVE",
  "directoryType": "ACTIVE_DIRECTORY",
  "connectionType": "LDAP",
  "serviceAccountUsername": "$($netbios)\\administrator",
  "serviceAccountPassword": "$($datagen.SysprepPassword)"
}
"@
  
  $URL   = "https://$($clusterip):9440/PrismGateway/services/rest/v1/authconfig/directories"

  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    write $json
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $JSON -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-Remove-AuthConfig {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode,
    [string] $name

  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
  $netbios = $datagen.Domainname.split(".")[0];
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Removing AuthConfig $name"

  
  $URL   = "https://$($clusterip):9440/PrismGateway/services/rest/v1/authconfig/directories/$name"

  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "DELETE"  -headers $headers;
  } catch {
    sleep 10
    write $json
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "DELETE"  -headers $headers;
  }

  Return $task
} 


Function REST-Add-RoleMapping {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode

  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
  $netbios = $datagen.Domainname.split(".")[0];
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Configuring AuthConfig"

  $json = @"
{
  "directoryName": "$netbios",
  "role": "ROLE_CLUSTER_ADMIN",
  "entityType": "GROUP",
  "entityValues": ["Domain Admins"]
}
"@

  $URL   = "https://$($clusterip):9440/PrismGateway/services/rest/v1/authconfig/directories/$($netbios)/role_mappings?&entityType=GROUP&role=ROLE_CLUSTER_ADMIN"

  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $JSON -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-Get-RoleMapping {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode

  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  
  $netbios = $datagen.Domainname.split(".")[0];
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Getting RoleMapptings for $netbios"


  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/authconfig/directories/$($netbios)/role_mappings"

  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }

  Return $task
} 


Function REST-ADD-NTP {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $NTP,
    [string] $mode

  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Adding NTP server $NTP"
  $Body = '["'+$NTP+'"]' 

  $URL    = "https://$($clusterip):9440/PrismGateway/services/rest/v1/cluster/ntp_servers/add_list"

  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $Body -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $Body -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-Remove-NTP {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $NTP,
    [string] $mode

  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Removing NTP server $NTP"
  $Body = '["'+$NTP+'"]' 

  $URL    = "https://$($clusterip):9440/PrismGateway/services/rest/v1/cluster/ntp_servers/remove_list"

  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $Body -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $Body -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 


Function REST-List-NTP {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode

  )
  if ($mode -eq "PC"){
    $clusterIP = $datagen.PCClusterIP
  }  else {
    $clusterip = $datavar.PEClusterIP
  }  

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Retrieving NTP servers"

  $URL   = "https://$($clusterip):9440/PrismGateway/services/rest/v1/cluster/ntp_servers"

  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }

  Return $task
} 




Function REST-Add-DataStore {
  Param (
    [string] $PEClusterIP,
    [string] $clpassword,
    [string] $clusername,
    [object] $hosts,
    [String] $containername
  )

  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing DataStore Create for $($hosts.entities.count) nodes"

  $URL = "https://$($PEClusterIP):9440/PrismGateway/services/rest/v1/containers/datastores/add_datastore"
  $Payload= @"
{
  "containerName": "$($containername)",
  "datastoreName": "",
  "nodeIds": [],
  "readOnly": false
}
"@ 
  $object = convertfrom-json $Payload
  Foreach ($node in $hosts.entities){
    $object.nodeids += $node.serviceVMid
  }
  
  $Payload = $object | convertto-json -depth 100
  if ($debug -ge 2){
    $Payload
  }
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Payload -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Payload -ContentType 'application/json' -headers $headers;
  }
  

  Return $task
} 

Function REST-Get-VMs {
  Param (
    [string] $PEClusterIP,
    [string] $clpassword,
    [string] $clusername
  )

  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing VM List"

  $URL = "https://$($PEClusterIP):9440/PrismGateway/services/rest/v1/vms"
 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }
  write-log -message "We found $($task.entities.count) items."

  Return $task
} 

Function REST-Query-Role-List {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $rolename
  )

  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing Role UUID list"

  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/roles/list"
    $Payload= @{
    kind="role"
    offset=0
    length=999
  } 

  $JSON = $Payload | convertto-json
  try {
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }
  write-log -message "We found $($task.entities.count) items, filtering."

  $result = $task.entities | where {$_.spec.name -eq $rolename}
  Return $result
} 

Function REST-Query-Role-Object {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $RoleUUID
  )

  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Getting Role for $RoleUUID"

  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/roles/$($RoleUUID)"
  try{
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers;
  }

  Return $task
} 

Function REST-Create-Role-Object {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $roleName,
    [object] $consumerroleObject,
    [string] $projectUUID,
    [string] $projectName
  )

  write-log -message "This function is not used yet."

  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Creating Duplicate $rolename Role"
  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/roles"
$json = @"
{
  "spec": {
    "name": "$($roleName) V2",
    "resources": {
      "permission_reference_list": 
      $($consumerroleObject.spec.resources.permission_reference_list |ConvertTo-Json)
    },
    "description": "$($consumerroleObject.spec.description)"
  },
  "api_version": "3.1.0",
  "metadata": {
    "spec_version": 0,
    "kind": "role",
    "project_reference": {
      "kind": "project",
      "name": "$($projectName)",
      "uuid": "$($projectUUID)"
    }
  }
}
"@
  try {
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }
  

  Return $result
} 

Function REST-Query-Images {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $silent =0
  )

  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  if ($silent -ne 1){

    write-log -message "Executing Images List Query"

  }
  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/images/list"
  $Payload= @{
    kind="image"
    offset=0
    length=999
  } 

  $JSON = $Payload | convertto-json
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }
  if ($task.entities.count -eq 0){

    if ($silent -ne 1){
      write-log -message "0? Let me try that again after a small nap."
 
      do {
        $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
        sleep 30
        $count++
        if ($silent -ne 1){
          write-log -message "Cycle $count Getting Images types, current items found is $($task.entities.count)"
        }
      } until ($count -ge 10 -or $task.entities.count -ge 1)
    }
  }
  if ($silent -ne 1){
    write-log -message "We found $($task.entities.count) items."
  }
  Return $task
} 


Function REST-Mount-CDRom-Image {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $VMuuid,
    [object] $cdrom,
    [object] $Image
  )

  $clusterip = $datavar.PEClusterIP  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Mounting CD for VM with ID $VMuuid"
  write-log -message "Using ISO $($Image.Name)"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v2.0/vms/$($VMuuid)/disks/update"

  write-log -message "Using URL $URL"

$Payload= @"
{
  "vm_disks": [{
    "disk_address": {
      "vmdisk_uuid": "$($cdrom.disk_address.vmdisk_uuid)",
      "device_index": $($cdrom.disk_address.device_index),
      "device_bus": "$($cdrom.disk_address.device_bus)"
    },
    "flash_mode_enabled": false,
    "is_cdrom": true,
    "is_empty": false,
    "vm_disk_clone": {
      "disk_address": {
        "vmdisk_uuid": "$($Image.vmDiskId)"
      },
      "minimum_size": "$($Image.vmDiskSize)"
    }
  }]
}
"@
  if ($debug -ge 2){
    $Payload
  }
  try{
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $Payload -ContentType 'application/json' -headers $headers;

    write-log -message "CDROM mounted" 

  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $Payload -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 



Function REST-Create-Alert-Policy {
  Param (
    [object] $datagen,
    [object] $group,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Replacing JSON String Variables"
$Json = @"
{
  "auto_resolve": true,
  "created_by": "admin",
  "description": "API Generated for XPlay Demo",
  "enabled": true,
  "error_on_conflict": true,
  "filter": "entity_type==vm;(group_entity_type==abac_category;group_entity_id==$($group.entity_id))",
  "impact_types": [
    "Performance"
  ],
  "last_updated_timestamp_in_usecs": 0,
  "policies_to_override": null,
  "related_policies": null,
  "title": "AppFamily:DevOps - VM CPU Usage",
  "trigger_conditions": [
    {
      "condition": "vm.hypervisor_cpu_usage_ppm=gt=400000",
      "condition_type": "STATIC_THRESHOLD",
      "severity_level": "CRITICAL"
    }
  ],
  "trigger_wait_period_in_secs": 0
}
"@ 

  $URL = "https://$($datagen.PCClusterIP):9440/PrismGateway/services/rest/v2.0/alerts/policies"

  if ($debug -eq 2){
    $Json | out-file "C:\temp\Alert.json"
  }

  write-log -message "Executing Import"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 


Function REST-Query-Groups {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing Images List Query"

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/groups"
$Payload= @"
{
  "entity_type": "category",
  "query_name": "eb:data:General-1551028671919",
  "grouping_attribute": "abac_category_key",
  "group_sort_attribute": "name",
  "group_sort_order": "ASCENDING",
  "group_count": 20,
  "group_offset": 0,
  "group_attributes": [{
    "attribute": "name",
    "ancestor_entity_type": "abac_category_key"
  }, {
    "attribute": "immutable",
    "ancestor_entity_type": "abac_category_key"
  }, {
    "attribute": "cardinality",
    "ancestor_entity_type": "abac_category_key"
  }, {
    "attribute": "description",
    "ancestor_entity_type": "abac_category_key"
  }, {
    "attribute": "total_policy_counts",
    "ancestor_entity_type": "abac_category_key"
  }, {
    "attribute": "total_entity_counts",
    "ancestor_entity_type": "abac_category_key"
  }],
  "group_member_count": 5,
  "group_member_offset": 0,
  "group_member_sort_attribute": "value",
  "group_member_sort_order": "ASCENDING",
  "group_member_attributes": [{
    "attribute": "name"
  }, {
    "attribute": "value"
  }, {
    "attribute": "entity_counts"
  }, {
    "attribute": "policy_counts"
  }, {
    "attribute": "immutable"
  }]
}
"@ 

  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }
  write-log -message "We found $($task.group_results.entity_results.count) items."

  Return $task
} 






Function REST-XPlay-Query-PlayBooks {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername
  )

  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing ActionTypes Query"

  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/action_rules/list"
  $Payload= @{
    kind="action_rule"
    offset=0
    length=999
  } 

  $JSON = $Payload | convertto-json
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }
  write-log -message "We found $($task.entities.count) items."
  if ($task.entities.count -eq 0){

    write-log -message "0? Let me try that again after a small nap."

    do {
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
      sleep 30
      $count++

      write-log -message "Cycle $count Getting action types, current items found is $($task.entities.count)"
    } until ($count -ge 10 -or $task.entities.count -ge 1)
  }
  Return $task
} 

Function REST-XPlay-Query-ActionTypes {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername
  )

  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing ActionTypes Query"

  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/action_types/list"
  $Payload= @{
    kind="action_type"
    offset=0
    length=999
  } 

  $JSON = $Payload | convertto-json
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }
  write-log -message "We found $($task.entities.count) items."
  if ($task.entities.count -eq 0){

    write-log -message "0? Let me try that again after a small nap."

    do {
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
      sleep 30
      $count++

      write-log -message "Cycle $count Getting action types, current items found is $($task.entities.count)"
    } until ($count -ge 10 -or $task.entities.count -ge 1)
  }
  Return $task
} 

Function REST-Query-DetailPlaybook {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $uuid
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building Playbook Query JSON"

  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/action_rules/$($uuid)"
  try {
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }  
  Return $task
} 

Function REST-Query-DetailAlertPolicy {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $uuid
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building Alert Query JSON"

  $URL = "https://$($ClusterPC_IP):9440/PrismGateway/services/rest/v2.0/alerts/policies/$($uuid)"
  try {
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }  
  Return $task
} 


Function REST-XPlay-Create-Playbook {
  Param (
    [object] $datagen,
    [object] $AlertTriggerObject,
    [object] $AlertActiontypeObject,
    [object] $AlertTypeObject,
    [object] $BluePrintObject,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  $alertActiontype = $AlertActiontypeObject.entities | where {$_.status.resources.display_name -eq "REST API"}
  $BPAppID = $(($BluePrintObject.spec.resources.app_profile_list | where {$_.name -eq "IIS"}).uuid)
  write-log -message "Replacing JSON String Variables"
  write-log -message "Using Action Type $($alertActiontype.metadata.uuid)"
  write-log -message "Using Alert Trigger $($AlertTriggerObject.entity_id)"
  write-log -message "Using Alert Type A$($AlertTypeObject.group_results.entity_results.entity_id)"
  write-log -message "Using Blueprint $($BluePrintObject.metadata.uuid)"
  write-log -message "Using BP App $($BPAppID)"

######## THE A IN ALERT TRIGGER TYPE NEEDS TO BE THERE
$Json = @"
{
  "api_version": "3.1",
  "metadata": {
    "kind": "action_rule",
    "spec_version": 0
  },
  "spec": {
    "resources": {
      "name": "IIS Xplay Demo",
      "description": "IIS Xplay Demo",
      "is_enabled": true,
      "should_validate": true,
      "trigger_list": [
        {
          "action_trigger_type_reference": {
            "kind": "action_trigger_type",
            "uuid": "$($AlertTriggerObject.entity_id)",
            "name": "alert_trigger"
          },
          "input_parameter_values": {
            "alert_uid": "A$($AlertTypeObject.group_results.entity_results.entity_id)",
            "severity": "[\"critical\"]",
            "source_entity_info_list": "[]"
          }
        }
      ],
      "execution_user_reference": {
        "kind": "user",
        "name": "admin",
        "uuid": "00000000-0000-0000-0000-000000000000"
      },
      "action_list": [
        {
          "action_type_reference": {
            "kind": "action_type",
            "uuid": "$($alertActiontype.metadata.uuid)",
            "name": "rest_api_action"
          },
          "display_name": "",
          "input_parameter_values": {
            "username":  "$($datagen.buildaccount)",
            "request_body":  "{\n \"spec\": {\n   \"app_profile_reference\": {\n     \"kind\": \"app_profile\",\n     \"name\": \"IIS\",\n     \"uuid\": \"$($BPAppID)\"\n   },\n   \"runtime_editables\": {\n     \"action_list\": [\n       {\n       }\n     ],\n     \"service_list\": [\n       {\n       }\n     ],\n     \"credential_list\": [\n       {\n       }\n     ],\n     \"substrate_list\": [\n       {\n       }\n     ],\n     \"package_list\": [\n       {\n       }\n     ],\n     \"app_profile\": {\n     },\n     \"task_list\": [\n       {\n       }\n     ],\n     \"variable_list\": [\n       {\n       }\n     ],\n     \"deployment_list\": [\n       {\n       }\n     ]\n   },\n   \"app_name\": \"IIS-{{trigger[0].source_entity_info.uuid}}\"\n }\n}",
            "url":  "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($BluePrintObject.metadata.uuid)/simple_launch",
            "headers":  "Content-Type: application/json",
            "password":  "$($datavar.PEPass)",
            "method":  "POST"
          },
          "should_continue_on_failure": false,
          "max_retries": 0
        }
      ]
    }
  }
}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/action_rules"
  if ($debug -ge 2){
    $Json | out-file c:\temp\bplaunch.json
  }

  write-log -message "Executing Playbook Create for alert "
  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;

    write-log -message "Nutanix is the best..."

  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 


Function REST-XPlay-Query-AlertTriggerType {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Replacing JSON String Variables"
$Json = @"
{
  "entity_type": "trigger_type",
  "group_member_attributes": [
    {
      "attribute": "name"
    },
    {
      "attribute": "display_name"
    }
  ],
  "group_member_count": 20
}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/groups"
  if ($debug -ge 2){
    $Json | out-file c:\temp\bplaunch.json
  }

  write-log -message "Executing Alert Type Query"
  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  }
  if ($task.total_group_count -eq 0){

    write-log -message "0? Let me try that again after a small nap."
    $count = 0
    do {
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
      sleep 30
      $count++

      write-log -message "Cycle $count Getting Alert trigger types, current items found is $($task.total_group_count)"
    } until ($count -ge 10 -or $task.total_group_count -ge 1)
  }
  Return $task
} 

Function REST-XPlay-Query-AlertUUID {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building Alert UUID JSON"
$Json = @"
{
  "entity_type": "alert_check_schema",
  "group_member_attributes": [
    {
      "attribute": "alert_title"
    },
    {
      "attribute": "_modified_timestamp_usecs_"
    },
    {
      "attribute": "alert_uid"
    }
  ],
  "group_member_sort_attribute": "_modified_timestamp_usecs_",
  "group_member_sort_order": "DESCENDING",
  "group_member_count": 100,
  "filter_criteria": "alert_title==AppFamily:DevOps - VM CPU Usage;alert_uid!=[no_val]"
}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/groups"

  write-log -message "Executing Alert UUID Query"
  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 









Export-ModuleMember *

