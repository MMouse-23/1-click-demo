Function Wrap-1CD-VMDK {
  param (
   [object] $datagen,
   [object] $datavar
  ) 
  $count = 0
  do{
    $count ++
    $applications = REST-Query-Calm-Apps -datavar $datavar -datagen $datagen
    $state = ($applications.entities | where {$_.status.name -eq "1CD"}).status.state
    if (!$state){
      write-log -message "1CD App is not present yet..." -SEV "WARN"
      $count + 5
      sleep 119
    } elseif ($state -eq "provisioning") {
      write-log -message "Waiting for 1CD Blueprint currently in state: $state Sleeping 2 minutes for $count out of 75"

      sleep 119
    } elseif ($state -eq "Running"){
      $exit = 1
    } elseif ($state -match "Error"){
      $exit = 1
    } 
  } until ( $exit -eq 1 -or $count -ge 75)
  write-log -message "1CD is in state $state"
  $1CDResult = "1CD App is in state $state"
  if ($state -eq "Running"){

    write-log -message "NDFS Filepath"

    $vms = REST-Get-VMs -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount
    $vm = $vms.entities | where {$_.vmname -eq "1-click-demo"}
    $1cdVM = REST-Get-VM-Detail -datavar $datavar -datagen $datagen -uuid $vm.uuid
    $NDFSFilepath = ($1cdVM.vm_disk_info | where { $_.disk_address.device_bus -eq "scsi"}).disk_address.ndfs_filepath

    write-log -message "Powering off"

    REST-Set-VM-Power-State -datavar $datavar -datagen $datagen -VMuuid $vm.uuid -State "acpi_shutdown"

    write-log -message "Converting Image"

    SSH-1CD-VMDK -datavar $datavar -datagen $datagen -NDFSFilepath $NDFSFilepath

  }

}
Export-ModuleMember *

