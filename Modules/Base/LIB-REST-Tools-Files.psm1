
Function REST-Add-FileServerDomain {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $vfiler
  )
  $clusterip = $datavar.PEClusterIP  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $netbios = $datagen.domainname.split(".")[0]
  $user = $datagen.seupn.split("@")[0]
  write-log -message "Adding FileServer to Domain $($datagen.domainname)"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/vfilers/$($vfiler.entities.uuid)/configureNameServices/"

  write-log -message "Using URL $URL"

$Payload= @"
{
  "ldapDetails": null,
  "adDetails": {
    "windowsAdDomainName": "$($datagen.domainname)",
    "windowsAdUsername": "administrator",
    "windowsAdPassword": "$($datavar.pepass)",
    "addUserAsFsAdmin": true,
    "organizationalUnit": "",
    "preferredDomainController": "",
    "overwriteUserAccount": true,
    "rfc2307Enabled": false,
    "useSameCredentialsForDns": true,
    "protocolType": "1"
  },
  "localDetails": null,
  "nvmOnly": false,
  "fileServerUuid": null,
  "nfsv4Domain": null,
  "nfsVersion": "NFSV3V4"
}
"@ 
  if ($debug -ge 2){
    $Payload | out-file c:\temp\addFSdomain.json
  }
  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;

    write-log -message "Add FS to Domain done"

  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;

    write-log -message "Add FS to domain done"
  }
  
  Return $task
} 



Function REST-Delete-FileAnalyticsDownload {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $Anaversion
  )
  $clusterip = $datavar.PEClusterIP  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $netbios = $datagen.domainname.split(".")[0]
  $user = $datagen.seupn.split("@")[0]

  write-log -message "Adding Fileserver Shares"

  $prefix = Convert-IpAddressToMaskLength $datavar.infrasubnetmask
  $ipconfig = "$($datavar.InfraGateway)/$($prefix)"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/upgrade/file_analytics/softwares/$($Anaversion)"

  write-log -message "Using URL $URL"


  try{

    write-log -message "Deleting Analytics Download"
      
    $task = Invoke-RestMethod -Uri $URL -method "DELETE"  -headers $headers;
    sleep 40


  } catch {

    write-log -message "Deleting Analytics Download"

    $task = Invoke-RestMethod -Uri $URL -method "post" -headers $headers;
    sleep 40

  }
  return $task
}

Function REST-Add-FileServerShare-Karbon {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $vfiler
  )
  $clusterip = $datavar.PEClusterIP  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $netbios = $datagen.domainname.split(".")[0]
  $user = $datagen.seupn.split("@")[0]

  write-log -message "Adding Fileserver Shares"

  $prefix = Convert-IpAddressToMaskLength $datavar.infrasubnetmask
  $ipconfig = "$($datavar.InfraGateway)/$($prefix)"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/vfilers/$($vfiler.entities.uuid)/shares/?force=true"

  write-log -message "Using URL $URL"

$Share= @"
{
  "name": "K8s",
  "fileServerUuid": "$($vfiler.entities.uuid)",
  "enablePreviousVersion": false,
  "windowsAdDomainName": "$($datagen.domainname)",
  "description": "",
  "maxSizeGiB": 500,
  "protocolType": "NFS",
  "secondaryProtocolType": "NONE",
  "sharePath": "",
  "isNestedShare": false,
  "authenticationType": "SYSTEM",
  "defaultShareAccessType": "NONE",
  "anonymousUid": "1024",
  "anonymousGid": "1024",
  "squashType": "ALL_SQUASH",
  "clientReadWrite": "$($ipconfig)",
  "clientReadOnly": "",
  "clientNoAccess": "",
  "shareType": "GENERAL"
}
"@

  try{

    write-log -message "Creating Karbon NFS Share"
      
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Share -ContentType 'application/json' -headers $headers;
    sleep 40


  } catch {

    write-log -message "Karbon NFS Share Userhome again"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Share -ContentType 'application/json' -headers $headers;
    sleep 40

  }

    
  write-log -message "All Shares Created"


  Return $task
} 


