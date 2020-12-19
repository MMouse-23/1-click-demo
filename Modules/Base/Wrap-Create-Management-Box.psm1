Function Wrap-Create-Management-Box {
  param (
    [object] $datavar,
    [object] $datagen,
    [object] $ISOurlData
  )

  write-log -message "Creating Management VM" -sev "CHAPTER" -slacklevel 1

  if ($datavar.Hypervisor -match "ESX"){

    write-log -message "oh dear, all this bolt on crap VMware...."

    Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -vmname $datagen.Mgmt1_VMname -VMIP $datagen.Mgmt1_VMIP -VMDNS1 $datavar.DNSServer -guestOS "windows9Server64Guest" -NDFSSource $datagen.DC_ImageName -DHCP $false -container $datagen.DisksContainerName -createTemplate $false
  
  } else {
    
    write-log -message "Insanity"
  
  }
  write-log -message "Adding Tools for Management Box" -sev "CHAPTER" -slacklevel 1

  sleep 60

  PSR-Install-Choco -datavar $datavar -datagen $datagen -ip $datagen.Mgmt1_VMIP

  sleep 60

  PSR-Install-PowerCLI -datavar $datavar -datagen $datagen -ip $datagen.Mgmt1_VMIP

  write-log -message "Management Box Finished" -sev "CHAPTER"
}

