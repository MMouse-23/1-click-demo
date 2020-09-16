
Function REST-Add-Objects-AD {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $netbios = $datagen.Domainname.split(".")[0];
$Json = @"
{
  "api_version": "3.1.0",
  "metadata": {
    "kind": "directory_service"
  },
  "spec": {
    "name": "$netbios",
    "resources": {
      "domain_name": "$($datagen.Domainname)",
      "directory_type": "ACTIVE_DIRECTORY",
      "url": "ldap://$($datagen.DC1Name).$($datagen.domainname):3268",
      "service_account": {
        "username": "$($netbios)\\administrator",
        "password": "$($datagen.SysprepPassword)"
      }
    }
  }
}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/oss/iam_proxy/directory_services"

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


Function REST-Enable-Objects {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

$Json = @"
{"state":"ENABLE"}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/services/oss"

  write-log -message "Enabling Object Services"
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

Function REST-Query-Object-Install {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/services/oss/status"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }

  Return $task
} 


Function REST-Install-Objects-Store {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $subnet,
    [object] $cluster

  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $DNS = $($datagen.ObjectsIntRange).split("|")[0]
  $vip = $($datagen.ObjectsIntRange).split("|")[1]
  $domain = ("$($datavar.pocname).domain1").tolower()
  
$Json = @"
{
  "api_version": "3.0",
  "metadata": {
    "kind": "objectstore"
  },
  "spec": {
    "name": "$($datavar.pocname)",
    "description": "$($datavar.pocname)",
    "resources": {
      "domain": "$domain",
      "cluster_reference": {
        "kind": "cluster",
        "uuid": "$($cluster.metadata.uuid)"
      },
      "buckets_infra_network_dns": "$DNS",
      "buckets_infra_network_vip": "$vip",
      "buckets_infra_network_reference": {
        "kind": "subnet",
        "uuid": "$($subnet.uuid)"
      },
      "client_access_network_reference": {
        "kind": "subnet",
        "uuid": "$($subnet.uuid)"
      },
      "aggregate_resources": {
        "total_vcpu_count": 30,
        "total_memory_size_mib": 98304,
        "total_capacity_gib": 51200
      },
      "client_access_network_ip_list": ["$($datagen.objectsextrange)"]
    }
  }
}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/oss/api/nutanix/v3/objectstores"

  write-log -message "Enabling Object Services"
  write-log -message "Using URL $URL"
  write-log -message "using JSON:"
  write-log -message $Json

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 





Function REST-Query-Objects-Store {
  Param (
    [object] $datagen,
    [object] $datavar

  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

$Json = @"
{
  "entity_type": "objectstore",
  "group_member_sort_attribute": "name",
  "group_member_sort_order": "ASCENDING",
  "group_member_count": 20,
  "group_member_offset": 0,
  "group_member_attributes": [{
    "attribute": "name"
  }, {
    "attribute": "domain"
  }, {
    "attribute": "num_msp_workers"
  }, {
    "attribute": "usage_bytes"
  }, {
    "attribute": "num_buckets"
  }, {
    "attribute": "num_objects"
  }, {
    "attribute": "num_alerts_internal"
  }, {
    "attribute": "client_access_network_ip_used_list"
  }, {
    "attribute": "total_capacity_gib"
  }, {
    "attribute": "last_completed_step"
  }, {
    "attribute": "state"
  }, {
    "attribute": "percentage_complete"
  }, {
    "attribute": "ipv4_address"
  }, {
    "attribute": "num_alerts_critical"
  }, {
    "attribute": "num_alerts_info"
  }, {
    "attribute": "num_alerts_warning"
  }, {
    "attribute": "error_message_list"
  }, {
    "attribute": "cluster_name"
  }, {
    "attribute": "client_access_network_name"
  }, {
    "attribute": "client_access_network_ip_list"
  }, {
    "attribute": "buckets_infra_network_name"
  }, {
    "attribute": "buckets_infra_network_vip"
  }, {
    "attribute": "buckets_infra_network_dns"
  }]
}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/oss/api/nutanix/v3/groups"

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

Function REST-Create-Objects-Bucket {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $storeID,
    [string] $bucketname

  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

$Json = @"
{
  "api_version": "3.0",
  "metadata": {
    "kind": "bucket"
  },
  "spec": {
    "name": "$($bucketname)",
    "description": "",
    "resources": {
      "features": []
    }
  }
}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/oss/api/nutanix/v3/objectstores/$($StoreID)/buckets"

  write-log -message "Query Object Services"
  write-log -message "Using URL $URL"
  write-log -message "using JSON:"
  write-log -message $Json

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 


Function REST-DELETE-Objects-Store {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $storeUUID

  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  $URL = "https://$($datagen.PCClusterIP):9440/oss/api/nutanix/v3/objectstores/$($storeUUID)"

  write-log -message "Query Object Services"
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

