Function CMDPSR-Create-VM {
  param (
    $Sysprepfile,
    [string] $SysprepPassword,
    [string] $Networkname,
    [string] $Subnetmask,
    [string] $VMname,
    [string] $VMip,
    [string] $VMgw,
    [string] $ImageName,
    [string] $DNSServer1,
    [string] $DNSServer2,
    [decimal] $CPU = 4,
    [decimal] $RAM = 8192,
    [decimal] $DiskSizeGB = 80,
    [string] $Sysprep,
    [string] $PEClusterIP,
    [string] $clusername,
    [string] $clpassword,
    [string] $DisksContainerName,
    [string] $mode,
    [object] $datagen,
    [object] $datavar
  )

  $count5 = 0

  do {
    $count1 = 0
    $count2 = 0
    $count3 = 0
    $count4 = 0
    $count5++
    $ip = $null
    write-log -message "Connecting to PS CMD on Prism Element";
  
    try {;
      $hide = LIB-Connect-PSnutanix -ClusterName $PEClusterIP -NutanixClusterUsername $clusername -NutanixClusterPassword $clpassword;
    
      $count++
      $cluster = Get-NTNXCluster;
      if ($cluster){;
    
        write-log -message "Creating a New VM";
    
      };
    } catch {;
    
      write-log -message "Not connected." -sev "WARN";
    
    };

    ##### Currently this module only supports creating single disk clones of existing images. TO DO add blanc disk / iso mount support for 2016
    ##### This module assumes DHCP for the created VM. Once it reads the DHCP IP, it will connect using PowerShell
    ##### Once connected over PSR the IP stack will be changed to its final fixed IP.
  

      $VM = Get-NTNXVM |where {$_.vmname -eq $VMname};
      if ($vm){;
  
        write-log -message "You did not clean up after last attempt."
        write-log -message "Cleaning up for you..., are you like my author?.."
  
        $vm.vmid | Remove-NTNXVirtualMachine
        if ($VMname -match "^DC1-.*POC"){
          $VM = Get-NTNXVM |where {$_.vmname -match "^DC2-.*POC"} | select -first 1 -ea:0
          $vm.vmid | Remove-NTNXVirtualMachine -ea:0
        }
        sleep 30
      };

  
    write-log -message "Starting Network Setup";
  
    $nicSpec = New-NTNXObject -Name VMNicSpecDTO;
    $network = Get-NTNXNetwork | where { $_.name -match $Networkname };
    if($network){;
      $nicSpec.networkuuid = $network.uuid;
      if ($mode -eq "ReserveIP"){

        write-log -message "Using DHCP Reservation for $vmname";

        $nicSpec.requestedIpAddress = $VMip
        $nicSpec.requestIp = $VMip;
      }
      write-log -message "Network found, UUID Captured $($network.uuid)";

      if ($mode -eq "SysprepIP"){

        write-log -message "Lets hope this customized sysprep works";

      }
    } else {;
  
      write-log -message "Specified VLANID: $Networkname, does not exist, it needs to be created in Prism, exiting" -sev "ERROR";
      write-log -message "Is this a hosted POC???, are we connected to Nutanix Powershell?" -sev "ERROR";
  
    };
  
    write-log -message "Done setting up network";
    if ($ImageName -notmatch "ISO"){
      write-log -message "Setting up cloned disk";
    
      $vmDisk = New-NTNXObject -Name VMDiskDTO;
      $diskCloneSpec = New-NTNXObject -Name VMDiskSpecCloneDTO;
      $diskImage = (Get-NTNXImage | ?{$_.name -eq $ImageName});
      if($diskImage){;
        if($diskImage.Length -gt 1){;
          $diskToUse = $diskImage[0];
          foreach($disk in $diskImage){;
            if($disk.updatedTimeInUsecs -gt $diskToUse.updatedTimeInUsecs){ ;
              $diskToUse = $disk;
            };
          };
          $diskImage = $diskToUse;
        };
        $diskCloneSpec.vmDiskUuid = $diskImage.vmDiskId;
        $VMCust = new-ntnxobject -name VMCustomizationConfigDTO;
        $vmcust.userdata = $Sysprepfile;
        $vmDisk.vmDiskClone = $diskCloneSpec;
        write-log -message "Disk Image Clone created.";
    
      } else {;
    
        write-log -message "Specified Image Name: $ImageName, does not exist in the Image Store, exiting" -sev "ERROR"
    
      };

    } else {
      write-log -message "ISO Based VM";
    
      $vmDisk = New-NTNXObject -Name VMDiskDTO;
      $diskCreateSpec = New-NTNXObject -Name VmDiskSpecCreateDTO
      $diskCreateSpec.containerUuid = (Get-NTNXContainer -SearchString $DisksContainerName).containerUuid
      $diskCreateSpec.sizeMb = $DiskSizeGB * 1024
      $vmDisk.vmDiskCreate = $diskCreateSpec
      $vmDisk = @($vmDisk)
      $diskCloneSpec = New-NTNXObject -Name VMDiskSpecCloneDTO
      $ISOImage = (Get-NTNXImage | ?{$_.name -eq $ImageName});
      if($ISOImage){;
        $diskCloneSpec.vmDiskUuid = $ISOImage.vmDiskId
        $vmISODisk = New-NTNXObject -Name VMDiskDTO
        $vmISODisk.isCdrom = $true
        $vmISODisk.vmDiskClone = $diskCloneSpec
        $vmDisk = @($vmDisk)
        $vmDisk += $vmISODisk

        write-log -message "ISO clone and Disk created, diskobject contains $($vmDisk.count) objects.";
    
      } else {;
    
        write-log -message "Specified Image Name: $ImageName, does not exist in the Image Store, exiting" -sev "ERROR"
    
      };
    };

  
    write-log -message "Creating VM";
  
    $createJobID = New-NTNXVirtualMachine -MemoryMb $RAM -Name $VMname -NumVcpus $CPU -NumCoresPerVcpu 1 -VmNics $nicSpec -VmDisks $vmDisk -Description $Description -VmCustomizationConfig $vmcust -ea:0;
    $count = 0;
    $count1 = 0;
    do{
  
      write-log -message "Waiting 5 seconds for $VMName to finish creating...";
      write-log -message "If not created yet, try/loop 6 more times.";
  
      Sleep 5;
      $VMidToPowerOn = (Get-NTNXVM -SearchString $VMName).vmid;
      $count1 = $count1 + 1
    } until ($VMidToPowerOn -or $count1 -ge 6)
    if ($VMidToPowerOn){;
  
      write-log -message "Powering on $VMName";
  
      $poweronJobID = Set-NTNXVMPowerOn -Vmid $VMidToPowerOn;
      if($poweronJobID){;
  
        write-log -message "Successfully powered on $VMName";
  
      } else {;
  
        write-log -message "Couldn't power on $VMName, exiting" -sev "WARN"
  
      };
    } else {;
  
      write-log -message "Failed to Get $VMName after creation, not powering on..." -sev "WARN"
  
    };
  
    write-log -message "Waiting for VM to come online with non-APIPA IP";
    write-log -message "Waiting 15 seconds for each attempt.";
    write-log -message "If a valid IP is not set, try/loop 6 more times.";
    
    do {;
  
      write-log -message "Attempt 1, count: $count2"
  
      $VM = Get-NTNXVM |where {$_.vmname -eq $VMname};
      $ip = $vm.ipAddresses[0];
      sleep 60;
      try {
        if ($vm.powerstate -ne "on"){
          $poweronJobID = Set-NTNXVMPowerOn -Vmid $VMidToPowerOn;
        }
      } catch {
  
        write-log -message "$VMName is already powered on?";
  
      }
      $count2++
    } until ($ip -and $ip -notmatch "^169" -or $count2 -ge 6);
  
      write-log -message "Using IP $ip";
  
    if ($ip -match "^169"){
  
      write-log -message "BAD IP, this should not be possible." -sev "ERROR"
      write-log -message "trying again. As its me coding."  -sev "WARN"
  
      $count2 = 0  
      do {;
  
        write-log -message "Attempt 1, count: $count2"
  
        $VM = Get-NTNXVM |where {$_.vmname -eq $VMname};
        $ip = $vm.ipAddresses[0];
        sleep 60;
        $count2++
      } until ($ip -and $ip -notmatch "^169" -or $count2 -ge 6);
    }

    if ($ip){

      write-log -message "Calculating subnet size";
  
      $subnetprefix = Convert-IpAddressToMaskLength $Subnetmask;
    
      write-log -message "Subnet mask is $Subnetmask";
      write-log -message "Calculated size is $subnetprefix";
    
      if ($subnetprefix -eq 0){;
    
        write-log -message "Garbage in is garbage out, not letting that happen." -sev "WARN";
    
      }   
      
      write-log -message "Building Powershell remoting credential";
    
      $password = $SysprepPassword | ConvertTo-SecureString -asplaintext -force;
      $credential = New-Object System.Management.Automation.PsCredential("administrator",$password);
      
      write-log -message "Waiting for sysprep to finish";
  
      if ($imagename -match "2016"){
        sleep 30
  
        write-log -message "This takes a little longer on 2016";
        
      }
  
      sleep 60;
      try {
        $oldIPtest = test-connection -computername $ip -ea:0;
      } catch {
  
        write-log -message "Slow block.... Are we sure its healthy?" -sev "WARN";
        
        sleep 119
      }
      try{
        $code = $oldIPtest[0].statuscode
      } catch {
  
      }
      if ($code -ne 0){
        $ipretry = 0
        do{
          write-log -message "Host is not alive yet waiting for SYSPrep some more"
      
          $ipretry ++
          sleep 30
          $oldIPtest = test-connection -computername $ip -ea:0;
          $code = $oldIPtest[0].statuscode
        } until ($ipretry -ge 6 -or $code -eq 0)
      }
  
      if ($code -eq 0){;
        sleep 80
        write-log -message "Host is alive at $IP"
        write-log -message "Changing the VM IPaddress and name using PowerShell Remoting.";
        if ($mode -eq "ReserveIP" ){
  
            write-log -message "DHCP Mode"
  
          $connect = invoke-command -computername $ip -credential $credential {;
            if ($Args[4] -match "2016"){
              Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name "fDenyTSConnections" -Value 0
              Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -Name "UserAuthentication" -Value 1
              Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
            }
            Rename-Computer -NewName $Args[3] -force; 
          } -Args $VMip,$VMgw,$subnetprefix,$VMname,$imagename -asjob;
        } else{
  
          write-log -message "Fixed ip Mode"
  
          $connect = invoke-command -computername $ip -credential $credential {;
            if ($Args[4] -match "2016"){
              $AUSettings = (New-Object -com "Microsoft.Update.AutoUpdate").Settings
              $AUSettings.NotificationLevel = 1
              $AUSettings.Save
              Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name "fDenyTSConnections" -Value 0
              Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -Name "UserAuthentication" -Value 1
              Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
              sc.exe config wuauserv start=disabled         
              sc.exe query wuauserv         
              sc.exe stop wuauserv
              sc.exe query wuauserv      
              REG.exe QUERY HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\wuauserv /v Start 
            }
            Rename-Computer -NewName $Args[3] -force; New-NetIPAddress -IPAddress $args[0] -DefaultGateway $args[1] -PrefixLength $args[2] -InterfaceIndex (Get-NetAdapter).InterfaceIndex ; shutdown -r -t 1;
          } -Args $VMip,$VMgw,$subnetprefix,$VMname,$imagename -asjob;
        }
  
        write-log -message "Sleeping after command execution.";
    
        sleep 90;
      } else {;
  
      write-log -message "Cannot Reach VM on its first IP Something is wrong. This message will self distruct in 5 seconds." -sev "WARN";
    
      };
    } else {

      write-log -message "Cannot Reach VM on its first IP Something is wrong. This message will self distruct in 5 seconds." -sev "WARN";

    }
    try {
      $NEWIPtest = test-connection -computername $VMip -ea:0;
    } catch {
      
      write-log -message "Cannot Reach VM on its NEW IP Something is wrong. This message will self distruct in 5 seconds." -sev "WARN";
  
    }
    if ($NEWIPtest){
  
      write-log -message "IP change successful, setting DNS";
  
      $connect = invoke-command -computername $VMip -credential $credential {;
        Set-DnsClientServerAddress -interfacealias (Get-NetAdapter).name -ServerAddresses ("$($args[0])","$($args[1])");
      }  -Args $DNSServer1,$DNSServer2;
  
      write-log -message "This is the captain speaking, one to beam up.";
      $result = "Success"
    } else {
      write-log -message "VM is not reachable on its new IP, retrying the VM Create.";
      $result = "Failed"
    }
    
  } until ($NEWIPtest -or $count5 -eq 5)

  write-log -message "Getting VMs"

  $vms = REST-Get-VMs -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.PEPass -clusername $datagen.BuildAccount
  
  write-log -message "Filtering VM for $VMIP"
  
  $vm = $VMS.entities | where {$_.IPaddresses -eq $VMIP}
  
  write-log -message "Getting VM Disk Detail for $($vm.uuid) using $VMIP"
  
  $VMdetail = REST-Get-VM-Detail -datavar $datavar -datagen $datagen -uuid $vm.uuid
  
  write-log -message "Finding CDROM"
  
  $CDrom = $VMdetail.vm_disk_info | where {$_.is_cdrom -eq $true}
  if ($cdrom.is_empty -eq $false){
  
    write-log -message "CDROM is not Empty, eject captain."
  
    REST-Unmount-CDRom -datavar $datavar -datagen $datagen -uuid $vm.uuid -cdrom $cdrom
  }
  $VMdetail = REST-Get-VM-Detail -datavar $datavar -datagen $datagen -uuid $vm.uuid
  $CDrom = $VMdetail.vm_disk_info | where {$_.is_cdrom -eq $true}
  if ($cdrom.is_empty -eq $false){
  
    write-log -message "CDROM is still not Empty hmm" -sev "WARN"
  
    REST-Unmount-CDRom -datavar $datavar -datagen $datagen -uuid $vm.uuid -cdrom $cdrom
  }
  if ($datagen.Frame_GoldenVMIP -ne $VMIP){
    write-log -message "Mounting NGT"
    
    REST-Mount-NGT -datavar $datavar -datagen $datagen -vmuuid $vm.vmid
    
    write-log -message "Installing NGT"
    
    PSR-Install-NGT -datagen $datagen -datavar $datavar -ip $VMIP
  
    write-log -message "NGT Install Running, Waiting for CDROM Eject"
  } else {

    write-log -message "Not Installing NGT on Frame"

  }
  do {
    $errorwait++
    $VMdetail = REST-Get-VM-Detail -datavar $datavar -datagen $datagen -uuid $vm.uuid
    
    write-log -message "Finding CDROM"
    
    $CDrom = $VMdetail.vm_disk_info | where {$_.is_cdrom -eq $true}
    if ($cdrom.is_empty -eq $false){
    
      write-log -message "CDROM is not Empty, Install is still running"

      sleep 119
    } else {

      write-log -message "CDROM is Empty, NGT Install is done."

    }

  } until ($cdrom.is_empty -eq $true -or $errorwait -ge 5)

  write-log -message "Syncing Local VM time and Timezome to match this service."
  try {
    PSR-Set-Time -datagen $datagen -datavar $datavar -ip $VMIP
  } catch {
    sleep 30
    PSR-Set-Time -datagen $datagen -datavar $datavar -ip $VMIP
  }
  $resultobject =@{
    Result = $result
  };
  return $resultobject
};
Export-ModuleMember *