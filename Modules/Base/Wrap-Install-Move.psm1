Function Wrap-Install-Move {
  param (
   [object] $datagen,
   [object] $datavar
  ) 
  $Count = 0
  do{
    $count ++
    try{
      write-log -message "Wait for Move Image(s)"  -slacklevel 1

      if ($datavar.Hypervisor -match "ESX") {

        if ($datavar.installXray -eq 1){
          Wait-XRAY-Task -datavar $datavar
        }
        
        write-log -message "Building Move VM" -slacklevel 1
    
        Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -vmname $datagen.Move_VMName -VMIP $datagen.MoveIP -guestOS "centos64Guest" -NDFSSource $datagen.Move_Imagename -DHCP $false -container $($datagen.DisksContainerName) -createTemplate $false -cpu 2 -ram 4092 -cores 2 -mode "move"
        
        sleep 60
      } else {
  
        REST-Wait-ImageUpload -imagename $datagen.Move_Imagename -datavar $datavar -datagen $datagen
   
        write-log -message "Building Move VM" -slacklevel 1

        $VM = CMD-Create-VM -DisksContainerName $datagen.DisksContainerName -Subnetmask $datavar.InfraSubnetmask -Networkname $datagen.Nw1Name -VMname $datagen.Move_VMName -ImageNames $datagen.Move_Imagename -cpu 2 -ram 4092 -cores 2 -VMip $datagen.MoveIP -VMgw $datavar.InfraGateway -DNSServer1 $datagen.DC1IP -DNSServer2 $datagen.DC2IP -PEClusterIP $datavar.PEClusterIP -clusername $datagen.buildaccount -clpassword $datavar.PEPass
      } 
     
      write-log -message "Resetting Move SSH Pass" -slacklevel 1

      $success = $true
    } catch {
      $success = $false
    }
  } until ($success -eq $true -or $count -ge 5) 

  $status = SSH-ResetPass-Px -PxClusterIP $datagen.MoveIP -clusername "admin" -clpassword $datavar.PEPass -mode "Move"
  
  sleep 110
  write-log -message "Getting Access Token" -sev "CHAPTER"
    
  $token = REST-Move-Login -datagen $datagen -datavar $datavar
    
  write-log -message "Registering with token $($token.token)"
    
  $register = REST-Move-EULA -datagen $datagen -datavar $datavar -token $token
    
  write-log -message "Configuring Providers"  -slacklevel 1
  
  REST-Move-SetProvider -datagen $datagen -datavar $datavar -Token $token -mode "Target"

  REST-Move-SetProvider -datagen $datagen -datavar $datavar -Token $token -mode "Source"

  write-log -message "Move Installation and Configuration Finished" -slacklevel 1
}
Export-ModuleMember *

