## These Functions all require PowerCLI to be installed.
## Install-Module -Name VMware.PowerCLI
## The VMware API is poor and impossible to program against or reverse engineer.

Function Wrap-ESX-Finalize {
  Param (
    $datavar,
    $datagen
  )

  CMD-Rename-DataCenter -datavar $datavar -newname "Nutanix"

  CMD-Rename-Cluster -datavar $datavar -oldname "Cluster1" -newname "$($datavar.pocname)"

  CMD-Rename-VM -datavar $datavar -oldname "VCSA" -newname "VC1-$($datavar.pocname)"

  CMD-Config-HADRS -datavar $datavar -HA $false

  CMD-Disable-VM-Memory-Alerts -datavar $datavar

  CMD-Create-DatastoreCluster -datavar $datavar
  
}