Function REST-Add-FileServerAdmin {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $vfiler
  )
  $clusterip = $datavar.PEClusterIP  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $netbios = $datagen.domainname.split(".")[0]
  $user = $datagen.seupn.split("@")[0]
  write-log -message "Adding Fileserver admins"
  write-log -message "Adding $($user)"
  write-log -message "From Netbios $($netbios)"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/vfilers/$($vfiler.entities.uuid)/admin_users/"

  write-log -message "Using URL $URL"

$Payload= @"
{
  "uuid": "",
  "fileServerUuid": "$($vfiler.entities.uuid)",
  "user": "$($user)",
  "role": "ADMIN"
}
"@ 
  if ($debug -ge 2){
    $Payload | out-file c:\temp\addFSUser.json
  }
  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;

    write-log -message "FS admins added"

  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;

    write-log -message "FS admins added"
  }
  
  Return $task
} 

Function REST-Create-FileServer {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $network,
    [string] $filesversion,
    [string] $nodecount
  )
  $clusterip = $datavar.PEClusterIP  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Creating the fileserver with $nodecount node(s)"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/vfilers/"

  write-log -message "Using URL $URL"

$Payload= @"
{
  "name": "$($Datagen.FS1_IntName)",
  "numCalculatedNvms": "$nodecount",
  "numVcpus": "4",
  "memoryGiB": "12",
  "internalNetwork": {
    "subnetMask": "$($datavar.InfraSubnetmask)",
    "defaultGateway": "$($datavar.InfraGateway)",
    "uuid": "$($network.uuid)",
    "pool": ["$($($datagen.FS1IntRange).split(' ')[0]) $($($datagen.FS1IntRange).split(' ')[1])"]
  },
  "externalNetworks": [{
    "subnetMask": "$($datavar.InfraSubnetmask)",
    "defaultGateway": "$($datavar.InfraGateway)",
    "uuid": "$($network.uuid)",
    "pool": ["$($datagen.FS1ExtRange)"]
  }],
  "windowsAdDomainName": "PHX-POC091.nutanix.local",
  "windowsAdUsername": "administrator",
  "windowsAdPassword": "$($datagen.SysprepPassword)",
  "dnsServerIpAddresses": ["$($datagen.DC1IP)", "$($datagen.DC2IP)"],
  "ntpServers": ["$($datagen.NTPServer1)", "$($datagen.NTPServer2)", "$($datagen.NTPServer3)", "$($datagen.NTPServer4)"],
  "sizeGib": "5120",
  "version": "$($filesversion)",
  "dnsDomainName": "$($datagen.Domainname)",
  "nameServicesDTO": {
    "adDetails": {
      "windowsAdDomainName": "$($datagen.Domainname)",
      "windowsAdUsername": "administrator",
      "windowsAdPassword": "$($datagen.SysprepPassword)",
      "addUserAsFsAdmin": true,
      "organizationalUnit": "",
      "preferredDomainController": "$($datagen.DC1Name).$($datagen.Domainname)",
      "overwriteUserAccount": true,
      "rfc2307Enabled": true,
      "useSameCredentialsForDns": true,
      "protocolType": "3"
    },
    "nfsv4Domain": ""
  },
  "addUserAsFsAdmin": true,
  "organizationalUnit": "",
  "preferredDomainController": "$($datagen.DC1Name).$($datagen.Domainname)",
  "fsDnsOperationsDTO": {
    "dnsOpType": "MS_DNS",
    "dnsServer": "",
    "dnsUserName": "administrator",
    "dnsPassword": "$($datagen.SysprepPassword)"
  },
  "pdName": "NTNX-$($datagen.FS1_IntName)"
}
"@ 
  if ($debug -ge 2){
    $Payload | out-file c:\temp\createFS.json
  }
  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;

    write-log -message "File Server install Started" 

  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }
 

  Return $task
} 

Function REST-Query-FileServer {
  Param (
    [object] $datagen,
    [object] $datavar

  )
  $clusterip = $datavar.PEClusterIP  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building UserGroup Query JSON"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/vfilers"

  try {
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

  }

  Return $task
} 

Function REST-Query-Fileanalytics {
  Param (
    [object] $datagen,
    [object] $datavar

  )
  $clusterip = $datavar.PEClusterIP  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building Query JSON"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v2.0/analyticsplatform"

  try {
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

  }

  Return $task
} 

