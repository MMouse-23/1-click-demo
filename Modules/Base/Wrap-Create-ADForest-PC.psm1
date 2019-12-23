Function Wrap-Create-ADForest-PC {
  param (
    [object] $datavar,
    [object] $datagen,
    $ServerSysprepfile,
    $basedir,
    $moduledir
  )     

  write-log -message "Promoting First DC VM" -sev "CHAPTER" -slacklevel 1

  try {
    PSR-Create-Domain -IP $datagen.DC1IP -SysprepPassword $datagen.SysprepPassword -DNSServer $datavar.DNSServer -Domainname $datagen.Domainname

  } catch {

    write-log -message "Re-creating First DC VM" -sev "WARN"
    
    if ($datavar.Hypervisor -match "ESX"){

      write-log -message "oh dear, all this bolt on crap VMware...."

      Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -vmname $datagen.DC1Name -VMIP $datagen.DC1IP -guestOS "windows9Server64Guest" -NDFSSource $datagen.DC_ImageName -DHCP $false -container $datagen.DisksContainerName -createTemplate $false
      sleep 60

    } else {
      
      $ServerSysprepfileDC2 = LIB-IP-Server-SysprepXML -Password $datavar.PEPass -gw $datavar.InfraGateway -ip $datagen.DC2IP -mask $datavar.InfraSubnetmask -ifname "Ethernet0"
      $VM1 = CMDPSR-Create-VM -datagen $datagen -datavar $datavar -mode "Static" -DisksContainerName $datagen.DiskContainerName -Subnetmask $datavar.InfraSubnetmask -Sysprepfile $ServerSysprepfileDC2 -Networkname $datagen.Nw1Name -VMname $datagen.DC1Name -ImageName $datagen.DC_ImageName -cpu 4 -ram 4096 -VMip $datagen.DC1IP -VMgw $datavar.InfraGateway -DNSServer1 $datagen.DC1IP -DNSServer2 $datagen.DC2IP -SysprepPassword $datagen.SysprepPassword -PEClusterIP $datavar.PEClusterIP -clusername $datagen.buildaccount -clpassword $datavar.PEPass
      sleep 60
    }
    try {
      PSR-Create-Domain -IP $datagen.DC1IP -SysprepPassword $datagen.SysprepPassword -DNSServer $datavar.DNSServer -Domainname $datagen.Domainname
    } catch {
      sleep 300
      PSR-Create-Domain -IP $datagen.DC1IP -SysprepPassword $datagen.SysprepPassword -DNSServer $datavar.DNSServer -Domainname $datagen.Domainname
    }
  }

  write-log -message "Setting IPAM DNS"
  
  if ($datavar.hypervisor -match "ahv|nutanix"){
    try {
      $networks = REST-Get-PE-Networks -datavar $datavar -datagen $datagen
      $first = $networks.entities | where {$_.name -eq $datagen.Nw1name}
      $first.ipConfig.dhcpOptions.domainNameServers = "$($DAtagen.DC1IP),$($DAtagen.DC2IP)"
      $first.ip_config.dhcp_options.domain_search = $datagen.Domainname
      REST-Set-PE-Network -network $first -datagen $datagen -datavar $datavar
      
    } catch {
      sleep 500 
      
      write-log -message "IPAM Corner Case" -sev "WARN"
  
      $networks = REST-Get-PE-Networks -datavar $datavar -datagen $datagen
      $first = $networks.entities | where {$_.name -eq $datagen.Nw1name}
      $first.ip_config.dhcp_options.domain_name_servers = "$($DAtagen.DC1IP),$($DAtagen.DC2IP)"
      $first.ip_config.dhcp_options.domain_search = $datagen.Domainname
      REST-Set-PE-Network -network $first -datagen $datagen -datavar $datavar

  
    }
  } else {
    ## Assuming else is VMware or something that does not use AOS / AHV IPAM
    write-log -message "Installing DHCP Server" -sev "CHAPTER"

    PSR-Create-DHCP -datavar $datavar -datagen $datagen

    ##$networkname = $datagen.nw2name
    ##
    ## $subnet = (REST-Get-PE-Networks -datavar $datavar -datagen $datagen).entities | where {$_.name -eq $networkname}
    ## $vm = (REST-Get-VMs -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.PEPass -clusername $datavar.peadmin).entities | where {$_.vmName -eq $datagen.DC1Name}
    ## REST-ADD-Nic-VMware -datavar $datavar -datagen $datagen -networkuuid $subnet.uuid -vmuuid $vm.uuid

  }
  
  write-log -message "Getting HostIPs for the PE stack" -slacklevel 1
 
  $hosts = REST-PE-Get-Hosts -datagen $datagen -datavar $datavar

  write-log -message "Generating Domain Content" -sev "CHAPTER"

  sleep 90
  $count = 0 

  $test = PSR-Generate-DomainContent -datavar $datavar -datagen $datagen -SysprepPassword $datagen.SysprepPassword -IP $datagen.DC1IP -Domainname $datagen.Domainname -sename $datagen.sename -hosts $hosts
  #$test2 = PSR-Generate-DomainContent -datavar $datavar -datagen $datagen -SysprepPassword $datagen.SysprepPassword -IP $datagen.DC2IP -Domainname $datagen.Domainname -sename $datagen.sename -hosts $hosts
  # this is done on the DC 2 wrapper
  write-log -message "Forest Install Finished" -sev "CHAPTER" -slacklevel 1

    #replaceme with REST
}