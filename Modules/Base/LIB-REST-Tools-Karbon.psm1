
Function REST-Karbon-Get-Images-Local {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $token
  )

  $URL = "https://$($datagen.PCClusterIP):7050/acs/image/list"
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

Function REST-Karbon-Create-Files-StorageCloss {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $cluster,
    [object] $token
  )

  $URL = "https://$($datagen.PCClusterIP):7050/acs/k8s/cluster/$($cluster.cluster_metadata.uuid)/storage_class"
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

  $URL = "https://$($datagen.PCClusterIP):7050/acs/k8s/cluster/$($cluster.cluster_metadata.uuid)/workers"
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

  $URL = "https://$($datagen.PCClusterIP):7050/acs/k8s/cluster/$($cluster.cluster_metadata.uuid)/storage_class/list"
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

  $URL = "https://$($datagen.PCClusterIP):7050/acs/k8s/cluster/$($cluster.cluster_metadata.uuid)/volume"
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

  $URL = "https://$($datagen.PCClusterIP):7050/acs/image/portal/list"
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

Function REST-Karbon-Get-Versions {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $token
  )

  $URL = "https://$($datagen.PCClusterIP):7050/acs/k8sversion/list"
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

  $URL = "https://$($datagen.PCClusterIP):7050/acs/image/download"
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

  $URL = "https://$($datagen.PCClusterIP):7050/acs/k8s/cluster/list"
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


Function REST-Karbon-Create-Cluster {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $image,
    [object] $token,
    [string] $k8version,
    [object] $PCcluster,
    [object] $subnet
  )

  $URL = "https://$($datagen.PCClusterIP):7050/acs/k8s/cluster"
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
  "name": "K8-$($datavar.pocname)",
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
        "file_system": "ext4",
        "flash_mode": false
      }
    }
  },
  "etcd_config": {
    "num_instances": 3,
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

  $URL = "https://$($datagen.PCClusterIP):7050/acs/k8s/cluster"
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
  "name": "K8-$($datavar.pocname)",
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

  $URL = "https://$($datagen.PCClusterIP):7050/acs/k8s/cluster/$($K8cluster.cluster_metadata.uuid)"
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
