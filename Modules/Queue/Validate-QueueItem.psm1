Function Validate-QueueItem {
  param (
    [string] $processingmode,
    [string] $Scanuuid
  )

  if ($processingmode -ne "SCAN") {;
    $intqueueuuid = $QueueUUID
  } else {
    $intqueueuuid = $Scanuuid
  }
  try{
    if ($processingmode -eq "NOW") {;
      $item = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLQueueTableName) WHERE QueueStatus='Ready';"  
    } else {
      $item = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLQueueTableName) WHERE QueueUUID='$intqueueuuid';" 
    }
  } catch {}


  $Validation = "OK"
  if ($item){
    $object = $item
    if ($processingmode -ne "SCAN") {;
      write-log -message "Processing Item $($object.QueueUUID) for $($object.pocname)"

    } else {
      $intqueueuuid = $Scanuuid
    }

  
    ##############
    ## Fixing Known Errors
    ##############
    if ($object.InfraGateway -match "^1055.*"){
      $object.InfraGateway = $object.InfraGateway -replace "1055(.*)", '10.55$1'
    } elseif ($object.InfraGateway -match "^1042.*"){
      $object.InfraGateway = $object.InfraGateway -replace "1042(.*)", '10.42$1'
    } elseif ($object.InfraGateway -match "^1038.*"){
      $object.InfraGateway = $object.InfraGateway -replace "1038(.*)", '10.38$1'
    }

    $array = $object.PEClusterIP.split(".")
    if ($array.count -eq 3){
      write "Correcting PE Corrupted IP"
      ## Todo
    } 

    if ($object.DNSServer -match "^1055.*"){
      $object.DNSServer = $object.DNSServer -replace "1055(.*)", '10.55$1'
    } elseif ($object.DNSServer -match "^1042.*"){
      $object.DNSServer = $object.DNSServer -replace "1042(.*)", '10.42$1'
    }
    
    if ($object.InfraSubnetmask -match "255.*128$"){;
      $object.InfraSubnetmask = "255.255.255.128";
    } elseif ($object.InfraSubnetmask -match "255.*192$"){;
      $object.InfraSubnetmask = "255.255.255.192";
    } elseif ($object.InfraSubnetmask -match "255.*224$"){;
      $object.InfraSubnetmask = "255.255.255.224";
    };
    if ($object.Nw2subnet -match "255.*\.0$"){;
      $object.Nw2subnet = "255.255.255.0"; 
    } elseif ($object.Nw2subnet -match "255.*128$"){;
      $object.Nw2subnet = "255.255.255.128";
    } elseif ($object.Nw2subnet -match "255.*192$"){;
      $object.Nw2subnet = "255.255.255.192";
    } elseif ($object.Nw2subnet -match "255.*224$"){;
      $object.Nw2subnet = "255.255.255.224";
    };
    if ($object.AOS -eq "59.1"){;
      $object.aos = "5.9.1";
    };

    ##############
    ## Validating Possible Errors This needs to be write....
    ##############
    [array]$logging = $null
    $IPpattern = "^([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}$"
    if ($object.PEClusterIP -match $IPpattern){
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | INFO  | Prism Element Cluster IP valid."
      }
    } else { 
      $validation = "Error"
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | Error | The Cluster Element IP is not a valid IPaddress $($object.PEClusterIP)"
      }
    }
    if ($object.HyperVisor -match "AHV|Nutanix" -or $object.HyperVisor -eq "AutoDetect" -or $debug -ge 2){
      if ($debug -ge 1){
        if ($object.HyperVisor -eq "AutoDetect"){
          write "$(get-date -format "hh:mm:ss") | WARN  | AHV is required"
        } else {
          write "$(get-date -format "hh:mm:ss") | INFO  | The HyperVisor is valid, AHV Only"
        }
      }
    } else {;
      $validation = "Error";
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | Error | The HyperVisor is invalid, $($object.HyperVisor) is not supported" 
      }
    };
    if ($object.InfraSubnetmask -match $IPpattern){
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | INFO  | The Cluster Subnetmask is valid."
      }
    } else {;
      $validation = "Error";
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | Error | The Cluster Subnetmask is not a valid SubnetMask $($object.InfraSubnetmask)"
      };
    };
    if ($object.InfraGateway -match $IPpattern){
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | INFO  | The Cluster Element Gateway is valid."
      }
    } else {;
      $validation = "Error";
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | Error | The Cluster Element Gateway is not a valid IPaddress $($object.InfraGateway)"
      };
    };

    $checksubnet = Test-SameSubnet -ip1 "$($object.PEClusterIP)" -ip2 "$($object.InfraGateway)" -mask "$($object.InfraSubnetmask)"
    
    if ($checksubnet -eq $true){
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | INFO  | The Cluster Element Gateway $($object.InfraGateway) is in the same network as the Cluster $($object.PEClusterIP)"
      }
    } else {;
      $validation = "Error";
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | Error | The PE Cluster IP $($object.PEClusterIP) and Gateway $($object.InfraGateway) are not in the same network"
      };
    };
    if ($object.Nw1Vlan -match "[0-9]+"){
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | INFO  | The Network Vlan $($object.Nw1Vlan) is an integer"
      }
    } else {;
      $validation = "Error";
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | Error | The Network Vlan $($object.Nw1Vlan) is not an integer"
      };
    };
    if ($object.DNSServer -match $IPpattern){
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | INFO  | The Cluster Element DNSServer is valid."
      }
    } else {;
      $validation = "Error";
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | Error | The Cluster Element DNSServer is not a valid IPaddress $($object.DNSServer)"
      };
    };
    if ($object.PEAdmin -match '[~#%&*{}\\:<>!?/|+" @\[\]_.]'){;
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | Error | The Admin username contains spaces or special chars, ->$($object.PEAdmin)<-.";
      }
      $validation = "Error";
    } else {
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | INFO  | The Admin username is validated."      
      }
    }
    if ($object.PEPass -eq $null){;
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | Error | The Admin password is blanc, you have to specify the password if you edit the config in the UI.";
      }
      $validation = "Error";
    } elseif ($object.PEPass -notmatch '[~#%&*{}\\:!<>?/|+" @\[\]_.]' -or $object.PEPass -notmatch "[0-9]" -or $object.pepass -notmatch "[a-z]" -or $object.pepass -notmatch "[A-Z]" -or $object.pepass.length -le 7 -or $object.pepass -match "nutanix"){;
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | Error | Password does not meet the complexity requirements 1 upper, 1 lower, 1 special, 1 digit and 8 chars long, No dollarsigns or anything matching the word 'nutanix'.";
      }
      $validation = "Error";
    } else {
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | INFO  | The Admin Password is validated."      
      }
    }
    if ($object.POCname -match '[~#%&*{}\\:<>?/|+" @\[\]_.]'){;
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | Error | The POCname contains Special chars, ->$($object.POCname)<-";
      }
      $validation = "Error";
    } elseif ($object.POCname.length -ge 11){;
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | Error | The POCname cannot be longer then 8 chars, Current is ->$($object.POCname.length)<-";
      }
      $validation = "Error";
    } elseif ($object.POCname.length -le 1){;
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | Error | The POCname cannot be shorter than 2 chars, Current is ->$($object.POCname.length)<-";
      }
      $validation = "Error";
    } else {
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | INFO  | The POCname is clean" 
      }
    }
    if ($object.SenderEMail -match '[~#%&*{}\\:<>?/|+" \[\]]'){;
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | Error | The Sender Email contains Special chars, ->$($object.SenderEMail)<-.";
      }
      $validation = "Error";   
    } else {
      if ($debug -ge 1){
        write "$(get-date -format "hh:mm:ss") | INFO  | The Sender Email is validated." 
      } 
    }



    if ($validation -ne "OK" -and $processingmode -ne "SCAN" -or ($object.queue -eq "Manual")){;
      $processingmode = "Manual";
    };

    if ($processingmode -eq "Manual"){;
      $query = "UPDATE [$($SQLDatabase)].[dbo].$($SQLQueueTableName) 
          SET QueueStatus = 'Manual', 
              QueueValid = '$validation',
              InfraSubnetmask = '$($object.InfraSubnetmask)',
              InfraGateway = '$($object.InfraGateway)',
              DNSServer = '$($object.DNSServer)',
              Nw2subnet = '$($object.Nw2subnet)',
              AOSVersion = '$($object.AOSVersion)'
          WHERE QueueUUID='$($object.QueueUUID)';" 

      $Update = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query $query;
    } elseif ($processingmode -eq "NOW" -and $validation -eq "OK") {;
      $query = "UPDATE [$($SQLDatabase)].[dbo].$($SQLQueueTableName) 
                SET QueueStatus = 'OutGoing', 
                    QueueValid = '$validation',
                    InfraSubnetmask = '$($object.InfraSubnetmask)',
                    InfraGateway = '$($object.InfraGateway)',
                    DNSServer = '$($object.DNSServer)',
                    Nw2subnet = '$($object.Nw2subnet)',
                    AOSVersion = '$($object.AOSVersion)'
                WHERE QueueUUID='$($object.QueueUUID)';" 
                
      $Update = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query $query;
    } elseif ($processingmode -eq "SCAN") {;
    
    } else {;
      
    };
    return $validation;
  } else {;
    Write-host "Nothing to Process";
  };
};