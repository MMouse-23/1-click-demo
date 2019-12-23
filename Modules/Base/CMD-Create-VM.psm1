Function CMD-Create-VM {
  param (
    $Sysprepfile,
    [string] $Networkname,
    [string] $Subnetmask,
    [string] $VMname,
    [string] $VMip,
    [string] $VMgw,
    [array]  $ImageNames,
    [string] $DNSServer1,
    [string] $DNSServer2,
    [decimal] $CPU = 4,
    [decimal] $cores = 1,
    [decimal] $RAM = 16,
    [decimal] $DiskSizeGB = 80,
    [string] $Sysprep,
    [string] $PEClusterIP,
    [string] $clusername,
    [string] $clpassword,
    [string] $DisksContainerName
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

        SLEEP 60

      };

  
    write-log -message "Starting Network Setup";
  
    $nicSpec = New-NTNXObject -Name VMNicSpecDTO;
    $network = Get-NTNXNetwork | where { $_.name -match $Networkname };
    if($network){;
      $nicSpec.networkuuid = $network.uuid;
      $nicSpec.requestedIpAddress = $VMip;
      $nicSpec.requestIp = $true
  
      write-log -message "Network found, UUID Captured $($network.uuid)";
  
    } else {;
  
      write-log -message "Specified VLANID: $Networkname, does not exist, it needs to be created in Prism, exiting" -sev "ERROR";
      write-log -message "Is this a hosted POC???, are we connected to Nutanix Powershell?" -sev "ERROR";
  
    };
  
$sysprep = @"
#cloud-config
runcmd:
 - configure_static_ip ip=$VMip gateway=$VMgw netmask=$Subnetmask nameserver=$($DNSServer1),$($DNSServer2)
"@

    write-log -message "Done setting up network";

    $vmdisks = $null
    foreach ($image in $ImageNames){
      if ($image -notmatch "ISO"){
  
        write-log -message "Setting up cloned disk";
     
        $vmDisk = New-NTNXObject -Name VMDiskDTO;
        $diskCloneSpec = New-NTNXObject -Name VMDiskSpecCloneDTO;
        $diskImage = (Get-NTNXImage | ?{$_.name -eq $image});
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
          $vmcust.userdata = $sysprep;
          $vmDisk.vmDiskClone = $diskCloneSpec;
          
          write-log -message "Disk Image Clone created.";
        } else {;
      
          write-log -message "Specified Image Name: $image, does not exist in the Image Store, exiting" -sev "ERROR"
      
        };
  
      } else {
        write-log -message "ISO Based Image";
      
        $vmDisk = New-NTNXObject -Name VMDiskDTO;
        $diskCreateSpec = New-NTNXObject -Name VmDiskSpecCreateDTO
        $diskCreateSpec.containerUuid = (Get-NTNXContainer -SearchString $DisksContainerName).containerUuid
        $diskCreateSpec.sizeMb = $DiskSizeGB * 1024
        $vmDisk.vmDiskCreate = $diskCreateSpec
        $vmDisk = @($vmDisk)
        $diskCloneSpec = New-NTNXObject -Name VMDiskSpecCloneDTO
        $ISOImage = (Get-NTNXImage | ?{$_.name -eq $image});
        if($ISOImage){;
          $diskCloneSpec.vmDiskUuid = $ISOImage.vmDiskId
          $vmISODisk = New-NTNXObject -Name VMDiskDTO
          $vmISODisk.isCdrom = $true
          $vmISODisk.vmDiskClone = $diskCloneSpec
          $vmDisk = @($vmDisk)
          $vmDisk += $vmISODisk
  
          write-log -message "ISO clone and Disk created, diskobject contains $($vmDisk.count) objects.";
      
        } else {;
      
          write-log -message "Specified Image Name: $image, does not exist in the Image Store, exiting" -sev "ERROR"
      
        };
      };
      [array]$vmdisks += $vmDisk
    };

    write-log -message "Creating VM";
  
    $createJobID = New-NTNXVirtualMachine -MemoryMb $RAM -Name $VMname -NumVcpus $CPU -NumCoresPerVcpu $cores -VmNics $nicSpec -VmDisks $vmDisks -Description $Description -VmCustomizationConfig $vmcust -ea:0;
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
  
        write-log -message "$VMName is already powered on";
  
      }
      $count2++
    } until ($ip -and $ip -notmatch "^169" -or $count2 -ge 15);
  
      write-log -message "Using IP $ip";
  
    if ($ip -match "^169"){
  
      write-log -message "BAD IP, this should not be possible." -sev "ERROR"
      write-log -message "trying again. As its me coding."  -sev "WARN"
  
      $count2 = 0  
      do {;
  
        write-log -message "Attempting count: $count2"
  
        $VM = Get-NTNXVM |where {$_.vmname -eq $VMname};
        $ip = $vm.ipAddresses[0];
        sleep 60;
        $count2++
      } until ($ip -and $ip -notmatch "^169" -or $count2 -ge 15);
    }

    write-log -message "Waiting for cloud init to finish";
  
    sleep 110

    try {
      $NEWIPtest = test-connection -computername $VMip -ea:0;
    } catch {
      
      write-log -message "Cannot Reach VM on its NEW IP Something is wrong. This message will self distruct in 5 seconds." -sev "WARN";
  
    }
    if ($NEWIPtest){
  
      write-log -message "IP change succesful";
  
      write-log -message "This is the captain speaking, one to beam up.";
      $result = "Success"
    } else {
      write-log -message "VM is not reachable on its new IP, retrying the VM Create.";
      $result = "Failed"
    }
  } until ($NEWIPtest -or $count5 -eq 5)
  $resultobject =@{
    Result = $result
  };
  return $resultobject
};