Function REST-Add-FileServerShares {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $vfiler,
    [string] $nodecount
  )
  $clusterip = $datavar.PEClusterIP  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $netbios = $datagen.domainname.split(".")[0]
  $user = $datagen.seupn.split("@")[0]
  write-log -message "Adding Fileserver Shares"


  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/vfilers/$($vfiler.entities.uuid)/shares/?force=true"

  write-log -message "Using URL $URL"

$Userhomejson1= @"
{
  "name": "Userhome",
  "fileServerUuid": "$($vfiler.entities.uuid)",
  "enablePreviousVersion": true,
  "windowsAdDomainName": "$($datagen.domainname)",
  "description": "User Home Data",
  "maxSizeGiB": 0,
  "protocolType": "SMB",
  "secondaryProtocolType": "NONE",
  "sharePath": "",
  "isNestedShare": false,
  "enableAccessBasedEnumeration": true,
  "shareType": "HOMES"
}
"@
$Userhomejson2= @"
{
  "name": "Userhome",
  "fileServerUuid": "$($vfiler.entities.uuid)",
  "enablePreviousVersion": true,
  "windowsAdDomainName": "$($datagen.domainname)",
  "description": "User Home Data",
  "maxSizeGiB": 0,
  "protocolType": "SMB",
  "secondaryProtocolType": "NONE",
  "sharePath": "",
  "isNestedShare": false,
  "enableAccessBasedEnumeration": true,
  "shareType": "GENERAL"
}
"@
$Departmentjson= @"
{
  "name": "Department",
  "fileServerUuid": "$($vfiler.entities.uuid)",
  "enablePreviousVersion": false,
  "windowsAdDomainName": "$($datagen.domainname)",
  "description": "Department data",
  "maxSizeGiB": 0,
  "protocolType": "SMB",
  "secondaryProtocolType": "NONE",
  "sharePath": "",
  "isNestedShare": false,
  "enableAccessBasedEnumeration": true,
  "shareType": "GENERAL"
}
"@
$Publicjson= @"
{
  "name": "Public",
  "fileServerUuid": "$($vfiler.entities.uuid)",
  "enablePreviousVersion": false,
  "windowsAdDomainName": "$($datagen.domainname)",
  "description": "Public data",
  "maxSizeGiB": 0,
  "protocolType": "SMB",
  "secondaryProtocolType": "NONE",
  "sharePath": "",
  "isNestedShare": false,
  "enableAccessBasedEnumeration": true,
  "shareType": "GENERAL"
}
"@ 
  if ($nodecount -le 2){
    $Userhomejson = $Userhomejson2
  } else {
    $Userhomejson = $Userhomejson1
  }
  
  if ($debug -ge 2){
    $Userhome | out-file c:\temp\addShares1.json
  }
  try {
    $shares = REST-PE-GetShares -datavar $datavar -datagen $datagen
    $userhome =  $shares.entities.name | where {$_ -eq "Userhome"}
    $department = $shares.entities.name | where {$_ -eq "Department"}
    $public = $shares.entities.name | where {$_ -eq "Public"}
  }catch {

   write-log -message "We are not supposed to error here"

  }
  try{
    if (!$userhome){
      write-log -message "Creating Userhome"
      
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $Userhomejson -ContentType 'application/json' -headers $headers;
      sleep 40

      write-log -message "Userhome Created"

    } else {

      write-log -message "Userhome Already Exists"  

    }


  } catch {

    write-log -message "Creating Userhome again"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Userhomejson -ContentType 'application/json' -headers $headers;
    sleep 40

  }
  try {
    if (!$public){
      write-log -message "Creating Public"

      $task = Invoke-RestMethod -Uri $URL -method "post" -body $Publicjson -ContentType 'application/json' -headers $headers;
      sleep 40

      write-log -message "Public Created"
    } else {

      write-log -message "Public Already exists"

    }
  } catch {

    write-log -message "Creating Public again"
    
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Publicjson -ContentType 'application/json' -headers $headers;
    sleep 40

    write-log -message "Public Created"

  }
  try{
    if (!$department){

     write-log -message "Creating Department"

     sleep 40

     $task = Invoke-RestMethod -Uri $URL -method "post" -body $Departmentjson -ContentType 'application/json' -headers $headers;     

    } else {

     write-log -message "Department already exists"
      
    }


  } catch {

    write-log -message "Creating Department again"

    sleep 40

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Departmentjson -ContentType 'application/json' -headers $headers;

    write-log -message "Department Created"

  }
    
  write-log -message "All Shares Created"


  Return $task
} 


