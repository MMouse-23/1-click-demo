
Function REST-Karbon-Get-Images-Local {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $token
  )

  $URL = "https://$($datagen.PCClusterIP):9440/karbon/acs/image/list"
  $Cookie = New-Object System.Net.Cookie
  $Cookie.Name = "NTNX_IGW_SESSION" # Add the name of the cookie
  $Cookie.Value = "$($token.value)" # Add the value of the cookie
  [System.Uri]$uri = $url 
  $Cookie.Domain = $uri.DnsSafeHost
  $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $WebSession.Cookies.Add($Cookie)

  write-log -message "Getting OS Images for Karbon"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -websession $websession
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -websession $websession
    Return $RespErr
  }

  Return $task
} 


Function REST-Karbon-Login {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  write-log -message "Debug level is $($debug)";
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building PC Batch Login query to get me a token"

  $URL = "https://$($datagen.PCClusterIP):9440/karbon/prism/api/nutanix/v3/batch"
  $JSON = @"
{
  "action_on_failure": "CONTINUE",
  "execution_order": "SEQUENTIAL",
  "api_request_list": [{
    "operation": "GET",
    "path_and_params": "/api/nutanix/v3/users/me"
  }, {
    "operation": "GET",
    "path_and_params": "/api/nutanix/v3/users/info"
  }],
  "api_version": "3.0"
}
"@
  try {
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers -SessionVariable websession;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers -SessionVariable websession;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }
  $cookies = $websession.Cookies.GetCookies($url) 
  Return $cookies
} 

Function REST-Karbon-Create-Files-StorageCloss {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $cluster,
    [object] $token
  )

  $URL = "https://$($datagen.PCClusterIP):9440/karbon/acs/k8s/cluster/$($cluster.cluster_metadata.uuid)/storage_class"
  $Cookie = New-Object System.Net.Cookie
  $Cookie.Name = "NTNX_IGW_SESSION" # Add the name of the cookie
  $Cookie.Value = "$($token.value)" # Add the value of the cookie
  [System.Uri]$uri = $url 
  $Cookie.Domain = $uri.DnsSafeHost
  $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $WebSession.Cookies.Add($Cookie)

  write-log -message "Creating StorageClass For Cluster $($cluster.cluster_metadata.uuid)"

  $json = @"
{
  "metadata": {
    "name": "files-storageclass"
  },
  "spec": {
    "reclaim_policy": "Delete",
    "sc_files_spec": {
      "nfs_server": "$($datagen.DataServicesIP)",
      "nfs_path": "/K8s"
    }
  }
}


"@
  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
    Return $RespErr
  }

  Return $task
} 



Function REST-Karbon-Add-Node {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $cluster,
    [object] $token,
    [string] $nodecount
  )

  $URL = "https://$($datagen.PCClusterIP):9440/karbon/acs/k8s/cluster/$($cluster.cluster_metadata.uuid)/workers"
  $Cookie = New-Object System.Net.Cookie
  $Cookie.Name = "NTNX_IGW_SESSION" # Add the name of the cookie
  $Cookie.Value = "$($token.value)" # Add the value of the cookie
  [System.Uri]$uri = $url 
  $Cookie.Domain = $uri.DnsSafeHost
  $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $WebSession.Cookies.Add($Cookie)

  write-log -message "Using Cluster $($cluster.cluster_metadata.uuid)"

  $NodePoolName = $cluster.cluster_metadata.k8s_config.workers.node_pool_name | select -first 1

  write-log -message "Adding $nodecount node(s) for pool $($NodePoolName)"

  $json = @"
{
    "node_pool_name": "$($NodePoolName)",
    "worker_count": $nodecount
}
"@
  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
    Return $RespErr
  }

  Return $task
} 



Function REST-Karbon-List-StorageCloss {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $cluster,
    [object] $token
  )

  $URL = "https://$($datagen.PCClusterIP):9440/karbon/acs/k8s/cluster/$($cluster.cluster_metadata.uuid)/storage_class/list"
  $Cookie = New-Object System.Net.Cookie
  $Cookie.Name = "NTNX_IGW_SESSION" # Add the name of the cookie
  $Cookie.Value = "$($token.value)" # Add the value of the cookie
  [System.Uri]$uri = $url 
  $Cookie.Domain = $uri.DnsSafeHost
  $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $WebSession.Cookies.Add($Cookie)

  write-log -message "Listing StorageClasses For Cluster $($cluster.cluster_metadata.uuid)"

  $json = @"
{
  "length": 100,
  "namespace": "default"
}
"@
  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
    Return $RespErr
  }

  Return $task
} 

