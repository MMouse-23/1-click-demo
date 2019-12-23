

function Wrap-BluePrintBackup-Scheduler {
  param(
    $datavar,
    $datagen,
    $sysprepfile,
    $basedir,
    $ModuleDir

  )
  write-log -message "Starting BluePrint Backup scheduler" -sev "Chapter" -slacklevel 1
  ### This Wrapper should be inline with the main logic. Not spawned.
  ### Chances are the task name will become confusing.

  write-log -message "Checking existing Schedules" -slacklevel 1

  $emailsender = $datavar.SenderEMail 

  write-log -message "Query SQL Backups for $emailsender"

  $SQLbackups = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT datecreated, queueuuid FROM [$($SQLDatabase)].[dbo].$($SQLDataUserTableName) WHERE SenderEmail='$emailsender'" -MaxCharLength 3500000
  [array]$queueuuids = $SQLbackups.queueuuid | sort -unique
    
  write-log -message "We found $($SQLbackups.count) Backups" -slacklevel 1
  write-log -message "From $queueuuids different backup session(s)"

  $Runninguser = 0

  write-log -message "Checking Existing Tasks, this user has $($queueuuids.count) 1CDs in his history"

  $Running = Get-ScheduledTask | where {$_.taskname -match "^Backup" } -ea:0
  if ($running){
    foreach ($task in $Running){
      $ID = $task.taskname.split("-",2)[1]
      if ($ID -in $queueuuids -and $id.length -gt 8){
          
        write-log -message "User has an active Backup task with ID $ID, not starting a new one" -sev "WARN"
        $Runninguser = 1
  
      }
    }
  }
  if ($Runninguser -eq 0){

    write-log -message "Getting BP Baseline"
    sleep 60
    $blueprints = REST-Query-Calm-BluePrints -datavar $datavar -datagen $datagen
  
    write-log -message "We found $($blueprints.entities.count) BluePrints to be ignored." -slacklevel 1
  
    Foreach ($bp in $blueprints.entities){
  
      write-log -message "Adding $($bp.status.name) to the ignore list."
  
      [array]$BlueprintFilters += $bp.status.name
    }

    write-log -message "Spawning Backup Module" -slacklevel 1
  
    $LauchCommand = 'Wrap-BluePrintBackup-Engine -datagen $datagen -datavar $datavar -ServerSysprepfile $ServerSysprepfile -basedir $basedir -BlueprintsPath ' + $BlueprintsPath + ' -blueprintfilters $blueprintfilters'
    Lib-Spawn-Wrapper -Type "Backup" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand -blueprintfilters $blueprintfilters
  }

  write-log -message "Backup Engine Scheduler Finished." -sev "Chapter" -slacklevel 1
}

function Wrap-BluePrintBackup-Restore {
  param(
    $datavar,
    $datagen
  )
  write-log -message "Starting BluePrint Backup restore" -sev "Chapter" -slacklevel 1
  ### This Wrapper should be inline with the main logic. Not spawned.
  ### Chances are the task name will become confusing.

  write-log -message "Checking existing Schedules"

  $emailsender = $datavar.SenderEMail 
  
  write-log -message "Query SQL Backups for $emailsender"

  $SQLbackups = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT datecreated, queueuuid, BackupIndex FROM [$($SQLDatabase)].[dbo].$($SQLDataUserTableName) WHERE SenderEmail='$emailsender'" -MaxCharLength 3500000
    
  write-log -message "We found $($SQLbackups.count) Backups" -slacklevel 1

  write-log -message "Selecting Last Backup"

  $RestorepointTemp = $SQLbackups | sort DateCreated -Descending | select -first 1

  $SQLbackups = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT * FROM [$($SQLDatabase)].[dbo].$($SQLDataUserTableName) WHERE QueueUUID='$($RestorepointTemp.queueuuid)'" -MaxCharLength 3500000

  $Restorepoint = $SQLbackups | sort DateCreated -Descending | select -first 1

  $Restores= $null
  $blueprintsarray = $null
  [array]$looparray = $Restorepoint.PSObject.Properties | Select-Object -Expand Name
  foreach ($item in $looparray){
    if ($item -match "Blueprint.*_name"){
      [array]$blueprintsarray += $item
    }
  }
  $numbers = $null
  Foreach ($item in $blueprintsarray){
    [array]$numbers += [string](($item -split "BluePrint") -split "_")[1]
  }
  foreach ($number in $numbers){
    $blueprintname = ($Restorepoint.PSObject.Properties | where {$_.name -eq "BluePrint$($number)_name"}).value
    $blueprintJson = ($Restorepoint.PSObject.Properties | where {$_.name -eq "BluePrint$($number)_json"}).value

    write-log -message "Getting data for BluePrint$($number)_name"

    if ($blueprintname -ne "NA" -and $blueprintname -notmatch "No backup"){

      write-log -message "Adding $blueprintname to the restore pool"

      $myObject = [PSCustomObject]@{
        Name     = $blueprintname
        JSON     = $blueprintJson
      }
      [array]$Restores += $myObject      
    }
    
  }

  write-log -message "Restoring Backup from $($Restorepoint.DateCreated) , this restorepoint contains $($Restores.count) blueprints" -slacklevel 1

  foreach ($restore in $restores){
    write-host $restore.json
    REST-Restore-BackupBlueprint -datagen $datagen -datavar $datavar -blueprint $restore.json

  }

}

