Function Lib-Spawn-Wrapper {
  param (
    [object]$datavar,
    [object]$datagen,
    [string]$sysprepfile,
    [string]$ModuleDir,
    [string]$Lockdir,
    [string]$parentuuid,
    [string]$basedir,
    [string]$ProdMode,
    [bool]  $interactive,
    [string]$psm1file,
    [string]$LauchCommand,
    [Array] $blueprintfilters,
    [string]$Type
  )
  write-log -message "Debug level is $debug";
  write-log -message "Building Launcher";


  $Basescript = get-content "$($basedir)\Base-Outgoing-Queue-Processor.ps1"

  $loader = $null
  foreach ($line in $basescript){
    [array]$loader += $line
    if ($line -match "#-----End Loader-----"){
      break
    }
  }
  write-log -message "Creating Queue File";

  $newdatavar = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLDataVarTableName) WHERE QueueUUID='$parentuuid';"
  $newdatavar | export-csv "$($basedir)\Queue\Spawns\$($type)-$($parentuuid)-1.queue" -Encoding Unicode

  $newdatagen = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLDataGenTableName) WHERE QueueUUID='$parentuuid';"
  $newdatagen | export-csv "$($basedir)\Queue\Spawns\$($type)-$($parentuuid)-2.queue" -Encoding Unicode
  if ($type -match "^Backup"){
    $blueprintfilters | out-file "$($basedir)\Queue\Spawns\$($type)-$($parentuuid)-3.queue" -Encoding Unicode
  }
  
  write-log -message "Loading template";

  $template = get-content "$($basedir)\Modules\Templates\WrapLauncherV1.psd1"

  write-log -message "Loading Queue File";

  [array]$queuefile1 =  '$QueueFile1 = ' + "`"$($type)-$($parentuuid)-1.queue`"`n"
  [array]$queuefile2 =  '$QueueFile2 = ' + "`"$($type)-$($parentuuid)-2.queue`"`n"
  if ($type -match "^Backup"){
    [array]$queuefile3 =  '$QueueFile3 = ' + "`"$($type)-$($parentuuid)-3.queue`"`n"
  } else {
    $queuefile3 = 'write-log -message "Queuefile 3 does not apply"'
  }

  #write-log -message "Loading the wrapper";

  #$wrapper = get-content $psm1file
  #$wrapper = $wrapper.replace('Export-ModuleMember *', "")

  write-log -message "Compiling Script";

  [array]$script =  $loader
         $script += "###QueueFile"
         $script += $queuefile1
         $script += $queuefile2
         $script += $queuefile3
         $script += "###Type"
         $script += "`$global:type = " + "`"$type`""
         $script += "`$global:email = " + "`"$email`""
         $script += "`$global:Logginglevel = " + "`"$Logginglevel`""
         $script += "###RAMCAP"
         $script += "`$global:RAMCAP = " + "`"$RAMCAP`""
         $script += "###Template"
         $script += $template
         #$script += "###Wrapper"
         #$script += $wrapper
         $script += "###Execute"
         $script += $LauchCommand
         $script += "stop-transcript"

  $script | out-file "$($basedir)\Queue\Spawns\$($type)-$($parentuuid).ps1"
  $jobname = "$($Type)-$($parentuuid)";
  Get-ScheduledTask $jobname -ea:0 | stop-scheduledtask -ea:0
  Get-ScheduledTask $jobname -ea:0 | unregister-scheduledtask -confirm:0 -ea:0
  [string]$script = "$($basedir)\Queue\Spawns\$($type)-$($parentuuid).ps1"
  $action = New-ScheduledTaskAction -Execute "$pshome\powershell.exe" -Argument $script
  if ($type -notmatch "^Backup"){
    $trigger =New-ScheduledTaskTrigger -Once -At (Get-Date).date
  } else {
   $trigger = New-ScheduledTaskTrigger -Daily -At (get-date).addminutes(10)
  }
  

  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd;

  if ($type -match "WatchDog"){
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType "S4U" -RunLevel Highest
    $task = Register-ScheduledTask -TaskName $jobname -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
    sleep 10
    $task | start-scheduledtask
  } elseif ($type -match "^Backup") {
    ## Only run hidden on debug 1
    $queue = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd -MultipleInstances Queue
    if ($debug -le 1){
      $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType "S4U" -RunLevel Highest
      $task = Register-ScheduledTask -TaskName $jobname -Action $action -Trigger $trigger -Principal $principal -Settings $queue -Force
    } else {
      $task = Register-ScheduledTask -TaskName $jobname -Action $action -Trigger $trigger -Settings $queue -Force
    }
    $jobname = "$($Type)-$($parentuuid)";
    $task = Get-ScheduledTask $jobname -ea:0 
    $task.Triggers.Repetition.Duration = "P1D" ##Repeat for a duration of one day
    $task.Triggers.Repetition.Interval = "PT1H" ##Repeat every 30 minutes, use PT1H for every hour
    $task | Set-ScheduledTask
    sleep 10
    $task | start-scheduledtask
  } elseif ($debug -le 1 -and $portable -ne 1) {
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType "S4U" -RunLevel Highest
    $task = Register-ScheduledTask -TaskName $jobname -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
    sleep 10
    $task | start-scheduledtask
  } else {
    $task = Register-ScheduledTask -TaskName $jobname -Action $action -Trigger $trigger -Settings $settings;
    sleep 10
    $task | start-scheduledtask
  } 

};
Export-ModuleMember *
 


