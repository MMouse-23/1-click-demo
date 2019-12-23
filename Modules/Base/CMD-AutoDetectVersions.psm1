Function CMD-AutoDetectVersions {
  param (
    [string] $PEClusterIP,
    [string] $peadmin,
    [string] $pepass
  )
  $count1 = 0
  $count2 = 0
  write-log -message "Connecting to PS CMD on Prism Element"

  try {
    $hide = LIB-Connect-PSnutanix -ClusterName $PEClusterIP -NutanixClusterUsername $PEAdmin -NutanixClusterPassword $PEPass

    $count++
    $cluster = Get-NTNXCluster
    if ($cluster){;

      write-log -message "AutoDetecting Versions"

    };
  } catch {

    write-log -message "Not connected." -sev "WARN"

  }
  try {
    $AHVhost = ((Get-NTNXHost)[0])
    $AOSVersion = (Get-NTNXCluster).version
    $SystemModel = $AHVhost.blockmodelname
    $hypervisor = $AHVhost.hypervisorFullName

    write-log -message "AOS detected is $($AOSVersion)."
    write-log -message "System model detected is $($SystemModel)."
    write-log -message "Hypervisor is $($hypervisor)."
    
    $status = "Success"
  } catch {
    $status = "Failed"

    write-log -message "Manual Entry, could not detect block model and AOS."
  }
  $resultobject =@{
    Result = $status
    AOSVersion = $AOSVersion
    SystemModel = $SystemModel
    HyperVisor = $HyperVisor
  };
  return $resultobject
};
Export-ModuleMember *