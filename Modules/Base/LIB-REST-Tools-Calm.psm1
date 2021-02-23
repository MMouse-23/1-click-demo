Function REST-Update-DefaultProject-ESX {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $project,
    [string] $environmentUUID,
    [string] $adminroleuuid,
    [string] $Domainadminuuid,
    [object] $VMwareAccount
  )
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $useruuid = ($project.spec.resources.user_reference_list | where {$_.name -eq "svc_build"}).uuid
  $domainparts = $datagen.domainname.split(".")

  write-log -message "Updating Default Project $($project.metadata.uuid)"
  write-log -message "With Provider $($VMwareAccount.metadata.uuid)"
  write-log -message "With Admin Role ID $($adminroleuuid)"
  write-log -message "SVC Build Account UUID $useruuid"
  write-log -message "Domain Admins Group UUID $Domainadminuuid"
  write-log -message "Using Domain Admin DN CN=Domain Admins,CN=Users,DC=$($($DomainParts)[0]),DC=$($($DomainParts)[1]),DC=$($($DomainParts)[2])"

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/projects_internal/$($project.metadata.uuid)"
  write-log -message "Loading Json"
  $json1 = @"
{
  "spec": {
    "access_control_policy_list": [{
      "acp": {
        "name": "1-CD-DefaultProject",
        "resources": {
          "role_reference": {
            "name": "Project Admin",
            "uuid": "$($adminroleuuid)",
            "kind": "role"
          },
          "user_group_reference_list": [{
            "name": "CN=Domain Admins,CN=Users,DC=$($($DomainParts)[0]),DC=$($($DomainParts)[1]),DC=$($($DomainParts)[2])",
            "kind": "user_group",
            "uuid": "$($Domainadminuuid)"
          }],
          "user_reference_list": [],
          "filter_list": {
            "context_list": [{
              "scope_filter_expression_list": [{
                "operator": "IN",
                "left_hand_side": "PROJECT",
                "right_hand_side": {
                  "uuid_list": ["$($project.metadata.uuid)"]
                }
              }],
              "entity_filter_expression_list": [{
                "operator": "IN",
                "left_hand_side": {
                  "entity_type": "ALL"
                },
                "right_hand_side": {
                  "collection": "ALL"
                }
              }]
            }, {
              "entity_filter_expression_list": [{
                "operator": "IN",
                "left_hand_side": {
                  "entity_type": "image"
                },
                "right_hand_side": {
                  "collection": "ALL"
                }
              }, {
                "operator": "IN",
                "left_hand_side": {
                  "entity_type": "marketplace_item"
                },
                "right_hand_side": {
                  "collection": "SELF_OWNED"
                }
              }, {
                "operator": "IN",
                "right_hand_side": {
                  "collection": "ALL"
                },
                "left_hand_side": {
                  "entity_type": "directory_service"
                }
              }, {
                "operator": "IN",
                "right_hand_side": {
                  "collection": "ALL"
                },
                "left_hand_side": {
                  "entity_type": "role"
                }
              }, {
                "operator": "IN",
                "right_hand_side": {
                  "uuid_list": ["$($project.metadata.uuid)"]
                },
                "left_hand_side": {
                  "entity_type": "project"
                }
              }, {
                "operator": "IN",
                "right_hand_side": {
                  "collection": "ALL"
                },
                "left_hand_side": {
                  "entity_type": "user"
                }
              }, {
                "operator": "IN",
                "right_hand_side": {
                  "collection": "ALL"
                },
                "left_hand_side": {
                  "entity_type": "user_group"
                }
              }, {
                "operator": "IN",
                "left_hand_side": {
                  "entity_type": "environment"
                },
                "right_hand_side": {
                  "collection": "SELF_OWNED"
                }
              }, {
                "operator": "IN",
                "right_hand_side": {
                  "collection": "ALL"
                },
                "left_hand_side": {
                  "entity_type": "app_icon"
                }
              }, {
                "operator": "IN",
                "right_hand_side": {
                  "collection": "ALL"
                },
                "left_hand_side": {
                  "entity_type": "category"
                }
              }, {
                "operator": "IN",
                "left_hand_side": {
                  "entity_type": "cluster"
                },
                "right_hand_side": {
                  "uuid_list": []
                }
              }]
            }]
          }
        },
        "description": "1CD Project First Update"
      },
      "metadata": {
        "kind": "access_control_policy"
      },
      "operation": "ADD"
    }],
    "project_detail": {
      "name": "default",
      "resources": {
        "account_reference_list": [{
          "uuid": "$($VMwareAccount.metadata.uuid)",
          "kind": "account",
          "name": "vmware"
        }],
        "user_reference_list": [{
          "kind": "user",
          "name": "admin",
          "uuid": "00000000-0000-0000-0000-000000000000"
        }, {
          "kind": "user",
          "name": "svc_build",
          "uuid": "$($useruuid)"
        }],
        "environment_reference_list": [],
        "external_user_group_reference_list": [{
          "name": "CN=Domain Admins,CN=Users,DC=$($($DomainParts)[0]),DC=$($($DomainParts)[1]),DC=$($($DomainParts)[2])",
          "kind": "user_group",
          "uuid": "$($Domainadminuuid)"
        }],
        "subnet_reference_list": []
      }
    },
    "user_list": [],
    "user_group_list": []
  },
  "api_version": "3.1",
  "metadata": {
    "kind": "project",
    "spec_version": $($project.metadata.spec_version),
    "categories_mapping": {},
    "categories": {},
    "uuid": "$($project.metadata.uuid)"
  }
}
"@

