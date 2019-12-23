function CMD-Set-DataservicesIP {
  param (
    $DataServicesIP,
    $PEClusterIP,
    $clusername,
    $clpassword,
    $DEBUG
  )
  $count = 0
  do {
    $count++
    write-log -message "Connecting to PS CMD on Prism Element"

    try {
      $hide = LIB-Connect-PSNutanix -ClusterName $PEClusterIP -NutanixClusterUsername $clusername -NutanixClusterPassword $clpassword
  
      $count++
      $cluster = Get-NTNXCluster
      if ($cluster){;
  
        write-log -message "Setting Dataservices IP"
  
      };
    } catch {
      write-log -message "Not connected." -sev "WARN"
    }
    $IP = (Get-NTNXCluster).clusterExternalDataServicesIPAddress
    if ($ip){

      write-log -message "Data Services IP already set, updating"
      write-log -message "Current value: $ip"
      write-log -message "New value: $ip"

    } else {;
      try{
        Set-NTNXCluster -ClusterExternalDataServicesIPAddress $DataServicesIP
      } Catch {
        Set-NTNXCluster -ClusterExternalDataServicesIPAddress $DataServicesIP
      }
    };
    try{ 
      $IP = (Get-NTNXCluster).clusterExternalDataServicesIPAddress
      write-log -message "DataServicesIP is set to $ip";
    
      if ($ip -ne $DataServicesIP){
  
        write-log -message "Something is wrong, trying again." -sev "WARN"
  
        $status = "Failed"
      } else {
  
        write-log -message "All done here";
  
        $status = "Success"
      }
    } catch {
  
        write-log -message "Something is wrong, trying again." -sev "WARN"
  
        $status = "Failed"
    }
  } until ($status -eq "Success" -or $count -ge 5)
  $resultobject =@{
    Result = $status
  };
  return $resultobject
};
Export-ModuleMember *
