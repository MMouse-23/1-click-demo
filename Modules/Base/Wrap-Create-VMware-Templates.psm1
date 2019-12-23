function Wrap-Create-VMware-Templates{
 param(
    [object] $datagen,
    [object] $datavar

)

    write-log -message "Creating VMware Templates for SSP"
    write-log -message "Separate Wrapper to save time after image upload."

    SSH-Wait-ImageUpload -datavar $datavar -datagen $datagen -ISOurlData $ISOurlData1 -image "CentOS_1CD"
    SSH-Wait-ImageUpload -datavar $datavar -datagen $datagen -ISOurlData $ISOurlData1 -image "Windows 2012"
    SSH-Wait-ImageUpload -datavar $datavar -datagen $datagen -ISOurlData $ISOurlData1 -image $datagen.Frame_WinImage

    Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -createTemplate $true -guestos "windows9Server64Guest" -VMname 'Windows 2016' -container $datagen.DisksContainerName -NDFSSource 'Windows 2016'
    Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -createTemplate $true -guestos "windows8Server64Guest" -VMname 'Windows 2012' -container $datagen.DisksContainerName -NDFSSource 'Windows 2012'
    Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -createTemplate $true -guestos "centos64Guest" -VMname 'CentOS 8' -container $datagen.DisksContainerName -NDFSSource 'CentOS_1CD'
    Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -createTemplate $true -guestos "windows9_64Guest" -VMname 'Windows 10_1CD' -container $datagen.DisksContainerName -NDFSSource 'Windows 10_1CD'

    ## 4th template is created as part of the frame golden image.

}


