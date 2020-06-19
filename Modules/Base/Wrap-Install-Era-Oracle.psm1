Function Wrap-Install-Era-Oracle {
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $basedir,
    $ServerSysprepfile

  )
  $maincounter = 0
  if ($RAMCAP -ge 1){
    $ram = 8192
  } else {
     $ram = 16384
  }
  do {
    $maincounter ++
    do {
      $count++
      sleep 15
  
      write-log -message "Wait for Oracle Server Image(s)" -slacklevel 1

      if ($datavar.Hypervisor -match "ESX") {
  
        [array]$filenames += $datagen.Oracle1_0Image
        [array]$filenames += $datagen.Oracle1_1Image
        [array]$filenames += $datagen.Oracle1_2Image
        [array]$filenames += $datagen.Oracle1_3Image
        [array]$filenames += $datagen.Oracle1_4Image
        [array]$filenames += $datagen.Oracle1_5Image
        [array]$filenames += $datagen.Oracle1_6Image
        [array]$filenames += $datagen.Oracle1_7Image
        [array]$filenames += $datagen.Oracle1_8Image
        [array]$filenames += $datagen.Oracle1_9Image

        foreach ($image in $filenames){

          SSH-Wait-ImageUpload -datavar $datavar -datagen $datagen -ISOurlData $ISOurlData1 -image $image

        }
        
      } else {
  
        REST-Wait-ImageUpload -imagename $datagen.Oracle1_0Image -datavar $datavar -datagen $datagen
        REST-Wait-ImageUpload -imagename $datagen.Oracle1_1Image -datavar $datavar -datagen $datagen
        REST-Wait-ImageUpload -imagename $datagen.Oracle1_2Image -datavar $datavar -datagen $datagen
        REST-Wait-ImageUpload -imagename $datagen.Oracle1_3Image -datavar $datavar -datagen $datagen
        REST-Wait-ImageUpload -imagename $datagen.Oracle1_4Image -datavar $datavar -datagen $datagen
        REST-Wait-ImageUpload -imagename $datagen.Oracle1_5Image -datavar $datavar -datagen $datagen
        REST-Wait-ImageUpload -imagename $datagen.Oracle1_6Image -datavar $datavar -datagen $datagen
    
      } 
        
      write-log -message "Building Oracle VM" -slacklevel 1
      if ($datavar.Hypervisor -match "ESX") {

        Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -vmname $datagen.Oracle_VMName -VMIP $datagen.OracleIP -guestOS "rhel7_64Guest" -NDFSSource $filenames -DHCP $false -container $datagen.EraContainerName -createTemplate $false -cpu 2 -ram $ram -cores 4

      } else {

        [array]$images += $datagen.Oracle1_0Image
        [array]$images += $datagen.Oracle1_1Image
        [array]$images += $datagen.Oracle1_2Image
        [array]$images += $datagen.Oracle1_3Image
        [array]$images += $datagen.Oracle1_4Image
        [array]$images += $datagen.Oracle1_5Image
        [array]$images += $datagen.Oracle1_6Image
        $VM = CMD-Create-VM -DisksContainerName $datagen.EraContainerName -Subnetmask $datavar.InfraSubnetmask -Networkname $datagen.Nw1Name -VMname $datagen.Oracle_VMName -ImageNames $images -cpu 2 -ram $ram -cores 4 -VMip $datagen.OracleIP -VMgw $datavar.InfraGateway -DNSServer1 $datagen.DC1IP -DNSServer2 $datagen.DC2IP -PEClusterIP $datavar.PEClusterIP -clusername $datagen.buildaccount -clpassword $datavar.PEPass

      }
    
      write-log -message "Resetting Oracle SSH Pass 1"
    
      $status = SSH-ResetPass-Px -PxClusterIP $datagen.OracleIP -clusername $datavar.PEadmin -clpassword $datavar.PEPass -mode "Oracle1"
  
      write-log -message "Resetting Oracle SSH Pass 2"
    
      $status = SSH-ResetPass-Px -PxClusterIP $datagen.OracleIP -clusername $datavar.PEadmin -clpassword $datavar.PEPass -mode "Oracle2"
  
      write-log -message "Resetting Oracle SSH Pass 3"
    
      $status = SSH-ResetPass-Px -PxClusterIP $datagen.OracleIP -clusername $datavar.PEadmin -clpassword $datavar.PEPass -mode "Oracle3"
  
      write-log -message "Resetting Oracle SSH Pass 4"
    
      $status = SSH-ResetPass-Px -PxClusterIP $datagen.OracleIP -clusername $datavar.PEadmin -clpassword $datavar.PEPass -mode "Oracle4"
    } until ($status.result -eq "Success" -or $count -ge 3)
  
    write-log -message "Starting Oracle Databases" -slacklevel 1
  
    SSH-Startup-Oracle -OracleIP $datagen.OracleIP -clpassword $datavar.PEPass
      sleep 30
    SSH-Oracle-InsertDemo -OracleIP $datagen.OracleIP -clpassword $datavar.PEPass -filename1 "$basedir\Binaries\OracleDemo\adump.sh" -filename2 "$basedir\Binaries\OracleDemo\ticker.sh" -filename3 "$basedir\Binaries\OracleDemo\swingbench.sh"
  
    $count = 0  
    do {
      $count ++
      $cluster = REST-ERA-GetClusters -datavar $datavar -datagen $datagen
  
      if ($cluster.id -match "[0-9]"){
  
        write-log -message "Using Cluster $($cluster.id)"
  
      } else {
  
        sleep 30
        write-log -message "Cluster is not created yet waiting $count out of 5"
  
      }
    } until ($cluster.id -match "[0-9]" -or $count -ge 5)
  
    write-log -message "Getting SLAs"
  
    $slas = REST-ERA-GetSLAs -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
    $gold = $slas | where {$_.name -eq "DEFAULT_OOB_GOLD_SLA"}
  
    write-log -message "Using GOLD SLA SLAs $($gold.id)"
    sleep 60
    write-log -message "Registering Oracle Server with first DB" -slacklevel 1
    sleep  60
  
    $subcounter = 0
    do {
      $subcounter ++
      try {
        $operation = REST-ERA-RegisterOracle-ERA -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin -ERACluster $cluster -OracleIP $datagen.OracleIP -SLA $gold -dbname "TESTDB"
        sleep 60
      } catch {
        SSH-Startup-Oracle -OracleIP $datagen.OracleIP -clpassword $datavar.PEPass
        sleep 30
        SSH-Oracle-InsertDemo -OracleIP $datagen.OracleIP -clpassword $datavar.PEPass -filename1 "$basedir\Binaries\OracleDemo\adump.sh" -filename2 "$basedir\Binaries\OracleDemo\ticker.sh" -filename3 "$basedir\Binaries\OracleDemo\swingbench.sh"
      }
      $count = 0
      do {
        $result = REST-ERA-Operations -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
        $count++
        
        sleep 60
    
        write-log -message "Pending Operation completion cycle $count"
    
        $real = $result.operations | where {$_.id -eq $operation.operationid}
    
        if ($real.status){
    
          write-log -message "Database is being registered $($real.percentageComplete) % complete."
    
        }
    
      } until ($count -ge 35 -or ($real -and $real.status -eq 4) -or $real.percentageComplete -eq 100)
    } until (($real -and $real.percentageComplete -eq 100) -or $subcounter -ge 2)
  } until (($real -and $real.percentageComplete -eq 100) -or $maincounter -ge 2)    
  write-log -message "Doing ERA Software Profile magic." -slacklevel 1

  $databases = REST-ERA-GetDatabases -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
  $database = $databases | where {$_.name -eq "TESTDB"}

  $operation = REST-ERA-Oracle-SW-ProfileCreate -datagen $datagen -datavar $datavar -database $database

  write-log -message "Creating Network Oracle Profile"

  $OracleProfile = REST-ERA-Oracle-NW-ProfileCreate -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin -Networkname $datagen.Nw1name
  $count = 0
  $count = 0
  do {
    $result = REST-ERA-Operations -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
    $count++
    sleep 20
  
    write-log -message "Pending Operation completion cycle $count"
  
    $real = $result.operations | where {$_.id -eq $OracleProfile.operationid}
    if ($real.status){
  
      write-log -message "Profile Create is $($real.percentageComplete) % complete."
  
    }
  } until ($count -ge 18 -or ($real -and $real.status -eq 4) -or $real.percentageComplete -eq 100)
  sleep 20
  do {
    $count ++
    sleep 10

    write-log -message "$($profiles.count) Profiles found, let me retry."

    $profiles = REST-ERA-GetProfiles -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
    $networkprofile = $profiles | where {$_.type -eq "network" -and $_.enginetype -eq "oracle_database"}
    $parameterPRofile = $profiles | where {$_.type -eq "Database_Parameter" -and $_.enginetype -eq "oracle_database"}
  } until (($networkprofile -and $parameterPRofile) -or $count -ge 10)



  write-log -message "Getting databases"

  $databases = REST-ERA-GetDatabases -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
  $database = $databases | where {$_.name -eq "TESTDB"}  

  write-log -message "Creating Oracle Snapshot"

  $operation = REST-ERA-CreateSnapshot -datagen $datagen -datavar $datavar -DBUUID $($database.timeMachineId)

  $count = 0
  do {
    $result = REST-ERA-Operations -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
    $count++
    sleep 5
    if ($count % 4 -eq 0){
  
      write-log -message "Pending Operation completion cycle $count"
  
    }
    $real = $result.operations | where {$_.id -eq $operation.operationid}
    if ($real.status){
      if ($count % 4 -eq 0){
  
        write-log -message "Snapshot is $($real.percentageComplete) % complete."
  
      } 
    }
  } until ($count -ge 18 -or ($real -and $real.status -eq 4) -or $real.percentageComplete -eq 100)

  write-log -message "Using Database ID $($database.id), Getting Snapshots" 

  write-log -message "Taking a nap for the timemachine to wake up." 

  sleep 110

  $snapshots = REST-ERA-GetLast-SnapShot -datagen $datagen -datavar $datavar -database $database
  $snapshot = ($snapshots.capability | where {$_.mode -eq "MANUAL"}).snapshots | select -last 1

  write-log -message "Using Snapshot ID $($snapshot.id)" 

  write-log -message "Creating Low Oracle DB Profile"
  write-log -message "Calculating Oracle Profile size" 
  
  $computeprofile = $profiles | where {$_.type -eq "compute" -and $_.name -match "LOW"}

  $GBCompute = ($computeprofile.versions[0].properties | where {$_.name -eq "MEMORY_SIZE"}).value

  write-log -message "GB Compute is '$($GBCompute)GB'"

  $MBRAM = [math]::Round(([int]$GBCompute * 1024) * 0.66)

  $DBprofile = REST-ERA-Oracle-DB-Low-ProfileCreate -datagen $datagen -datavar $datavar -mb_ram $MBRAM

  write-log -message "Getting Low Oracle DB Profile" 
  $profiles = REST-ERA-GetProfiles -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
  $DBprofile = $PROFILEs | where {$_.engineType -eq "oracle_database" -and $_.name -eq "LowProfile"}

  write-log -message "Creating Postgres Clone" 

  REST-ERA-Oracle-Clone `
    -datagen $datagen `
    -datavar $datavar `
    -snapshot $snapshot `
    -profiles $profiles `
    -EraCluster $cluster `
    -database $database `
    -DatabaseType "oracle_database" `
    -NewDatabaseName "Oracle_Clone" `
    -dbparamID $DBprofile.id `
    -NewVMName "Oracle2-$($datavar.pocname)" `
    -NewSid "TESTDEV"
  
}
Export-ModuleMember *


