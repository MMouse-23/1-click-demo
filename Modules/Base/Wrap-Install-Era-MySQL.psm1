Function Wrap-Install-Era-MYSQL {
  param (
    [object] $datavar,
    [object] $datagen
  )
  write-log -message "Installing MySQL ERA"  -slacklevel 1 

  write-log -message "Get Cluster UUID" 

  $cluster = REST-ERA-GetClusters -datavar $datavar -datagen $datagen

  write-log -message "Getting SLAs"

  $slas = REST-ERA-GetSLAs -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin
  $gold = $slas | where {$_.name -eq "DEFAULT_OOB_GOLD_SLA"}

  write-log -message "Getting  Profiles"
  $profiles = REST-ERA-GetProfiles -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin

  $MySQLNW = $profiles | where { $_.type -eq "Network" -and $_.EngineType -match "MySQL"}
  $SoftwareProfileID = ($profiles | where {$_.name -match "MYsql_.*_OOB"} | select -last 1).id

  Write-log -message "Software Profile ID :"
  ($profiles | where {$_.name -match "MYsql.*_OOB"}).id

  $computeProfileId = ($profiles | where {$_.name -eq "LOW_OOB_COMPUTE"}).id
  $dbParameterProfileId = ($profiles | where {$_.name -eq "DEFAULT_MYSQL_PARAMS"}).id

  write-log -message "SoftwareProfile ID is $SoftwareProfileID"

  $Profilecounter = 0
  $SoftwareProfileID = ($profiles | where {$_.name -match "MYsql_.*_OOB"} | select -last 1).id
  if ($SoftwareProfileID -notmatch "[a-z]"){
    do {
      $Profilecounter ++
      $profiles = REST-ERA-GetProfiles -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin 
      $SoftwareProfileID = ($profiles | where {$_.name -match "MYsql_.*_OOB"} | select -last 1).id
      if ($SoftwareProfileID){

        write-log -message "There we are ..... $SoftwareProfileID"

      }  else {

        $profiles | where {$_.name -match "Maria"}
        write-log -message "Playing hide and seek are we"
        
        sleep 119
      }
    } until ($SoftwareProfileID -or $Profilecounter -ge 10)
  }
  $operation = REST-ERA-ProvisionServer -dbservername $datagen.ERA_MySQLName -networkProfileId $MySQLNW.id -SoftwareProfileID $SoftwareProfileID -computeProfileId $computeProfileId -dbParameterProfileId $dbParameterProfileId -type "MySQL_database" -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin -ERACluster $cluster -SLA $gold -publicSSHKey $datagen.PublicKey -pocname $datavar.pocname

  $count = 0
  do {
    $result = REST-ERA-Operations -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin
    $count++
    
    sleep 60

    write-log -message "Pending Operation completion cycle $count"

    $real = $result.operations | where {$_.id -eq $operation.operationid}

    if ($real.status){

      write-log -message "Server is being built $($real.percentageComplete) % complete."

    }
    if ($real.status -eq 9){
     $operation = REST-ERA-ProvisionServer -dbservername $datagen.ERA_MariaName -networkProfileId $marianw.id -SoftwareProfileID $SoftwareProfileID -computeProfileId $computeProfileId -dbParameterProfileId $dbParameterProfileId -type "mariadb_database" -port "3306" -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin -ERACluster $cluster -SLA $gold -publicSSHKey $datagen.PublicKey -pocname $datavar.pocname
    }

  } until ($count -ge 18 -or ($real -and $real.status -eq 4) -or $real.percentageComplete -eq 100)

  $DBServers = REST-ERA-GetDBServers -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin
  $DBServer = $DBservers | where {$_.name -eq $datagen.ERA_MySQLName}

  $operation = REST-ERA-ProvisionDatabase -databasename "MYSQLDB01" -DBServer $DBServer -networkProfileId $MySQLNW.id -SoftwareProfileID $SoftwareProfileID -computeProfileId $computeProfileId -dbParameterProfileId $dbParameterProfileId -type "mysql_database" -port "3306" -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin -ERACluster $cluster -SLA $gold -publicSSHKey $datagen.PublicKey -pocname $datavar.pocname
 
  $count = 0
  do {
    $result = REST-ERA-Operations -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin
    $count++
    
    sleep 60

    write-log -message "Pending Operation completion cycle $count"

    $real = $result.operations | where {$_.id -eq $operation.operationid}

    if ($real.status){

      write-log -message "Server is being built $($real.percentageComplete) % complete."

    }
    if ($real.status -eq 9){
     $operation = REST-ERA-ProvisionServer -dbservername $datagen.ERA_MariaName -networkProfileId $marianw.id -SoftwareProfileID $SoftwareProfileID -computeProfileId $computeProfileId -dbParameterProfileId $dbParameterProfileId -type "mariadb_database" -port "3306" -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin -ERACluster $cluster -SLA $gold -publicSSHKey $datagen.PublicKey -pocname $datavar.pocname
    }

  } until ($count -ge 18 -or ($real -and $real.status -eq 4) -or $real.percentageComplete -eq 100)
  
  write-log -message "MySQL ERA Installation Finished"  -slacklevel 1 
}