Function REST-Karbon-ClaimFilesVolume {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $cluster,
    [object] $token,
    [object] $class
  )

  $URL = "https://$($datagen.PCClusterIP):9440/karbon/acs/k8s/cluster/$($cluster.cluster_metadata.uuid)/volume"
  $Cookie = New-Object System.Net.Cookie
  $Cookie.Name = "NTNX_IGW_SESSION" # Add the name of the cookie
  $Cookie.Value = "$($token.value)" # Add the value of the cookie
  [System.Uri]$uri = $url 
  $Cookie.Domain = $uri.DnsSafeHost
  $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $WebSession.Cookies.Add($Cookie)

  write-log -message "Creating Volume For Cluster $($cluster.cluster_metadata.uuid)"

  $json = @"
{
  "metadata": {
    "name": "1-click-demo-rm-volume",
    "namespace": "default"
  },
  "spec": {
    "size": 20,
    "storage_class_name": "$($class.metadata.name)",
    "access_mode": "ReadWriteMany"
  }
}
"@
  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
    Return $RespErr
  }

  Return $task
} 


Function REST-Karbon-Get-Images-Portal {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $token
  )

  $URL = "https://$($datagen.PCClusterIP):9440/karbon/acs/image/portal/list"
  $Cookie = New-Object System.Net.Cookie
  $Cookie.Name = "NTNX_IGW_SESSION" # Add the name of the cookie
  $Cookie.Value = "$($token.value)" # Add the value of the cookie
  [System.Uri]$uri = $url 
  $Cookie.Domain = $uri.DnsSafeHost
  $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $WebSession.Cookies.Add($Cookie)

  write-log -message "Getting OS Images for Karbon"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -websession $websession
  } catch {
    sleep 10
    write-log -message "We Already did this"
  }

  Return $task
} 

Function REST-Karbon-Get-Versions-Local {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $token
  )

  $URL = "https://$($datagen.PCClusterIP):9440/karbon/acs/k8sversion/list"
  $Cookie = New-Object System.Net.Cookie
  $Cookie.Name = "NTNX_IGW_SESSION" 
  $Cookie.Value = "$($token.value)" 
  [System.Uri]$uri = $url 
  $Cookie.Domain = $uri.DnsSafeHost
  $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $WebSession.Cookies.Add($Cookie)

  write-log -message "Getting OS Images for Karbon"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -websession $websession
  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "GET" -websession $websession
  }

  Return $task
} 

Function REST-Karbon-Get-Versions-Portal {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $token
  )

  $URL = "https://$($datagen.PCClusterIP):9440/karbon/acs/k8srelease/portal/list"
  $Cookie = New-Object System.Net.Cookie
  $Cookie.Name = "NTNX_IGW_SESSION" 
  $Cookie.Value = "$($token.value)" 
  [System.Uri]$uri = $url 
  $Cookie.Domain = $uri.DnsSafeHost
  $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $WebSession.Cookies.Add($Cookie)

  write-log -message "Getting OS Images for Karbon"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -websession $websession
  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "GET" -websession $websession
  }

  Return $task
} 



Function REST-Karbon-Download-Images {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $image,
    [object] $token
  )

  $URL = "https://$($datagen.PCClusterIP):9440/karbon/acs/image/download"
  $Cookie = New-Object System.Net.Cookie
  $Cookie.Name = "NTNX_IGW_SESSION" # Add the name of the cookie
  $Cookie.Value = "$($token.value)" # Add the value of the cookie
  [System.Uri]$uri = $url 
  $Cookie.Domain = $uri.DnsSafeHost
  $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $WebSession.Cookies.Add($Cookie)

  write-log -message "Downloading OS Images for Karbon"

  $json = @"
{
  "uuid":"$($image.uuid)"
}
"@
  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
    Return $RespErr
  }

  Return $task
} 

