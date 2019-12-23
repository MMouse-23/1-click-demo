function CMD-Set-SMTPServerSettings {
  param (
    [object] $datavar,
    $ip,
    [object] $datagen
  )
  $count = 0
  do {
    $count++
    write-log -message "Connecting to PS CMD on Prism Element"

    try {
      $hide = LIB-Connect-PSNutanix -ClusterName $ip -NutanixClusterUsername $datagen.Buildaccount -NutanixClusterPassword $datavar.PEPass
  
      $count++
      $cluster = Get-NTNXCluster
      if ($cluster){;
  
        write-log -message "Setting SMTP Settings"
  
      };
    } catch {
      write-log -message "Not connected." -sev "WARN"
    }
    $smtp = Get-NTNXSmtpServer
    if ($smtp.address -ne $null -or $smtp.address -match $datagen.smtpServer){

      write-log -message "SMTP already set, updating"
      write-log -message "Current value: $($smtp.address)"
      write-log -message "New value: $($datagen.smtpServer)"

    } else {;

      write-log -message "SMTP is not set, creating"
      write-log -message "New value: $($datagen.smtpServer)"

    }
    try{
      Set-NTNXSmtpServer -address $datagen.smtpServer -FromEmailAddress $datagen.smtpSender -port $datagen.smtpport
    } Catch {
      Set-NTNXSmtpServer -address $datagen.smtpServer -FromEmailAddress $datagen.smtpSender -port $datagen.smtpport
    }
    
    try{ 
      $smtp = Get-NTNXSmtpServer
      write-log -message "SMTP server is set to $($smtp.address)";
    
      if ($smtp.address -ne $datagen.smtpServer){
  
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