$json2 = @"
{
          "kind": "environment",
          "uuid": "$environmentUUID"
}
"@

  if ($environmentuuid){

    write-log -message "Converting To Object and adding Environment."

    $object1 = $json1 | convertfrom-json
    $object2 = $json2 | convertfrom-json
    $object1.spec.project_detail.resources.environment_reference_list += $object2

    write-log -message "Final Object Created converting back to JSON"

    $Json1 = $object1 | convertto-json -depth 100
  }
  if ($debug -ge 2){
    write $Json1
  }
  try{
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $json1 -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $json1 -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-Update-DefaultProject-AHV {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $project,
    [object] $subnet,
    [string] $environmentUUID
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $useruuid = ($project.spec.resources.user_reference_list | where {$_.name -eq "svc_build"}).uuid

  write-log -message "Updating Default Project $($project.metadata.uuid)"
  write-log -message "With Subnet $($subnet.uuid)"
  write-log -message "Build Account UUID $useruuid"

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/projects_internal/$($project.metadata.uuid)"
  write-log -message "Loading Json"
  $json = @"
{
  "spec": {
    "access_control_policy_list": [],
    "project_detail": {
      "name": "default",
      "resources": {
        "account_reference_list": [],
        "user_reference_list": [{
          "kind": "user",
          "name": "admin",
          "uuid": "00000000-0000-0000-0000-000000000000"
        }, {
          "kind": "user",
          "name": "svc_build",
          "uuid": "$useruuid"
        }],
        "environment_reference_list": [{
          "kind": "environment",
          "uuid": "$environmentUUID"
        }],
        "external_user_group_reference_list": [],
        "subnet_reference_list": [{
          "kind": "subnet",
          "name": "$($subnet.name)",
          "uuid": "$($subnet.uuid)"
        }]
      }
    },
    "user_list": [],
    "user_group_list": []
  },
  "api_version": "3.1",
  "metadata": {
    "kind": "project",
    "spec_version": $($project.metadata.spec_version),
    "categories": {},
    "uuid": "$($project.metadata.uuid)"
  }
}
"@
  $object = $json | convertfrom-json
  

  try{
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 


Function REST-LIST-SSP-VMwareImages {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $Accountuuid
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }


  write-log -message "Getting VMware Templates for $Accountuuid"
  
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/vmware/v6/template/list"
  write-log -message "Loading Json"
  $json = @"
{
  "filter": "account_uuid==$($Accountuuid);"
}
"@
  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json'  -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-Runbook-Import-Blob {
  Param (
    [object] $PCClusterIP,
    [object] $PCClusterUser,
    [object] $PCClusterPass,
    [string] $filename
  )

  $credPair = "$($PCClusterUser):$($PCClusterPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }


  write-log -message "Importing Runbook $filename"
  
  $URL = "https://$($PCClusterIP):9440/api/nutanix/v3/runbooks/import_file"


  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -InFile $filename -ContentType 'multipart/form-data' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -InFile $filename -ContentType 'multipart/form-data' -headers $headers;
  }

  Return $task
} 



Function REST-LIST-Environments {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }


  write-log -message "Getting all Project Environments"
  
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/environments/list"
  write-log -message "Loading Json"
  $json = @"
{
  "filter": ""
}
"@
  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json'  -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 


Function REST-Create-Environment-ESX {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $project,
    [object] $subnet,
    [object] $Winimage,
    [object] $Linimage,
    [string] $accountuuid,
    [object] $environment
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $useruuid = ($project.spec.resources.user_reference_list | where {$_.name -eq "svc_build"}).uuid
  if ($environment.metadata.uuid){
    write-log -message "Updating Existing Environment $($environment.metadata.uuid)"
    $name = $environment.metadata.uuid
    $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/environments/$($environment.metadata.uuid)"
    $method = "PUT"
    $WincredUUID = ($environment.status.resources.credential_definition_list | where {$_.name -eq "sysprepcreds"}).uuid
    $LincredUUID =($environment.status.resources.credential_definition_list | where {$_.name -eq "centos"}).uuid
    $Resource1UUID = ($environment.status.resources.substrate_definition_list | where {$_.os_type -eq "Linux"}).uuid
    $Resource2UUID = ($environment.status.resources.substrate_definition_list | where {$_.os_type -eq "Windows"}).uuid
      
  } else {
    $method = "POST"
    $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/environments"
    $name = "Environment-$($project.spec.name)"
    $WincredUUID = (new-guid).Guid
    $LincredUUID = (new-guid).Guid
    $Resource1UUID = (new-guid).Guid
    $Resource2UUID = (new-guid).Guid

  }
  write-log -message "With Subnet $($subnet.uuid)"
  write-log -message "Windows Image $($Winimage.config.instanceUuid)"
  write-log -message "Linux Image $($Linimage.config.instanceUuid)"
  write-log -message "Updating Environment for project $($project.spec.name)"




  
  write-log -message "Loading Json"
  $json1 = @"
{
  "spec": {
    "name": "$($name)",
    "resources": {
      "substrate_definition_list": [{
        "variable_list": [],
        "action_list": [],
        "name": "Untitled",
        "editables": {
          "create_spec": {
            "resources": {
              "template_nic_list": {},
              "guest_customization": {
                "linux_data": {
                  "dns_primary": true,
                  "domain": true,
                  "hostname": true,
                  "timezone": true,
                  "dns_secondary": true
                }
              },
              "nic_list": {},
              "controller_list": {},
              "template_controller_list": {},
              "template_disk_list": {}
            }
          }
        },
        "os_type": "Linux",
        "type": "VMWARE_VM",
        "readiness_probe": {
          "connection_type": "SSH",
          "retries": "5",
          "disable_readiness_probe": false,
          "address": "@@{platform.ipAddressList[0]}@@",
          "delay_secs": "60",
          "connection_port": 22,
          "login_credential_local_reference": {
            "kind": "app_credential",
            "uuid": "$($LincredUUID)"
          }
        },
        "uuid": "$($Resource1UUID)",
        "create_spec": {
          "name": "vm-@@{calm_array_index}@@-@@{calm_time}@@",
          "type": "PROVISION_VMWARE_VM",
          "drs_mode": true,
          "cluster": "$($Datavar.pocname)",
          "template": "$($Linimage.config.instanceUuid)",
          "storage_pod": "OS",
          "resources": {
            "template_nic_list": [{
              "nic_type": "e1000e",
              "net_name": "key-vim.host.PortGroup-$($datagen.nw1name)",
              "key": 4000
            }],
            "nic_list": [],
            "num_vcpus_per_socket": 1,
            "num_sockets": 1,
            "memory_size_mib": 2048,
            "guest_customization": {
              "cloud_init": "#cloud-config\npassword: $($datavar.pepass)\nchpasswd: { expire: False }\nssh_pwauth: True\nruncmd:\n - configure_static_ip ip=$($datagen.LinTemplateIP) gateway=$($datavar.infragateway) netmask=$($Datavar.infrasubnetmask) nameserver=$($datagen.dc1ip),$($datagen.dc2ip)",
              "customization_type": "GUEST_OS_LINUX"
            },
            "account_uuid": "$($accountuuid)"
          }
        }
      }, {
        "variable_list": [],
        "action_list": [],
        "name": "Untitled",
        "editables": {
          "create_spec": {
            "resources": {
              "template_nic_list": {},
              "guest_customization": {
                "windows_data": {
                  "dns_primary": true,
                  "dns_secondary": true,
                  "network_settings": {
                    "0": {
                      "ip": true,
                      "gateway_default": true,
                      "subnet_mask": true
                    }
                  }
                }
              },
              "nic_list": {},
              "controller_list": {},
              "template_controller_list": {},
              "template_disk_list": {}
            }
          }
        },
        "os_type": "Windows",
        "type": "VMWARE_VM",
        "readiness_probe": {
          "connection_type": "POWERSHELL",
          "retries": "5",
          "disable_readiness_probe": false,
          "address": "@@{platform.ipAddressList[0]}@@",
          "delay_secs": "60",
          "connection_port": 5985,
          "login_credential_local_reference": {
            "kind": "app_credential",
            "uuid": "$($wincredUUID)"
          }
        },
        "uuid": "$($Resource2UUID)",
        "create_spec": {
          "name": "vm-@@{calm_array_index}@@-@@{calm_time}@@",
          "type": "PROVISION_VMWARE_VM",
          "drs_mode": true,
          "cluster": "$($Datavar.pocname)",
          "template": "$($Winimage.config.instanceUuid)",
          "storage_pod": "OS",
          "resources": {
            "template_nic_list": [{
              "net_name": "key-vim.host.PortGroup-$($datagen.nw1name)",
              "key": 4000
            }],
            "nic_list": [],
            "num_vcpus_per_socket": 1,
            "num_sockets": 4,
            "memory_size_mib": 8192,
            "guest_customization": {
              "customization_type": "GUEST_OS_WINDOWS",
              "windows_data": {
                "domain": "$($datagen.domainname)",
                "domain_user": "administrator",
                "dns_primary": "$($datage.dc1ip)",
                "computer_name": "vm-@@{calm_array_index}@@-@@{calm_time}@@",
                "command_list": ["cmd.exe /c netsh advfirewall set allprofiles state off", "powershell -Command {Set-ItemProperty 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server\\' -Name \"fDenyTSConnections\" -Value 0}", "powershell -Command &quot;Enable-PSRemoting -Force", "cmd.exe /c winrm quickconfig -q", "cmd.exe /c winrm quickconfig -transport:http", "cmd.exe /c winrm set winrm/config @{MaxTimeoutms=\"1800000\"}", "cmd.exe /c winrm set winrm/config/winrs @{MaxMemoryPerShellMB=\"300\"}", "cmd.exe /c winrm set winrm/config/service @{AllowUnencrypted=\"true\"}", ""],
                "auto_logon": true,
                "network_settings": [{
                  "is_dhcp": false,
                  "subnet_mask": "$($Datavar.infrasubnetmask)",
                  "gateway_default": "$($Datavar.infragateway)",
                  "ip": "$($datagen.WinTemplateIP)"
                }],
               "domain_password": {
                  "value": "$($datagen.SysprepPassword)",
                  "attrs": {
                    "is_secret_modified": true
                  }
                },
                "organization_name": "Nutanix",
                "login_count": 1,
                "is_domain": true,
                "timezone": "110",
                "full_name": "Nutanix",
                "password": {
                  "value": "$($Datavar.pepass)",
                  "attrs": {
                    "is_secret_modified": true
                  }
                },
                "dns_secondary": "$($datage.dc2ip)"
              }
            },
            "account_uuid": "$($accountuuid)"
          }
        }
      }],
      "credential_definition_list": [{
        "name": "SysprepCreds",
        "type": "PASSWORD",
        "username": "administrator",
        "secret": {
          "attrs": {
            "is_secret_modified": true
          },
          "value": "$($datavar.pepass)"
        },
        "uuid": "$($WincredUUID)"
      }, {
        "name": "centos",
        "type": "PASSWORD",
        "username": "centos",
        "secret": {
          "attrs": {
            "is_secret_modified": true
          },
          "value": "$($datavar.pepass)"
        },
        "uuid": "$($LincredUUID)"
      }]
    }
  },
  "api_version": "3.0",
  "metadata": {
    "use_categories_mapping": false,
    "name": "Environment-$($project.spec.name)",
    "kind": "environment",
    "owner_reference": {
      "kind": "user",
      "name": "admin",
      "uuid": "00000000-0000-0000-0000-000000000000"
    }
  }
}
"@


$json2 = @"
{
  "metadata": {
    "use_categories_mapping": false,
    "name": "$($name)",
    "spec_version": $($environment.metadata.spec_version),
    "kind": "environment",
    "uuid":  "$($environment.metadata.uuid)",
    "owner_reference": {
      "kind": "user",
      "name": "admin",
      "uuid": "00000000-0000-0000-0000-000000000000"
    }
  }
}
"@

  if ($environment.metadata.uuid){

    write-log -message "Existing ENV found, Updating"

    $object1 = $json1 | convertfrom-json
    $object2 = $json2 | convertfrom-json
    $object1.metadata = $object2.metadata
    $json1 = $object1 | ConvertTo-Json -depth 100

    if ($debug -ge 2 ){
      write $json2
      write $json1
    }

  }

  try{
    $task = Invoke-RestMethod -Uri $URL -method $method -body $json1 -ContentType 'application/json'  -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method $method -body $json1 -ContentType 'application/json' -headers $headers;
  }
  Return $task
} 

Function REST-List-SSP-Account {
   Param (
     [object] $datagen,
     [object] $datavar
   )

   $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
   $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
   $headers = @{ Authorization = "Basic $encodedCredentials" }

   $AccountID = (new-guid).Guid

   write-log -message "Listing Account / Provider $AccountID"

   $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/accounts/list"
   write-log -message "Loading Json"
   $json = @"
 {
 }
"@
   try{
     $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json'  -headers $headers;
   } catch {
     sleep 10

     $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

     $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers;
   }

   Return $task
}

Function REST-Runbook-Import-Blob {
  Param (
    [object] $PCClusterIP,
    [object] $PCClusterUser,
    [object] $PCClusterPass,
    [string] $Json,
    [string] $project_uuid,
    [string] $name
  )

  $credPair = "$($PCClusterUser):$($PCClusterPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }


  write-log -message "Importing Runbook $filename"
  
  $URL = "https://$($PCClusterIP):9440/api/nutanix/v3/runbooks/import_file"

  $boundary = [System.Guid]::NewGuid().ToString(); 
  $LF = "`r`n";
  $bodyLines = (
      "--$boundary",
      "Content-Disposition: form-data; name=`"file`"; filename=`"blob`"",
      '',
      $Json,
      "--$boundary",
      "Content-Disposition: form-data; name=`"name`"",
      '',
      $name,
      "--$boundary",
      "Content-Disposition: form-data; name=`"project_uuid`"",
      '',
      $project_uuid,
      "--$boundary",
      "Content-Disposition: form-data; name=`"passphrase`"",
      '',
      1,
      "--$boundary--"
  ) -join $LF


  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $bodyLines -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $bodyLines -headers $headers;
  }

  Return $task
} 


Function REST-Add-Endpoint-Windows {
  Param (
    [string] $PCClusterIP,
    [string] $PCClusterUser,
    [string] $PCClusterPass,
    [object] $project,
    [string] $IP,
    [string] $username,
    [string] $Password,
    [string] $credname,
    [string] $Endpname
  )

  $credPair = "$($PCClusterUser):$($PCClusterPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Generating new UUIDs"
  $credUUID = (new-guid).guid
  $EndpointUUid = (new-guid).guid
  $json = @"
{
  "api_version": "3.0",
  "metadata": {
    "kind": "endpoint",
    "project_reference": {
      "name": "$($project.status.name)",
      "kind": "project",
      "uuid": "$($project.metadata.uuid)"
    },
    "uuid": "$($EndpointUUid)"
  },
  "spec": {
    "resources": {
      "type": "Windows",
      "attrs": {
        "credential_definition_list": [{
          "description": "",
          "username": "$($username)",
          "type": "PASSWORD",
          "name": "$($credname)",
          "secret": {
            "attrs": {
              "is_secret_modified": true
            },
            "value": "$($Password)"
          },
          "uuid": "$($credUUID)"
        }],
        "login_credential_reference": {
          "name": "$($credname)",
          "kind": "app_credential",
          "uuid": "$($credUUID)"
        },
        "values": ["$($IP)"],
        "value_type": "IP",
        "port": 5985,
        "connection_protocol": "http"
      }
    },
    "name": "$($Endpname)"
  }
}
"@
  $URL = "https://$($PCClusterIP):9440/api/nutanix/v3/endpoints"

  write-log -message "Creating EndPoint"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers
  } catch {
    sleep 10
    $_.Exception.Message
    $respStream = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($respStream)
    $respBody = $reader.ReadToEnd() | ConvertFrom-Json
    write-log -message $respBody
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers
    Return $RespErr
  } 
  $return = @{
    EndpointUUID = $EndpointUUid
    EndpointName = $Endpname
    CredUUID     = $credUUID
    CredName     = $credname
  }
  Return $return
} 


Function REST-Get-Runbook-Detailed {
  Param (
    [object] $PCClusterIP,
    [object] $PCClusterUser,
    [object] $PCClusterPass,
    [string] $uuid
  )

  $credPair = "$($PCClusterUser):$($PCClusterPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }


  $URL = "https://$($PCClusterIP):9440/api/nutanix/v3/runbooks/$($uuid)"

  write-log -message "Getting Runbook Detail"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers
  } catch {
    sleep 10
    $_.Exception.Message
    $respStream = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($respStream)
    $respBody = $reader.ReadToEnd() | ConvertFrom-Json
    write-log -message $respBody
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers
    Return $RespErr
  } 

  Return $task
} 

Function REST-Get-Runbooks {
  Param (
    [object] $PCClusterIP,
    [object] $PCClusterUser,
    [object] $PCClusterPass
  )

  $credPair = "$($PCClusterUser):$($PCClusterPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Generating new UUIDs"
  $credUUID = (new-guid).guid
  $EndpointUUid = (new-guid).guid
  $json = @"
{
  "length": 20,
  "offset": 0,
  "filter": "state!=DELETED"
}
"@
  $URL = "https://$($PCClusterIP):9440/api/nutanix/v3/runbooks/list"

  write-log -message "Retrieving Runbooks"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers
  } catch {
    sleep 10
    $_.Exception.Message
    $respStream = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($respStream)
    $respBody = $reader.ReadToEnd() | ConvertFrom-Json
    write-log -message $respBody
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers
    Return $RespErr
  } 

  Return $task
} 

Function REST-Update-Runbook {
  Param (
    [object] $PCClusterIP,
    [object] $PCClusterUser,
    [object] $PCClusterPass,
    [object] $RunbookDetail
  )

  $credPair = "$($PCClusterUser):$($PCClusterPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Preparing Payload for update"

  $RunbookDetail.psobject.members.remove("Status")

  $URL = "https://$($PCClusterIP):9440/api/nutanix/v3/runbooks/$($RunbookDetail.metadata.uuid)"

  $json = $RunbookDetail | convertto-json -depth 100
  if ($debug -ge 2){
    $json | out-file c:\temp\runbook.json
  }
  write-log -message "Updating Runbook $($RunbookDetail.metadata.uuid)"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $json -ContentType 'application/json' -headers $headers
  } catch {
    sleep 10
    $_.Exception.Message
    $respStream = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($respStream)
    $respBody = $reader.ReadToEnd() | ConvertFrom-Json
    write-log -message $respBody
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $json -ContentType 'application/json' -headers $headers
    Return $RespErr
  } 

  Return $task
} 

Function REST-Enable-ShowBack {
   Param (
     [object] $datagen,
     [object] $datavar
   )

   $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
   $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
   $headers = @{ Authorization = "Basic $encodedCredentials" }

   $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/app_showback/enable"
   write-log -message "Enabling Showback"
   $json = @"
{
  "showback":true
}
"@
   try{
     $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json'  -headers $headers;
   } catch {
     sleep 10

     $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

     $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers;
   }

   Return $task
}


Function REST-Update-SSP-AccountCost {
   Param (
     [object] $datagen,
     [object] $datavar,
     [object] $accountdetail
   )

   $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
   $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
   $headers = @{ Authorization = "Basic $encodedCredentials" }
   $accountdetail.psobject.members.remove("Status")
   $ShowbackRatesUUID = (new-guid).Guid
   
$json = @"
{
    "price_items": [{
        "details": {
          "occurrence": "recurring"
        },
        "state_cost_list": [{
          "state": "ON",
          "cost_list": [{
            "interval": "hour",
            "name": "sockets",
            "value": 0.05
          }, {
            "interval": "hour",
            "name": "memory",
            "value": 0.05
          }, {
            "interval": "hour",
            "name": "storage",
            "value": 0.003
          }]
        }, {
          "state": "OFF",
          "cost_list": [{
            "interval": "hour",
            "name": "storage",
            "value": 0.001
          }]
        }],
        "uuid": "$($ShowbackRatesUUID)"
      }]
}
"@
  $Costobject = $json | convertfrom-json
  $accountdetail.spec.resources | Add-Member -notepropertyname "price_items" -notepropertyvalue "0" -force
  $accountdetail.spec.resources.price_items = $Costobject.price_items

  $outputJSON = $accountdetail | ConvertTo-Json -depth 100

  write-log -message "Adding Cost to Account"

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/accounts/$($account.entities.metadata.uuid)"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $outputJSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $outputJSON -ContentType 'application/json' -headers $headers;
  }

  Return $task
}

Function REST-List-SSP-AccountDetail {
   Param (
     [object] $datagen,
     [object] $datavar,
     [object] $account
   )

   $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
   $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
   $headers = @{ Authorization = "Basic $encodedCredentials" }


   write-log -message "Listing Account / Provider $($account.metadata.uuid)"

   $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/accounts/$($account.metadata.uuid)"

   try{
     $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
   } catch {
     sleep 10

     $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

     $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
   }

   Return $task
}

Function REST-Verify-SSP-Account {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $Account
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }


  write-log -message "Verifying account $Accountuuid"
  
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/accounts/$($Account.metadata.uuid)/verify"
  write-log -message "Using URL $url"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }

  Return $task
} 

Function REST-Create-SSP-KarbonAccount {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $karbonClusterUUID
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  $AccountID = (new-guid).Guid

  write-log -message "Creating Account / Provider $AccountID"
  
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/accounts"
  write-log -message "Loading Json"
  $json = @"
{
  "api_version": "3.0",
  "metadata": {
    "kind": "account",
    "uuid": "$AccountID"
  },
  "spec": {
    "name": "Karbon",
    "resources": {
      "type": "k8s",
      "data": {
        "type": "karbon",
        "cluster_uuid": "$($karbonClusterUUID)"
      }
    }
  }
}
"@
  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json'  -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-Create-SSP-VMwareAccount {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  $AccountID = (new-guid).Guid

  write-log -message "Creating Account / Provider $AccountID"
  
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/accounts"
  write-log -message "Loading Json"
  $json = @"
{
  "api_version": "3.0",
  "metadata": {
    "kind": "account",
    "uuid": "$AccountID"
  },
  "spec": {
    "name": "VMWare ESXi",
    "resources": {
      "type": "vmware",
      "data": {
        "server": "$($datavar.VCenterIP)",
        "datacenter": "Nutanix",
        "username": "$($datavar.VCenterUser)",
        "password": {
          "value": "$($datavar.VCenterPass)",
          "attrs": {
            "is_secret_modified": true
          }
        },
        "port": "443"
      }
    }
  }
}
"@
  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json'  -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 


Function REST-Update-SSP-VMwareAccount {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $account
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Creating Account / Provider $($Account.metadata.uuid)"
  
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/accounts/$($Account.metadata.uuid)"

  write-log -message "Using URL $URL "
  write-log -message "Datacenter is $($Account.status.resources.data.datacenter)"
  write-log -message "Loading Json"

  $json = @"

{
  "spec": {
    "name": "$($account.status.name)",
    "resources": {
      "type": "vmware",
      "data": {
        "username": "$($Account.status.resources.data.username)",
        "password": {
          "attrs": {
            "is_secret_modified": false
          }
        },
        "port": "443",
        "server": "$($Account.status.resources.data.server)",
        "datacenter": "Nutanix"
      }
    }
  },
  "api_version": "3.0",
  "metadata": {
    "use_categories_mapping": false,
    "name": "$($account.status.name)",
    "spec_version": $($account.metadata.spec_version),
    "kind": "account",
    "uuid": "$($Account.metadata.uuid)",
    "owner_reference": {
      "kind": "user",
      "name": "admin",
      "uuid": "00000000-0000-0000-0000-000000000000"
    }
  }
}
"@

write $json
  try{
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $json -ContentType 'application/json'  -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 



Function REST-Create-Environment-AHV {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $project,
    [object] $subnet,
    [object] $Winimage,
    [object] $Linimage
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $useruuid = ($project.spec.resources.user_reference_list | where {$_.name -eq "svc_build"}).uuid

  write-log -message "Updating Environment $($project.metadata.uuid)"
  write-log -message "With Subnet $($subnet.uuid)"
  write-log -message "Windows Image $($Winimage.metadata.uuid)"
  write-log -message "Linux Image $($Linimage.metadata.uuid)"
  write-log -message "Updating Environment $($project.spec.resources.environment_reference_list.uuid)"
  $WincredUUID = (new-guid).Guid
  $LincredUUID = (new-guid).Guid
  $Resource1UUID = (new-guid).Guid
  $Resource2UUID = (new-guid).Guid
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/environments"
  write-log -message "Loading Json"
  $json = @"
{
  "api_version": "3.0",
  "metadata": {
    "kind": "environment"
  },
  "spec": {
    "name": "Environment-$($project.spec.name)", 
    "resources": {
      "substrate_definition_list": [{
        "variable_list": [],
        "type": "AHV_VM",
        "os_type": "Windows",
        "action_list": [],
        "create_spec": {
          "name": "-@@{calm_array_index}@@-@@{calm_time}@@",
          "resources": {
            "disk_list": [{
              "data_source_reference": {
                "kind": "image",
                "name": "$($Winimage.spec.name)",
                "uuid": "$($Winimage.metadata.uuid)" 
              },
              "device_properties": {
                "device_type": "DISK",
                "disk_address": {
                  "device_index": 0,
                  "adapter_type": "SCSI"
                }
              }
            }],
            "boot_config": {
              "boot_device": {
                "disk_address": {
                  "device_index": 0,
                  "adapter_type": "SCSI"
                }
              }
            },
            "num_sockets": 4,
            "num_vcpus_per_socket": 1,
            "memory_size_mib": 4096,
            "guest_customization": {
              "sysprep": {
                "unattend_xml": "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<unattend xmlns=\"urn:schemas-microsoft-com:unattend\">\n    <settings pass=\"oobeSystem\">\n        <component name=\"Microsoft-Windows-International-Core\" processorArchitecture=\"amd64\" publicKeyToken=\"31bf3856ad364e35\" language=\"neutral\" versionScope=\"nonSxS\" xmlns:wcm=\"http://schemas.microsoft.com/WMIConfig/2002/State\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n            <InputLocale>0413:00020409</InputLocale>\n            <SystemLocale>en-US</SystemLocale>\n            <UILanguageFallback>en-US</UILanguageFallback>\n            <UserLocale>nl-NL</UserLocale>\n        </component>\n        <component name=\"Microsoft-Windows-Shell-Setup\" processorArchitecture=\"amd64\" publicKeyToken=\"31bf3856ad364e35\" language=\"neutral\" versionScope=\"nonSxS\" xmlns:wcm=\"http://schemas.microsoft.com/WMIConfig/2002/State\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n            <AutoLogon>\n                <Enabled>true</Enabled>\n                <LogonCount>9999999</LogonCount>\n                <Username>Administrator</Username>\n                <Password>\n                    <PlainText>true</PlainText>\n                    <Value>$($datavar.pepass)</Value>\n                </Password>\n            </AutoLogon>\n            <OOBE>\n                <HideEULAPage>true</HideEULAPage>\n                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>\n                <NetworkLocation>Home</NetworkLocation>\n                <ProtectYourPC>2</ProtectYourPC>\n            </OOBE>\n            <UserAccounts>\n                <AdministratorPassword>\n                    <PlainText>true</PlainText>\n                    <Value>$($datavar.pepass)</Value>\n                </AdministratorPassword>\n            </UserAccounts>\n            <FirstLogonCommands>\n                <SynchronousCommand wcm:action=\"add\">\n                    <CommandLine>cmd.exe /c winrm quickconfig -q</CommandLine>\n                    <Description>Win RM quickconfig -q</Description>\n                    <Order>20</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <CommandLine>cmd.exe /c winrm quickconfig -transport:http</CommandLine>\n                    <Description>Win RM quickconfig -transport:http</Description>\n                    <Order>21</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <CommandLine>cmd.exe /c winrm set winrm/config @{MaxTimeoutms=\"1800000\"}</CommandLine>\n                    <Description>Win RM MaxTimoutms</Description>\n                    <Order>22</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <CommandLine>cmd.exe /c winrm set winrm/config/winrs @{MaxMemoryPerShellMB=\"300\"}</CommandLine>\n                    <Description>Win RM MaxMemoryPerShellMB</Description>\n                    <Order>23</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <CommandLine>cmd.exe /c winrm set winrm/config/service @{AllowUnencrypted=\"true\"}</CommandLine>\n                    <Description>Win RM AllowUnencrypted</Description>\n                    <Order>24</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <CommandLine>cmd.exe /c winrm set winrm/config/service/auth @{Basic=\"true\"}</CommandLine>\n                    <Description>Win RM auth Basic</Description>\n                    <Order>25</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <CommandLine>cmd.exe /c winrm set winrm/config/client/auth @{Basic=\"true\"}</CommandLine>\n                    <Description>Win RM auth Basic</Description>\n                    <Order>26</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <CommandLine>cmd.exe /c winrm set winrm/config/listener?Address=*+Transport=HTTP @{Port=\"5985\"} </CommandLine>\n                    <Description>Win RM listener Address/Port</Description>\n                    <Order>27</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <CommandLine>cmd.exe /c netsh advfirewall firewall set rule group=\"remote administration\" new enable=yes </CommandLine>\n                    <Description>Win RM adv firewall enable</Description>\n                    <Order>29</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <CommandLine>cmd.exe /c net stop winrm </CommandLine>\n                    <Description>Stop Win RM Service </Description>\n                    <Order>28</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <CommandLine>cmd.exe /c net start winrm </CommandLine>\n                    <Description>Start Win RM Service</Description>\n                    <Order>32</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <CommandLine>powershell -Command &quot;Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force&quot;</CommandLine>\n                    <Description>Set PowerShell ExecutionPolicy</Description>\n                    <Order>1</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <Order>2</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                    <CommandLine>powershell -Command &quot;Enable-PSRemoting -Force&quot;</CommandLine>\n                    <Description>Enable PowerShell Remoting</Description>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <Order>61</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                    <CommandLine>powershell -Command &quot;Enable-NetFirewallRule -DisplayGroup \"Remote Desktop\"&quot;</CommandLine>\n                    <Description>Rule RDP Filewall</Description>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <Order>62</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                    <CommandLine>powershell -Command &quot;Set-ItemProperty 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server\\WinStations\\RDP-Tcp\\' -Name \"UserAuthentication\" -Value 1&quot;</CommandLine>\n                    <Description>Enable RDP2016</Description>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <Order>63</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                    <CommandLine>powershell -Command &quot;Set-ItemProperty 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server\\' -Name \"fDenyTSConnections\" -Value 0&quot;</CommandLine>\n                    <Description>Enable RDP2016p2</Description>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <Order>5</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                    <Description>RDP adv firewall enable</Description>\n                    <CommandLine>cmd.exe /c netsh advfirewall firewall set rule group=&quot;Remote Desktop&quot; new enable=yes </CommandLine>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <Order>31</Order>\n                    <CommandLine>cmd.exe /c sc config winrm start= auto</CommandLine>\n                    <RequiresUserInput>true</RequiresUserInput>\n                    <Description>No-Delay Auto start WinRM on boot</Description>\n                </SynchronousCommand>\n                <SynchronousCommand wcm:action=\"add\">\n                    <Order>30</Order>\n                    <RequiresUserInput>true</RequiresUserInput>\n                    <CommandLine>cmd.exe /c netsh advfirewall set allprofiles state off</CommandLine>\n                    <Description>Disable Windows Firewall</Description>\n                </SynchronousCommand>\n            </FirstLogonCommands>\n<ShowWindowsLive>false</ShowWindowsLive>\n        </component>\n    </settings>\n    <settings pass=\"specialize\">\n        <component name=\"Microsoft-Windows-Deployment\" processorArchitecture=\"amd64\" publicKeyToken=\"31bf3856ad364e35\" language=\"neutral\" versionScope=\"nonSxS\" xmlns:wcm=\"http://schemas.microsoft.com/WMIConfig/2002/State\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n            <RunSynchronous>\n                <RunSynchronousCommand wcm:action=\"add\">\n                    <Order>1</Order>\n                    <Path>net user administrator /active:Yes</Path>\n                    <WillReboot>Never</WillReboot>\n                </RunSynchronousCommand>\n            </RunSynchronous>\n        </component>\n        <component name=\"Microsoft-Windows-Security-SPP-UX\" processorArchitecture=\"amd64\" publicKeyToken=\"31bf3856ad364e35\" language=\"neutral\" versionScope=\"nonSxS\" xmlns:wcm=\"http://schemas.microsoft.com/WMIConfig/2002/State\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n            <SkipAutoActivation>true</SkipAutoActivation>\n        </component>\n        <component name=\"Microsoft-Windows-Shell-Setup\" processorArchitecture=\"amd64\" publicKeyToken=\"31bf3856ad364e35\" language=\"neutral\" versionScope=\"nonSxS\" xmlns:wcm=\"http://schemas.microsoft.com/WMIConfig/2002/State\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n            <ComputerName>*</ComputerName>\n        </component>\n    </settings>\n    <settings pass=\"windowsPE\">\n        <component name=\"Microsoft-Windows-International-Core-WinPE\" processorArchitecture=\"amd64\" publicKeyToken=\"31bf3856ad364e35\" language=\"neutral\" versionScope=\"nonSxS\" xmlns:wcm=\"http://schemas.microsoft.com/WMIConfig/2002/State\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n            <SetupUILanguage>\n            <UILanguage>en-US </UILanguage>\n            </SetupUILanguage>\n            <InputLocale>en-US </InputLocale>\n            <SystemLocale>en-US </SystemLocale>\n            <UILanguage>en-US </UILanguage>\n            <UILanguageFallback>en-US </UILanguageFallback>\n            <UserLocale>en-US </UserLocale>\n        </component>\n    </settings>\n</unattend>"
              }
            },
            "nic_list": [{
              "subnet_reference": {
                "uuid": "$($subnet.uuid)"
              },
              "ip_endpoint_list": []
            }]
          }
        },
        "name": "Untitled",
        "readiness_probe": {
          "connection_type": "POWERSHELL",
          "connection_port": 5985,
          "address": "@@{platform.status.resources.nic_list[0].ip_endpoint_list[0].ip}@@",
          "login_credential_local_reference": {
            "kind": "app_credential",
            "uuid": "$WincredUUID" 
          }
        },
        "editables": {
          "create_spec": {
            "resources": {
              "disk_list": {},
              "nic_list": {},
              "serial_port_list": {}
            }
          }
        },
        "uuid": "$Resource1UUID"
      }, {
        "variable_list": [],
        "type": "AHV_VM",
        "os_type": "Linux",
        "action_list": [],
        "create_spec": {
          "name": "-@@{calm_array_index}@@-@@{calm_time}@@",
          "resources": {
            "disk_list": [{
              "data_source_reference": {
                "kind": "image",
                "name": "$($Linimage.spec.name)",
                "uuid": "$($Linimage.metadata.uuid)" 
              },
              "device_properties": {
                "device_type": "DISK",
                "disk_address": {
                  "device_index": 0,
                  "adapter_type": "SCSI"
                }
              }
            }],
            "boot_config": {
              "boot_device": {
                "disk_address": {
                  "device_index": 0,
                  "adapter_type": "SCSI"
                }
              }
            },
            "guest_customization": {
              "cloud_init": {
                "user_data": "#cloud-config\npassword: $($datavar.pepass)\nchpasswd: { expire: False }\nssh_pwauth: True"
              }
            },
            "num_sockets": 2,
            "num_vcpus_per_socket": 1,
            "memory_size_mib": 2048,
            "nic_list": [{
              "subnet_reference": {
                "uuid": "$($subnet.uuid)"
              },
              "ip_endpoint_list": []
            }]
          }
        },
        "name": "Untitled",
        "readiness_probe": {
          "connection_type": "SSH",
          "connection_port": 22,
          "address": "@@{platform.status.resources.nic_list[0].ip_endpoint_list[0].ip}@@",
          "login_credential_local_reference": {
            "kind": "app_credential",
            "uuid": "$LincredUUID" 
          }
        },
        "editables": {
          "create_spec": {
            "resources": {
              "disk_list": {},
              "nic_list": {},
              "serial_port_list": {}
            }
          }
        },
        "uuid": "$Resource2UUID"
      }],
      "credential_definition_list": [{
        "name": "SysprepCreds",
        "type": "PASSWORD",
        "username": "administrator",
        "secret": {
          "attrs": {
            "is_secret_modified": true
          },
          "value": "$($datavar.pepass)"
        },
        "uuid": "$WincredUUID"
      }, {
        "name": "centos",
        "type": "PASSWORD",
        "username": "centos",
        "secret": {
          "attrs": {
            "is_secret_modified": true
          },
          "value": "$($datavar.pepass)"
        },
        "uuid": "$LincredUUID"
      }]
    }
  }
}
"@
  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json'  -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 






Function REST-Update-Project {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername,
    [array]  $Subnet,
    [array]  $consumer,
    [array]  $projectadmin,
    [array]  $cluster,
    [string] $customer,    
    [array]  $admingroup,
    [array]  $usergroup,    
    [array]  $Project,
    [string]  $environmentUUID,
    [int] $Projectspec,
    [object] $account
  )

  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  write-log -message "Executing Project Update"
  [int]$spec 
  $UserGroupURL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/projects_internal/$($project.metadata.uuid)"
  $json1 = @"

{
  "spec": {
    "access_control_policy_list": [
    ],
    "project_detail": {
      "name": "$($project.spec.name)", 
      "resources": {
        "resource_domain": {
          "resources": [{
              "limit": 1717986918400,
              "resource_type": "STORAGE"
            },
            {
              "limit": 40,
              "resource_type": "VCPUS"
            },
            {
              "limit": 85899345920,
              "resource_type": "MEMORY"
            }
          ]
        },
        "account_reference_list": [

        ],
        "environment_reference_list": [{
          "kind": "environment",
          "uuid": "$environmentUUID"
        }],
        "user_reference_list": [

        ],
        "external_user_group_reference_list": [{
            "kind": "user_group",
            "name": "$($admingroup.status.resources.directory_service_user_group.distinguished_name)",
            "uuid": "$($admingroup.metadata.uuid)"
          },
          {
            "kind": "user_group",
            "name": "$($usergroup.status.resources.directory_service_user_group.distinguished_name)",
            "uuid": "$($usergroup.metadata.uuid)"
          }
        ],
        "subnet_reference_list": [{
          "kind": "subnet",
          "name": "$($subnet.name)",
          "uuid": "$($subnet.uuid)"
        }]
      },
      "description": "$($project.spec.description)"
    },
    "user_list": [

    ],
    "user_group_list": [

    ]
  },
  "api_version": "3.1",
  "metadata": {
    "kind": "project",
    "uuid": "$($project.metadata.uuid)",
    "project_reference": {
      "kind": "project",
      "name": "$($project.spec.name)", 
      "uuid": "$($project.metadata.uuid)"
    },
    "spec_version": $($Projectspec),
    "owner_reference": {
      "kind": "user",
      "uuid": "00000000-0000-0000-0000-000000000000",
      "name": "admin"
    },
    "categories": {

    }
  }
}

"@


 $json2 = @"
        {
          "uuid": "$($account.metadata.uuid)",
          "kind": "account",
          "name": "vmware"
        }
"@

  write-log -message "Converting Child"

  $child = $json2 | convertfrom-json

  write-log -message "Injecting Child into Parent"

  $object1 = $json1 | convertfrom-json
  $object1.spec.project_detail.resources.account_reference_list += $child

  write-log -message "Updating Default Project $($project.metadata.uuid)"

  $json1 = $object1 | ConvertTo-Json -depth 100

  $countretry = 0
  do {
    $countretry ++
    try{
      $task = Invoke-RestMethod -Uri $UserGroupURL -method "put" -body $json1 -ContentType 'application/json' -headers $headers;
      $RESTSuccess = 1
      sleep 10
    } catch {
      $task = Invoke-RestMethod -Uri $UserGroupURL -method "put" -body $json1 -ContentType 'application/json' -headers $headers;
      sleep 20
      write-log -message "Retry REST $countretry"
    }
  } until ($RESTSuccess -eq 1 -or $countretry -ge 6)

  if ($RESTSuccess -eq 1){
    write-log -message "Project Update Success"
  } else {
    write-log -message "Project Update Failed" 
  }
  Return $task
} 


Function REST-Update-Xplay-Blueprint {
  Param (
    [Object] $BPObject,
    [object] $datagen,
    [object] $datavar,
    [object] $image,
    [object] $subnet
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Prepping object"

  $BPObject.psobject.properties.Remove('status')

  write-log -message "Replacing Object Variables"

  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "SysprepCreds"}).secret.attrs.is_secret_modified = $true
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "SysprepCreds"}).secret | add-member noteproperty value $datavar.pepass -force
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "DomainCreds"}).secret.attrs.is_secret_modified = $true
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "DomainCreds"}).secret | add-member noteproperty value $datavar.pepass -force
  ($BPObject.spec.resources.substrate_definition_list[0]).create_spec.resources.disk_list[0].data_source_reference | add-member noteproperty uuid $image.metadata.uuid -force
  $bpobject.spec.resources.substrate_definition_list | where {$_.Type -eq "AHV_VM"} | % {$_.create_spec.resources.nic_list.subnet_reference.uuid = $subnet.uuid}
  $bpobject.spec.resources.substrate_definition_list | where {$_.Type -eq "AHV_VM"} | % {$_.create_spec.resources.nic_list.subnet_reference.name = $subnet.name}
  (($BPObject.spec.resources.app_profile_list[0]).variable_list | where {$_.name -eq "NLBIP"}).value = $datagen.IISNLBIP
  (($BPObject.spec.resources.app_profile_list[0]).variable_list | where {$_.name -eq "MachineName"}).value = "IIS-$($datavar.pocname)-01"
  (($BPObject.spec.resources.app_profile_list[0]).variable_list | where {$_.name -eq "DomainFQDN"}).value = $datagen.Domainname


  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($BPObject.metadata.uuid)"

  $Json = $BPObject | ConvertTo-Json -depth 100
  if ($debug -eq 2){
    $Json | out-file "C:\temp\IIS.json"
  }

  write-log -message "Executing Import"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $Json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $Json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 



Function REST-Get-ACPs {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername
  )

  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing ACPs List"

  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/access_control_policies/list"
  $Payload= @{
    kind="access_control_policy"
    offset=0
    length=250
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


Function REST-Create-Project {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $customer,
    [string] $domainname,
    [string] $UserGroupName,    
    [string] $UserGroupUUID,
    [string] $AdminGroupName,
    [string] $AdminGroupUUID,
    [string] $SubnetName,    
    [string] $SubnetUUID
  )

  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $domainparts = $domainname.split(".")
  write-log -message "Executing Project Create"

  $UserGroupURL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/projects"
  $json = @"
{
  "spec": {
    "name": "$($customer) Project 1",
    "resources": {
      "resource_domain":{  
         "resources":[  
            {  
               "limit":40,
               "resource_type":"VCPUS"
            },
            {  
               "limit":1717986918400,
               "resource_type":"STORAGE"
            },
            {  
               "limit":85899345920,
               "resource_type":"MEMORY"
            }
         ]
      },
      "subnet_reference_list":[  
         {  
            "kind":"subnet",
            "name":"$($SubnetName)",
            "uuid":"$($SubnetUUID)"
         }
      ],
      "external_user_group_reference_list": [
        {  
           "kind":"user_group",
           "uuid":"$($UserGroupUUID)",
           "name":"$($UserGroupName)"
        },
        {  
           "kind":"user_group",
           "uuid":"$($AdminGroupUUID)",
           "name":"$($AdminGroupName)"
        }
      ],

      "user_reference_list": [
      ]
    },
    "description": "SSP Definition for $($customer)"
  },
  "api_version": "3.1.0",
  "metadata": {
    "kind": "project",
    "spec_version": 0,
    "owner_reference":{  
       "kind":"user",
       "uuid":"00000000-0000-0000-0000-000000000000",
       "name":"admin"
    },
    "categories": {

    }
  }
}
"@
  try{
    $task = Invoke-RestMethod -Uri $UserGroupURL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
    $task = Invoke-RestMethod -Uri $UserGroupURL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  }

  sleep 5
  Return $task

} 





Function REST-Create-ACP-RoleMap {
  Param (
    [string] $ClusterPC_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $Customer,
    [array]  $role,
    [array] $group,
    [array] $project,
    [string] $GroupType
  )
  ## This module is depricated afaik done in project update...
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  write-log -message "Executing ACP Create"

  $URL = "https://$($ClusterPC_IP):9440/api/nutanix/v3/access_control_policies"
  $json = @"
{
  "spec": {
    "name": "ACP $($Customer) for $($GroupType)",
    "resources": {
      "role_reference": {
        "kind": "role",
        "uuid": "$($role.metadata.uuid)"
      },
      "user_reference_list": [],
      "filter_list": {
        "context_list": [{
          "entity_filter_expression_list": [{
            "operator": "IN",
            "left_hand_side": {
              "entity_type": "ALL"
            },
            "right_hand_side": {
              "collection": "ALL"
            }
          }],
          "scope_filter_expression_list": [{
              "operator": "IN",
              "right_hand_side": {
                "uuid_list": ["$($project.metadata.uuid)"]
              },
              "left_hand_side": "PROJECT"
            }

          ]
        }]
      },
      "user_group_reference_list": [{
        "kind": "user_group",
        "uuid": "$($group.metadata.uuid)"
      }]
    },
    "description": "ACP $($Customer) for $($GroupType)"
  },
  "metadata": {
    "kind": "access_control_policy"
  }
}
"@
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  }catch{
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  }
  Return $task
} 



Function REST-Query-DetailBP {
  Param (
    [object] $datavar,
    [object] $datagen,
    [string] $uuid
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Getting Blueprint Detail for $uuid"

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($uuid)"

  write-log -message "URL is $url"

  try {
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "get" -headers $headers

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }  
  Return $task
} 



Function REST-Update-Splunk-Blueprint-Image {
  Param (
    [object] $BPObject,
    [object] $datagen,
    [object] $Account,
    [object] $datavar,
    [object] $image
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Loading Json"

$JSON2 = @"
{
  "substrate_definition_list": [{
        "variable_list": [],
        "action_list": [],
        "name": "$($datagen.splunkname)",
        "os_type": "Linux",
        "type": "VMWARE_VM",
        "readiness_probe": {
          "connection_type": "SSH",
          "retries": "5",
          "disable_readiness_probe": false,
          "timeout_secs": "120",
          "address": "@@{platform.ipAddressList[0]}@@",
          "connection_port": 22,
          "login_credential_local_reference": {
            "kind": "app_credential",
            "name": "Splunk_VM",
            "uuid": "$(($bpobject.spec.resources.credential_definition_list | where {$_.name -eq "Splunk_VM"}).uuid)"
          },
          "delay_secs": "60"
        },
        "uuid": "$($bpobject.spec.resources.substrate_definition_list.uuid)",
        "description": "",
        "create_spec": {
          "type": "PROVISION_VMWARE_VM",
          "name": "vm-@@{calm_array_index}@@-@@{calm_time}@@",
          "resources": {
            "guest_customization": {
              "customization_type": "GUEST_OS_LINUX",
              "linux_data": {
                "network_settings": [{
                  "is_dhcp": false,
                  "ip": "$($datagen.splunkIP)",
                  "subnet_mask": "$($datavar.infrasubnetmask)",
                  "gateway_default": "$($datavar.infragateway)"
                }],
                "dns_primary": "$($datagen.dc1ip)",
                "dns_secondary": "$($datagen.dc2ip)",
                "hostname": "$($datagen.splunkname)",
                "domain": "$($datagen.domainname)",
                "timezone": "Europe/Amsterdam"
              }
            },
            "account_uuid": "$($Account.metadata.uuid)",
            "num_vcpus_per_socket": 1,
            "num_sockets": 4,
            "memory_size_mib": 8192
          },
          "drs_mode": true,
          "cluster": "$($datavar.pocname)",
          "template": "$($image.config.instanceuuid)",
          "storage_pod": "OS"
        },
        "editables": {
          "create_spec": {
            "resources": {
              "nic_list": {},
              "controller_list": {},
              "template_nic_list": {},
              "template_controller_list": {},
              "template_disk_list": {},
              "guest_customization": {
                "linux_data": {
                  "network_settings": {}
                }
              }
            }
          }
        }
      }]
}
"@

  $newBPObject = $BPObject
  $newBPObject.psobject.members.remove("Status")
  #$newBPObject.spec.resources.psobject.members.remove("substrate_definition_list")
  $object =  ($JSON2 | convertfrom-json)
  $newBPObject.spec.resources.substrate_definition_list = $object.substrate_definition_list

  $json1 = $newBPObject | convertto-json -depth 100

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($BPObject.metadata.uuid)"

  if ($debug -eq 2){
    $json1 | out-file "C:\temp\BPUpdate2.json"
  }
  write-log -message "Updating Image with Creds for $($BPObject.metadata.uuid)"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $json1 -ContentType 'application/json' -headers $headers
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $json1 -ContentType 'application/json' -headers $headers
    Return $RespErr
  }

  Return $task
} 

Function REST-Update-Generic-MarketPlace-Blueprint {
  Param (
    [object] $blueprintdetail,
    [object] $datagen,
    [object] $datavar,
    [object] $subnet,
    [object] $image,
    [string] $VMname
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  $BPObject = $blueprintdetail

  write-log -message "Prepping object"

  $BPObject.psobject.properties.Remove('status')

  write-log -message "Setting Credential Objects"

  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "CENTOS"}).secret.attrs.is_secret_modified = $true
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "CENTOS"}).secret | add-member noteproperty value $datavar.pepass -force

  write-log -message "Updating Name"

  $BPObject.spec.resources.substrate_definition_list[0].create_spec.name = $VMname

  write-log -message "Correcting Image"

  $blueprintdetail.spec.resources.substrate_definition_list | % {$_.create_spec.resources.disk_list[0].data_source_reference.uuid = $image.metadata.uuid}

  write-log -message "Setting up Subnet"

  $BPObject.spec.resources.substrate_definition_list | % {$_.create_spec.resources.nic_list.subnet_reference.uuid = $subnet.uuid }

  write-log -message "Passing the ball to Calm"

  $Json = $BPObject | ConvertTo-Json -depth 100
   
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($blueprintdetail.metadata.uuid)"

  write-log -message "Executing Update using URL $url"
  if ($debug -ge 2){
    $json | out-file c:\temp\1cd.json
  }

  try{
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $Json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $Json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 


Function REST-Update-1CD-Blueprint {
  Param (
    [object] $blueprintdetail,
    [object] $datagen,
    [object] $datavar,
    [object] $subnet
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  $BPObject = $blueprintdetail

  write-log -message "Prepping object"

  $BPObject.psobject.properties.Remove('status')

  write-log -message "Setting Credential Objects"

  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "Service_account"}).secret.attrs.is_secret_modified = $true
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "Service_account"}).secret | add-member noteproperty value $datavar.pepass -force
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "administrator"}).secret.attrs.is_secret_modified = $true
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "administrator"}).secret | add-member noteproperty value $datavar.pepass -force

  write-log -message "Inserting Token URLs"

  ($BPObject.spec.resources.service_definition_list.variable_list | where {$_.name -eq "Token1URL"}).attrs.is_secret_modified = $true
  ($BPObject.spec.resources.service_definition_list.variable_list | where {$_.name -eq "Token1URL"}) | add-member noteproperty value "https://dl.dropboxusercontent.com/s/6r02cdnwmfxg214/ReleaseToken1.txt" -force
  ($BPObject.spec.resources.service_definition_list.variable_list | where {$_.name -eq "Token2URL"}).attrs.is_secret_modified = $true
  ($BPObject.spec.resources.service_definition_list.variable_list | where {$_.name -eq "Token2URL"}) | add-member noteproperty value "https://dl.dropboxusercontent.com/s/hudk913vmgvxvdn/ReleaseToken2.txt" -force

  write-log -message "Setting up nic and IP"

  $BPObject.spec.resources.substrate_definition_list.create_spec.resources.nic_list.subnet_reference.uuid = $subnet.uuid
  $BPObject.spec.resources.substrate_definition_list.create_spec.resources.nic_list.ip_endpoint_list.type = "ASSIGNED"
  $BPObject.spec.resources.substrate_definition_list.create_spec.resources.nic_list.ip_endpoint_list.ip = $datagen.Mgmt1_VMIP

  write-log -message "Passing the ball to Calm"

  $Json = $BPObject | ConvertTo-Json -depth 100
   
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($blueprintdetail.metadata.uuid)"

  write-log -message "Executing Update using URL $url"
  if ($debug -ge 2){
    $json | out-file c:\temp\1cd.json
  }

  try{
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $Json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $Json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 



Function REST-Update-XenDesktopBP {
  Param (
    [object] $blueprintdetail,
    [object] $datagen,
    [object] $datavar,
    [object] $subnet
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  $BPObject = $blueprintdetail

  write-log -message "Prepping object"

  $BPObject.psobject.properties.Remove('status')

  write-log -message "Setting Credential Objects"
  $netbios = ($datagen.domainname.split("."))[0]
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "Service_Account"}).secret.attrs.is_secret_modified = $true
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "Service_Account"}).secret | add-member noteproperty value $datavar.pepass -force
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "administrator"}).secret.attrs.is_secret_modified = $true
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "administrator"}).secret | add-member noteproperty value $datavar.pepass -force
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "PC_CRED"}).secret.attrs.is_secret_modified = $true
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "PC_CRED"}).secret | add-member noteproperty value $datavar.pepass -force
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "DomainInstallUser"}).secret.attrs.is_secret_modified = $true
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "DomainInstallUser"}).secret | add-member noteproperty value $datavar.pepass -force
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "Domain_Service_Account"}).secret.attrs.is_secret_modified = $true
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "Domain_Service_Account"}).secret | add-member noteproperty value $datavar.pepass -force
  ($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "Domain_Service_Account"}).username = "$($netbios)\svc_HIX"

$DomainPromptPy = @"
api_url = 'https://localhost:9440/PrismGateway/services/rest/v1/authconfig'
headers = {'Content-Type': 'application/json',  'Accept':'application/json'}
#headers = {'Content-Type': 'application/json',  'Accept':'application/json', 'Authorization': 'Bearer {}'.format(jwt)}
r = urlreq(api_url, verb='GET', auth="BASIC", user='admin', passwd='$($datavar.pepass)', headers=headers, verify=False)
#r = urlreq(api_url, verb='GET', headers=headers, verify=False)
if r.ok:
    resp = json.loads(r.content)
    #pprint(resp)
else:
    print "Post request failed", r.content
    exit(1)
authProv = []
for i in resp['directoryList']:
    authProv.append(str(i['domain']))
authProv.append("Create New")
#print (authProv)
print(','.join(authProv))
"@ 

  ($bpobject.spec.resources.app_profile_list[0].variable_list | Where {$_.name -eq "WindowsDomain"}).options.attrs.script = $DomainPromptPy

$ContainerPy = @"
api_url = 'https://$($Datavar.PEClusterIP):9440/PrismGateway/services/rest/v2.0/storage_containers'
headers = {'Content-Type': 'application/json',  'Accept':'application/json'}
#headers = {'Content-Type': 'application/json',  'Accept':'application/json', 'Authorization': 'Bearer {}'.format(jwt)}
r = urlreq(api_url, verb='GET', auth="BASIC", user='admin', passwd='$($Datavar.PEPass)', headers=headers, verify=False)
#r = urlreq(api_url, verb='POST', params=json.dumps(payload), headers=headers, verify=False)
if r.ok:
    resp = json.loads(r.content)
    #pprint(resp)
else:
    print "Post request failed", r.content
    exit(1)
ContainerNames = []
for i in resp['entities']:
    ContainerNames.append(str(i['name']))
ContainerNames.append("Create New")
#print (authProv)
print(','.join(ContainerNames))
"@ 
  ($bpobject.spec.resources.app_profile_list[0].variable_list | Where {$_.name -eq "StorageContainerName"}).options.attrs.script = $ContainerPy

$NetworkPy = @"
api_url = 'https://$($Datavar.PEClusterIP):9440/api/nutanix/v3/subnets/list'
headers = {'Content-Type': 'application/json',  'Accept':'application/json'}
#headers = {'Content-Type': 'application/json',  'Accept':'application/json', 'Authorization': 'Bearer {}'.format(jwt)}

payload = {
  "kind": "subnet",
  "offset": 0,
  "length": 999
}

r = urlreq(api_url, verb='POST', auth="BASIC", user='admin', passwd='$($Datavar.PEPass)', headers=headers, params=json.dumps(payload), verify=False)


#r = urlreq(api_url, verb='POST', params=json.dumps(payload), headers=headers, verify=False)
if r.ok:
    resp = json.loads(r.content)
    #pprint(resp)
else:
    print "Post request failed", r.content
    exit(1)
VLanNames = []
VLanNames.append("AutoSelect")
for i in resp['entities']:
    VLanNames.append(str(i['spec']['name']))

print(','.join(VLanNames))
"@ 
  ($bpobject.spec.resources.app_profile_list[0].variable_list | Where {$_.name -eq "VLanName"}).options.attrs.script = $NetworkPy

$FileServerPy = @"
api_url = 'https://$($Datavar.PEClusterIP):9440/PrismGateway/services/rest/v1/vfilers'
headers = {'Content-Type': 'application/json',  'Accept':'application/json'}
#headers = {'Content-Type': 'application/json',  'Accept':'application/json', 'Authorization': 'Bearer {}'.format(jwt)}
r = urlreq(api_url, verb='GET', auth="BASIC", user='admin', passwd='$($Datavar.PEPass)', headers=headers, verify=False)
#r = urlreq(api_url, verb='POST', params=json.dumps(payload), headers=headers, verify=False)
if r.ok:
    resp = json.loads(r.content)
    #pprint(resp)
else:
    print "Post request failed", r.content
    exit(1)
authProv = []
for i in resp['entities']:
    authProv.append(str(i['name']))
authProv.append("Create New")
#print (authProv)
print(','.join(authProv))
"@ 
  ($bpobject.spec.resources.app_profile_list[0].variable_list | Where {$_.name -eq "FileServer"}).options.attrs.script = $FileServerPy


  write-log -message "PE / PC Pass"

  ($bpobject.spec.resources.app_profile_list[0].variable_list | where {$_.name -eq "Z_PCPassClearText" }).value = $datavar.pepass

  write-log -message "PE IP"
  ($bpobject.spec.resources.app_profile_list[0].variable_list | where {$_.name -eq "PEIP" }).value = $datavar.PEClusterIP

  write-log -message "UserPass"
  ($bpobject.spec.resources.app_profile_list[0].variable_list | where {$_.name -eq "UserPassword" }) | add-member noteproperty value $datavar.pepass
  ($bpobject.spec.resources.app_profile_list[0].variable_list | where {$_.name -eq "UserPassword" }).attrs.is_secret_modified = $true

  write-log -message "AdminPass"
  ($bpobject.spec.resources.app_profile_list[0].variable_list | where {$_.name -eq "AdminPassword" }) | add-member noteproperty value $datavar.pepass
  ($bpobject.spec.resources.app_profile_list[0].variable_list | where {$_.name -eq "AdminPassword" }).attrs.is_secret_modified = $true

  write-log -message "Setting up nic and IP"
  $bpobject.spec.resources.substrate_definition_list  | where {$_.Type -eq "AHV_VM"} | % {$_.create_spec.resources.nic_list.subnet_reference.uuid = $subnet.uuid}

  write-log -message "Passing the ball to Calm"

  $Json = $BPObject | ConvertTo-Json -depth 100
   
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($blueprintdetail.metadata.uuid)"

  write-log -message "Executing Update using URL $url"
  if ($debug -ge 2){
    $json | out-file c:\temp\1cd.json
  }

  try{
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $Json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $Json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-LIST-SSP-VMwareImages {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $Accountuuid
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }


  write-log -message "Getting VMware Templates for $Accountuuid"
  
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/vmware/v6/template/list"
  write-log -message "Loading Json"
  $json = @"
{
  "filter": "account_uuid==$($Accountuuid);"
}
"@
  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json'  -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 



Function REST-XPlay-BluePrint-Launch {
  Param (
    [object] $datagen,
    [string] $BPuuid,
    [string] $taskUUID,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Replacing JSON String Variables"
$Json = @"
{
 "spec": {
   "app_profile_reference": {
     "kind": "app_profile",
     "name": "IIS",
     "uuid": "$taskUUID"
   },
   "runtime_editables": {
     "action_list": [
       {
       }
     ],
     "service_list": [
       {
       }
     ],
     "credential_list": [
       {
       }
     ],
     "substrate_list": [
       {
       }
     ],
     "package_list": [
       {
       }
     ],
     "app_profile": {
     },
     "task_list": [
       {
       }
     ],
     "variable_list": [
       {
       }
     ],
     "deployment_list": [
       {
       }
     ]
   },
   "app_name": "IIS-000"
 }
}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($BPuuid)/simple_launch"
  if ($debug -ge 2){
    $Json | out-file c:\temp\bplaunch.json
  }

  write-log -message "Executing Launch for $BPuuid"
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

Function REST-Import-Generic-Blueprint {
  Param (
    [string] $BPfilepath,
    [object] $datagen,
    [string] $ProjectUUID,
    [object] $datavar
  )
  ## This module should be depricated, no more changing strings in JSON
  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Loading Json"

  $jsonstring = get-content $BPfilepath
  $jsonstring = $jsonstring -replace "---PROJECTREF---", $($ProjectUUID)
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/import_json"

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


Function REST-Publish-CalmMarketPlaceBP {
  Param (
    [object] $BPobject,
    [object] $datagen,
    [object] $projects,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Stripping Object properties from Detailed object"

  if ($BPobject.psobject.members.name -contains "status"){
    $BPobject.psobject.members.Remove("status")

    write-log -message "Removing Status"

  } 

  write-log -message "Adding $($projects.entities.count) Projects into the BluePrint"

  foreach ($project in $projects.entities){

    $json = @"
{
        "name": "$($project.metadata.project_reference.name)",
        "kind": "project",
        "uuid": "$($project.metadata.uuid)"
}
"@ 
    $projectref = $json | convertfrom-json
    $bpobject.spec.resources.project_reference_list += $projectref
  }

  write-log -message "Setting State to Published."

  $bpobject.spec.resources.app_state = "PUBLISHED"

  $Json = $bpobject | ConvertTo-Json -depth 100
   
  if ($debug -ge 2 ){
    $Json | out-file c:\temp\bpmarket.json
  }

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/calm_marketplace_items/$($bpobject.metadata.uuid)"

  write-log -message "Executing PUT on $($bpobject.metadata.uuid)"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $Json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "PUT" -body $Json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-Import-Generic-Blueprint-Object {
  Param (
    [string] $BPfilepath,
    [object] $datagen,
    [object] $project,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Loading Json"

  $object = ($json = get-content $BPfilepath) | convertfrom-json

  write-log -message "Stripping Object properties from Detailed object"

  if ($object.psobject.members.name -contains "contains_secrets"){
    $object.psobject.members.Remove("contains_secrets")

    write-log -message "Removing contains_secrets"

  } 
  if ($object.psobject.members.name -contains "status"){
    $object.psobject.members.Remove("status")

    write-log -message "Removing Status"

  } 
  if ($object.psobject.members.name -contains "product_version"){
    $object.psobject.members.Remove("product_version")

    write-log -message "Removing Product Version"

  }

  write-log -message "Adding Project $($project.metadata.uuid) ID into BluePrint"

  if (!$object.metadata.project_reference){
    $child = New-Object PSObject
    $child | add-member -notepropertyname uuid "0"
    $child | add-member -notepropertyname kind "project"
    $object.metadata | add-member -notepropertyname project_reference $child
  }
  $object.metadata.project_reference.uuid = $project.metadata.uuid

  $Json = $object | ConvertTo-Json -depth 100
   
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/import_json"

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

Function REST-Restore-BackupBlueprint {
  Param (
    $blueprint,
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Loading Json as Object"

  $BPObject = convertfrom-json $blueprint
  $Projectname = $BPObject.metadata.project_reference.name
  if (!$Projectname){
    $Projectname = "default"
  }

  write-log -message "Finding Project by name $Projectname"

  $projects = REST-Query-Projects -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.PEPass -clusername $datagen.BuildAccount
  $project = $projects.entities | where {$_.spec.name -eq $Projectname}

  if ($project){

    write-log -message "We found a matching project $($project.spec.name) with UUID $($project.metadata.uuid)"

  } else {

    write-log -message "$Projectname was not found restoring under default."

    $project = $projects.entities | where {$_.spec.name -eq "default"}

    write-log -message "Using default project for this restore with UUID $($project.metadata.uuid)"

  }
  if ($BPObject.metadata.project_reference){
    $BPObject.metadata.project_reference.uuid = $project.metadata.uuid
  } else {

    write-log -message "BP Does not contain a default project."

  }
  $jsonstring = $BPObject | ConvertTo-Json -depth 100
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/import_json"

  write-log -message "Restoring BP $($BPObject.spec.name) under project $($project.spec.name)"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $jsonstring -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on Function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $jsonstring -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-PostGress-SSP-BluePrint-Launch {
  Param (
    [object] $datagen,
    [string] $BPuuid,
    [string] $taskUUID,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Replacing JSON String Variables"
$Json = @"
{
 "spec": {
   "app_profile_reference": {
     "kind": "app_profile",
     "name": "PostGresDB01_DEV",
     "uuid": "$taskUUID"
   },
   "runtime_editables": {
     "action_list": [
       {
       }
     ],
     "service_list": [
       {
       }
     ],
     "credential_list": [
       {
       }
     ],
     "substrate_list": [
       {
       }
     ],
     "package_list": [
       {
       }
     ],
     "app_profile": {
     },
     "task_list": [
       {
       }
     ],
     "variable_list": [
       {
       }
     ],
     "deployment_list": [
       {
       }
     ]
   },
   "app_name": "PostGresDB01 Database Clone"
 }
}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($BPuuid)/simple_launch"
  if ($debug -ge 2){
    $Json | out-file c:\temp\bplaunch.json
  }

  write-log -message "Executing Launch for $BPuuid"
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

Function REST-Generic-BluePrint-Launch {
  Param (
    [object] $datagen,
    [string] $BPuuid,
    [object] $taskobject,
    [object] $datavar,
    [string] $appname,
    [string] $varlist = "{}"
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Replacing JSON String Variables"
$Json = @"
{
 "spec": {
   "app_profile_reference": {
     "kind": "app_profile",
     "name": "$($taskobject.name)",
     "uuid": "$($taskobject.uuid)"
   },
   "runtime_editables": {
     "action_list": [
       {
       }
     ],
     "service_list": [
       {
       }
     ],
     "credential_list": [
       {
       }
     ],
     "substrate_list": [
       {
       }
     ],
     "package_list": [
       {
       }
     ],
     "app_profile": {
     },
     "task_list": [

     ],
     "variable_list": [
       $varlist
     ],
     "deployment_list": [
       {
       }
     ]
   },
   "app_name": "$($appname)"
 }
}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($BPuuid)/simple_launch"
  if ($debug -ge 2){
    $Json | out-file c:\temp\Genbplaunch.json
  }

  write-log -message "Executing Launch for $BPuuid"
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


Function REST-BluePrint-Launch-XenDesktop {
  Param (
    [object] $datagen,
    [object] $BPobject,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Working with BP UUID $($BPobject.metadata.uuid)"

  write-log -message "Replacing Object Variables"

  write-log -message "Admin Accounts"
  $adminaccounts = "Ray.Donovan"
  ($bpobject.spec.resources.app_profile_list[0].variable_list | where {$_.name -eq "AdminAccounts" }).value = $adminaccounts

  write-log -message "WindowsDomain"
  ($bpobject.spec.resources.app_profile_list[0].variable_list | where {$_.name -eq "WindowsDomain" }).value = $datagen.Domainname

  write-log -message "FileServer"
  ($bpobject.spec.resources.app_profile_list[0].variable_list | where {$_.name -eq "FileServer" }).value = $datagen.FS1_IntName

  write-log -message "StorageContainerName"
  ($bpobject.spec.resources.app_profile_list[0].variable_list | where {$_.name -eq "StorageContainerName" }).value = $datagen.DisksContainerName

  write-log -message "VLanName"
  ($bpobject.spec.resources.app_profile_list[0].variable_list | where {$_.name -eq "VLanName" }).value = $datagen.Nw1name 

  write-log -message "UserPass"
  ($bpobject.spec.resources.app_profile_list[0].variable_list | where {$_.name -eq "UserPassword" }) | add-member noteproperty value $datavar.pepass -force
  ($bpobject.spec.resources.app_profile_list[0].variable_list | where {$_.name -eq "UserPassword" }).attrs.is_secret_modified = $true

  write-log -message "AdminPass"
  ($bpobject.spec.resources.app_profile_list[0].variable_list | where {$_.name -eq "AdminPassword" }) | add-member noteproperty value $datavar.pepass -force
  ($bpobject.spec.resources.app_profile_list[0].variable_list | where {$_.name -eq "AdminPassword" }).attrs.is_secret_modified = $true

  write-log -message "App Name"
  $bpobject.spec  | add-member noteproperty application_name "XenDeskTop" -force
$appprofile = @"
{
    "app_profile_reference": {
      "kind": "app_profile",
      "uuid": "$($BPobject.spec.resources.app_profile_list.uuid)"
    }
}
"@
  $bpobject.spec  | add-member noteproperty app_profile_reference "temp" -force
  $appprofileobj = $appprofile | convertfrom-json
  $bpobject.spec.app_profile_reference = $appprofileobj.app_profile_reference

  write-log -message "Stripping Object properties from Detailed object"

  if ($bpobject.psobject.members.name -contains "contains_secrets"){
    $bpobject.psobject.members.Remove("contains_secrets")

    write-log -message "Removing contains_secrets"

  } 
  if ($bpobject.psobject.members.name -contains "status"){
    $bpobject.psobject.members.Remove("status")

    write-log -message "Removing Status"

  } 
  if ($bpobject.psobject.members.name -contains "product_version"){
    $bpobject.psobject.members.Remove("product_version")

    write-log -message "Removing Product Version"

  }
  $bpobject.spec.psobject.members.Remove("name")
  
  write-log -message "Converting Object back to Json Payload"

  $Json = $bpobject | convertto-json -depth 100


  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($BPobject.metadata.uuid)/launch"
  if ($debug -ge 2){
    $Json | out-file c:\temp\GenbplaunchFull.json
  }

  write-log -message "Executing Launch for $($BPobject.metadata.uuid)"
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


Function REST-Maria-SSP-BluePrint-Launch {
  Param (
    [object] $datagen,
    [string] $BPuuid,
    [string] $taskUUID,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Replacing JSON String Variables"
$Json = @"
{
 "spec": {
   "app_profile_reference": {
     "kind": "app_profile",
     "name": "MariaDB01_DEV",
     "uuid": "$taskUUID"
   },
   "runtime_editables": {
     "action_list": [
       {
       }
     ],
     "service_list": [
       {
       }
     ],
     "credential_list": [
       {
       }
     ],
     "substrate_list": [
       {
       }
     ],
     "package_list": [
       {
       }
     ],
     "app_profile": {
     },
     "task_list": [
       {
       }
     ],
     "variable_list": [
       {
       }
     ],
     "deployment_list": [
       {
       }
     ]
   },
   "app_name": "MariaDB01 Database Clone"
 }
}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($BPuuid)/simple_launch"
  if ($debug -ge 2){
    $Json | out-file c:\temp\bplaunch.json
  }

  write-log -message "Executing Launch for $BPuuid"
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


Function REST-Update-Splunk-Blueprint {
  Param (
    [object] $BPObject,
    [object] $Subnet,
    [object] $image,
    [string] $BlueprintUUID,
    [object] $datagen,
    [string] $ProjectUUID,
    [object] $datavar,
    [string] $SERVER_NAME,
    [object] $account
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Loading Json"
  foreach ($line in $datagen.PrivateKey){
    [string]$Keystring += $line + "`n" 
  }
  $Keystring = $Keystring.Substring(0,$Keystring.Length-1)
  $newBPObject = $BPObject
  if ($debug -eq 2){
    $json = $newBPObject| convertto-json -depth 100
    $json | out-file "C:\temp\Splunk1.json"
  }
  $newBPObject.psobject.members.remove("Status")
  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "SPLUNK_ADMIN_PASSWORD"}) | add-member noteproperty value $datavar.pepass -force
  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "SPLUNK_ADMIN_PASSWORD"}).attrs.is_secret_modified = 'true'
  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "SPLUNK_LICENSE"}) | add-member noteproperty value "123" -force
  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "SPLUNK_ADMIN_PASSWORD"}).attrs.is_secret_modified = 'true'
  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "INSTANCE_PUBLIC_KEY"}).value = $datagen.publickey
  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "SERVER_NAME"}).value = "$($SERVER_NAME)"
  if ($datavar.hypervisor -match "Nutanix|AHV"){
    $newBPObject.spec.resources.substrate_definition_list.create_spec.resources.nic_list.subnet_reference.uuid = $subnet.uuid
    $newBPObject.spec.resources.substrate_definition_list.create_spec.resources.nic_list.subnet_reference.name = $subnet.name
    (($newBPObject.spec.resources.substrate_definition_list)[0].create_spec.resources.disk_list.data_source_reference)[0] | add-member noteproperty uuid $image.metadata.uuid -force
  } else {
    $newBPObject.spec.resources.substrate_definition_list.create_spec.template = $image.config.instanceUuid
    $newBPObject.spec.resources.substrate_definition_list.create_spec.cluster = $datavar.pocname
    $newBPObject.spec.resources.substrate_definition_list.create_spec.resources.account_uuid = $account.metadata.uuid
#    $ipjson = @"
#    {
#              "linux_data": {
#                "network_settings": [{
#                  "is_dhcp": true,
#                  "ip": "",
#                  "subnet_mask": "",
#                  "gateway_default": ""
#                }],
#                "dns_primary": "$($datagen.dc1ip)",
#                "dns_secondary": "$($datagen.dc2ip)",
#                "hostname": "$($SERVER_NAME)",
#                "domain": "$($datagen.domainname)",
#                "timezone": "Europe/Amsterdam"
#              }
#    } 
#"@
#
#
#
#    $newBPObject.spec.resources.substrate_definition_list.create_spec.resources.guest_customization.linux_data = ($ipjson | ConvertFrom-Json).linux_data
    $newBPObject.spec.resources.substrate_definition_list.readiness_probe.login_credential_local_reference.uuid = $(($BPObject.spec.resources.credential_definition_list | where {$_.name -eq "Splunk_VM"}).uuid)
  }
  
  $newBPObject.metadata.project_reference.uuid = $ProjectUUID
  ($newBPObject.spec.resources.credential_definition_list | where {$_.name -eq "Splunk_VM"}).secret | add-member noteproperty value $Keystring -force
  ($newBPObject.spec.resources.credential_definition_list | where {$_.name -eq "Splunk_VM"}).secret.attrs.is_secret_modified = 'true'

  $json = $newBPObject | convertto-json -depth 100

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($BlueprintUUID)"

  if ($debug -eq 2){
    $json | out-file "C:\temp\Splunk2.json"
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

Function REST-Update-HasiCorp-Blueprint {
  Param (
    [object] $BPObject,
    [object] $Subnet,
    [object] $image,
    [string] $BlueprintUUID,
    [object] $datagen,
    [string] $ProjectUUID,
    [object] $datavar,
    [string] $SERVER_NAME
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Loading Json"
  foreach ($line in $datagen.PrivateKey){
    [string]$Keystring += $line + "`n" 
  }
  $Keystring = $Keystring.Substring(0,$Keystring.Length-1)
  $newBPObject = $BPObject
  if ($debug -eq 2){
    $json = $newBPObject| convertto-json -depth 100
    $json | out-file "C:\temp\Splunk1.json"
  }
  $newBPObject.psobject.members.remove("Status")

  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "INSTANCE_PUBLIC_KEY"}).value = $datagen.publickey
  ($newBPObject.spec.resources.substrate_definition_list)[0].create_spec.resources.nic_list.subnet_reference.uuid = $subnet.uuid
  ($newBPObject.spec.resources.substrate_definition_list)[0].create_spec.resources.nic_list.subnet_reference.name = $subnet.name
  ($newBPObject.spec.resources.substrate_definition_list)[1].create_spec.resources.nic_list.subnet_reference.uuid = $subnet.uuid
  ($newBPObject.spec.resources.substrate_definition_list)[1].create_spec.resources.nic_list.subnet_reference.name = $subnet.name
  #($newBPObject.spec.resources.substrate_definition_list)[0].create_spec.resources.disk_list.data_source_reference | add-member noteproperty uuid $image.metadata.uuid -force
  #($newBPObject.spec.resources.substrate_definition_list)[0].create_spec.resources.disk_list.data_source_reference | add-member noteproperty name $image.spec.name -force
  #($newBPObject.spec.resources.substrate_definition_list)[1].create_spec.resources.disk_list.data_source_reference | add-member noteproperty uuid $image.metadata.uuid -force
  #($newBPObject.spec.resources.substrate_definition_list)[1].create_spec.resources.disk_list.data_source_reference | add-member noteproperty name $image.spec.name -force
  $newBPObject.metadata.project_reference.uuid = $ProjectUUID
  ($newBPObject.spec.resources.credential_definition_list | where {$_.name -eq "CentOS_Key"}).secret | add-member noteproperty value $Keystring -force
  ($newBPObject.spec.resources.credential_definition_list | where {$_.name -eq "CentOS_Key"}).secret.attrs.is_secret_modified = 'true'

  $json = $newBPObject | convertto-json -depth 100

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($BlueprintUUID)"

  if ($debug -eq 2){
    $json | out-file "C:\temp\Splunk2.json"
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

Function REST-Update-Win3Tier-Blueprint {
  Param (
    [object] $BPObject,
    [object] $Subnet,
    [object] $image,
    [string] $BlueprintUUID,
    [object] $datagen,
    [string] $ProjectUUID,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $newBPObject = $BPObject
  $newBPObject.psobject.members.remove("Status")

  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "DbPassword"}) | add-member noteproperty value $datavar.pepass -force
  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "DbPassword"}).attrs.is_secret_modified = 'true'
  ($newBPObject.spec.resources.substrate_definition_list)[0].create_spec.resources.nic_list.subnet_reference.uuid = $subnet.uuid
  ($newBPObject.spec.resources.substrate_definition_list)[0].create_spec.resources.nic_list.subnet_reference.name = $subnet.name
  ($newBPObject.spec.resources.substrate_definition_list)[1].create_spec.resources.nic_list.subnet_reference.uuid = $subnet.uuid
  ($newBPObject.spec.resources.substrate_definition_list)[1].create_spec.resources.nic_list.subnet_reference.name = $subnet.name
  (($newBPObject.spec.resources.substrate_definition_list)[0].create_spec.resources.disk_list.data_source_reference)[0] | add-member noteproperty uuid $image.metadata.uuid -force
  (($newBPObject.spec.resources.substrate_definition_list)[0].create_spec.resources.disk_list.data_source_reference)[1] | add-member noteproperty uuid ($newBPObject.spec.resources.package_definition_list | where {$_.name -eq "MSSQL2014_ISO"}).uuid -force
  (($newBPObject.spec.resources.substrate_definition_list)[1].create_spec.resources.disk_list.data_source_reference)[0] | add-member noteproperty uuid $image.metadata.uuid -force
  $newBPObject.metadata.project_reference.uuid = $ProjectUUID
  ($newBPObject.spec.resources.credential_definition_list | where {$_.name -eq "WIN_VM_CRED"}).secret | add-member noteproperty value $datavar.pepass -force
  ($newBPObject.spec.resources.credential_definition_list | where {$_.name -eq "WIN_VM_CRED"}).secret.attrs.is_secret_modified = 'true'
  ($newBPObject.spec.resources.credential_definition_list | where {$_.name -eq "SQL_CRED"}).secret | add-member noteproperty value $datavar.pepass -force
  ($newBPObject.spec.resources.credential_definition_list | where {$_.name -eq "SQL_CRED"}).secret.attrs.is_secret_modified = 'true'

  $json = $newBPObject | convertto-json -depth 100

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($BlueprintUUID)"

  if ($debug -eq 2){
    $json | out-file "C:\temp\Splunk2.json"
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

Function REST-Update-ERA-SSP-Blueprint {
  Param (
    [object] $BPObject,
    [string] $BlueprintUUID,
    [object] $datagen,
    [string] $ProjectUUID,
    [object] $datavar,
    [string] $dbname,
    [string] $snapID
  )

  $credPair = "$($datavar.peadmin):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Loading Json"
  foreach ($line in $datagen.PrivateKey){
    [string]$Keystring += $line + "`n" 
  }
  $Keystring = $Keystring.Substring(0,$Keystring.Length-1)
  $newBPObject = $BPObject
  if ($debug -eq 2){
    $json = $newBPObject| convertto-json -depth 100
    $json | out-file "C:\temp\ERAClone1.json"
  }
  $newBPObject.psobject.members.remove("Status")
  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "cloned_db_password"}) | add-member noteproperty value $datavar.pepass -force
  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "cloned_db_password"}).attrs.is_secret_modified = 'true'
  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "era_ip"}).value = $datagen.ERA1IP
  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "cloned_db_public_key"}).value = $datagen.publickey
  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "source_db_name"}).value = "$($dbname)"
  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "source_snapshot_id"}).value = "$($snapID)"
  ($newBPObject.spec.resources.app_profile_list.variable_list | where {$_.name -eq "cloned_db_name"}).value = "$($dbname)_DEV"
  $newBPObject.metadata.project_reference.uuid = $ProjectUUID
  ($newBPObject.spec.resources.credential_definition_list | where {$_.name -eq "db_server_creds"}).secret | add-member noteproperty value $Keystring -force
  ($newBPObject.spec.resources.credential_definition_list | where {$_.name -eq "db_server_creds"}).secret.attrs.is_secret_modified = 'true'
  ($newBPObject.spec.resources.credential_definition_list | where {$_.name -eq "era_creds"}).secret | add-member noteproperty value $datavar.pepass -force
  ($newBPObject.spec.resources.credential_definition_list | where {$_.name -eq "era_creds"}).secret.attrs.is_secret_modified = 'true'

  $json = $newBPObject | convertto-json -depth 100

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($BlueprintUUID)"

  if ($debug -eq 2){
    $json | out-file "C:\temp\ERAClone2.json"
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


Function REST-Get-Calm-GlobalMarketPlaceItems {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
$Json = @"
{
  "filter_criteria": "marketplace_item_type_list==APP;(app_state==PUBLISHED,app_state==ACCEPTED)",
  "group_member_offset": 0,
  "group_member_count": 5000,
  "entity_type": "marketplace_item",
  "group_member_attributes": [{
    "attribute": "name"
  }, {
    "attribute": "author"
  }, {
    "attribute": "version"
  }, {
    "attribute": "categories"
  }, {
    "attribute": "owner_reference"
  }, {
    "attribute": "owner_username"
  }, {
    "attribute": "project_names"
  }, {
    "attribute": "project_uuids"
  }, {
    "attribute": "app_state"
  }, {
    "attribute": "description"
  }, {
    "attribute": "spec_version"
  }, {
    "attribute": "app_attribute_list"
  }, {
    "attribute": "app_group_uuid"
  }, {
    "attribute": "icon_list"
  }, {
    "attribute": "change_log"
  }, {
    "attribute": "app_source"
  }]
}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/groups"

  write-log -message "Getting All Market Place Items."
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

Function REST-Get-Calm-PublishedMarketPlaceItems {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
$Json = @"
{
  "group_member_sort_attribute": "version",
  "group_member_sort_order": "DESCENDING",
  "grouping_attribute": "app_group_uuid",
  "group_count": 60,
  "group_offset": 0,
  "filter_criteria": "marketplace_item_type_list==APP;(app_state==PUBLISHED)",
  "group_member_count": 1,
  "entity_type": "marketplace_item",
  "group_member_attributes": [{
    "attribute": "name"
  }, {
    "attribute": "author"
  }, {
    "attribute": "version"
  }, {
    "attribute": "categories"
  }, {
    "attribute": "owner_reference"
  }, {
    "attribute": "owner_username"
  }, {
    "attribute": "project_names"
  }, {
    "attribute": "project_uuids"
  }, {
    "attribute": "app_state"
  }, {
    "attribute": "description"
  }, {
    "attribute": "spec_version"
  }, {
    "attribute": "app_attribute_list"
  }, {
    "attribute": "app_group_uuid"
  }, {
    "attribute": "icon_list"
  }, {
    "attribute": "change_log"
  }, {
    "attribute": "app_source"
  }]
}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/groups"

  write-log -message "Getting All Market Place Items."
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


Function REST-Get-Calm-GlobalMarketPlaceItem-Detail {
  Param (
    [object] $datagen,
    [object] $datavar,
    [string] $BPUUID
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/calm_marketplace_items/$($BPUUID)"

  write-log -message "Getting Market Place Item Detail."
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

Function REST-Move-BluePrint-Launch1 {
  Param (
    [object] $datagen,
    [string] $BPuuid,
    [string] $taskUUID,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Replacing JSON String Variables"
$Json = @"
{
 "spec": {
   "app_profile_reference": {
     "kind": "app_profile",
     "name": "Nutanix",
     "uuid": "$taskUUID"
   },
   "runtime_editables": {
     "action_list": [
       {
       }
     ],
     "service_list": [
       {
       }
     ],
     "credential_list": [
       {
       }
     ],
     "substrate_list": [
       {
       }
     ],
     "package_list": [
       {
       }
     ],
     "app_profile": {
     },
     "task_list": [
       {
       }
     ],
     "variable_list": [
       {
       }
     ],
     "deployment_list": [
       {
       }
     ]
   },
   "app_name": "Nutanix Move"
 }
}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($BPuuid)/simple_launch"
  if ($debug -ge 2){
    $Json | out-file c:\temp\bplaunch.json
  }

  write-log -message "Executing Launch for $BPuuid"
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

Function REST-Karbon-BluePrint-Launch {
  Param (
    [object] $datagen,
    [string] $BPuuid,
    [string] $taskUUID,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Replacing JSON String Variables"
$Json = @"
{
 "spec": {
   "app_profile_reference": {
     "kind": "app_profile",
     "name": "Default",
     "uuid": "$taskUUID"
   },
   "runtime_editables": {
     "action_list": [
       {
       }
     ],
     "service_list": [
       {
       }
     ],
     "credential_list": [
       {
       }
     ],
     "substrate_list": [
       {
       }
     ],
     "package_list": [
       {
       }
     ],
     "app_profile": {
     },
     "task_list": [
       {
       }
     ],
     "variable_list": [
       {
       }
     ],
     "deployment_list": [
       {
       }
     ]
   },
   "app_name": "Karbon Installer"
 }
}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/blueprints/$($BPuuid)/simple_launch"
  if ($debug -ge 2){
    $Json | out-file c:\temp\bplaunch.json
  }

  write-log -message "Executing Launch for $BPuuid"
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


Function REST-Query-Calm-DetailedApps {
  Param (
    [object] $datavar,
    [object] $datagen,
    [string] $uuid
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($datagen.buildaccount):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Query Calm $($UUID) App Detailed"

  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/apps/$($UUID)"

  write-log -message "Using URL $URL"
  write-log -message "Using IP $($datagen.PCClusterIP)"

  $JSON = $Payload | convertto-json
  write-host  $JSON
  try {
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }  
  Return $task
} 



Function REST-Move-BluePrint-LaunchAPP {
  Param (
    [object] $appdetail,
    [object] $action,
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Replacing JSON String Variables"
$Json = @"
{
  "spec": {
    "target_uuid": "$($appdetail.metadata.uuid)",
    "target_kind": "Application",
    "args": []
  },
  "api_version": "3.0",
  "metadata": {
    "project_reference": {
      "kind": "project",
      "uuid": "$($appdetail.metadata.project_reference.uuid)"
    },
    "name": "Nutanix Move",
    "spec_version": 5,
    "kind": "app"
  }
}
"@ 
  $URL = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/apps/$($appdetail.metadata.uuid)/actions/$($Action.uuid)/run"

  write-log -message "Executing App Launch for APP $($appdetail.metadata.uuid) using Action ID $($Action.uuid)"
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

function REST-update-project-ACP {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $projectdetail,
    [object] $Subnet,
    [object] $consumer,
    [object] $projectadmin,
    [object] $cluster,
    [string] $customer,    
    [object] $admingroup,
    [object] $usergroup
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Prepping object"
  $projectdetail.psobject.properties.Remove('status')

  write-log -message "Updating Project $($projectdetail.metadata.uuid)"
  write-log -message "Building child object to be inserted"


  
$json2 = @"
[{
        "acp": {
          "name": "ACP PAdmin for $customer",
          "resources": {
            "role_reference": {
              "kind": "role",
              "uuid": "$($ProjectAdmin.metadata.uuid)"
            },
            "user_reference_list": [

            ],
            "filter_list": {
              "context_list": [{
                  "entity_filter_expression_list": [{
                    "operator": "IN",
                    "left_hand_side": {
                      "entity_type": "all"
                    },
                    "right_hand_side": {
                      "collection": "ALL"
                    }
                  }],
                  "scope_filter_expression_list": [{
                    "operator": "IN",
                    "left_hand_side": "PROJECT",
                    "right_hand_side": {
                      "uuid_list": [
                        "$($projectdetail.metadata.uuid)"
                      ]
                    }
                  }]
                },
                {
                  "entity_filter_expression_list": [{
                      "operator": "IN",
                      "left_hand_side": {
                        "entity_type": "category"
                      },
                      "right_hand_side": {
                        "collection": "ALL"
                      }
                    },
                    {
                      "operator": "IN",
                      "left_hand_side": {
                        "entity_type": "cluster"
                      },
                      "right_hand_side": {
                        "uuid_list": [
                          "$($cluster.metadata.uuid)"
                        ]
                      }
                    },
                    {
                      "operator": "IN",
                      "left_hand_side": {
                        "entity_type": "directory_service"
                      },
                      "right_hand_side": {
                        "collection": "ALL"
                      }
                    },
                    {
                      "operator": "IN",
                      "left_hand_side": {
                        "entity_type": "environment"
                      },
                      "right_hand_side": {
                        "collection": "SELF_OWNED"
                      }
                    },
                    {
                      "operator": "IN",
                      "left_hand_side": {
                        "entity_type": "image"
                      },
                      "right_hand_side": {
                        "collection": "ALL"
                      }
                    },
                    {
                      "operator": "IN",
                      "left_hand_side": {
                        "entity_type": "marketplace_item"
                      },
                      "right_hand_side": {
                        "collection": "SELF_OWNED"
                      }
                    },
                    {
                      "operator": "IN",
                      "left_hand_side": {
                        "entity_type": "project"
                      },
                      "right_hand_side": {
                        "uuid_list": [
                          "$($projectdetail.metadata.uuid)"
                        ]
                      }
                    },
                    {
                      "operator": "IN",
                      "left_hand_side": {
                        "entity_type": "role"
                      },
                      "right_hand_side": {
                        "collection": "ALL"
                      }
                    }
                  ],
                  "scope_filter_expression_list": [

                  ]
                },
                {
                  "entity_filter_expression_list": [{
                    "operator": "IN",
                    "left_hand_side": {
                      "entity_type": "user"
                    },
                    "right_hand_side": {
                      "collection": "ALL"
                    }
                  }],
                  "scope_filter_expression_list": [{
                    "operator": "IN",
                    "left_hand_side": "PROJECT",
                    "right_hand_side": {
                      "uuid_list": [
                        "$($projectdetail.metadata.uuid)"
                      ]
                    }
                  }]
                },
                {
                  "entity_filter_expression_list": [{
                    "operator": "IN",
                    "left_hand_side": {
                      "entity_type": "user_group"
                    },
                    "right_hand_side": {
                      "collection": "ALL"
                    }
                  }],
                  "scope_filter_expression_list": [{
                    "operator": "IN",
                    "left_hand_side": "PROJECT",
                    "right_hand_side": {
                      "uuid_list": [
                        "$($projectdetail.metadata.uuid)"
                      ]
                    }
                  }]
                }
              ]
            },
            "user_group_reference_list": [{
              "kind": "user_group",
              "name": "$($admingroup.spec.resources.directory_service_user_group.distinguished_name)",
              "uuid": "$($admingroup.metadata.uuid)"
            }]
          },
          "description": "prismui-desc-a8527482f0b1123"
        },
          "operation": "ADD",
        "metadata": {
          "kind": "access_control_policy"
        }
      },
      {
        "acp": {
          "name": "ACP Admin for $customer",
          "resources": {
            "role_reference": {
              "kind": "role",
              "uuid": "$($Consumer.metadata.uuid)"
            },
            "user_reference_list": [

            ],
            "filter_list": {
              "context_list": [{
                  "entity_filter_expression_list": [{
                    "operator": "IN",
                    "left_hand_side": {
                      "entity_type": "all"
                    },
                    "right_hand_side": {
                      "collection": "ALL"
                    }
                  }],
                  "scope_filter_expression_list": [{
                    "operator": "IN",
                    "left_hand_side": "PROJECT",
                    "right_hand_side": {
                      "uuid_list": [
                        "$($projectdetail.metadata.uuid)"
                      ]
                    }
                  }]
                },
                {
                  "entity_filter_expression_list": [{
                      "operator": "IN",
                      "left_hand_side": {
                        "entity_type": "category"
                      },
                      "right_hand_side": {
                        "collection": "ALL"
                      }
                    },
                    {
                      "operator": "IN",
                      "left_hand_side": {
                        "entity_type": "cluster"
                      },
                      "right_hand_side": {
                        "uuid_list": [
                          "$($cluster.metadata.uuid)"
                        ]
                      }
                    },
                    {
                      "operator": "IN",
                      "left_hand_side": {
                        "entity_type": "image"
                      },
                      "right_hand_side": {
                        "collection": "ALL"
                      }
                    },
                    {
                      "operator": "IN",
                      "left_hand_side": {
                        "entity_type": "marketplace_item"
                      },
                      "right_hand_side": {
                        "collection": "SELF_OWNED"
                      }
                    }
                  ],
                  "scope_filter_expression_list": [

                  ]
                }
              ]
            },
            "user_group_reference_list": [{
              "kind": "user_group",
              "name": "$($usergroup.spec.resources.directory_service_user_group.distinguished_name)",
              "uuid": "$($usergroup.metadata.uuid)"
            }]
          },
          "description": "prismui-desc-9838f052a82f"
        },
        "operation": "ADD",
        "metadata": {
          "kind": "access_control_policy"
        }
      }]
"@

  write-log -message "Converting Child"

  $child = $json2 | convertfrom-json

  try {
    write-log -message "Terminating childs"

    $projectdetail.spec.psobject.properties.Remove('access_control_policy_list')
  } catch {
    write-log -message "Parent does not have childs yet."
  }
  if (!$projectdetail.spec.access_control_policy_list){
    $projectdetail.spec | Add-Member -notepropertyname "access_control_policy_list" $child -force

    write-log -message "So the external user group reference list does not exist yet for this project. Adding a construct."
  }

  write-log -message "Injecting Child into Parent"

  $projectdetail.spec.access_control_policy_list = [array]$child

  write-log -message "Updating Project $($projectdetail.metadata.uuid)"

  $json1 = $projectdetail | ConvertTo-Json -depth 100
  if ($debug -ge 2 ){
    $json1 | out-file c:\temp\acp.json
  }

  $URL1 = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/projects_internal/$($projectdetail.metadata.uuid)"

  try{
    $task = Invoke-RestMethod -Uri $URL1 -method "put" -body $json1 -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL1 -method "put" -body $json1 -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

function REST-update-project-RBAC {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $projectdetail,
    [object] $admingroup,
    [object] $usergroup
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Prepping object"
  $projectdetail.psobject.properties.Remove('status')


  write-log -message "Updating Project UUID $($projectdetail.metadata.uuid)"
  write-log -message "Updating Project Name $($projectdetail.spec.project_detail.name)"
  write-log -message "Adding $($admingroup.metadata.uuid) For Admin group"
  write-log -message "Adding $($usergroup.metadata.uuid) For User group"
  write-log -message "Building child object to be inserted"
  
   
      $json1 = @"
          {
            "kind": "user_group",
            "name": "$($admingroup.spec.resources.directory_service_user_group.distinguished_name)",
            "uuid": "$($admingroup.metadata.uuid)"
          }
"@
      $json2 = @"
          {
            "kind": "user_group",
            "name": "$($usergroup.spec.resources.directory_service_user_group.distinguished_name)",
            "uuid": "$($usergroup.metadata.uuid)"
          }
"@


  
      write-log -message "Converting Child"
      [array]$childs = $json2 | convertfrom-json
      [array]$childs += $json1 | convertfrom-json

  
  
  write-log -message "Injecting Child into Parent"
  try {
    write-log -message "Terminating childs"

    $projectdetail.spec.project_detail.resources.psobject.properties.Remove('external_user_group_reference_list')
  } catch {
    write-log -message "Parent does not have childs yet."
  }
  if (!$projectdetail.spec.project_detail.resources.external_user_group_reference_list){
    $projectdetail.spec.project_detail.resources | Add-Member -notepropertyname "external_user_group_reference_list" $childs -force

    write-log -message "So the external user group reference list does not exist yet for this project. Adding a construct."
  }

  $projectdetail.spec.project_detail.resources.external_user_group_reference_list += [array]$childs

  write-log -message "Updating Project $($projectdetail.metadata.uuid)"

  $json1 = $projectdetail | ConvertTo-Json -depth 100

  if ($debug -ge 2){
    $json1 | out-file c:\temp\projectUser.json
  }

  $URL1 = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/calm_projects/$($projectdetail.metadata.uuid)"
  $counter = 0
  do{
    $counter ++
    try{
      $task = Invoke-RestMethod -Uri $URL1 -method "put" -body $json1 -ContentType 'application/json' -headers $headers;
      $exit = 1
    } catch {
      sleep 10
      $exit = 0
      $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
      $task = Invoke-RestMethod -Uri $URL1 -method "put" -body $json1 -ContentType 'application/json' -headers $headers;
    }
  } until ($exit -eq 1 -or $counter -ge 5)
  Return $task
} 

function REST-update-project-Account {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $projectdetail,
    [object] $accounts
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Prepping object"
  $projectdetail.psobject.properties.Remove('status')

  write-log -message "Updating Project UUID $($projectdetail.metadata.uuid)"
  write-log -message "Updating Project Name $($projectdetail.spec.project_detail.name)"
  write-log -message "Adding $($accounts.entities.count) Account(s)"
  write-log -message "Building child object to be inserted"
  foreach ($account in $accounts.entities){
    if ($account.status.resources.type -ne "Nutanix" ){
      $json2 = @"
        {
          "uuid": "$($account.metadata.uuid)",
          "kind": "account",
          "name": "$($account.status.resources.type)"
        }
"@
      write $json2

  
      write-log -message "Converting Child"
      $child = $json2 | convertfrom-json
      [array]$childs += $child
    }
  }
  write-log -message "Injecting Child into Parent"
  try {
    write-log -message "Terminating childs"

    $projectdetail.spec.project_detail.resources.psobject.properties.Remove('account_reference_list')
  } catch {
    write-log -message "Parent does not have childs yet."
  }
  if (!$projectdetail.spec.project_detail.resources.account_reference_list){
    $projectdetail.spec.project_detail.resources | Add-Member -notepropertyname "account_reference_list" $childs -force

    write-log -message "So the account reference list does not exist yet for this project. Adding a construct."
  }

  $projectdetail.spec.project_detail.resources.account_reference_list += [array]$childs

  write-log -message "Updating Project $($projectdetail.metadata.uuid)"

  $json1 = $projectdetail | ConvertTo-Json -depth 100

  if ($debug -ge 2){
    $json1 | out-file c:\temp\projectaccount.json
  }

  $URL1 = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/calm_projects/$($projectdetail.metadata.uuid)"
  $counter = 0
  do{
    $counter ++
    try{
      $task = Invoke-RestMethod -Uri $URL1 -method "put" -body $json1 -ContentType 'application/json' -headers $headers;
      $exit = 1
    } catch {
      sleep 119
      $exit = 0
      $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
      $task = Invoke-RestMethod -Uri $URL1 -method "put" -body $json1 -ContentType 'application/json' -headers $headers;
    }
  } until ($exit -eq 1 -or $counter -ge 5)
  Return $task
} 

function REST-update-project-environment {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $projectdetail,
    [object] $environment
  )

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Prepping object"
  $projectdetail.psobject.properties.Remove('status')

  write-log -message "Updating Project $($projectdetail.metadata.uuid)"
  write-log -message "Adding Environment $($environment.metadata.uuid)"
  write-log -message "Building child object to be inserted"
  
$json2 = @"
{
    "kind":  "environment",
    "uuid":  "$($environment.metadata.uuid)"
}
"@

  write-log -message "Converting Child"

  $child = $json2 | convertfrom-json

  write-log -message "Injecting Child into Parent"

  $projectdetail.spec.project_detail.resources.environment_reference_list += $child

  write-log -message "Updating Project $($projectdetail.metadata.uuid)"

  $json1 = $projectdetail | ConvertTo-Json -depth 100

  write $json1

  $URL1 = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/projects_internal/$($projectdetail.metadata.uuid)"

  try{
    $task = Invoke-RestMethod -Uri $URL1 -method "put" -body $json1 -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL1 -method "put" -body $json1 -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-Get-ProjectDetail {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $project
  )

  write-log -message "Building Header"

  $credPair = "$($datagen.buildaccount):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Getting Detailed Project $($project.metadata.uuid)"

  $URL1 = "https://$($datagen.PCClusterIP):9440/api/nutanix/v3/projects_internal/$($project.metadata.uuid)"
  
  write-log -message "Using URL ->$($url1)<-"

  try{
    $task = Invoke-RestMethod -Uri $URL1 -method "GET" -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL1 -method "GET" -headers $headers;
  }
  return $task
}