Function REST-Karbon-Get-Clusters {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $token
  )

  $URL = "https://$($datagen.PCClusterIP):9440/karbon/acs/k8s/cluster/list"
  $Cookie = New-Object System.Net.Cookie
  $Cookie.Name = "NTNX_IGW_SESSION" # Add the name of the cookie
  $Cookie.Value = "$($token.value)" # Add the value of the cookie
  [System.Uri]$uri = $url 
  $Cookie.Domain = $uri.DnsSafeHost
  $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $WebSession.Cookies.Add($Cookie)

  write-log -message "Getting Karbon Clusters"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
    Return $RespErr
  }

  Return $task
} 


Function REST-Karbon-Create-Cluster-Fannel {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $image,
    [object] $token,
    [string] $k8version,
    [object] $PCcluster,
    [object] $subnet
  )

  $URL = "https://$($datagen.PCClusterIP):9440/karbon/acs/k8s/cluster"
  $Cookie = New-Object System.Net.Cookie
  $Cookie.Name = "NTNX_IGW_SESSION" # Add the name of the cookie
  $Cookie.Value = "$($token.value)" # Add the value of the cookie
  [System.Uri]$uri = $url 
  $Cookie.Domain = $uri.DnsSafeHost
  $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $WebSession.Cookies.Add($Cookie)

  write-log -message "Creating Karbon Cluster"
  write-log -message "Using Subnet UUID $($subnet.uuid)"
  write-log -message "Using Image UUID $($image.image_uuid)"
  write-log -message "Using Production worker /master count but 4GB of RAM"
  write-log -message "Using VIP IP $($datagen.KarbonIP)"
  write-log -message "Using Cluster UUID $($PCcluster.metadata.uuid)"
  write-log -message "Using Container $($datagen.KarbonContainerName)"
  write-log -message "Using K8 Clustername K8-$($datavar.pocname)"

  $json = @"
{
  "name": "K8-$($datavar.pocname)-F",
  "description": "",
  "vm_network": "$($subnet.uuid)",
  "k8s_config": {
    "service_cluster_ip_range": "172.19.0.0/16",
    "network_cidr": "172.20.0.0/16",
    "fqdn": "",
    "workers": [{
      "node_pool_name": "",
      "name": "",
      "uuid": "",
      "resource_config": {
        "cpu": 8,
        "memory_mib": 8192,
        "image": "$($image.image_uuid)",
        "disk_mib": 122880
      }
    }, {
      "node_pool_name": "",
      "name": "",
      "uuid": "",
      "resource_config": {
        "cpu": 8,
        "memory_mib": 8192,
        "image": "$($image.image_uuid)",
        "disk_mib": 122880
      }
    }, {
      "node_pool_name": "",
      "name": "",
      "uuid": "",
      "resource_config": {
        "cpu": 8,
        "memory_mib": 8192,
        "image": "$($image.image_uuid)",
        "disk_mib": 122880
      }
    }],
    "master_config": {
      "external_ip": "$($datagen.KarbonIP)",
      "deployment_type": "mm_vrrp"
    },
    "masters": [{
      "node_pool_name": "",
      "name": "",
      "uuid": "",
      "resource_config": {
        "cpu": 4,
        "memory_mib": 4096,
        "image": "$($image.image_uuid)",
        "disk_mib": 122880
      }
    }, {
      "node_pool_name": "",
      "name": "",
      "uuid": "",
      "resource_config": {
        "cpu": 4,
        "memory_mib": 4096,
        "image": "$($image.image_uuid)",
        "disk_mib": 122880
      }
    }],
    "os_flavor": "$($image.os_flavor)",
    "network_subnet_len": 24,
    "version": "$($k8version)"
  },
  "cluster_ref": "$($PCcluster.metadata.uuid)",
  "logging_config": {
    "enable_app_logging": false
  },
  "storage_class_config": {
    "metadata": {
      "name": "default-storageclass"
    },
    "spec": {
      "reclaim_policy": "Delete",
      "sc_volumes_spec": {
        "cluster_ref": "$($PCcluster.metadata.uuid)",
        "user": "$($datagen.buildaccount)",
        "password": "$($datavar.pepass)",
        "storage_container": "$($datagen.KarbonContainerName)",
        "file_system": "xfs",
        "flash_mode": false
      }
    }
  },
  "etcd_config": {
    "num_instances": 3,
    "name": "K8-$($datavar.pocname)-F",
    "nodes": [{
      "node_pool_name": "",
      "name": "",
      "uuid": "",
      "resource_config": {
        "cpu": 4,
        "memory_mib": 8192,
        "image": "$($image.image_uuid)",
        "disk_mib": 40960
      }
    }]
  }
}
"@
if ($debug -ge 2 ){
  $json | out-file c:\temp\fannel.json
}
  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
    Return $RespErr
  }

  Return $task
} 

