Function Wrap-Install-Era-PostGresHA {
  param (
    [object] $datavar,
    [object] $datagen
  )
  write-log -message "Installing PostGres HA ERA"  -slacklevel 1 

  write-log -message "Get Cluster UUID" 

  $cluster = REST-ERA-GetClusters -datavar $datavar -datagen $datagen

  write-log -message "Getting SLAs"

  $slas = REST-ERA-GetSLAs -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin
  $gold = $slas | where {$_.name -eq "DEFAULT_OOB_GOLD_SLA"}

  write-log -message "Getting  Profiles"
  $profiles = REST-ERA-GetProfiles -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin
  $dbParameterProfileId = ($profiles | where {$_.name -eq "DEFAULT_POSTGRES_PARAMS"}).id
  $computeProfileId = ($profiles | where {$_.name -eq "LOW_OOB_COMPUTE"}).id
  $hosts = REST-Get-PE-Hosts -username "admin" -datavar $datavar
  $min = 3
  if ($hosts.entities.count -ge  $min){
    write-log -message "PostGres HA Magic" 
  
    $postgressnw= $profiles | where { $_.type -eq "Network" -and $_.EngineType -match "PostGres"}
    $Profilecounter = 0
    $SoftwareProfile = ($profiles | where {$_.name -match "POSTGRES_.*_OOB" -and $_.name -match "HA" })

    
    $operation = REST-ERA-Provision-HA-Database -postgresclustername "PostGHACL01" -postgresserverprefix "PostG-$($datavar.pocname)" -Databasename "PostGHADB01" -networkProfileId $postgressnw.id -SoftwareProfile $SoftwareProfile -computeProfileId $computeProfileId -dbParameterProfileId $dbParameterProfileId -type "postgres_database" -port "5432" -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin -ERACluster $cluster -SLA $gold -publicSSHKey $datagen.PublicKey -pocname $datavar.pocname
    sleep 60
    $result = REST-ERA-Operations -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin
    $real = $result.operations | where {$_.systemTriggered -ne $true -and $_.entityName -eq "PostGHADB01"} | select -first 1
    $count = 0
    $retry = 0 
    do {
      if ($real -and $real.status -eq 4 ){
        sleep 5
        $retry++
        
        write-log -message "PostGress HA Failure" -SEV "WARN"
        
        $hide = LIB-Connect-PSNutanix -ClusterName $datavar.PEClusterIP -NutanixClusterUsername $datagen.buildaccount -NutanixClusterPassword $datavar.PEPass
        $hide = get-ntnxvm | where {$_.vmname -match "^PostGresHA"} | Set-NTNXVMPowerOff -ea:0
        if ($debug -ge 3){
          $hide = get-ntnxvm | where {$_.vmname -match "^PostGresHA"} | set-NTNXVirtualMachine -name "DeadPC0$($MasterLoopCounter)"
        } else {
          $hide = get-ntnxvm | where {$_.vmname -match "^PostGresHA"} | Remove-NTNXVirtualMachine -ea:0
        }
        sleep 90
        $operation = REST-ERA-Provision-HA-Database -postgresclustername "PostGHACL01" -postgresserverprefix "PostG-CN-$($datavar.pocname)" -Databasename "PostGHADB01" -networkProfileId $postgressnw.id -SoftwareProfile $SoftwareProfile -computeProfileId $computeProfileId -dbParameterProfileId $dbParameterProfileId -type "postgres_database" -port "5432" -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin -ERACluster $cluster -SLA $gold -publicSSHKey $datagen.PublicKey -pocname $datavar.pocname
      } 
      $result = REST-ERA-Operations -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin
      $count++
      $real = $result.operations | where {$_.systemTriggered -ne $true -and $_.entityName -eq "PostGHADB01"} | select -first 1
      sleep 60
  
      write-log -message "Pending Operation completion cycle $count"
  
      if ($real.status){
  
        write-log -message "Server is being built $($real.percentageComplete) % complete."
  
      }
      if (!$real -and $real.status -ne 1 -and $real.percentageComplete -ne 100 ){
        if ($count % 4 -eq 0){
          $hide = LIB-Connect-PSNutanix -ClusterName $datavar.PEClusterIP -NutanixClusterUsername $datagen.buildaccount -NutanixClusterPassword $datavar.PEPass
          $hide = get-ntnxvm | where {$_.vmname -match "^PostGresHA"} | Set-NTNXVMPowerOff -ea:0
          if ($debug -ge 3){
            $hide = get-ntnxvm | where {$_.vmname -match "^PostGresHA"} | set-NTNXVirtualMachine -name "DeadPC0$($MasterLoopCounter)"
          } else {
            $hide = get-ntnxvm | where {$_.vmname -match "^PostGresHA"} | Remove-NTNXVirtualMachine -ea:0
          }
          $operation = REST-ERA-Provision-HA-Database -postgresclustername "PostGHACL01" -postgresserverprefix "PostG-CN-$($datavar.pocname)" -Databasename "PostGHADB01" -networkProfileId $postgressnw.id -SoftwareProfile $SoftwareProfile -computeProfileId $computeProfileId -dbParameterProfileId $dbParameterProfileId -type "postgres_database" -port "5432" -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin -ERACluster $cluster -SLA $gold -publicSSHKey $datagen.PublicKey -pocname $datavar.pocname
        }
      }
    } until ($count -ge 60 -or $retry -ge 5 -or $real.percentageComplete -eq 100)
  } else {
    write-log -message "PostGres HA Disabled on Single node clusters due to IP shortage." 
  }
  
  write-log -message "PostGres HA ERA Installation Finished"  -slacklevel 1 
}