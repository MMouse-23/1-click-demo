function LIB-Test-ClusterPrereq{
  param (
    $PEClusterIP
  )
  do {;
    $count = $count +1;
    write-log -message "Connection to cluster $PEClusterIP"
    write-log -message "Attempt $count out of 3"
    try {
      $test = test-connection -computername "$PEClusterIP" -ea:0;
      sleep 15;
      $status = $test[0].statuscode -eq 0
    } catch {
      write-log -message "Connection to cluster not possible"
    }
  } until ($status -or $count -eq 3 );
  If ($status){;

    write-log -message "Cluster Operable, proceeding";

    $Status = "Success"
  } else {

    write-log -message "Danger Will Robinson" -sev "WARN"

    $Status = "Failed"
  };
  $resultobject =@{
    Result = $Status
  };
  return $resultobject
};
Export-ModuleMember *
