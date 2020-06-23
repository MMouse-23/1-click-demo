function Wrap-Join-PxtoADDomain{
  param (
    [object] $datagen,
    [object] $datavar,
    [string] $mode
  )

  $count3 = 0;

  do{;
    $count3++

    $netbios = $datagen.Domainname.split(".")[0];
    
    write-log -message "Mode is $mode"
    write-log -message "We determined the netbios name is $netbios";
    write-log -message "Setting up DNS with entries $($datagen.DC1IP) and $($datagen.DC2IP)";
    write-log -message "Removing NTP servers, Adding AD NTP Servers";
    write-log -message "Using LDAP String ldap://$($datagen.DC1Name).$($datagen.domainname):3268"
    
    try {
      $NTPServers = REST-List-NTP -datagen $datagen -datavar $datavar -mode $mode
      foreach ($ntp in $NTPServers){
        $hide=REST-Remove-NTP -datagen $datagen -datavar $datavar -mode $mode
      }
      $hide=REST-ADD-NTP -datagen $datagen -datavar $datavar -mode $mode -NTP $datagen.NTPServer1
      $hide=REST-ADD-NTP -datagen $datagen -datavar $datavar -mode $mode -NTP $datagen.NTPServer2
      $hide=REST-ADD-NTP -datagen $datagen -datavar $datavar -mode $mode -NTP $datagen.NTPServer3
      $hide=REST-ADD-NTP -datagen $datagen -datavar $datavar -mode $mode -NTP $datagen.NTPServer4

      write-log -message "NTP Setup Success";
      REST-List-NTP -datagen $datagen -datavar $datavar -mode $mode

    } catch {

      write-log -message "NTP Setup Failure" -sev "WARN";

    }

    write-log -message "Getting DNS servers";
    try{
      [array]$DNS =REST-Get-DNS-Servers -datagen $datagen -datavar $datavar -mode $mode
      
      if ($dns){

        write-log -message "We have $($Dns.count) DNS servers to remove";

        $hide = REST-Remove-DNS-Servers -datagen $datagen -datavar $datavar -DNSArr $dns -mode $mode
        
      } else {

        write-log -message "There are no DNS Servers to Remove";

      }
      $DNS =$null
      [array]$DNS += $datagen.DC1IP
      [array]$DNS += $datagen.DC2IP
      $hide = REST-Add-DNS-Servers -datagen $datagen -datavar $datavar -DNSArr $dns -mode $mode   

      write-log -message "Checking DNS servers"
          
      REST-Get-DNS-Servers -datagen $datagen -datavar $datavar -mode $mode

      write-log -message "DNS Setup Success";

    } catch {
      
      write-log -message "DNS Setup Failure" -sev "WARN"

    }
    $count = 0

    $authdom = REST-Get-AuthConfig -datagen $datagen -datavar $datavar -mode $mode
    if ($authdom.directoryList.domain -eq $datagen.domainname){;

      write-log -message "$($mode) already Joined.";
      write-log -message "See Domain below";

      $authdom.directoryList.domain
    } else {

      if ($authdom.directoryList.domain -and $authdom.directoryList.domain -ne $datagen.domainname){

        REST-Remove-AuthConfig -datavar $datavar -datagen $datagen -name $authdom.directoryList.name

        write-log -message "Auto DC Garbage!";
        
      }

      $pxjoin = 0
      $count = 0
      do {
        $count++
        try{
          REST-ADD-AuthConfig -datagen $datagen -datavar $datavar -mode $mode

          write-log -message "$($mode) Join Success.";

          $pxjoin =1
        } catch {
          sleep 119

          $pxjoin =0
          write-log -message "$($mode) Join Failure." -sev "WARN"
        }
      } until ($pxjoin -eq 1 -or $count -ge 8)
    }
    sleep 10
    $authdom = REST-Get-AuthConfig -datagen $datagen -datavar $datavar -mode $mode

    $roleMapping = REST-Get-RoleMapping -datagen $datagen -datavar $datavar -mode $mode
    if ($roleMapping){
      write-log -message "Roles are already mapped for $netbios"
      REST-Get-RoleMapping -datagen $datagen -datavar $datavar -mode $mode
    } else {
      REST-Add-RoleMapping -datagen $datagen -datavar $datavar -mode $mode
      write-log -message "Roles mapped for $netbios";
      REST-Get-RoleMapping -datagen $datagen -datavar $datavar -mode $mode
    }
    
  } Until ($authdom.directoryList.domain -eq $datagen.domainname -or $count3 -ge 3)
  if ($authdom.directoryList.domain -eq $datagen.domainname){
    $status = "Success"
    if ($debug -ge 2){
      $authdom
    }
  } else {
    $status = "Failure"
  }
  $resultobject =@{
    Result = $status
  };
  return $resultobject
};
Export-ModuleMember *