Function REST-Karbon-Create-Cluster-Calico {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $image,
    [object] $token,
    [string] $k8version,
    [object] $PCcluster,
    [object] $subnet,
    [string] $VIP
  )

  $URL = "https://$($datagen.PCClusterIP):9440/karbon/v1/k8s/clusters"
  $Cookie = New-Object System.Net.Cookie
  $Cookie.Name = "NTNX_IGW_SESSION" # Add the name of the cookie
  $Cookie.Value = "$($token.value)" # Add the value of the cookie
  [System.Uri]$uri = $url 
  $Cookie.Domain = $uri.DnsSafeHost
  $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $WebSession.Cookies.Add($Cookie)

  write-log -message "Creating Karbon Cluster"
  write-log -message "Using Subnet UUID $($subnet.uuid)"
  write-log -message "Using Image UUID $($image.image_uuid)"
  write-log -message "Using Production worker /master count but 4GB of RAM"
  write-log -message "Using VIP IP $($VIP)"
  write-log -message "Using Cluster UUID $($PCcluster.metadata.uuid)"
  write-log -message "Using Container $($datagen.KarbonContainerName)"
  write-log -message "Using K8 Clustername K8-$($datavar.pocname)"

  $json = @"
{
  "cni_config": {
    "calico_config": {
      "ip_pool_configs": [
        {
          "cidr": "172.21.0.0/16"
        }
      ]
    },
    "node_cidr_mask_size": 24,
    "pod_ipv4_cidr": "172.21.0.0/16",
    "service_ipv4_cidr": "172.22.0.0/16"
  },
  "etcd_config": {
    "node_pools": [
      {
        "ahv_config": {
          "cpu": 2,
          "disk_mib": 40960,
          "memory_mib": 8192,
          "network_uuid": "$($subnet.uuid)",
          "prism_element_cluster_uuid": "$($PCcluster.metadata.uuid)"
        },
        "name": "etcd-node-pool",
        "node_os_version": "$($image.version)",
        "num_instances": 3
      }
    ]
  },
  "masters_config": {
    "active_passive_config": {
      "external_ipv4_address": "$($VIP)"
    },
    "node_pools": [
      {
        "ahv_config": {
          "cpu": 2,
          "disk_mib": 122880,
          "memory_mib": 4096,
          "network_uuid": "$($subnet.uuid)",
          "prism_element_cluster_uuid": "$($PCcluster.metadata.uuid)"
        },
        "name": "master-node-pool",
        "node_os_version": "$($image.version)",
        "num_instances": 2
      }
    ]
  },
  "metadata": {
    "api_version": "v1.0.0"
  },
  "name": "K8-$($datavar.pocname)-C",
  "storage_class_config": {
    "default_storage_class": true,
    "name": "default-storageclass",
    "reclaim_policy": "Delete",
    "volumes_config": {
      "file_system": "xfs",
      "flash_mode": false,
      "password": "$($datavar.pepass)",
      "prism_element_cluster_uuid": "$($PCcluster.metadata.uuid)",
      "storage_container": "$($datagen.KarbonContainerName)",
      "username": "$($datagen.buildaccount)"
    }
  },
  "version": "$($k8version)",
  "workers_config": {
    "node_pools": [
      {
        "ahv_config": {
          "cpu": 4,
          "disk_mib": 122880,
          "memory_mib": 8192,
          "network_uuid": "$($subnet.uuid)",
          "prism_element_cluster_uuid": "$($PCcluster.metadata.uuid)"
        },
        "name": "worker-node-pool",
        "node_os_version": "$($image.version)",
        "num_instances": 3
      }
    ]
  }
}
"@
  $json | out-file c:\temp\K8s2.json

  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
    Return $RespErr
  }

  Return $task
} 


