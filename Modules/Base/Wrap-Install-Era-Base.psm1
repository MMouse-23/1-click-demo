Function Wrap-Install-Era-Base {
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $basedir,
    [string] $BlueprintsPath,
    $ServerSysprepfile

  )
  if ($datavar.Hypervisor -match "ESX|VMware"){
    $requiredprofiles = 16
    $networkname = $datagen.nw2name
  } else {
    $requiredprofiles = 16
    $networkname = $datagen.nw1name
  }
  
  if ($datavar.Hypervisor -match "AHV|Nutanix" -and  $datavar.InstallEra -eq 1 ){

    write-log -message "Forking ERA MSSQL" -slacklevel 1

    $LauchCommand = 'Wrap-Install-Era-MSSQL -datagen $datagen -datavar $datavar -ServerSysprepfile $ServerSysprepfile -basedir $basedir'
    Lib-Spawn-Wrapper -Type "ERA_MSSQL" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -psm1file "$($ModuleDir)\Wrap-Install-Era-MSSQL.psm1" -LauchCommand $LauchCommand
    sleep 10
  } else {

    write-log -message "MSSQL will not be supported on ESX" -slacklevel 1

  }
  if ($datavar.hypervisor -match "ESX|VMWare"){  
    write-log -message "Forking ERA ESX Oracle, early" -slacklevel 1
  
    $LauchCommand = 'Wrap-Install-Era-Oracle -datagen $datagen -datavar $datavar -ServerSysprepfile $ServerSysprepfile -basedir $basedir'
    Lib-Spawn-Wrapper -Type "ERA_Oracle" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -psm1file "$($ModuleDir)\Wrap-Install-Era-Oracle.psm1" -LauchCommand $LauchCommand
    sleep 10
  }

  do {
    $basecounter++
    sleep 15
    if ($basecounter -ge 2){

      write-log -message "ERA is a super product yet still here i am." -slacklevel 1

    }

    write-log -message "Building ERA Server" -slacklevel 1
    write-log -message "Wait for ERA Server Image"

    if ($datavar.Hypervisor -match "ESX") {

      #$filename = SSH-Wait-ImageUpload -datavar $datavar -datagen $datagen -ISOurlData $ISOurlData1 -image $datagen.ERA_ImageName
      #why are we waiiting for forrest if we rely on SEcond subnet DHCP
      #Wait-Forest-Task -datavar $datavar

      Wait-Mgt-Task -datavar $datavar
      
      write-log -message "Building ERA VM with $($datagen.ERA_ImageName)" 

      Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -vmname $datagen.ERA1Name -VMIP $datagen.ERA1IP -guestOS "centos64Guest" -NDFSSource $datagen.ERA_ImageName -DHCP $false -container $datagen.EraContainerName -createTemplate $false -ram 16384 -cpu 4 -mode "era"
      SSH-ERA-ESX-StaticIP -datavar $datavar -datagen $datagen
      
    } else {

      REST-Wait-ImageUpload -imagename $datagen.ERA_ImageName -datavar $datavar -datagen $datagen
      
      write-log -message "Building ERA VM" 
  
      $VM = CMD-Create-VM -DisksContainerName $datagen.EraContainerName -Subnetmask $datavar.InfraSubnetmask -Networkname $datagen.Nw1Name -VMname $datagen.ERA1Name -ImageNames $datagen.ERA_ImageName -cpu 4 -ram 16384 -VMip $datagen.ERA1IP -VMgw $datavar.InfraGateway -DNSServer1 $datagen.DC1IP -DNSServer2 $datagen.DC2IP -PEClusterIP $datavar.PEClusterIP -clusername $datavar.peadmin -clpassword $datavar.PEPass

    } 
    

    write-log -message "Resetting ERA SSH Pass" 
  
    $status = SSH-ResetPass-Px -PxClusterIP $datagen.ERA1IP -clusername $datavar.peadmin -clpassword $datavar.PEPass -mode "ERA"

    write-log -message "Resetting ERA Portal Password"
  
    REST-ERA-ResetPass -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin
  
    write-log -message "Accepting ERA EULA"
  
    REST-ERA-AcceptEULA -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin
  
    write-log -message "Register Cluster Stage 1"
  
    $output = REST-ERA-RegisterClusterStage1 -datavar $datavar -datagen $datagen
  
    write-log -message "Get Cluster UUID" 
    sleep 10
    $Clustercounter = 0  
    do {
      $Clustercounter ++
      $cluster = REST-ERA-GetClusters -datavar $datavar -datagen $datagen
  
      if ($cluster.id -match "[0-9]"){
  
        write-log -message "Using Cluster $($cluster.id)"
  
      } else {
  
        sleep 30
        write-log -message "Cluster is not created yet waiting $count out of 5"
  
      }
    } until ($cluster.id -match "[0-9]" -or $Clustercounter -ge 5)

    write-log -message "Register Cluster Stage 2 using cluster $($cluster.id)" -sev "Chapter"
  
    sleep 119
    $maincounter = 0

    try {
      do{
        $maincounter++
        REST-ERA-RegisterClusterStage2 -datavar $datavar -datagen $datagen -ClusterUUID $cluster.id
      
        write-log -message "Register PE Networkname" 

        REST-ERA-AttachPENetwork -datavar $datavar -datagen $datagen -ClusterUUID $cluster.id -Networkname $networkname
  
        write-log -message "Get Cluster UUID" 
    
        $cluster = REST-ERA-GetClusters -datavar $datavar -datagen $datagen
    
        write-log -message "Getting SLAs"
    
        $slas = REST-ERA-GetSLAs -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin
        $gold = $slas | where {$_.name -eq "DEFAULT_OOB_GOLD_SLA"}
    
        write-log -message "Using GOLD SLA SLAs $($gold.id)"
        write-log -message "Creating Network Profiles" -slacklevel 1 
    
        $postgressnw = REST-ERA-PostGresNWProfileCreate -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin -Networkname $networkname
    
        $marianw = REST-ERA-MariaNWProfileCreate -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin -Networkname $networkname

        $mysql = REST-ERA-MySQLNWProfileCreate -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin -Networkname $networkname
      
        if ($ramcap -ge 1){ 

          write-log -message "Creating 8GB Profile" -slacklevel 1

          REST-ERA-Create-UltraLow-ComputeProfile  -datavar $datavar -datagen $datagen

        } else {

          write-log -message "Creating 16GB Profile" -slacklevel 1

          REST-ERA-Create-Low-ComputeProfile -datavar $datavar -datagen $datagen 
        }

        write-log -message "ERA is spinning up its internal logic, please standby" -slacklevel 1 
        write-log -message "ERA is becomming self aware."    
        write-log -message "ERA Cyberdine systems model 110"
  
        $count = 0
        do {
          $result = REST-ERA-Operations -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin
          $count++
          
          sleep 60

          write-log -message "Pending Operation completion cycle $count"

          $real = $result.operations | where {$_.name -eq "Configure OOB software profiles"}

          if ($real.status){

            write-log -message "Profiles are beeing created $($real.percentageComplete) % complete."

          }
    
        } until ($count -ge 40 -or ($real -and $real.status -eq 4) -or $real.percentageComplete -eq 100)

        write-log -message "Getting all Profiles" -slacklevel 1
        $Profilecounter = 0
        do {
          $Profilecounter ++
          sleep 119
  
          write-log -message "$($profiles.count) Profiles found, let me retry."
          #on esx only 16 or more?
          $profiles = REST-ERA-GetProfiles -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin 

        } until ($profiles.count -ge $requiredprofiles -or $Profilecounter -ge 5)

      } until ($profiles.count -ge $requiredprofiles -or $maincounter -ge 5)
      
    } catch {
      $ERABaseRestult = "failed"
    }

    if ( $profiles.count -ge 10 ) {
      $ERABaseRestult = "Success"
    } else {
      $ERABaseRestult = "Failed"
    }

  } until ($ERABaseRestult -eq "Success" -or $basecounter -ge 3)

  write-log -message "We found $($profiles.count) Profiles" 
  write-log -message "Building ERA Server Completed" -slacklevel 1

  if ($datavar.Hypervisor -match "ESX|VMware"){

    write-log -message "ESX Needs to wait for DHCP to take over from HPOC DHCP, this takes a few minutes." 

    #Wait-Forest-Task -datavar $datavar

    write-log -message "DHCP Should be installed now, waiting another 10 Minutes before HPOC DHCP stops working."

    #sleep 600

  } 

  write-log -message "Forking ERA MySQL" -slacklevel 1

  $LauchCommand = 'Wrap-Install-Era-MySQL -datagen $datagen -datavar $datavar -ServerSysprepfile $ServerSysprepfile -basedir $basedir'
  Lib-Spawn-Wrapper -Type "ERA_MySQL" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -psm1file "$($ModuleDir)\Wrap-Install-Era-MySQL.psm1" -LauchCommand $LauchCommand
  sleep 10

  if ($datavar.hypervisor -notmatch "ESX|VMWare" -and $datavar.InstallEra -eq 1){  
    write-log -message "Forking ERA Oracle" -slacklevel 1
  
    $LauchCommand = 'Wrap-Install-Era-Oracle -datagen $datagen -datavar $datavar -ServerSysprepfile $ServerSysprepfile -basedir $basedir'
    Lib-Spawn-Wrapper -Type "ERA_Oracle" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -psm1file "$($ModuleDir)\Wrap-Install-Era-Oracle.psm1" -LauchCommand $LauchCommand
    sleep 10
  }

  write-log -message "Forking ERA Postgres HA" -slacklevel 1
  if ($datavar.InstallEra -eq 1){
    $LauchCommand = 'Wrap-Install-Era-PostGresHA -datagen $datagen -datavar $datavar'
    Lib-Spawn-Wrapper -Type "ERA_PostgresHA" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -psm1file "$($ModuleDir)\Wrap-Install-Era-MySQL.psm1" -LauchCommand $LauchCommand
    sleep 10
  }

  write-log -message "Provsioning Maria and Postgres" -slacklevel 1

  $marianw = $profiles | where { $_.type -eq "Network" -and $_.EngineType -match "Maria"}
  $SoftwareProfileID = ($profiles | where {$_.name -match "MARIADB_.*_OOB"}).id

  Write-log -message "Software Profile ID :"
  ($profiles | where {$_.name -match "MARIADB_.*_OOB"}).id

  $computeProfileId = ($profiles | where {$_.name -eq "LOW_OOB_COMPUTE"}).id
  $dbParameterProfileId = ($profiles | where {$_.name -eq "DEFAULT_MARIADB_PARAMS"}).id

  write-log -message "SoftwareProfile ID is $SoftwareProfileID"

  $Profilecounter = 0
  $SoftwareProfileID = ($profiles | where {$_.name -match "MARIADB_.*_OOB"}).id
  if ($SoftwareProfileID -notmatch "[a-z]"){
    do {
      $Profilecounter ++
      $profiles = REST-ERA-GetProfiles -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin 
      $SoftwareProfileID = ($profiles | where {$_.name -match "MARIADB_.*_OOB"}).id
      if ($SoftwareProfileID){

        write-log -message "There we are ..... $SoftwareProfileID"

      }  else {

        $profiles | where {$_.name -match "Maria"}
        write-log -message "Playing hide and seek are we"
        if ($profilecounter -eq 3 -or $profilecounter -eq 6){

          write-log -message "Lets Help ERA a hand"
          
          REST-ERA-RegisterClusterStage2 -datavar $datavar -datagen $datagen -ClusterUUID $cluster.id
        }
        
        sleep 119
      }
    } until ($SoftwareProfileID -or $Profilecounter -ge 25)
  }

  write-log -message "Creating MariaDB Server"

  if ($SoftwareProfileID){
    try {
      $ServerCreateOperation = REST-ERA-ProvisionServer -dbservername $datagen.ERA_MariaName -networkProfileId $marianw.id -SoftwareProfileID $SoftwareProfileID -computeProfileId $computeProfileId -dbParameterProfileId $dbParameterProfileId -type "mariadb_database" -port "3306" -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin -ERACluster $cluster -SLA $gold -publicSSHKey $datagen.PublicKey -pocname $datavar.pocname
    } catch {
      $retryMaria = 1
    }
  } else {

    write-log -message "Software Profile ID is not created yet, very rarely this takes longer then normal, we will be back later." 

    $retryMaria = 1
  }

  write-log -message "Waiting for Create MariaDB Server"

  $count = 0
  do {
    $result = REST-ERA-Operations -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin
    $count++
    
    sleep 60

    write-log -message "Pending Operation completion cycle $count"

    $real = $result.operations | where {$_.id -eq $ServerCreateOperation.operationid}

    if ($real.status){

      write-log -message "Server is being built $($real.percentageComplete) % complete."

    }
    if ($real.status -eq 9 -or $real.status -eq 4){
     $ServerCreateOperation = REST-ERA-ProvisionServer -dbservername $datagen.ERA_MariaName -networkProfileId $marianw.id -SoftwareProfileID $SoftwareProfileID -computeProfileId $computeProfileId -dbParameterProfileId $dbParameterProfileId -type "mariadb_database" -port "3306" -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin -ERACluster $cluster -SLA $gold -publicSSHKey $datagen.PublicKey -pocname $datavar.pocname
    }

  } until ($count -ge 40 -or ($real -and $real.status -eq 5) -or $real.percentageComplete -eq 100)

  $DBServers = REST-ERA-GetDBServers -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin
  $DBServer = $DBservers | where {$_.name -eq $datagen.ERA_MariaName}

  $operation = REST-ERA-ProvisionDatabase -databasename "MariaDB01" -DBServer $DBServer -networkProfileId $marianw.id -SoftwareProfileID $SoftwareProfileID -computeProfileId $computeProfileId -dbParameterProfileId $dbParameterProfileId -type "mariadb_database" -port "3306" -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin -ERACluster $cluster -SLA $gold -publicSSHKey $datagen.PublicKey -pocname $datavar.pocname

  $count = 0
  do {
    $result = REST-ERA-Operations -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin
    $count++
    
    sleep 60

    write-log -message "Pending Operation completion cycle $count"

    $result.operations | where {$_.systemTriggered -ne $true -and $_.dbserverID -eq $dbserver.id}

    if ($real.status){

      write-log -message "Database is being built $($real.percentageComplete) % complete."

    }
    if ($real.status -eq 9 -or $real.status -eq 4 ){
     $operation = REST-ERA-ProvisionDatabase -databasename "MariaDB01" -DBServer $DBServer -networkProfileId $marianw.id -SoftwareProfileID $SoftwareProfileID -computeProfileId $computeProfileId -dbParameterProfileId $dbParameterProfileId -type "mariadb_database" -port "3306" -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin -ERACluster $cluster -SLA $gold -publicSSHKey $datagen.PublicKey -pocname $datavar.pocname
    }

  } until ($count -ge 40 -or ($real -and $real.status -eq 5) -or $real.percentageComplete -eq 100)



  write-log -message "Provision PostGres" -slacklevel 1

  $postgressnw= $profiles | where { $_.type -eq "Network" -and $_.EngineType -match "PostGres"}
  $Profilecounter = 0
  $SoftwareProfileID = ($profiles | where {$_.name -match "POSTGRES_.*_OOB" -and $_.name -notmatch "HA" }).id
  if ($SoftwareProfileID -notmatch "[a-z]"){
    do {
      $Profilecounter ++
      $profiles = REST-ERA-GetProfiles -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin 
      $SoftwareProfileID = ($profiles | where {$_.name -match "POSTGRES_.*_OOB"}).id
      if ($SoftwareProfileID){

        write-log -message "There we are ..... $SoftwareProfileID"

      }  else {

        $profiles | where {$_.name -match "POST"}
        write-log -message "Playing hide and seek are we"
        
        sleep 119
      }
    } until ($SoftwareProfileID -or $Profilecounter -ge 25)
  }
  $dbParameterProfileId = ($profiles | where {$_.name -eq "DEFAULT_POSTGRES_PARAMS"}).id

  $operation = REST-ERA-ProvisionServer -dbservername $datagen.ERA_PostGName -networkProfileId $postgressnw.id -SoftwareProfileID $SoftwareProfileID -computeProfileId $computeProfileId -dbParameterProfileId $dbParameterProfileId -type "postgres_database" -port "5432" -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin -ERACluster $cluster -SLA $gold -publicSSHKey $datagen.PublicKey -pocname $datavar.pocname

  $count = 0
  do {
    $result = REST-ERA-Operations -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin
    $count++
    
    sleep 30

    write-log -message "Pending Operation completion cycle $count"


    $real = $result.operations | where {$_.id -eq $operation.operationid}

    if ($real.status){

      write-log -message "Server is being built $($real.percentageComplete) % complete."

    }
    if ($real.status -eq 9){
       $operation =REST-ERA-ProvisionServer -dbservername $datagen.ERA_PostGName -networkProfileId $postgressnw.id -SoftwareProfileID $SoftwareProfileID -computeProfileId $computeProfileId -dbParameterProfileId $dbParameterProfileId -type "postgres_database" -port "5432" -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin -ERACluster $cluster -SLA $gold -publicSSHKey $datagen.PublicKey -pocname $datavar.pocname

    }
  } until ($count -ge 35 -or ($real -and $real.status -eq 4) -or $real.percentageComplete -eq 100)
  
  $DBServers = REST-ERA-GetDBServers -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin
  $DBServer = $DBservers | where {$_.name -eq $datagen.ERA_PostGName}
  
  REST-ERA-ProvisionDatabase -databasename "PostGresDB01" -DBServer $DBServer -networkProfileId $postgressnw.id -SoftwareProfileID $SoftwareProfileID -computeProfileId $computeProfileId -dbParameterProfileId $dbParameterProfileId -type "postgres_database" -port "5432" -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin -ERACluster $cluster -SLA $gold -publicSSHKey $datagen.PublicKey -pocname $datavar.pocname
  
  write-log -message "ERA Base Installation Finished" -slacklevel 1
}
Export-ModuleMember *


