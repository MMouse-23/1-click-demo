function Wrap-WatchDog {
  param(
    $datavar,
    $datagen,
    $ParentLogfile,
    $basedir,
    $type,
    $ParentPID
  )
  if ($datagen.hostcount -lt 2){

  }
  if ($debug -ge 2 -or $slackbot -ge 2){
    $killcounter = 40
    $killcounterchild = 45
  } else {
    if ($datagen.hostcount -lt 2){
      #single node upgrade termination
      $killcounter = 35
      $killcounterchild = 40    
    }
    $killcounter = 10
    $killcounterchild = 14

  }
  $Maxloops = 2000  
  $currentSQLsize = 0
  $currentsize = 0
  if ($portable -eq 1){
    $slackbot = 0
  } else {
    $slackbot = $datavar.slackbot
    $token = get-content "$($basedir)\SlackToken.txt"
  }
  
  if ($token){  
    
    Write-log -message "Preparing slackbot intel"
    Write-log -message "Getting Slack User Object by email using $($datavar.SenderEmail)"
    
    $User = (Invoke-RestMethod -Uri https://slack.com/api/users.lookupByEmail -Body @{token="$Token"; email="$($datavar.SenderEmail)"}).user
    if (!$user){

      Write-log -message "User not found, disabling slackbot."
      $slackbot = 0
      
    }
  } else {
    $slackbot = 0
  }
  $killme2 = 0
  $mainkill = 0
  do {
    $Parent = get-process -id $ParentPID -ea:0
    $root = get-process -id $datavar.rootPID -ea:0

    Write-log -message "I am the Watchdog for $type"
    Write-log -message "I am the Guardian for ProcessID $ParentPID"
    Write-log -message "I was born out of $($datavar.ROOTPID)"


    $counter++
    $message = $null
    $filestamps = get-item $ParentLogfile
    try {
      [array]$filesize = get-content $ParentLogfile
    } catch {

      $killme2 ++

      Write-log -message "Parent is dead already......"

    }
    if (!$Parent){
      $killme2 ++
      
      Write-log -message "Parent is dead already......" 

    }
    if (!$root){
      $killme2 ++
      
      Write-log -message "Root is dead already......" 

    }
    if ($currentsize -eq 0){
      $file1 = $filesize
    } else {
      $file1 = $filesize | select-object -Skip $currentsize 
    }
    $file2 = $file1 | select -first 150
    if ($debug -ge 2){
      Write-log -message "Current Filesize is $currentsize"
      Write-log -message "New File size will be $($file2.count)"
    }
    #-and $line -notmatch "[!@#$%^;&*()`"{}<>]"
    [int]$currentsize = $currentsize + $file2.count

    if ($type -match "^Base"){

      Write-log -message "Base Thread Watchdog is updating stats"

      $datavar = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLDataVarTableName) WHERE QueueUUID='$QueueUUID';"
      $datagen = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLDataGenTableName) WHERE QueueUUID='$QueueUUID';"
      $basestatus = Lib-Update-Stats -datavar $datavar -datagen $datagen -ParentLogfile $ParentLogfile -basedir $basedir

    }
    if ($basestatus -match "Expired"){
        $mainKill ++
        $killme2 ++
        #At least 20 minutes not to kill the core during upgrades
        if ($mainkill -ge $killcounter -and $type -match "^Base"){

          write-log "Killing Core"
          stop-process -id $datavar.rootPID

        }

    }
    if (($basestatus -ne $null -and $basestatus -notmatch "Running|Pending") -or $killme2 -ge 2 -and $debug -eq 1){

      Write-log -message "Parent is not alive, count $killme2 out of $killcounter before i self terminate."
      Write-log -message "Base status is $basestatus Loop Counter is $counter"
      
      if ($killme2 -ge $killcounterchild){
        $tasks = get-scheduledtask | where {$_.taskname -match $QueueUUID -and $_.taskpath -notmatch "Microsoft|Scripting|Backup"}
        if ($root){
         $tasks =  $null
        }

        foreach ($task in $tasks){
          if ($task.taskname -notmatch "Backup"){
            if ($task.taskname -notmatch "Watchdog-Base"){

              write-log "Stopping task $($task.taskname)"

              $task | unregister-scheduledtask -confirm:0 -ea:0
            }
          }
        }
        $processes = Get-WmiObject Win32_Process |where {$_.commandline -match $QueueUUID}

        write-log "We are terminating $($processes.count) Powershell processes."
        
        if ($root){

          stop-process -id $pid
          
        }
        

        if ($processes){

          write-log "Root is gone and i am still here, cleaning house"

          foreach ($thread in $processes){

            $Threadinfo  = $thread.commandline -split "\\" | select -last 1

            write-log "We are terminating $($threadinfo.split(".")[0])"

            stop-process -id $thread.ProcessId -force -confirm:0 -ea:0

            write-log "Thread with command line $($thread.commandline) terminated."

          }
        }
      }
    }

    Foreach ($line in $file2){

      
      ## Parsing PSErrors into the Database first

      [array]$stream += $line
      if ($line -match "TerminatingError"){

        Write-log -message "Writing PowerShell Errors in the DB"

        $text = (($line -replace '"', '') -replace "'", '') 
        #$timestamp = (($stream | where {$_ -match "\| INFO  \|"} | select -last 1) -split " ")[0]
        if ($debug -ge 2 -or $slackbot -ge 2){
          $date = (get-date).addseconds(-16)
        } else {
          $date = (get-date).addseconds(-61)
        }
        $date = get-date
        $Logging = Invoke-Sqlcmd -ServerInstance $SQLInstLog -Query "SELECT Top 1 * FROM [$($SQLDatabase)].[dbo].$($SQLLoggingTableName) WHERE QueueUUID='$($datavar.QueueUUID)' order by 'EntryIndex' DESC;"
        $EntryIndex = $Logging.EntryIndex + 1
        sleep 2
        $SQLQuery = "USE `"$SQLDatabase`"
          INSERT INTO dbo.$SQLLoggingTableName (QueueUUID, EntryIndex, EntryType, LogType, Debug, Date, Message)
          VALUES('$($datavar.QueueUUID)','$EntryIndex','$Type','PSERR','$debug','$date','$text')"
        $SQLQueryOutput = Invoke-Sqlcmd -query $SQLQuery -ServerInstance $SQLInstance 
      }
    }

    Write-log -message "Getting SQL Log for Slack"
    #
    $Logging = Invoke-Sqlcmd -ServerInstance $SQLInstLog -Query "SELECT * FROM [$($SQLDatabase)].[dbo].$($SQLLoggingTableName) WHERE QueueUUID='$($datavar.QueueUUID)' AND EntryType='$Type' order by 'EntryIndex';"
    $count= 0 
    if ($currentSQLsize -eq 0){
      $Logs = $Logging
    } else {
      $Logs = $Logging | select-object -Skip $currentSQLsize 
    }
    [int]$currentSQLsize = $currentSQLsize + $Logs.count

    Write-log -message "Found $($Logging.count) total rows"
    Write-log -message "Found $($Log.count) new rows"
    write-log -message "Slackbot Level is $($slackbot)"
    $pattern1 = '[\\/]'
    foreach ($logline in $Logs){
      $buildtime = New-TimeSpan -Start $datavar.DateCreated -end $logline.date
      $buildstring = "$("{0:d2}" -f [int]$([math]::Round($buildtime.Hours))):$("{0:d2}" -f [int]$([math]::Round($buildtime.Minutes))):$("{0:d2}" -f [int]$([math]::Round($buildtime.Seconds)))"
      if ($logline.slacklevel -ge 0 -and $type -match "^Base"){
        if ($slackbot -eq 1 -and $logline.slacklevel -ge 1){
          [array]$message +=($buildstring + " | " + $logline.message + "\n") 
        } elseif ($slackbot -ge 2){
          if ($logline.logtype -eq "Chapter"){
            $message += ( '*' + $logline.message + '*' + "\n")    
          } elseif ($logline.logtype -eq "Warn"){
            [array]$message +=($buildstring + " | WARN  | " + $logline.message + "\n")
          } elseif ($logline.logtype -eq "ERROR"){
            [array]$message += ($buildstring + " | ERROR | " + $logline.message + "\n")
          } elseif ($logline.logtype -eq "ERROR"){
            $Text = $logline.message
            $Text = $Text -replace $pattern, '-'
            $text = $text -replace ">", ''
            [array]$message += ($buildstring + " | PSERR | " + $Text + "\n")
          } else {
            [array]$message +=($buildstring + " | INFO  | " + $logline.message + "\n") 
          }
        }
      }
    }

    Write-log -message "Message is $($message.count) Lines"
    Write-log -message "Formatting SlackMessage for $($User.id)"

    if (($message | select -first 1).length -ge 6 -and $message -ne $oldmessage -and $slackbot -ge 1 ){
      $newmessage = $null
      [array]$newmessage += (("\n*Update from: $($datavar.pocname)-$($type): *") + "\n")
      [array]$newmessage += $message
      $countmessage++
      Write-log -message "Sending Slack Message to $($user.id)"
      Write-log -message "Message is $($newmessage.count) lines"
      Write-log -message "A total of $countmessage messages where sent."
      Slack-Send-DirectMessage -message $newmessage -user $user.id -token $token
    } elseif ($slackbot -eq 0 -and $type -match "^Base") {
      
      if ($counter % 16 -eq 0){
        $item = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLDataStatsTableName) WHERE QueueUUID='$($datavar.QueueUUID)';"
        if ($item.status -eq "Running"){
          Write-log -message "Sending Slack Message to $($user.id)"
          $newmessage = $null
          [array]$newmessage += (("$($datavar.pocname) build is at $($item.percentage) % \nChapter: $($item.CurrentChapter)") + "\n")
          Slack-Send-DirectMessage -message $newmessage -user $user.id -token $token
        }
      }
    }
    $oldmessage = $message
    if ($debug -ge 2 -or $slackbot -ge 2){

      sleep 15
    } else {

      sleep 60
    }
     
  } until ($counter -ge $Maxloops)
}