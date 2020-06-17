Function Wrap-Install-Era-MSSQL {
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $basedir,
    $ServerSysprepfile

  )
  $countsrv = 0
  # First loop = Build server
  do{
    $countsrv++
    write-log -message "Building MSSQL Server" -slacklevel 1
    write-log -message "Wait for SQL Server Image"
    
    if ($datavar.Hypervisor -match "ESX") {

      SSH-Wait-ImageUpload -datavar $datavar -datagen $datagen -ISOurlData $ISOurlData1 -image $datagen.ERA_MSSQLImage
      Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -vmname $datagen.ERA_MSSQLName -VMIP $datagen.ERA_MSSQLIP -guestOS "windows9Server64Guest" -NDFSSource $datagen.ERA_MSSQLImage -DHCP $false -container $datagen.EraContainerName -createTemplate $false -cpu 4 -ram 16384

    } else {

      REST-Wait-ImageUpload -imagename $datagen.ERA_MSSQLImage -datavar $datavar -datagen $datagen
      
      write-log -message "Creating ERA MSSQL VM" -slacklevel 1

      $VM1 = CMDPSR-Create-VM -mode "ReserveIP" -datagen $datagen -datavar $datavar -DisksContainerName $datagen.EraContainerName -Subnetmask $datavar.InfraSubnetmask -Sysprepfile $ServerSysprepfile -Networkname $datagen.Nw1Name -VMname $datagen.ERA_MSSQLName -ImageName $datagen.ERA_MSSQLImage -cpu 4 -ram 16384 -VMip $datagen.ERA_MSSQLIP -VMgw $datavar.InfraGateway -DNSServer1 $datagen.DC1IP -DNSServer2 $datagen.DC2IP -SysprepPassword $datagen.SysprepPassword -PEClusterIP $datavar.PEClusterIP -clusername $datagen.buildaccount -clpassword $datavar.PEPass

    } 
    
   
    write-log -message "Wait for Forest Task"
    do {
      $Looper++
      try{
        [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^Forest" }
      } catch {
        try {
          [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^Forest" }
        } catch {}
      }
      write-log -message "We found $($tasks.count) task";

      [array] $allready = $null
      write-log "Cycle $looper out of 200"
      if ($tasks){
        Foreach ($task in $tasks){
          if ($task.state -eq "ready"){
      
            write-log -message "Task $($task.taskname) is ready."
      
            $allReady += 1
      
          } else {
      
            $allReady += 0

            write-log -message "Task $($task.taskname) is $($task.state)."
            sleep 60
          };
        };
        
      } else {
        $allReady = 0 ## Do wait if tere are no jobs, required for portable mode in backup URL WAIT TIME

        Write-log -message "There are no jobs to process."
        sleep 60

      }
    } until ($Looper -ge 200 -or $allReady -notcontains 0)

    write-log -message "Join ERA MSSQL VM" -slacklevel 1

    PSR-Join-Domain -SysprepPassword $datagen.SysprepPassword -ip $datagen.ERA_MSSQLIP -dnsserver $datagen.DC2IP -Domainname $datagen.Domainname

    write-log -message "Finalizing SQL Server VM"

    $status = PSR-ERA-ConfigureMSSQL -datavar $datavar -SysprepPassword $datagen.SysprepPassword -ip $datagen.ERA_MSSQLIP -Domainname $datagen.Domainname -PEClusterIP $datavar.PEClusterIP -clusername $datagen.buildaccount -clpassword $datavar.PEPass -containername $datagen.EraContainerName -sename $datavar.SenderName

  } until ($status.result -eq "Success" -or $countsrv -ge 3)
  # First loop end

  if ($countsrv -ge 3){

    write-log -message "There is no point in proceeding" -sev "ERROR"

  }
  $count2 = 0
  # second loop register in ERA
  do {
    $count2++
    $count = 0
    # subloop get clusters
    do {
      $count ++
      $cluster = REST-ERA-GetClusters -datavar $datavar -datagen $datagen

      if ($cluster.id -match "[0-9]"){

        write-log -message "Using Cluster $($cluster.id)"

      } else {
        sleep 60

        write-log -message "Cluster is not created yet waiting $count out of 40"

      }
    } until ($cluster.id -match "[0-9]" -or $count -ge 40)

    write-log -message "Getting SLAs"
    $count = 0
    # subloop get subnets
    do {
      $count ++
      sleep 10

      $slas = REST-ERA-GetSLAs -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
      $gold = $slas | where {$_.name -eq "DEFAULT_OOB_GOLD_SLA"}
    
      write-log -message "Using GOLD SLA SLAs $($gold.id)"

    } until ($cluster.id -match "[0-9]" -or $count -ge 5)
    write-log -message "Registering Database for MSSQL in ERA" -sev "Chapter"
    # Register server
    try {
      $operation = REST-ERA-RegisterMSSQL-ERA -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin -ERACluster $cluster -MSQLVMIP $datagen.ERA_MSSQLIP -SLA $gold -sysprepPass $datagen.SysprepPassword -dbname "WideWorldImporters"
    } catch {
      try {

        write-log -message "Oeps, weve seen this before, timing issue..., sleeping 3 minutes before i retry entirely"

        sleep 180
        $operation = REST-ERA-RegisterMSSQL-ERA -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin -ERACluster $cluster -MSQLVMIP $datagen.ERA_MSSQLIP -SLA $gold -sysprepPass $datagen.SysprepPassword -dbname "WideWorldImporters"
      } catch {
        write-log -message "Oeps Lets do that again" -sev "WARN"
      }
    } 
  } until ($operation.operationid -match "[0-9]" -or $count2 -ge 3)  
  if ($operation.operationid -match "[0-9]"){
    # if the operation failed to even start we do not continue, frequent issue on 1101, timing related.
    $count = 0
    do {
      $result = REST-ERA-Operations -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
      $count++
      
      sleep 60
      if ($count % 8 -eq 0){
  
        write-log -message "Pending Operation completion cycle $count out of 100"
  
      }
      $real = $result.operations | where {$_.id -eq $operation.operationid}
  
      if ($real.status){
        if ($count % 8 -eq 0){
  
          write-log -message "Database is being registered $($real.percentageComplete) % complete."
  
        }
      }
    } until ($count -ge 100 -or ($real -and $real.status -eq 4) -or $real.percentageComplete -eq 100)
  
    write-log -message "Doing ERA 1.3 magic." -slacklevel 1
  
    $databases = REST-ERA-GetDatabases -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
    $database = $databases | where {$_.name -eq "WideWorldImporters"}
  
    $operation = REST-ERA-MSSQL-SW-ProfileCreate -datagen $datagen -datavar $datavar -database $database
    do {
      $result = REST-ERA-Operations -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
      $count++
      sleep 60
      if ($count % 4 -eq 0){
  
        write-log -message "Pending Operation completion cycle $count"
  
      }
      $real = $result.operations | where {$_.id -eq $operation.operationid}
      if ($real.status){
        if ($count % 4 -eq 0){
  
          write-log -message "Software Profile is $($real.percentageComplete) % complete."
  
        } 
      }
    } until ($count -ge 18 -or ($real -and $real.status -eq 4) -or $real.percentageComplete -eq 100)
    write-log -message "Creating Domain MSSQL Profile"
    
    $domainprofile = REST-ERA-Create-WindowsDomain-Profile -datagen $datagen -datavar $datavar

    write-log -message "Creating Network MSSQL Profile"

    $MSSQLProfile = REST-ERA-MSSQL-NW-ProfileCreate -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin -Networkname $datagen.Nw1name
  
    $count = 0
    
    do {
      $count ++
      sleep 10
  
      write-log -message "$($profiles.count) Profiles found, let me retry."
  
      $profiles = REST-ERA-GetProfiles -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
      $nwprofile = $profiles | where {$_.enginetype -eq "sqlserver_database" -and $_.type -eq "Network"}
    } until ($nwprofile -or $count -ge 10)
    $clonelooper= 0
  
    $databases = REST-ERA-GetDatabases -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
    $database = $databases | where {$_.name -eq "WideWorldImporters"}
    #$operation = REST-ERA-CreateSnapshot -datagen $datagen -datavar $datavar -DBUUID $($database.timeMachineId)
    sleep 360 
    do{
      $clonelooper ++
  
      write-log -message "Creating MSSQL Snapshot for cloning. Attempt $($clonelooper)/5" -slacklevel 1
    
      $snapcounter = 0
      do{
        $snapcounter ++
        try{
    
          write-log -message "Attempt Snapshot $snapcounter / 5"
    
          $operation = REST-ERA-CreateSnapshot -datagen $datagen -datavar $datavar -DBUUID $($database.timeMachineId)
          $success = $true
        } catch {
          sleep 60
        }
      } until ( $success -eq $true -or $snapcounter -eq 5)
      if ($snapcounter -ge 5 ){
    
        write-log -message "Danger Danger Cannot Create Snapshot." -sev = "ERROR"
    
      }
      $count = 0
      do {
        $result = REST-ERA-Operations -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
        $count++
        sleep 60
        if ($count % 4 -eq 0){
  
          write-log -message "Pending Operation completion cycle $count"
  
        }
        $real = $result.operations | where {$_.id -eq $operation.operationid}
        if ($real.status){
          if ($count % 4 -eq 0){
  
            write-log -message "snapshot is $($real.percentageComplete) % complete."
  
          } 
        }
      } until ($count -ge 18 -or ($real -and $real.status -eq 4) -or $real.percentageComplete -eq 100)
    
      sleep 60
      write-log -message "Getting Snapshot UUID"
    
      $snapshots = REST-ERA-GetLast-SnapShot -datagen $datagen -datavar $datavar -database $database
      $snapshot = ($snapshots.capability | where {$_.mode -eq "MANUAL"}).snapshots | select -last 1
    
      write-log -message "Provision MSSQL Clone" -slacklevel 1
    
      $clone = REST-ERA-MSSQL-Clone -datagen $datagen -datavar $datavar -database $database -profiles $profiles -snapshot $snapshot -ERACluster $cluster
      $count = 0
      write-log -message "Waiting for cloning process" -slacklevel 1
      do {
        $result = REST-ERA-Operations -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
        $count++
        sleep 60
        if ($count % 4 -eq 0){
  
          write-log -message "Pending Operation completion cycle $count out of 40"
  
        }
        $real = $result.operations | where {$_.id -eq $clone.operationid}
        if ($real.status){
          if ($count % 4 -eq 0){
  
            write-log -message "Clone is $($real.percentageComplete) % complete."
  
          }
        } ## Beyond 5 % is success, status 4 is bad
      } until ($count -ge 40 -or ($real -and $real.status -eq 4) -or [int]$real.percentageComplete -ge 36)
      sleep 60
      $result = REST-ERA-Operations -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
      $real = $result.operations | where {$_.id -eq $clone.operationid}
      if ($real.status -eq 4 -or $count -ge 40){
  
        write-log -message "Snapshot is bad, deleting VM." -sev "WARN"
        write-log -message "Using $($snapshot.id) as Snapshot Source ID" -sev "WARN"
        write-log -message "ERA is a super product yet still here i am"
  
        $clonecompleted = $false
      
        $hide = LIB-Connect-PSNutanix -ClusterName $datavar.PEClusterIP -NutanixClusterUsername $datagen.buildaccount -NutanixClusterPassword $datavar.PEPass
        $hide = get-ntnxvm | where {$_.vmname -match "^MSSQL2"} | Set-NTNXVMPowerOff -ea:0
        $VM = get-ntnxvm | where {$_.vmname -match "^MSSQL2"}
        $newname = "$($VM.vmname)-$clonelooper"
        $hide = get-ntnxvm | where {$_.vmname -match "^MSSQL2"} | set-NTNXVirtualMachine -name $newname -ea:0
  
        $body = $null
        $body += "ERA IP   = $($datagen.ERA1IP)<br>";
        $body += "ERA Pass = $($datavar.pepass)<br>";
        $body += "Owner of instance $($datavar.senderemail)<br>";
        $body += "If Possible check cause, we cannot guarantee the lenght of this machines availability. Can be hours or days<br>"; 
        $body += "Clone Operation ID is $($clone.operationid)<br>"
        $body +=  $real | convertto-html
        $body +=  "<br>"
        $body += "Snapshot failed at $($real.percentageComplete)<br>"
        $body += "New VM name is $newname<br>"
        $body += "PE IP is $($Datavar.peclusterip)<br>"
        $body += "PE Pass is $($Datavar.pepass)<br>"
  
        Send-MailMessage -BodyAsHtml -body $body -to "Michell.Grauwmans@nutanix.com" -from $datagen.smtpsender -port $datagen.smtpport -smtpserver $datagen.smtpserver -subject "Admin Copy, MSSQL Snapshot Failed."
        #Send-MailMessage -BodyAsHtml -body $body -to "omkarpradeep.salvi@nutanix.com" -from $datagen.smtpsender -port $datagen.smtpport -smtpserver $datagen.smtpserver -subject "1-click-Demo MSSQL Snapshot Failed."
  
      } else {
    
       $clonecompleted = $true
    
      }
    } until ($clonecompleted -eq $true -or $clonelooper -ge 4)

    write-log -message "Registering MSSQL Server with second DB" -slacklevel 1

    $operation = REST-ERA-RegisterMSSQL-ERA -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin -ERACluster $cluster -MSQLVMIP $datagen.ERA_MSSQLIP -SLA $gold -sysprepPass $datagen.SysprepPassword -dbname "WideWorldImportersDW"
  
  } else {

    write-log -message "First Database server failed to register, we cannot proceed" -sev "ERROR"

  }
  write-log -message "ERA MSSQL Installation Finished" -slacklevel 1
}
Export-ModuleMember *


