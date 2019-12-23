Function Wrap-Install-GoldenFrameImage {
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $basedir,
    $ServerSysprepfile
  )
  $countsrv = 0
  $countsrv++

  write-log -message "Building Frame Golder Image" -slacklevel 1
  write-log -message "Wait for Windows 10 Image"

  if ($datavar.Hypervisor -match "ESX") {
  
    Wait-Templates-Task -datavar $datavar

    write-log -message "Creating Windows 10 VM" -slacklevel 1
    
    Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -vmname $datagen.Frame_GoldenVMName -VMIP $datagen.Frame_GoldenVMIP -VMDNS1 $datavar.DNSServer -guestOS "windows9_64Guest" -NDFSSource $datagen.Frame_WinImage -DHCP $false -container $datagen.DisksContainerName -createTemplate $false 

  } else {
  
    REST-Wait-ImageUpload -imagename $datagen.Frame_WinImage -datavar $datavar -datagen $datagen

    write-log -message "Creating Windows 10 VM" -slacklevel 1

    $VM1 = CMDPSR-Create-VM -mode "ReserveIP" -vmip $datagen.Frame_GoldenVMIP -datagen $datagen -datavar $datavar -DisksContainerName $datagen.DisksContainerName -Subnetmask $datavar.InfraSubnetmask -Sysprepfile $ServerSysprepfile -Networkname $datagen.Nw1Name -VMname $datagen.Frame_GoldenVMName -ImageName $datagen.Frame_WinImage -cpu 4 -ram 16384  -VMgw $datavar.InfraGateway -DNSServer1 $datagen.DC1IP -DNSServer2 $datagen.DC2IP -SysprepPassword $datagen.SysprepPassword -PEClusterIP $datavar.PEClusterIP -clusername $datagen.buildaccount -clpassword $datavar.PEPass -NoNGT $true

   
  } 
  
  write-log -message "Getting VMs"

  $vms = REST-Get-VMs -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.PEPass -clusername $datagen.BuildAccount
  
  write-log -message "Filtering VM for $($datagen.Frame_GoldenVMIP)"
  
  $vm = $VMS.entities | where {$_.IPaddresses -eq $datagen.Frame_GoldenVMIP}
  
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
  
    write-log -message "Unmounting Whatever is in there now"
  
    REST-Unmount-CDRom -datavar $datavar -datagen $datagen -uuid $vm.uuid -cdrom $cdrom
  }

  $images = REST-Get-Image-Sizes -ClusterPC_IP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -silent 1
  $imageobj = $images.entities | where {$_.name -eq $datagen.Frame_AgentISO}

  write-log -message "Mounting Image $($imageobj.vmdiskid)"

  REST-Mount-CDRom-Image -datavar $datavar -datagen $datagen -VMuuid $vm.uuid -cdrom $cdrom -image $imageobj

  write-log -message "Installing Frame Agent"

 # PSR-Install-Frame-Agent -datagen $datagen -datavar $datavar -ip $datagen.Frame_GoldenVMIP
  #sleep 360

  $VMdetail = REST-Get-VM-Detail -datavar $datavar -datagen $datagen -uuid $vm.uuid
  $CDrom = $VMdetail.vm_disk_info | where {$_.is_cdrom -eq $true}
  if ($cdrom.is_empty -eq $false){
  
    write-log -message "Unmounting Frame Agent"
  
    REST-Unmount-CDRom -datavar $datavar -datagen $datagen -uuid $vm.uuid -cdrom $cdrom
  }


  $images = REST-Get-Image-Sizes -ClusterPC_IP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -silent 1
  $imageobj = $images.entities | where {$_.name -match "Office.*iso"}

  write-log -message "Mounting Image $($imageobj.vmdiskid)"

  REST-Mount-CDRom-Image -datavar $datavar -datagen $datagen -VMuuid $vm.uuid -cdrom $cdrom -image $imageobj

  write-log -message "Installing Office And Chrome"

  PSR-Install-Office -datagen $datagen -datavar $datavar -ip $datagen.Frame_GoldenVMIP
  sleep 360

  $VMdetail = REST-Get-VM-Detail -datavar $datavar -datagen $datagen -uuid $vm.uuid
  $CDrom = $VMdetail.vm_disk_info | where {$_.is_cdrom -eq $true}
  if ($cdrom.is_empty -eq $false){
  
    write-log -message "Unmounting Office"
  
    REST-Unmount-CDRom -datavar $datavar -datagen $datagen -uuid $vm.uuid -cdrom $cdrom
  }

  PSR-Install-WindowsUpdates -datagen $datagen -datavar $datavar -ip $datagen.Frame_GoldenVMIP

}
Export-ModuleMember *


