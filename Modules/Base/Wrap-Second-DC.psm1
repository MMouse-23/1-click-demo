Function Wrap-Second-DC {
  param (
    [object] $datavar,
    [object] $datagen,
    $ServerSysprepfile
  )
  do {
    $counter ++

    if ($counter -ge 2){
      $partial = $datagen.DC2Name -replace "^DC2(.*)", '$1'
      $dcname = "DC$($counter)" + $partial
    } else {
      $dcname = $datagen.DC2Name
    }
    write-log -message "Creating Second DC VM" -sev "CHAPTER" -slacklevel 1

    if ($datavar.Hypervisor -match "ESX"){

      write-log -message "oh dear, all this bolt on crap VMware...."

      Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -vmname $datagen.DC2Name -VMIP $datagen.DC2IP -guestOS "windows9Server64Guest" -NDFSSource $datagen.DC_ImageName -DHCP $false -container $datagen.DisksContainerName -createTemplate $false

    } else {

      $VM2 = CMDPSR-Create-VM -datagen $datagen -datavar $datavar -mode "FixedIP" -DisksContainerName $datagen.DiskContainerName -Subnetmask $datavar.InfraSubnetmask -Sysprepfile $ServerSysprepfile -Networkname $datagen.Nw1Name -VMname  $dcname -ImageName $datagen.DC_ImageName -cpu 4 -ram 4096 -VMip $datagen.DC2IP -VMgw $datavar.InfraGateway -DNSServer1 $datagen.DC1IP -DNSServer2 $datagen.DC2IP -SysprepPassword $datagen.SysprepPassword -PEClusterIP $datavar.PEClusterIP -clusername $datagen.buildaccount -clpassword $datavar.PEPass
    
    }
    write-log -message "Join Second DC" -sev "CHAPTER" -slacklevel 1
    
    $status = PSR-Add-DomainController -IP $datagen.DC2IP -SysprepPassword $datagen.SysprepPassword -DNSServer $datavar.DNSServer -Domainname $datagen.Domainname

    write-log -message "Installing CA" -sev "CHAPTER" -slacklevel 1

    $CA = PSR-Install-CA -IP $datagen.DC1IP -SysprepPassword $datagen.SysprepPassword -Domainname $datagen.Domainname

    write-log -message "Datavar $($datavar.POCName) POCName"
    
    sleep 180

    $test = PSR-Generate-DomainContent -datavar $datavar -datagen $datagen -SysprepPassword $datagen.SysprepPassword -IP $datagen.DC2IP -Domainname $datagen.Domainname -sename $datagen.sename -hosts $hosts
    
  } until ($status.result -eq "Success" -or $counter -ge 5)

  write-log -message "Second DC Finished" -sev "CHAPTER"
}

