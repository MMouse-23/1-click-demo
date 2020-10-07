function Wrap-Create-VMware-VM {
  Param (
    [object]  $datavar,
    [object]  $datagen,
    [string]  $VMname,
    [String]  $VMIP,
    [String]  $VMDNS1 = $datagen.DC1IP,
    [String]  $VMDNS2 = $datagen.DC2IP,
    [decimal] $CPU = 4,
    [decimal] $RAM = 8192,
    [decimal] $cores = 1,
    [decimal] $DiskSizeGB = 80,
    [string]  $guestOS,
    [Array]   $NDFSSource,
    [bool]    $DHCP,
    [string]  $container,
    [bool]    $createTemplate,
    [string]  $mode
  )

  write-log -message "Using VM Name $($VMname)"

  CMD-Connect-VMware -datavar $datavar
  $machine = get-vm -Name $VMName -ea:0
  if ($machine){
    if ($Debug -ge 6){
      write-log -message "Kill me now if you want to see the VM"
      sleep 60
    }
    write-log -message "Machine exists, deleting."

    $machine | stop-vm -confirm:0 -ea:0
    sleep 10
    $machine | remove-vm -confirm:0 -ea:0
    sleep 10
    $machine = get-vm -Name $VMName -ea:0
    if ($machine){

      write-log -message "Nasty one arnt you?" -sev "WARN"

    }
  } else {

    write-log -message "Nice and clean, always the best results..."

  }
  write-log -message "Getting networks"

 	$networks = REST-Get-PE-Networks -datavar $datavar -datagen $datagen
  $network = $networks.entities | where { $_.name -eq "$($datagen.Nw1name)" }

  write-log -message "Using Network UUID $($network.uuid)" 
  write-log -message "Using $guestOS as Guest OS"
  write-log -message "Using $NDFSSource as Source Image name"

  $imageURL = $($ISOurlData1.$($NDFSSource))

  if ($imageURL -match "ova|ovf"){
    

    write-log -message "Using $imageURL as Source Image URL"

    write-log -message "OVA Mode, using Management node inside the cluster for powershell remoting download."
    write-log -message "OVA Mode, waiting for Management node installer."
    write-log -message "Container is $container"

    if ($debug -le 6){
      Wait-Mgt-Task -datavar $datavar
    }
    $maincounter = 0
    do{
      $maincounter ++
      if ($maincounter -ge 1){
         CMD-Connect-VMware -datavar $datavar
         $machine = get-vm -Name $VMName -ea:0
         if ($machine){
       
           write-log -message "Machine exists, deleting."
       
           $machine | stop-vm -confirm:0 -ea:0
           sleep 10
           $machine | remove-vm -confirm:0 -ea:0
           sleep 10
           $machine = get-vm -Name $VMName -ea:0
           if ($machine){
       
             write-log -message "Nasty one arnt you?" -sev "WARN"
       
           }
         } else {
       
           write-log -message "Nice and clean, always the best results..."
       
         }
      }
      write-log -message "Creating OVA based VM."
  
         #Debug script with interactive function.     
         #$imageURL = "http://download.nutanix.com/move/3.2.0/move-3.2.0-esxi.ova"
         #$VMIP = $datagen.MoveIP
         #$vmname = $datagen.Move_VMName
         #$container = $datagen.DisksContainerName
         #PSR-Install-OVA-Template-IA -datavar $datavar -datagen $datagen -mgtip $datagen.Mgmt1_VMIP -container $container -vmname $vmname -imageURL $imageURL -vmIP $VMIP

      $failed = 0
      sleep 60
      $count = 0
      do {
        $count++
        #PSR-Install-OVA-Template-IA -datavar $datavar -datagen $datagen -mgtip $datagen.Mgmt1_VMIP -container $container -vmname $vmname -imageURL $imageURL -vmIP $VMIP

        $job = PSR-Install-OVA-Template -datavar $datavar -datagen $datagen -mgtip $datagen.Mgmt1_VMIP -container $container -vmname $vmname -imageURL $imageURL -vmIP $VMIP

        write-log -message "OVA Deploy is a job. Waiting till we find the VM ID"
        Wait-ESX-OVF-Task -datavar $datavar
        $vm = (REST-Get-VMs -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.PEPass -clusername $datavar.peadmin).entities | where {$_.vmName -eq $VMname}
      } until ($vm -or $count -ge 3)
      
      write-log -message "Using VM ID $($vm.uuid)"
  
      sleep 10
      CMD-Connect-VMware -datavar $datavar
  
      write-log -message "Updating the VM with powerCLI"
      Get-VM -Name $vmname | Set-VM -GuestId centos64Guest -Confirm:$false
      write-log -message "Removing ghosted NIC"
      get-vm -name $vmname | Get-NetworkAdapter | Remove-NetworkAdapter -confirm:0
      sleep 10
      REST-ADD-Nic-VMware -datavar $datavar -datagen $datagen -networkuuid $($network.uuid) -vmuuid $($vm.uuid)
      write-log -message "Sending Poweron"
  
      REST-Set-VM-Power-State -datavar $datavar -datagen $datagen -VMuuid "$($vm.uuid)" -state "On"
  
      write-log -message "Wait for VMTools to report IPaddress."
      sleep 110
      $count = 0
      do {
        $count++
        $vm = (REST-Get-VMs -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.PEPass -clusername $datavar.peadmin).entities | where {$_.vmName -eq $VMname}
        $IP = $vm.ipAddresses | where {$_ -notmatch ":"}
        if (!$ip){
          sleep 30
        }
      } until ($count -ge 3 -or $ip)
  
      write-log -message "VMware is so bolted on, yes we have an IP now, OVA based: $IP"
  
      if ($ip -ne $vmip){
  
        write-log -message "DHCP has been used for this vm, i am expecting $vmip but i have $IP"
        
        write-log -message "Changing IP stack using SSH"
        $VMToolsMissing = 0
        if (!$ip){
  
          write-log -message "Alright, lets see, we dont have an IP if we ask Prism or VMware."
          write-log -message "Lets see if our private DHCP knows this"
          write-log -message "Getting Mac First"
  
          $ALLVms = REST-Get-VM-Detail -datavar $datavar -datagen $datagen
          $nicdetails = $ALLVms.entities | where {$_.name -eq "$vmname"}
  
          write-log -message "Found $($nicdetails.vm_nics.count) Virtual Network Card(s)"
          write-log -message "Card has $($nicdetails.vm_nics.Mac_address), lets look that up"
          $mac = $($nicdetails.vm_nics.Mac_address) -replace ":",'-'
  
          write-log -message "Nothing is every easy.. $mac"
          write-log -message "Getting all leases."
  
          $ips = PSR-Get-DHCP-IP -datavar $datavar -datagen $datagen
  
          write-log -message "Filtering."
          $ip = ($ips | where {$_.clientID -eq $mac}).IPaddress
  
          write-log -message "There we go $ip, how about that being cloud native...."
          $VMToolsMissing = 1
        }
        $DHCPIP = $IP
        sleep 60

        if ($vmname -match "$($datagen.XRAY_VMName)" -or $vmname -match "$($datagen.Move_VMName)"){ 
          ## Xray does not have configure_IP, we need to use DHCP fallback below. 
          $failed = 0

        } else {
          try {
            $Failed = SSH-Finalize-Linux-VM -mode $mode -datavar $datavar -datagen $datagen -currentIP $ip -targetIP $vmip
          } catch {
            $failed = 1
          }          
        }

        sleep 40
        CMD-Connect-VMware -datavar $datavar
        get-vm -name $VMname | Shutdown-VMGuest -confirm:0 -ea:0
        sleep 40
        get-vm -name $VMname | stop-vm -confirm:0 -ea:0
        $randomname = get-random 12312
        $randomname = "$($randomname)_Spec_Centos"

        write-log -message "Running cust spec to set name"
        if ($failed -eq 1){

          $randomname = get-random 12312
          $randomname = "$($randomname)_Spec_Centos"
          $oscust = New-OSCustomizationSpec -OSType Linux -type NonPersistent -Name $randomname -Domain $datagen.Domainname -DNSServer "$($VMDNS1)", "$($VMDNS2)"
          Get-OSCustomizationSpec $oscust | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIp -IpAddress $VMIP -SubnetMask $datavar.InfraSubnetmask -DefaultGateway $datavar.InfraGateway


        } else {
          $oscust = New-OSCustomizationSpec -OSType Linux -type NonPersistent -Name $randomname -Domain $datagen.Domainname -DNSServer "$($VMDNS1)", "$($VMDNS2)" -NamingPrefix $VMname -NamingScheme "Fixed"
        }
        if ($VMToolsMissing -ne 1){
          get-vm -Name $VMname | Set-VM -OSCustomizationSpec $oscust -Confirm:0
        } else {
  
          write-log -message "We cannot customize OS if no VMTools are installed."
  
        }

        REST-Set-VM-Power-State -datavar $datavar -datagen $datagen -VMuuid "$($vm.uuid)" -state "On"
        sleep 30
        get-vm -name $vmname | Get-NetworkAdapter | set-networkadapter -connected $true -startconnected $true -confirm:0 -ea:0
        $ipretry = 0
        $failures = 0
        if ($vmname -match $datagen.XRAY_VMName -or $vmname -match $datagen.Move_VMName){
          $failures = 8
          # Fail Fast, XRAY Does not have proper VMtools / CLI, We need DHCP below.
        }
        do{

          write-log -message "Waiting till host is alive"
          write-log -message "IP $VMIP is not replying yet."
          
          $ipretry ++
          sleep 30
          $oldIPtest = test-connection -computername $VMIP -ea:0 -count 1
          $code = $oldIPtest.statuscode
          $seconds = $ipretry * 30
          write-log -message "Current return code is $code"
          if ($code -eq 0){
            write-log -message "Exiting here. This took $seconds seconds."
            $failed = 0
          } else {
            $failures ++
            write-log -message "Waiting for ping reply for $seconds seconds."
            if ($failures -ge 10){

              write-log -message "Creating a DHCP Reservation if all else fails."

              PSR-Add-DHCP-Reservation -datavar $datavar -datagen $datagen -targetIP $VMIP -source $DHCPIP -mode "IP"
              CMD-Connect-VMware -datavar $datavar
              get-vm -name $vmname | restart-vm -confirm:0

            }
          }

        } until ($ipretry -ge 30 -or $code -eq 0)
      }
    } until ($Failed -eq 0 -or $maincounter -ge 3)
  } else {

    foreach ($source in $NDFSSource){
      "We got Filename $($NDFSSource.count) image(s) to process."
      [string]$filename = $($($ISOurlData1.$($source)) -split "/") | select -last 1
      write-log -message "We got Filename $filename"
  
      if ($filename.length -ge 5){
  
        $filename = $filename.substring(0, $filename.length -7) + "-flat.vmdk"
  
        write-log -message "Changing to flat file: $filename"
  
        $imagefile = "/$($datagen.ImagesContainerName)/$($Filename)"
  
        write-log -message "Changing to full path: $imagefile"
        
      } else {
  
        write-log -message "Help filename is empty : $filename" -sev "ERROR"
  
      }
        
      write-log -message "VMDK Mode, Expecting VMDK on datastore, assumption is the mother of all..."
      write-log -message "Using Generated image path $imagefile"
  
      $outfilewin = $imagefile -replace "/","\"
  
      ## Control 
      CMD-Connect-VMware -datavar $datavar
      $datastoreitem = (get-item vmstores:\$($datavar.vcenterip)@443\Nutanix$($outfilewin))
      if ($datastoreitem){
  
        write-log -message "Controll Check PASS, VMDK Is present"
  
      } else {
        
        write-log -message "Controll Check FAIL" -SEV "WARN"
  
      }
      [array]$imagefiles += $imagefile
    }

    REST-Create-VM-VMware -datavar $datavar -datagen $datagen -guestOS $guestOS -VMname $VMname -network_uuid $($network.uuid) -NDFSSource $imagefiles -ram $ram -cpu $CPU -cores $cores
    
    $vmcounter = 0 
    do {
      $vmcounter++ 
      sleep 60
      $vm = (REST-Get-VMs -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.PEPass -clusername $datavar.peadmin).entities | where {$_.vmName -eq $VMname}
      if ($vm.uuid -match "[0-9]"){

        write-log -message "There we are, we have VM with UUID: $($vm.uuid)"

      } else {

        write-log -message "Slight delay in VM Create. Let me try again."

      }

    } until ($vm.uuid -match "[0-9]" -or $vmcounter -ge 5)

    if ($guestOS -match "windows" -and !$createTemplate){
      write-log -message "Sending VM Poweron for VM $($vm.uuid)"
      
      $loop = 0
      $exit = 0
      do {
        $loop++
        REST-Set-VM-Power-State -datavar $datavar -datagen $datagen -VMuuid "$($vm.uuid)" -state "On"
        sleep 20
        $vm = REST-Get-VM-Detail -datavar $datavar -datagen $datagen -uuid "$($vm.uuid)"
    
        if ($vm.power_state -eq "on"){
    
          write-log -message "VM Poweron Success"
    
          $exit = 1
        } else {
    
          write-log -message "Ah VMware crap..." -sev "WARN"
    
        }
      } until ($loop -ge 3 -or $exit -eq 1)
    
      #The below is needed because VMware Tools has not been running for this VM, thus it thinks the OS version is not supported for OS Customisation.....
      sleep 110
      CMD-Connect-VMware -datavar $datavar
      get-vm -name $VMname | Shutdown-VMGuest -confirm:0 -ea:0
      sleep 60
      get-vm -name $VMname | stop-vm -confirm:0 -ea:0
    }
    if ($guestos -eq "rhel7_64Guest" ){
      $looper = 0
      do {
        $Looper++
        write-log -message "Oracle Nic Detetction fix";

        $vm = (REST-Get-VMs -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.PEPass -clusername $datavar.peadmin).entities | where {$_.vmName -eq $VMname}
    
        write-log -message "Using VM ID $($vm.uuid)"
         
      } until ( $vm.uuid -match "[0-9]" -or $looper -ge 4)
      
        REST-ADD-Nic-VMware -datavar $datavar -datagen $datagen -networkuuid $($network.uuid) -vmuuid $($vm.uuid) -adapter_type "E1000"
        write-log -message "Sending Poweron"
  
        REST-Set-VM-Power-State -datavar $datavar -datagen $datagen -VMuuid "$($vm.uuid)" -state "On"  
    }
    if (!$createTemplate){
   
      write-log -message "Doing powerCLI magic for OS Customisation"
      
      if ($guestOS -eq "windows9Server64Guest" -or $guestos -eq "windows9_64Guest"){
        
        $randomname = get-random 12312
        $randomname = "$($randomname)_Spec_10_2016"
        $oscust = New-OSCustomizationSpec -Name $randomname -type NonPersistent -OSType Windows -FullName $datavar.pocname -OrgName Nutanix_Demo -NamingScheme Fixed -NamingPrefix $VMname -AdminPassword $datagen.SysprepPassword -Workgroup "Temp" -ChangeSid
        Get-OSCustomizationSpec $oscust | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIp -IpAddress $VMIP -SubnetMask $datavar.InfraSubnetmask -DefaultGateway $datavar.InfraGateway -Dns "$($VMDNS1)", "$($VMDNS2)"
        get-vm -Name $VMname | Set-VM -OSCustomizationSpec $oscust -Confirm:0
        write-log -message "Created Windows 10 / 2016 OS Spec"
      
      } elseif ($guestOS -eq "centos64Guest"){
  
        $randomname = get-random 12312
        $randomname = "$($randomname)_Spec_Centos"
        $oscust = New-OSCustomizationSpec -OSType Linux -type NonPersistent -Name $randomname -Domain $datagen.Domainname -DNSServer "$($VMDNS1)", "$($VMDNS2)"
        Get-OSCustomizationSpec $oscust | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIp -IpAddress $VMIP -SubnetMask $datavar.InfraSubnetmask -DefaultGateway $datavar.InfraGateway
        get-vm -Name $VMname | Set-VM -OSCustomizationSpec $oscust -Confirm:0
        
        write-log -message "Created Centos Spec"
  
      }
      
      CMD-Connect-VMware -datavar $datavar
  
      
      write-log -message "Sending VM Poweron for VM $($vm.uuid)"
    
      $loop = 0
      $exit = 0
      do {
        $loop++
        REST-Set-VM-Power-State -datavar $datavar -datagen $datagen -VMuuid "$($vm.uuid)" -state "On"
        sleep 20
        $vm = REST-Get-VM-Detail -datavar $datavar -datagen $datagen -uuid "$($vm.uuid)"
  
        if ($vm.power_state -eq "on"){
  
          write-log -message "VM Poweron Success"
  
          $exit = 1
        } else {
  
          write-log -message "Ah VMware crap..." -sev "WARN"
  
        }
      } until ($loop -ge 3 -or $exit -eq 1)
    
      if ($guestOS -match "win"){
        sleep 119
    
        write-log -message "This takes a little longer on 2016";
         
      }
      
      sleep 60
      
      write-log -message "Checking if i have an IP"
      $subcounter = 0
      if ($guestOS -eq "rhel7_64Guest"){
        $threshold = 10 
        $sleep  = 119
      } else {
        $threshold = 5
        $sleep = 45
      }
      
      do {
        $subcounter++
        sleep $sleep
        write-log -message "Checking if i have an IP $subcounter / $threshold "
        if ($guestOS -eq "rhel7_64Guest" -and $subcounter -eq 5){

          write-log -message "Oracle Hack Restarting VM at no IP."

          CMD-Connect-VMware -datavar $datavar
          get-vm -name $vmname | restart-vm -confirm:0
        }

        $vm = (REST-Get-VMs -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.PEPass -clusername $datavar.peadmin).entities | where {$_.vmName -eq $VMname}
        $IP = $vm.ipAddresses | where {$_ -notmatch ":"}


      } until ($IP -or $subcounter -ge $threshold )
      if (!$DHCP){
        if ($ip -eq $VMIP){
    
          write-log -message "VMware is so boring and bolted on, yes we have an IP now, Customisation based: $IP"

    
        } elseif ($guestOS -eq "rhel7_64Guest") {

          write-log -message "Oracle Hack Setting fixed IP through CLI $IP"

          write-log -message "Creating a DHCP Reservation if all else fails."

          PSR-Add-DHCP-Reservation -datavar $datavar -datagen $datagen -targetIP $VMIP -source $IP -mode "IP"

          CMD-Connect-VMware -datavar $datavar
          get-vm -name $vmname | restart-vm -confirm:0
          sleep 60
          $ip = $VMIP

        } else {

          write-log -message "$IP is not the same as $VMIP, Slow VMWare." -sev "WARN"
          $subcount3 = 0
          do {
            $subcount3 ++
            $vm = (REST-Get-VMs -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.PEPass -clusername $datavar.peadmin).entities | where {$_.vmName -eq $VMname}
            $IP = $vm.ipAddresses | where {$_ -notmatch ":"}

            write-log -message "The IP not as expected, usually a glitch in the Matrix.. Taking a blue pill."
            sleep 10
            if ($ip -eq $VMIP){
    
              write-log -message "VMware is so boring and bolted on, yes we have an IP now, Customisation based: $IP"
              write-log -message "We have returned to Wonderland."
    
            }
          } until ($ip -eq $VMIP)
        }
      } else {
        if ($ip){
    
          write-log -message "BYO IPAM $IP"
    
        } 
      }
    
      write-log -message "Waiting for Vmware to finish OS Cust"; 
      $ipretry = 0
      do{
        write-log -message "Waiting till host is alive"
        write-log -message "IP $ip is not replying yet."
        
        $ipretry ++
        sleep 30
        $oldIPtest = test-connection -computername $ip -ea:0 -count 1
        $code = $oldIPtest.statuscode

        write-log -message "Current return code is $code"
        if ($code -eq 0){
          $seconds = $ipretry * 30
          write-log -message "Exiting here. This took $seconds seconds."
        } else {
          write-log -message "Waiting for ping reply for $seconds seconds."
        }

      } until ($ipretry -ge 20 -or $code -eq 0)
      
      if ($code -eq 0){;

        if ($guestOS -match "Win"){
          try {

            write-log -message "First PSR Session"

            PSR-Set-Time -datagen $datagen -datavar $datavar -ip $VMIP
          } catch {
            sleep 30
            PSR-Set-Time -datagen $datagen -datavar $datavar -ip $VMIP
          }
          $password = $datagen.SysprepPassword | ConvertTo-SecureString -asplaintext -force;
          $credential = New-Object System.Management.Automation.PsCredential("administrator",$password);
          invoke-command -computername $VMIP -credential $credential {;
            write "Firewall Disable"
            netsh advfirewall set allprofiles state off
          }

          invoke-command -computername $VMIP -credential $credential {;
            write "Firewall Disable"
            netsh advfirewall set allprofiles state off
          }
          invoke-command -computername $VMIP -credential $credential {;
            netsh advfirewall set allprofiles state off
            if ($Args[4] -match "2016"){
              $AUSettings = (New-Object -com "Microsoft.Update.AutoUpdate").Settings
              $AUSettings.NotificationLevel = 1
              $AUSettings.Save
              Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name "fDenyTSConnections" -Value 0
              Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -Name "UserAuthentication" -Value 1
              netsh advfirewall set allprofiles state off
              sc.exe config wuauserv start=disabled         
              sc.exe query wuauserv         
              sc.exe stop wuauserv
              sc.exe query wuauserv      
              REG.exe QUERY HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\wuauserv /v Start 
            }
            Rename-Computer -NewName $Args[3] -force; New-NetIPAddress -IPAddress $args[0] -DefaultGateway $args[1] -PrefixLength $args[2] -InterfaceIndex (Get-NetAdapter).InterfaceIndex ; shutdown -r -t 1;

          } -Args $VMip,$VMgw,$subnetprefix,$VMname,$imagename -asjob;
      
          write-log -message "Syncing Local VM time and Timezome to match this service."
          
        }
        $result = "Success"
      } else {
        $result = "Failed"
      }

      write-log -message "Moving VM towards $container"

      CMD-Connect-VMware -datavar $datavar
      $moveit = Get-VM $vmname | Move-VM -datastore (Get-datastore "$($container)") -confirm:0 

    } else {

      if ($guestOS -match "win"){
        #CMD-Connect-VMware -datavar $datavar
        #
        #$randomname = get-random 12312
        #$randomname = "$($randomname)_Spec_10_2016"
        #$oscust = New-OSCustomizationSpec -Name $randomname -type NonPersistent -OSType Windows -FullName $datavar.pocname -OrgName Nutanix_Demo -NamingScheme Fixed -NamingPrefix "temp" -AdminPassword $datagen.SysprepPassword -Workgroup "Temp" -ChangeSid
        #get-vm -Name $VMname | Set-VM -OSCustomizationSpec $oscust -Confirm:0
        #sleep 180
        #Get-VM $vmname | Shutdown-VMGuest -confirm:0
      } else {
        $vm = (REST-Get-VMs -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.PEPass -clusername $datavar.peadmin).entities | where {$_.vmName -eq $VMname}
        $IP = $vm.ipAddresses | where {$_ -notmatch ":"}
        $status = SSH-ResetPass-Px -PxClusterIP $ip -clusername "admin" -clpassword $datavar.PEPass -mode "Centos"
      }

      try {
        CMD-Connect-VMware -datavar $datavar
        Get-VM $vmname | start-VM
        sleep 180
        Get-VM $vmname | Shutdown-VMGuest -confirm:0
        sleep 60
        Get-VM $vmname | Set-VM -ToTemplate -Confirm:0
      } catch {
        CMD-Connect-VMware -datavar $datavar
        Get-VM $vmname | start-VM
        sleep 180
        Get-VM $vmname | Shutdown-VMGuest -confirm:0
        sleep 60
        Get-VM $vmname | Set-VM -ToTemplate -Confirm:0
      }
    }

  }
  $resultobject =@{
    Result = $result
  };
  return $resultobject
} 

