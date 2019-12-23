function Wrap-Clean-Start {
  param (
    [object]$datavar,
    [object]$datagen
  )

  write-log -message "Cleaning house first."
  write-log -message "Making sure we have a Clean PE ENV"

  $hide = LIB-Connect-PSnutanix -ClusterName $datavar.PEClusterIP -NutanixClusterUsername $datavar.peadmin -NutanixClusterPassword $datavar.PEPass
  $images = REST-Query-Images -ClusterPC_IP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datavar.peadmin -silent 1
  $BadImages = $null
  [array] $BadImages += "Centos"
  [array] $BadImages += "Hycu"
  [array] $BadImages += "Oracle DB"
  [array] $BadImages += "SQL Server"
  [array] $BadImages += "Splunk"
  [array] $BadImages += "Windows"
  [array] $BadImages += "Windows"
  [array] $BadImages += "Xtract for"
  [array] $BadImages += "X-Ray"
  [array] $BadImages += "AutoDC VM"
  [array] $BadImages += "Move VM"
  [array] $BadImages += "AutoDC2"
  
  Foreach ($imagename in $BadImages){
    $VM = Get-NTNXVM |where {$_.vmname -match $imagename};
    if ($vm ){
      write-log -message "Cleaning VM with ID: $($vm.ipAddresses)"
      $vm.vmid | Set-NTNXVMPowerOff -ea:0
      sleep 5
      $vm.vmid | Remove-NTNXVirtualMachine -ea:0
    }

    foreach ($imageobject in $images.entities){
      if ($imageobject.spec.name -match $imagename){

        write-log -message "Cleaning Image with ID: $($imageobject.metadata.uuid)"
        write-log -message "Cleaning Image with Name: $($imageobject.spec.name)" 

        REST-Delete-Image -datavar $datavar -datagen $datagen -uuid $imageobject.metadata.uuid
      }
    }
  }

  $hide = LIB-Connect-PSnutanix -ClusterName $datavar.PEClusterIP -NutanixClusterUsername $datavar.peadmin -NutanixClusterPassword $datavar.PEPass
  $PCVM = Get-NTNXVM |where {$_.vmname -match "RX.*PC" -or $_.vmname -match "^PC.*$($datavar.pocname)"};
  if ($PCVM){
    $hide = Remove-NTNXClusterFromMulticluster -IpAddresses $PCVM.ipAddresses -username $datavar.peadmin -password $datavar.PEPass
    
     $PCVM.vmid | Remove-NTNXVirtualMachine -ea:0
     write-log -message "We are Cleaning PC..." -sev "WARN"

  } 

}
export-modulemember *