Function REST-Karbon-Create-Cluster-Dev {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $image,
    [object] $token,
    [string] $k8version,
    [object] $PCcluster,
    [object] $subnet
  )

  $URL = "https://$($datagen.PCClusterIP):9440/karbon/acs/k8s/cluster"
  $Cookie = New-Object System.Net.Cookie
  $Cookie.Name = "NTNX_IGW_SESSION" # Add the name of the cookie
  $Cookie.Value = "$($token.value)" # Add the value of the cookie
  [System.Uri]$uri = $url 
  $Cookie.Domain = $uri.DnsSafeHost
  $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $WebSession.Cookies.Add($Cookie)

  write-log -message "Creating Karbon Cluster"
  write-log -message "Using Subnet UUID $($subnet.uuid)"
  write-log -message "Using Image UUID $($image.image_uuid)"
  write-log -message "Using Production worker /master count but 4GB of RAM"
  write-log -message "Using VIP IP $($datagen.KarbonIP)"
  write-log -message "Using Cluster UUID $($PCcluster.metadata.uuid)"
  write-log -message "Using Container $($datagen.KarbonContainerName)"
  write-log -message "Using K8 Clustername K8-$($datavar.pocname)"

  $json = @"
{
  "name": "K8-$($datavar.pocname)-F",
  "description": "",
  "vm_network": "$($subnet.uuid)",
  "k8s_config": {
    "service_cluster_ip_range": "172.19.0.0/16",
    "network_cidr": "172.20.0.0/16",
    "fqdn": "",
    "workers": [{
      "node_pool_name": "",
      "name": "",
      "uuid": "",
      "resource_config": {
        "cpu": 4,
        "memory_mib": 8192,
        "image": "$($image.image_uuid)",
        "disk_mib": 122880
      }
    }],
    "masters": [{
      "node_pool_name": "",
      "name": "",
      "uuid": "",
      "resource_config": {
        "cpu": 2,
        "memory_mib": 4096,
        "image": "$($image.image_uuid)",
        "disk_mib": 122880
      }
    }],
    "os_flavor": "$($image.os_flavor)",
    "network_subnet_len": 24,
    "version": "$($k8version)"
  },
  "cluster_ref": "$($PCcluster.metadata.uuid)",
  "logging_config": {
    "enable_app_logging": false
  },
  "storage_class_config": {
    "metadata": {
      "name": "default-storageclass"
    },
    "spec": {
      "reclaim_policy": "Delete",
      "sc_volumes_spec": {
        "cluster_ref": "$($PCcluster.metadata.uuid)",
        "user": "$($datagen.buildaccount)",
        "password": "$($datavar.pepass)",
        "storage_container": "$($datagen.KarbonContainerName)",
        "file_system": "ext4",
        "flash_mode": false
      }
    }
  },
  "etcd_config": {
    "num_instances": 1,
    "name": "K8-$($datavar.pocname)",
    "nodes": [{
      "node_pool_name": "",
      "name": "",
      "uuid": "",
      "resource_config": {
        "cpu": 4,
        "memory_mib": 8192,
        "image": "$($image.image_uuid)",
        "disk_mib": 40960
      }
    }]
  }
}
"@
  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -websession $websession -body $json -ContentType 'application/json'
    Return $RespErr
  }

  Return $task
} 


Function REST-Karbon-Delete-Cluster {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $token,
    [object] $K8cluster
  )

  $URL = "https://$($datagen.PCClusterIP):9440/karbon/acs/k8s/cluster/$($K8cluster.cluster_metadata.uuid)"
  $Cookie = New-Object System.Net.Cookie
  $Cookie.Name = "NTNX_IGW_SESSION" # Add the name of the cookie
  $Cookie.Value = "$($token.value)" # Add the value of the cookie
  [System.Uri]$uri = $url 
  $Cookie.Domain = $uri.DnsSafeHost
  $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $WebSession.Cookies.Add($Cookie)

  write-log -message "Deleting Karbon Cluster"
  write-log -message "Using K8 Cluster UUID $($K8cluster.cluster_metadata.uuid)"


  try{
    $task = Invoke-RestMethod -Uri $URL -method "DELETE" -websession $websession
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "DELETE" -websession $websession
    Return $RespErr
  }

  Return $task
} 
