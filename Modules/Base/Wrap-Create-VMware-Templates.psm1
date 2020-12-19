function Wrap-Create-VMware-Templates{
 param(
    [object] $datagen,
    [object] $datavar

)

  write-log -message "Creating VMware Templates for SSP"
  write-log -message "Separate Wrapper to save time after image upload."

  Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -createTemplate $true -guestos "windows9Server64Guest" -VMname 'Windows 2016' -container $datagen.DisksContainerName -NDFSSource 'Windows 2016'
  Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -createTemplate $true -guestos "windows8Server64Guest" -VMname 'Windows 2012' -container $datagen.DisksContainerName -NDFSSource 'Windows 2012'
  Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -createTemplate $true -guestos "centos64Guest" -VMname 'CentOS 7' -container $datagen.DisksContainerName -NDFSSource 'CentOS_1CD'
  #Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -createTemplate $true -guestos "windows9_64Guest" -VMname 'Windows 10_1CD' -container $datagen.DisksContainerName -NDFSSource 'Windows 10_1CD'

}