function Wrap-BluePrintBackup-Engine {
  param(
    [object] $datavar,
    [object] $datagen,
    [array]  $blueprintfilters
  )
  $backupstaken = 0
  $maxloops = 11 ## 12 times 5 minutes is 1 hour
  $interval = 270 ## Seconds, counting 40 sec execution time. 
  $failurelimit = $maxloops - 2
  $loopscounter = 0
  $countbackupfailure = 0
  do{
    $loopscounter ++
    foreach ($bpfilter in $blueprintfilters){
  
      write-log -message "Blueprint with name $bpfilter is filtered from Backup"
  
    }
  
    write-log -message "Getting BluePrints to Backup"
  
    try {
      $blueprints = REST-Query-Calm-BluePrints -datavar $datavar -datagen $datagen
  
      write-log -message "We found $($blueprints.entities.count) BluePrints"
      ## We always find blueprints??
      if ($blueprints){
        [decimal]$deleted = ($blueprints.entities | where {$_.status.deleted -eq $true}).count
      }
      $BackupRun = 1
      write-log -message "$deleted are deleted BluePrints"
  
    } catch {
  
      write-log -message "Backup Failure" -sev "WARN"
      
      $BackupRun = 0
      $countBackupFailure++
  
    }
    $blueprintsfiltered = $null
    write-log -message "Current Failure count is $countBackupFailure out of $failurelimit"
    if ($countBackupFailure -lt $failurelimit){
      foreach ($item in $blueprints.entities){
        if ($item.status.name -notin $BlueprintFilters -and $item.status.deleted -eq $false){

          [array]$blueprintsfiltered += $item
          
        }
      }
      $BackupColumnCountint = 0
      $LastSQLbackup = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLDataUserTableName) WHERE SenderEmail='$emailsender' AND QueueUUID ='$($datavar.queueuuid)' ORDER BY 'BackupIndex' DESC" -MaxCharLength 3500000;
      if ($blueprintsfiltered -and $BackupRun -eq 1){
    
        write-log -message "We found $($blueprintsfiltered.count) BluePrints after filtering"
    
        foreach ($bp in $blueprintsfiltered){
          $BackupColumnCountint++
          $BackupColumnCount = '{0:d3}' -f $BackupColumnCountint

          write-log -message "Exporting $($bp.metadata.name) as backup collumn index $BackupColumnCount"

          $Objbackup = REST-Query-DetailBP -datavar $datavar -datagen $datagen -uuid $bp.metadata.uuid
          $Objbackup.psobject.members.remove("Status")
          [string]$jsonbackup = $Objbackup | convertto-json -depth 100
          New-Variable -Name "BPBackup$BackupColumnCount" -Value $Jsonbackup -force
          New-Variable -Name "BPName$BackupColumnCount" -Value $bp.metadata.name -force
    
        }
    
        write-log -message "Storing the remaining backup slots as empty."
    
        do {
          $backupslotsint++
          $backupslots = '{0:d3}' -f $backupslotsint
          $var = Get-Variable "BPName$backupslots" -ea:0
          if (!$var){
    
            write-log -message "BPName$backupslots is empty, storing empty slot."
    
            New-Variable -Name "BPName$backupslots" -Value "NA" -force
            New-Variable -Name "BPBackup$backupslots" -Value "NA" -force
          }
        } until ($backupslotsint -ge 50)
        $emailsender = $datavar.SenderEMail 
        $LastSQLbackup = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLDataUserTableName) WHERE SenderEmail='$emailsender' AND QueueUUID ='$($datavar.queueuuid)' ORDER BY 'BackupIndex' DESC" -MaxCharLength 3500000;
        [decimal]$Lastindex = $LastSQLbackup.BackupIndex
        [decimal]$NewIndex = $Lastindex + 1
        $date = get-date
        Write-log -message "Inserting Backup."
  
        $SQLQuery = "USE `"$SQLDatabase`"
          INSERT INTO dbo.$SQLDataUserTableName (QueueUUID, BackupIndex, SenderEmail, DateCreated, BluePrint001_Name, BluePrint002_Name, BluePrint003_Name, BluePrint004_Name, BluePrint005_Name, BluePrint006_Name, BluePrint007_Name, BluePrint008_Name, BluePrint009_Name, BluePrint010_Name, BluePrint011_Name, BluePrint012_Name, BluePrint013_Name, BluePrint014_Name, BluePrint015_Name, BluePrint016_Name, BluePrint017_Name, BluePrint018_Name, BluePrint019_Name, BluePrint020_Name, BluePrint021_Name, BluePrint022_Name, BluePrint023_Name, BluePrint024_Name, BluePrint025_Name, BluePrint026_Name, BluePrint027_Name, BluePrint028_Name, BluePrint029_Name, BluePrint030_Name, BluePrint031_Name, BluePrint032_Name, BluePrint033_Name, BluePrint034_Name, BluePrint035_Name, BluePrint036_Name, BluePrint037_Name, BluePrint038_Name, BluePrint039_Name, BluePrint040_Name, BluePrint041_Name, BluePrint042_Name, BluePrint043_Name, BluePrint044_Name, BluePrint045_Name, BluePrint046_Name, BluePrint047_Name, BluePrint048_Name, BluePrint049_Name, BluePrint050_Name, BluePrint001_JSON, BluePrint002_JSON, BluePrint003_JSON, BluePrint004_JSON, BluePrint005_JSON, BluePrint006_JSON, BluePrint007_JSON, BluePrint008_JSON, BluePrint009_JSON, BluePrint010_JSON, BluePrint011_JSON, BluePrint012_JSON, BluePrint013_JSON, BluePrint014_JSON, BluePrint015_JSON, BluePrint016_JSON, BluePrint017_JSON, BluePrint018_JSON, BluePrint019_JSON, BluePrint020_JSON, BluePrint021_JSON, BluePrint022_JSON, BluePrint023_JSON, BluePrint024_JSON, BluePrint025_JSON, BluePrint026_JSON, BluePrint027_JSON, BluePrint028_JSON, BluePrint029_JSON, BluePrint030_JSON, BluePrint031_JSON, BluePrint032_JSON, BluePrint033_JSON, BluePrint034_JSON, BluePrint035_JSON, BluePrint036_JSON, BluePrint037_JSON, BluePrint038_JSON, BluePrint039_JSON, BluePrint040_JSON, BluePrint041_JSON, BluePrint042_JSON, BluePrint043_JSON, BluePrint044_JSON, BluePrint045_JSON, BluePrint046_JSON, BluePrint047_JSON, BluePrint048_JSON, BluePrint049_JSON, BluePrint050_JSON)
          VALUES('$($datavar.QueueUUID)','$NewIndex','$($datavar.SenderEmail)','$date','$BPName001','$BPName002','$BPName003','$BPName004','$BPName005','$BPName006','$BPName007','$BPName008','$BPName009','$BPName010','$BPName011','$BPName012','$BPName013','$BPName014','$BPName015','$BPName016','$BPName017','$BPName018','$BPName019','$BPName020','$BPName021','$BPName022','$BPName023','$BPName024','$BPName025','$BPName026','$BPName027','$BPName028','$BPName029','$BPName030','$BPName031','$BPName032','$BPName033','$BPName034','$BPName035','$BPName036','$BPName037','$BPName038','$BPName039','$BPName040','$BPName041','$BPName042','$BPName043','$BPName044','$BPName045','$BPName046','$BPName047','$BPName048','$BPName049','$BPName050','$BPBackup001','$BPBackup002','$BPBackup003','$BPBackup004','$BPBackup005','$BPBackup006','$BPBackup007','$BPBackup008','$BPBackup009','$BPBackup010','$BPBackup011','$BPBackup012','$BPBackup013','$BPBackup014','$BPBackup015','$BPBackup016','$BPBackup017','$BPBackup018','$BPBackup019','$BPBackup020','$BPBackup021','$BPBackup022','$BPBackup023','$BPBackup024','$BPBackup025','$BPBackup026','$BPBackup027','$BPBackup028','$BPBackup029','$BPBackup030','$BPBackup031','$BPBackup032','$BPBackup033','$BPBackup034','$BPBackup035','$BPBackup036','$BPBackup037','$BPBackup038','$BPBackup039','$BPBackup040','$BPBackup041','$BPBackup042','$BPBackup043','$BPBackup044','$BPBackup045','$BPBackup046','$BPBackup047','$BPBackup048','$BPBackup049','$BPBackup050')"
        write-host $SQLQuery
  
        $SQLQueryOutput = Invoke-Sqlcmd -query $SQLQuery -ServerInstance $SQLInstance -DisableVariables
    
      } elseif ($BackupRun -eq 0) {

        write-log -message "Backup Failed, no point in proceeding."

      } else {
    
        write-log -message "There are no blueprints left to backup after filtering."
        write-log -message "Sleeping $interval seconds."
    
      }
    } else {
  
      write-log -message "Self Terminating 3,2,1...."
      ##Send Mail
      $BackupTask = Get-ScheduledTask | where {$_.taskname -match $datavar.QueueUUID -and $_.taskname -match "^Backup"} -ea:0
      
      if ($backuptask){
        #not sure if the IF is needed here :) There can be only one.... As that refers to self.
        LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "BackupEnd" -logfile "$($basedir)\Jobs\Spawns\$($BackupTask.taskname).log"## -stats
        $Backup = Get-ScheduledTask | where {$_.taskname -match $parentuuid -and $_.taskname -match "backup"} -ea:0
        $WatchDog = Get-ScheduledTask | where {$_.taskname -match $parentuuid -and $_.taskname -match "^WatchDog" -and $_.taskname -match "backup"} -ea:0
        remove-item "$($basedir)\Jobs\Spawns\$($backuptask.taskname).log" -ea:0 -force -confirm:0
        remove-item "$($basedir)\Queue\Spawns\$($backuptask.taskname).ps1" -ea:0 -force -confirm:0
        remove-item "$($basedir)\Queue\Spawns\$($backuptask.taskname)-1.queue" -ea:0 -force -confirm:0
        remove-item "$($basedir)\Queue\Spawns\$($backuptask.taskname)-2.queue" -ea:0 -force -confirm:0
        remove-item "$($basedir)\Queue\Spawns\$($backuptask.taskname)-3.queue" -ea:0 -force -confirm:0
        remove-item "$($basedir)\Jobs\Spawns\$($WatchDog.taskname).log" -ea:0 -force -confirm:0
        $WatchDog | stop-scheduledtask -ea:0 
        $WatchDog | unregister-scheduledtask -ea:0 -confirm:0
        $Backup | disable-scheduledtask -ea:0 
        $Backup | unregister-scheduledtask -ea:0 -confirm:0
        write-log -message "I cannot self terminate."
        break
      }
    }
    [decimal]$backupstaken += $blueprintsfiltered.count
    write-log -message "Cycle $loopscounter out of $maxloops done, we had a total of $countbackupfailure failures"
    write-log -message "There were $backupstaken Backups taken, Last index is $($LastSQLbackup.BackupIndex)"
    sleep $interval
  } Until ($loopscounter -ge $maxloops)
}


