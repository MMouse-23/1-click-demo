Function Wrap-Install-XRay {
  param (
    [object] $datavar,
    [object] $datagen

  )
  $counter = 0 

  

  do {
    $counter ++
    try {
      write-log -message "Wait for XRAY Image(s)"  -slacklevel 1

      if ($datavar.Hypervisor -match "ESX") {
        
        write-log -message "Building XRay VM" -slacklevel 1
        #  ON VMware XRAY Waits for ERA. When MySQL starts, ERA is Running.

        if ($datavar.installera -eq 1){
          Wait-MySQL-Task -datavar $datavar
        }
        
        Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -vmname $datagen.XRay_VMName -VMIP $datagen.XRayIP -guestOS "centos64Guest" -NDFSSource $datagen.XRAY_Imagename -DHCP $false -container $datagen.DisksContainerName -createTemplate $false -cpu 2 -ram 4092 -cores 2 -mode "xray"
  
      } else {
  
        REST-Wait-ImageUpload -imagename $datagen.XRAY_Imagename -datavar $datavar -datagen $datagen 
   
        write-log -message "Building XRay VM" -slacklevel 1
   
        $VM = CMD-Create-VM -DisksContainerName $datagen.DisksContainerName -Subnetmask $datavar.InfraSubnetmask -Networkname $datagen.Nw1Name -VMname $datagen.XRay_VMName -ImageNames $datagen.XRAY_Imagename -cpu 2 -ram 4092 -cores 2 -VMip $datagen.XRayIP -VMgw $datavar.InfraGateway -DNSServer1 $datagen.DC1IP -DNSServer2 $datagen.DC2IP -PEClusterIP $datavar.PEClusterIP -clusername $datagen.buildaccount -clpassword $datavar.PEPass
        
      } 
   
      $suc6 = $true
    } catch {
      $suc6 = $false
    }
  } until ($suc6 -eq $true -or $counter -eq 5)

  write-log -message "Resetting XRay SSH Pass" -slacklevel 1
     
  $status = SSH-ResetPass-Px -PxClusterIP $datagen.XRayIP -clusername $datagen.buildaccount -clpassword $datavar.PEPass -mode "xray"
   
  write-log -message "Setting XRay Portal Password" -slacklevel 1    
   
  REST-XRay-Login -datagen $datagen -datavar $datavar
   
  write-log -message "Accepting EULA" -slacklevel 1
   
  REST-XRay-EULA -datagen $datagen -datavar $datavar

}
Export-ModuleMember *