Function Lib-Get-Wrapper-Results {
  param (
    [object]$datavar,
    [object]$datagen,
    [string]$ModuleDir,
    [string]$parentuuid,
    [string]$basedir
  )
  write-log -message "Debug level is $debug";
  write-log -message "Getting Scheduled Tasks";

  do {
    $Looper++
    [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $parentuuid -and ($_.taskname -notmatch "^Watchdog" -and $_.taskname -notmatch "^Base" -and $_.taskname -notmatch "^Backup" -and $_.taskname -notmatch "^ERA_MSSQL" -and $_.taskname -notmatch "^Objects" -and $_.taskname -notmatch "Karbon-C")} -ea:0

    write-log -message "We found $($tasks.count) to process";

    [array] $allready = $null
    write-log "Cycle $looper out of 100"
    if ($tasks){
      Foreach ($task in $tasks){
        if ($task.state -eq "ready"){
    
          write-log -message "Task $($task.taskname) is ready."
    
          $allReady += 1
    
        } else {
    
          $allReady += 0

          write-log -message "Task $($task.taskname) is $($task.state)."
    
        };
      };
      sleep 60
    } else {
      $allReady = 1

      Write-log -message "There are no jobs to process."

    }
  } until ($Looper -ge 100 -or $allReady -notcontains 0)

  if ($allReady -eq 1 -and $tasks.count -ge 1){
    
    write-log -message "Grabbing logs for $($tasks.count) Jobs";
    $WatchDog = Get-ScheduledTask | where {$_.taskname -match $parentuuid -and $_.taskname -match "WatchDog" -and $_.taskname -notmatch "backup" } -ea:0
    $WatchDog | stop-scheduledtask -ea:0 
    $WatchDog | unregister-scheduledtask -ea:0 -confirm:0

    $Base = Get-ScheduledTask | where {$_.taskname -match $parentuuid -and $_.taskname -match "^Base"} -ea:0
    $Base | unregister-scheduledtask -ea:0 -confirm:0
    foreach ($Task in $tasks){
      $type = ($($task.taskname) -split "-")[0]
      $log = "$($basedir)\Jobs\Spawns\$($task.taskname).log"

      Write-log -message "Adding Log content for $type." 

      get-content $log

      Write-log -message "Removing task for $type with id $parentuuid" 

      Get-ScheduledTask $task.taskname | unregister-scheduledtask -ea:0 -confirm:0
      if ($debug -lt 3){
        remove-item "$($basedir)\Jobs\Spawns\$($task.taskname).log" -ea:0 -force -confirm:0
        remove-item "$($basedir)\Queue\Spawns\$($task.taskname).ps1" -ea:0 -force -confirm:0
        remove-item "$($basedir)\Queue\Spawns\$($task.taskname)-1.queue" -ea:0 -force -confirm:0
        remove-item "$($basedir)\Queue\Spawns\$($task.taskname)-2.queue" -ea:0 -force -confirm:0
        remove-item "$($basedir)\Queue\Spawns\$($task.taskname)-3.queue" -ea:0 -force -confirm:0
        remove-item "$($basedir)\Jobs\Spawns\$($WatchDog.taskname).log" -ea:0 -force -confirm:0
      } else {
        Write-log -message "Please remove job and queue manually."
      }
    }
  }
};
Export-ModuleMember *