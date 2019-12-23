

$loggingdir2 = "$($basedir)\jobs\Spawns"
$queuepath  = "$($basedir)\Queue\Spawns"
$item1 = get-item "$($queuepath)\$($QueueFile1)" -ea:0 | select -first 1
$datavar = import-csv $item1
$item2 = get-item "$($queuepath)\$($QueueFile2)" -ea:0 | select -first 1
$datagen = import-csv $item2
$item3 = get-item "$($queuepath)\$($QueueFile3)" -ea:0 | select -first 1
if ($type -match "^Backup"){

  write-log -message "BluePrint Filters loaded" 

  $BlueprintFilters = get-content "$($queuepath)\$($QueueFile3)"

  write-log -message "We found $($BlueprintFilters.count) Filters" 

}
$logfile    = "$($loggingdir2)\$($Type)-$($datavar.QueueUUID).log"

start-transcript -path $logfile 

write-log -message "Logging Activated for $Type Job Spawner" -sev "CHAPTER"
write-log -message "Getting Queue File $($queuepath)\$($QueueFile)"
write-log -message "Processing queue item ID $($datavar.QueueUUID)";
$datagen.privatekey = get-content "$($basedir)\system\temp\$($datavar.QueueUUID).key"

$global:debug = $datavar.debug
$global:queueuuid = $datavar.queueuuid


If ($datavar.debug -ge 2){

  write-log -message "Working with Dynamic dataset:" -sev "CHAPTER"

  $datavar | fl
  
  write-log -message "Working with Generated dataset:" -sev "CHAPTER"
  
  $datagen | fl

}
## DO not start a watchdog for backups, Watchdog will kill the backup before it can killitself. Root not running etc....

if ($type -notmatch "WatchDog|backup"){

  write-log -message "Launching WatchDog" -sev "CHAPTER" 

  $LauchCommand = 'Wrap-WatchDog -datagen $datagen -datavar $datavar -type ' + $Type + ' -basedir $basedir -ParentLogfile ' + "`"$logfile`"" + ' -ParentPID ' + $pid + " -RootPID "
  Lib-Spawn-Wrapper -Type "WatchDog-$($Type)" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -LauchCommand $LauchCommand
  
 }

$global:ServerSysprepfile = LIB-Server-SysprepXML -Password $datavar.PEPass

### ISO Dirs
$global:ISOurlData1 = LIB-Config-ISOurlData -region $datavar.Location -datavar $datavar

$global:ISOurlData2 = LIB-Config-ISOurlData -region "www" -datavar $datavar



write-log -message "Loading Wrapper Function" -sev "CHAPTER"
