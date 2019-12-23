## These Functions all require PowerCLI to be installed.
## Install-Module -Name VMware.PowerCLI
## The VMware API is poor and impossible to program against or reverse engineer.

Function CMD-Connect-VMware {
  Param (
    [object] $datavar
  )

  try {
    $hide = Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Scope AllUsers -confirm:0
    $hide = Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCeip $false -InvalidCertificateAction Ignore -confirm:0
    $hide = Connect-VIServer $datavar.VCenterIP -username $($datavar.VCenterUser) -password $($datavar.VCenterPass)
  } catch {

    sleep 10

    $hide = Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Scope AllUsers -confirm:0
    $hide = Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCeip $false -InvalidCertificateAction Ignore -confirm:0
    $hide = Connect-VIServer $datavar.VCenterIP -username $($datavar.VCenterUser) -password $($datavar.VCenterPass)
    $FName = Get-FunctionName;

    write-log -message "Error Caught on function $FName" -sev "WARN"

  }
}



Function CMD-Rename-DataCenter {
  Param (
    [object] $datavar,
    [string] $newname
  )

  write-log -message "Debug level is $debug";
  write-log -message "Connecting to VCenter $($datavar.VCenterIP)"

  CMD-Connect-VMware -datavar $datavar

  write-log -message "Rename VCenter Datacenter"
  write-log -message "Assuming only 1 exists :)"

  try { 

    Get-Datacenter | Set-Datacenter -name $newname

  } catch {
    sleep 10

    Get-Datacenter | Set-Datacenter -name $newname

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

  }

  Return $task
}

Function CMD-Create-DatastoreCluster {
  Param (
    [object] $datavar
  )

  write-log -message "Debug level is $debug";
  write-log -message "Connecting to VCenter $($datavar.VCenterIP)"

  CMD-Connect-VMware -datavar $datavar

  write-log -message "Creating VCenter Datastore Cluster"
  write-log -message "Assuming only 1 exists :)"

  try { 

    New-DatastoreCluster -Name "OS" -Location (Get-Datacenter)

    write-log -message "Moving Containers"

    get-datastore | where {$_.name -match "Default" } | Move-Datastore -Confirm:0 -Destination (Get-DatastoreCluster -Name "OS")

    New-DatastoreCluster -Name "ERA" -Location (Get-Datacenter)

    write-log -message "Moving Containers"

    get-datastore | where {$_.name -match "ERA" } | Move-Datastore -Confirm:0 -Destination (Get-DatastoreCluster -Name "ERA")

    write-log -message "Enable SDRS"

    Get-DatastoreCluster | Set-DatastoreCluster -SdrsAutomationLevel "Manual"

  } catch {
    sleep 10

    New-DatastoreCluster -Name $datavar.pocname -Location (Get-Datacenter)

    write-log -message "Moving Containers"

    get-datastore | where {$_.name -notmatch "Nutanix|NTNX|vmContainer" } | Move-Datastore -Confirm:0 -Destination (Get-DatastoreCluster)

    write-log -message "Enable SDRS"

    Get-DatastoreCluster | Set-DatastoreCluster -SdrsAutomationLevel "Manual"

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

  }

  Return $task
}

Function CMD-Rename-Network {
  Param (
    [object] $datavar,
    [object] $datagen
  )

  write-log -message "Debug level is $debug";
  write-log -message "Connecting to VCenter $($datavar.VCenterIP)"

  CMD-Connect-VMware -datavar $datavar

  write-log -message "Renaming VM Network"
  write-log -message "Assuming only 1 exists :)"

  try { 

    Get-VirtualPortGroup | where {$_.name -eq "VM Network"} | Set-VirtualPortGroup -Name $datagen.nw1name -confirm:0

  } catch {
    sleep 10

    Get-VirtualPortGroup | where {$_.name -eq "VM Network"} | Set-VirtualPortGroup -Name $datagen.nw1name -confirm:0

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

  }

  Return $task
}

Function CMD-Add-Network2 {
  Param (
    [object] $datavar,
    [object] $datagen
  )

  write-log -message "Debug level is $debug";
  write-log -message "Connecting to VCenter $($datavar.VCenterIP)"

  CMD-Connect-VMware -datavar $datavar

  write-log -message "Adding Network with the name $($datagen.Nw2name)"

  try { 

    Get-VirtualSwitch | where {$_ -match "0" } | % {$_ | new-virtualportgroup -Name $datagen.Nw2name -VLanId $datavar.Nw2Vlan}

  } catch {
    sleep 10

    Get-VirtualSwitch | where {$_ -match "0" } | % {$_ | new-virtualportgroup -Name $datagen.Nw2name -VLanId $datavar.Nw2Vlan}

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

  }

  Return $task
}