Function CMD-Create-VM-PW {
  param (
    $Sysprepfile,
    [string] $Networkname,
    [string] $Subnetmask,
    [string] $VMname,
    [string] $VMip,
    [string] $VMgw,
    [array]  $ImageNames,
    [string] $DNSServer1,
    [string] $DNSServer2,
    [decimal] $CPU = 4,
    [decimal] $cores = 1,
    [decimal] $RAM = 16,
    [decimal] $DiskSizeGB = 80,
    [string] $Sysprep,
    [string] $PEClusterIP,
    [string] $clusername,
    [string] $clpassword,
    [string] $DisksContainerName
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

        SLEEP 10

      };

  
    write-log -message "Starting Network Setup";
  
    $nicSpec = New-NTNXObject -Name VMNicSpecDTO;
    $network = Get-NTNXNetwork | where { $_.name -match $Networkname };
    if($network){;
      $nicSpec.networkuuid = $network.uuid;
      $nicSpec.requestedIpAddress = $VMip;
      $nicSpec.requestIp = $true
  
      write-log -message "Network found, UUID Captured $($network.uuid)";
  
    } else {;
  
      write-log -message "Specified VLANID: $Networkname, does not exist, it needs to be created in Prism, exiting" -sev "ERROR";
      write-log -message "Is this a hosted POC???, are we connected to Nutanix Powershell?" -sev "ERROR";
  
    };
  
$sysprep = @"
#cloud-config
password: $($datavar.pepass)
chpasswd: { expire: False }
ssh_pwauth: True
runcmd:
 - configure_static_ip ip=$VMip gateway=$VMgw netmask=$Subnetmask nameserver=$($DNSServer1),$($DNSServer2)
"@

    write-log -message "Done setting up network";

    $vmdisks = $null
    foreach ($image in $ImageNames){
      if ($image -notmatch "ISO"){
  
        write-log -message "Setting up cloned disk";
     
        $vmDisk = New-NTNXObject -Name VMDiskDTO;
        $diskCloneSpec = New-NTNXObject -Name VMDiskSpecCloneDTO;
        $diskImage = (Get-NTNXImage | ?{$_.name -eq $image});
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
          $vmcust.userdata = $sysprep;
          $vmDisk.vmDiskClone = $diskCloneSpec;
          
          write-log -message "Disk Image Clone created.";
        } else {;
      
          write-log -message "Specified Image Name: $image, does not exist in the Image Store, exiting" -sev "ERROR"
      
        };
  
      } else {
        write-log -message "ISO Based Image";
      
        $vmDisk = New-NTNXObject -Name VMDiskDTO;
        $diskCreateSpec = New-NTNXObject -Name VmDiskSpecCreateDTO
        $diskCreateSpec.containerUuid = (Get-NTNXContainer -SearchString $DisksContainerName).containerUuid
        $diskCreateSpec.sizeMb = $DiskSizeGB * 1024
        $vmDisk.vmDiskCreate = $diskCreateSpec
        $vmDisk = @($vmDisk)
        $diskCloneSpec = New-NTNXObject -Name VMDiskSpecCloneDTO
        $ISOImage = (Get-NTNXImage | ?{$_.name -eq $image});
        if($ISOImage){;
          $diskCloneSpec.vmDiskUuid = $ISOImage.vmDiskId
          $vmISODisk = New-NTNXObject -Name VMDiskDTO
          $vmISODisk.isCdrom = $true
          $vmISODisk.vmDiskClone = $diskCloneSpec
          $vmDisk = @($vmDisk)
          $vmDisk += $vmISODisk
  
          write-log -message "ISO clone and Disk created, diskobject contains $($vmDisk.count) objects.";
      
        } else {;
      
          write-log -message "Specified Image Name: $image, does not exist in the Image Store, exiting" -sev "ERROR"
      
        };
      };
      [array]$vmdisks += $vmDisk
    };

    write-log -message "Creating VM";
  
    $createJobID = New-NTNXVirtualMachine -MemoryMb $RAM -Name $VMname -NumVcpus $CPU -NumCoresPerVcpu $cores -VmNics $nicSpec -VmDisks $vmDisks -Description $Description -VmCustomizationConfig $vmcust -ea:0;
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
      sleep 10;
      try {
        if ($vm.powerstate -ne "on"){
          $poweronJobID = Set-NTNXVMPowerOn -Vmid $VMidToPowerOn;
        }
      } catch {
  
        write-log -message "$VMName is already powered on";
  
      }
      $count2++
    } until ($ip -and $ip -notmatch "^169" -or $count2 -ge 15);
  
      write-log -message "Using IP $ip";
  
    if ($ip -match "^169"){
  
      write-log -message "BAD IP, this should not be possible." -sev "ERROR"
      write-log -message "trying again. As its me coding."  -sev "WARN"
  
      $count2 = 0  
      do {;
  
        write-log -message "Attempting count: $count2"
  
        $VM = Get-NTNXVM |where {$_.vmname -eq $VMname};
        $ip = $vm.ipAddresses[0];
        sleep 10;
        $count2++
      } until ($ip -and $ip -notmatch "^169" -or $count2 -ge 15);
    }

    write-log -message "Waiting for cloud init to finish";
  
    sleep 10

    try {
      $NEWIPtest = test-connection -computername $VMip -ea:0;
    } catch {
      
      write-log -message "Cannot Reach VM on its NEW IP Something is wrong. This message will self distruct in 5 seconds." -sev "WARN";
  
    }
    if ($NEWIPtest){
  
      write-log -message "IP change succesful";
  
      write-log -message "This is the captain speaking, one to beam up.";
      $result = "Success"
    } else {
      write-log -message "VM is not reachable on its new IP, retrying the VM Create.";
      $result = "Failed"
    }
  } until ($NEWIPtest -or $count5 -eq 5)
  $resultobject =@{
    Result = $result
  };
  return $resultobject
};
Export-ModuleMember *
