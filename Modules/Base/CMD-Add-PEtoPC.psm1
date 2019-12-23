function CMD-Add-PEtoPC{
  param (
    $PCClusterIP,
    $PEClusterIP,
    $PEAdmin,
    $PEPass
  )
  do {

    write-log -message "Connecting to PS CMD on Prism Element"

    try {
      $hide = LIB-Connect-PSNutanix -ClusterName $PEClusterIP -NutanixClusterUsername $PEAdmin -NutanixClusterPassword $PEPass
  
      $count++
      $cluster = Get-NTNXCluster
      if ($cluster){;
  
        write-log -message "Joining PE Cluster to the PC Cluster"
  
      };
    } catch {

      write-log -message "Not connected." -sev "WARN"

    }
    try {
      $result = Add-NTNXClusterToMulticluster -IpAddresses $PCClusterIP -username $PEAdmin -password $PEPass;
    } catch {
      try { 
        $hide = Remove-NTNXClusterFromMulticluster -IpAddresses $PCClusterIP -username $PEAdmin -password $PEPass;
      } catch {

        write-log -message "Failed Joining / Removing PE Cluster to the PC Cluster." -sev "WARN"

      }
      sleep 120
      $result = Add-NTNXClusterToMulticluster -IpAddresses $PCClusterIP -username $PEAdmin -password $PEPass;
    };
  } until ($result -match "Success" -or $count -ge 3)
  sleep 20
  if ($result -match "Success"){
    $status = "Success"

    write-log -message "Pe has been Joined to PC";
    write-log -message "Loving it";

    $result

  } else {
    $status = "Failed"

    write-log -message "Danger Will Robbinson." -sev "ERROR";

  }
  $resultobject =@{
    Result = $status
  };
  return $resultobject
}
Export-ModuleMember *