Function REST-Get-FilesAnalyticsVersion {
  Param (
    [string] $PEClusterIP,
    [string] $clpassword,
    [string] $clusername
  )

  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing Analytics Version List"

  $URL = "https://$($PEClusterIP):9440/PrismGateway/services/rest/v1/upgrade/file_analytics/softwares"

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

Function REST-AFS-Get-Download-Status {
  Param (
    [object] $datagen,
    [object] $datavar
  )
  
  $clusterip = $datavar.PEClusterIP
   
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/upgrade/afs/softwares"
  #silent looper module

  try{
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "get"  -headers $headers;
  }

  Return $task
} 

Function REST-AFS-Start-Download {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $AFS
  )

  $clusterip = $datavar.PEClusterIP
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Downloading AFS $($datagen.Filesversion)"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v1/upgrade/afs/softwares/$($datagen.Filesversion)/download"

  write-log -message "Using URL $URL"

  $json = $AFS | convertto-json
  
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }

  Return $task
}



Function REST-Register-FileAnalyticsServer {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $vfiler,
    [string] $anaIP
  )

  $credPair = "$($datavar.peadmin):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Registering Analytics Server"
  write-log -message "Using vfiler $($vfiler.entities.uuid)"
  write-log -message "Using Domain Name $($datagen.Domainname)"
  write-log -message "Using IP $anaIP"

  $URL = "https://$($anaIP):3000/fileservers/subscription?user_name=admin&file_server_uuid=$($vfiler.entities.uuid)"

  write-log -message "Using URL $URL"

$Payload= @"
{
  "data_retention_months": "12",
  "dns_domain_name": "$($datagen.Domainname)",
  "file_server_uuid": "$($vfiler.entities.uuid)",
  "ad_credentials": {
    "domain": "$($datagen.Domainname)",
    "username": "administrator",
    "password": "$($datagen.SysprepPassword)",
    "rfc2307_enabled": true
  }
}
"@ 
  if ($debug -ge 2){
    $JSON | out-file c:\temp\regFSana.json
  }
  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;

    write-log -message "Analytics server registered" 

  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-Get-AnalyticsServer {
  Param (
    [string] $PEClusterIP,
    [string] $clpassword,
    [string] $clusername
  )

  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing Analytics Server List"

  $URL = "https://$($PEClusterIP):9440/PrismGateway/services/rest/v2.0/analyticsplatform"
 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }
  write-log -message "We found $($task.count) items."

  Return $task
} 


Function REST-Create-FileAnalyticsServer {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $network,
    [object] $container,
    [string] $AnalyticsVersion
  )
  $clusterip = $datavar.PEClusterIP  
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Creating the Analytics Server"
  write-log -message "Using Version $($AnalyticsVersion)"
  write-log -message "Using Container UUID $($container.containerUuid)"
  write-log -message "Using IP $($datagen.Files2IP)"
  write-log -message "Using Network $($network.uuid)"

  $URL = "https://$($clusterip):9440/PrismGateway/services/rest/v2.0/analyticsplatform"

  write-log -message "Using URL $URL"

$Payload= @"
{
  "image_version": "$($AnalyticsVersion)",
  "vm_name": "$($datagen.Files2VM_Name)",
  "container_uuid": "$($container.containerUuid)",
  "container_name": "$($container.name)",
  "network": {
    "uuid": "$($network.uuid)",
    "ip": "$($datagen.Files2IP)",
    "netmask": "$($datavar.InfraSubnetmask)",
    "gateway": "$($datavar.InfraGateway)"
  },
  "resource": {
    "memory": "32",
    "cores": "4",
    "vcpu": "4"
  },
  "dns_servers": ["$($datagen.DC1IP)", "$($datagen.DC2IP)"],
  "ntp_servers": ["$($datagen.NTPServer1)", "$($datagen.NTPServer2)", "$($datagen.NTPServer3)", "$($datagen.NTPServer4)"]
}
"@ 
  if ($debug -ge 2){
    $JSON | out-file c:\temp\createFSana.json
  }
  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;

    write-log -message "File Server install Started" 

  } catch {
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 