Function CMD-Config-HADRS {
  Param (
    [object] $datavar,
    [bool] $HA = $true,
    [bool] $DRS = $true
  )

  write-log -message "Debug level is $debug";
  write-log -message "Connecting to VCenter $($datavar.VCenterIP)"

  CMD-Connect-VMware -datavar $datavar

  write-log -message "Setting HA and DRS for cluster to $enable and DRS Level to $text"
  write-log -message "Assuming only 1 exists :)"
  if ($enable){
    try { 
  
      $cluster = Get-Cluster
      if ($DRS){
        $cluster | Set-Cluster -DrsEnabled:$DRS -Confirm:$false
      }
      $cluster = Get-Cluster
      if ($hA){
        $cluster | Set-Cluster -HAEnabled:$HA -Confirm:$false -HAAdmissionControlEnabled $true -HAFailoverLevel 1
        $hosts = REST-Get-PE-Hosts -datavar $datavar -username $datagen.BuildAccount
        $devide = $hosts.entities.count + 1
        $percentage = [math]::Round(100 / $devide)
        $spec = New-Object VMware.Vim.ClusterConfigSpec
        $spec.DasConfig = New-Object VMware.Vim.ClusterDasConfigInfo
        $spec.DasConfig.AdmissionControlPolicy = New-Object VMware.Vim.ClusterFailoverResourcesAdmissionControlPolicy
        $spec.DasConfig.AdmissionControlPolicy.AutoComputePercentages = $false
        $spec.DasConfig.AdmissionControlPolicy.CpuFailoverResourcesPercent = $percentage
        $spec.DasConfig.AdmissionControlPolicy.MemoryFailoverResourcesPercent = $percentage
        $cluster.ExtensionData.ReconfigureCluster($spec,$true)
      }
        
    } catch {
      sleep 10
  
  
      $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  
    }

  } else {

    try {
      $cluster = Get-Cluster
      $cluster | Set-Cluster -HAEnabled:$HA -DrsEnabled:$DRS -Confirm:$false

    } catch {
      $cluster = Get-Cluster
      $cluster | Set-Cluster -HAEnabled:$HA -DrsEnabled:$DRS -Confirm:$false
      $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
      
    }

  }

  Return $task
}

Function CMD-Rename-VM {
  Param (
    [object] $datavar,
    [string] $oldname,
    [string] $newname
  )

  write-log -message "Debug level is $debug";
  write-log -message "Connecting to VCenter $($datavar.VCenterIP)"

  CMD-Connect-VMware -datavar $datavar

  write-log -message "Rename VCenter VM $oldname towards $newname "

  if (get-vm -name $newname -ea:0) {

    write-log -message "New name already exists.";

    if (!(get-vm -name $oldname -ea:0)){

      write-log -message "Old VM is already renamed";

    } else {

      write-log -message "Old VM still exists but new is inuse" -sev "WARN";

    }
  } else {
    try { 
  
      $task = Get-VM -name $oldname | Set-VM -name $newname -confirm:0
  
    } catch {
      sleep 10
  
      $task = Get-VM -name $oldname | Set-VM -name $newname -confirm:0
  
      $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  
    }
  }
  Return $task
}

Function CMD-Disable-VM-Memory-Alerts {
  Param (
    [object] $datavar
  )

  write-log -message "Debug level is $debug";
  write-log -message "Connecting to VCenter $($datavar.VCenterIP)"

  CMD-Connect-VMware -datavar $datavar

  write-log -message "Disable and Clear Memory Alerts for VMs"

  try { 
    foreach($daState in $vm.DeclaredAlarmState){
      if($daState.OverallStatus -eq "red"){
        $alarm = Get-View $daState.Alarm
        continue
      }
    }
  
    $spec = [VMware.Vim.AlarmSpec]$alarm.Info
    $alarm.ReconfigureAlarm($spec) 
    $task = Get-AlarmDefinition "Virtual Machine Memory Usage" | Set-AlarmDefinition -Enabled $false
  
  } catch {
    sleep 10
  
    $task = Get-AlarmDefinition "Virtual Machine Memory Usage" | Set-AlarmDefinition -Enabled $false
  
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  
  }
  
  Return $task
}

Function CMD-Test-VCenter {
  Param (
    [object] $datavar
  )

  write-log -message "Debug level is $debug";
  write-log -message "Connecting to VCenter $($datavar.VCenterIP)"

  CMD-Connect-VMware -datavar $datavar

  write-log -message "Testing VCenter"
  try { 

    $cluster = get-cluster

  } catch {
    sleep 10

    $cluster = get-cluster

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

  }
  Return $cluster
}

Function CMD-Rename-Cluster {
  Param (
    [object] $datavar,
    [string] $oldname,
    [string] $newname
  )

  write-log -message "Debug level is $debug";
  write-log -message "Connecting to VCenter $($datavar.VCenterIP)"

  CMD-Connect-VMware -datavar $datavar

  write-log -message "Rename VCenter Cluster $($oldname) towards $($newname) "

  if (get-cluster -name $newname  -ea:0){

    write-log -message "New name already exists.";

    if (!(get-cluster -name $oldname -ea:0) ){

      write-log -message "Old cluster is already renamed";

    } else {

      write-log -message "Old cluster still exists but new is inuse" -sev "WARN";

    }
  } else {
    try { 
  
      $task = Get-Cluster -name $oldname | Set-Cluster -name $newname -confirm:0
  
    } catch {
      sleep 10
  
      $task = Get-Cluster -name $oldname | Set-Cluster -name $newname -confirm:0
  
      $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  
    }    
  }
  Return $task
}

Export-ModuleMember *
