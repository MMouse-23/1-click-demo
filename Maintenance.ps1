#### UserVariables
$global:Debug                      = 2
if ((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain -eq $true){
  $global:portable = 0
} else {
  $global:portable = 1
}

#### Program Variables
$logingdir                  = "C:\1-click-demo\System\Logging"
$JobsLogs                   = "C:\1-click-demo\Jobs\Spawns"
$BaseThreadlogingdir        = "C:\1-click-demo\Jobs\Prod"
$ArchiveThreadlogingdir     = "C:\1-click-demo\Jobs\Archive"
$ModuleDir                  = "C:\1-click-demo\Modules"
$daemons                    = "C:\1-click-demo\Daemons"
$Lockdir                    = "C:\1-click-demo\Lock"
$global:BaseDir             = "C:\1-click-demo\"
$queuepath 			            = "C:\1-click-demo\Queue\spawns"
$incomingqueue              = "Incoming"
$Manualqueue                = "Manual"
$Outgoing                   = "Outgoing"
$ready                      = "Ready"
$AutoQueueTimer             = 15
$datequeue                  = (get-date).adddays(-3)
$datelogs                   = (get-date).adddays(-30)
$dateBackups                = (get-date).adddays(-15)
$datetasks                  = (get-date).adddays(-3) ## Dont go lower then 2 or risk deleting running tasks over midnight.
$SingleModelck              = "$($Lockdir)\Single.lck"
if ($env:computername -match "dev"){
  $global:SQLInstance           = "1-click-dev\SQLEXPRESS"
  $global:SQLInstLog            = "1-click-dev\SQLEXPRESS"
} else {
  $global:SQLInstance           = "1-click-demo\SQLEXPRESS"
  $global:SQLInstLog            = "1-click-demo\SQLEXPRESS" 
}
$global:SQLDatabase           = "1ClickDemo"
$global:SQLQueueTableName     = "Queue"
$global:SQLDataVarTableName   = "DataVar"
$global:SQLDataGenTableName   = "DataGen"
$global:SQLLoggingTableName   = "Logging"
$global:SQLDataStatsTableName = "DataStats"
$global:SQLDataUserTableName  = "DataUser"
$global:SQLDataValidationTableName  = "DataValidation"

#### Loading
Import-Module "$($ModuleDir)\Queue\Get-IncommingQueueItem.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Queue\Validate-QueueItem.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Queue\Lib-Spawn-Base.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Queue\Lib-PortableMode.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Base\Lib-Send-Confirmation.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Base\LIB-Config-DetailedDataSet.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Base\LIB-Write-Log.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Backend\Lib-REST-Portal.psm1" -DisableNameChecking;
$global:type = "Backend"
$Guid = [guid]::newguid()
$logfile  = "$($logingdir)\Maintenance-$($Guid.guid).log"

add-type @"
  using System.Net;
  using System.Security.Cryptography.X509Certificates;
  public class TrustAllCertsPolicy : ICertificatePolicy {
      public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate,
                                        WebRequest request, int certificateProblem) {
          return true;
      }
   }
"@

[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3, [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12

start-transcript -path $logfile

# Program log cleanup

write-log -message "Starting Log Cleanup"

$oldFiles = get-item "$($logingdir)\Mantenance-*.log" | where {$_.lastwritetime -le ((get-date).adddays(-5))}
if ($oldfiles){

  write-log -message "Removing $($oldfiles.count) logfiles"

  remove-item $oldFiles -force -ea:0
}

$date = get-date

#### If portable check if images exist locally
if ((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain -eq $true){
  $global:portable = 0
} else {
  $global:portable = 1
}

# Program is on a one minute loop

write-log -message "Backend Process active"

write-log -message "Doing SQL Maintenance."
write-log -message "Purging Queue with date older $datequeue"
write-log -message "Purging Logs with date older $datelogs"
write-log -message "Purging Backups with date older $dateBackups"
write-log -message "Purging Queue History first"

$objects = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT * FROM [$($SQLDatabase)].[dbo].$($SQLQueueTableName)" 
$objects = $objects | where {[datetime]$_.datecreated -lt [datetime]$datequeue}

write-log -message "We found $($objects.count) records to delete."

$reccount = 0
Foreach ($record in $objects){
  $reccount++
  if ($reccount % 4 -eq 0){

    write-log -message "Object count $reccount; object date is $($record.datecreated)"

  }
  Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "DELETE FROM [$($SQLDatabase)].[dbo].$($SQLQueueTableName) WHERE QueueUUID='$($record.queueuuid)'"
  
}
write-log -message "Purging Log History second"

$objects = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT * FROM [$($SQLDatabase)].[dbo].$($SQLLoggingTableName)" 
$objects = $objects | where {[datetime]$_.date -lt [datetime]$datelogs}

write-log -message "We found $($objects.count) records to delete."

$reccount = 0
Foreach ($record in $objects){
  $reccount++
  if ($reccount % 4 -eq 0){

    write-log -message "Object count $reccount; object date is $($record.date)"

  }
  Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "DELETE FROM [$($SQLDatabase)].[dbo].$($SQLLoggingTableName) WHERE QueueUUID='$($record.queueuuid)'"
}

write-log -message "Purging User Backups Last"

$objects = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT datecreated, queueuuid FROM [$($SQLDatabase)].[dbo].$($SQLDataUserTableName)" 
$objects = $objects | where {[datetime]$_.datecreated -lt [datetime]$dateBackups}

write-log -message "We found $($objects.count) records to delete."

$reccount = 0
Foreach ($record in $objects){
  $reccount++
  if ($reccount % 4 -eq 0){

    write-log -message "Object count $reccount; object date is $($record.datecreated)"
    
  }
  Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "DELETE FROM [$($SQLDatabase)].[dbo].$($SQLDataUserTableName) WHERE QueueUUID='$($record.queueuuid)' AND BackupIndex='$($record.BackupIndex)'"
}

write-log -message "Cleaning Tasks"

$tasks = get-scheduledtask | where {$_.taskpath -notmatch "Microsoft|Scripting|Backup"}

write-log -message "We found $($tasks.count) Total tasks"
$killme = $null

foreach ($task in $tasks){
  [string]$stringtime = $task.Triggers.startboundary
  if ([datetime]$stringtime -lt $datetasks){
    [array]$killme += $task
  }
}

write-log -message "We found $($tasks.count) old tasks"

foreach ($task in $killme){
  sleep 30
  
  write-log -message "Checking task state after 30 seconds $($task.name)"

  $task = $task | get-scheduledtask 
  if ($task.state -ne "Running"){
    $task | Unregister-ScheduledTask -confirm:0 -ea:0
  } 

  write-log -message "$($task.Triggers.startboundary)"
}
## Purging DataStats
[array]$Statobjects = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT * FROM [$($SQLDatabase)].[dbo].$($SQLDataStatsTableName) WHERE Status='Running' OR Status='Pending'"

$date = get-date

foreach ($stat in $Statobjects){
  $Logging = Invoke-Sqlcmd -ServerInstance $SQLInstLog -Query "SELECT * FROM [$($SQLDatabase)].[dbo].$($SQLLoggingTableName) WHERE QueueUUID='$($stat.queueuuid)'"
  if ($Logging){
    write-log -message "Logging Found on $($stat.queueuuid)"
    $log = $logging | sort date | select -last 1
    $task = get-scheduledtask | where {$_.taskname -match "$($stat.queueuuid)"} -ea:0

    sleep 2

    if ($log.date -lt (get-date).addminutes(-800) -or !$log){
      write-log -message "Stat $($stat.QueueUUID) is marked as running, created on $($stat.DateCreated) but its master log has not been touched in the last 800 minutes."
      if ($log){
        write-log -message "Last Log was $($log.date)"
      } else {
        write-log -message "Stat is so old logs have been cleaned already"
      }
      write-log -message "Marking stat as cleaned."
      $query ="UPDATE [$($SQLDatabase)].[dbo].[$($SQLDataStatsTableName)] 
        SET Status = 'Cleaned', 
        DateStopped = '$date'
        WHERE QueueUUID='$($stat.QueueUUID)';" 
      write-host $query
      $Update = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query $query 
      $task | stop-ScheduledTask -ea:0
      $task | Unregister-ScheduledTask -ea:0 -confirm:0
    } else {
      write-log -message "Stat $($stat.QueueUUID) is actually running, cant touch this...."
    }
  }
}     

write-log -message "Cleaning Logs"
$systemlogfiles = get-childitem $logingdir
$deletelogfiles = $systemlogfiles | where { (get-date).addhours(-172) -ge $_.lastwritetime}
if ($deletelogfiles){
  write-log -message "We found $($deletelogfiles.count) to clean out of $($systemlogfiles.count) Logfiles."
  foreach ($item in $deletelogfiles){
    remove-item $item.fullname -force -ea:0
  }
}

write-log -message "Cleaning Spawn Logs"
$spawnlogfiles = get-childitem $JobsLogs
$deletelogfiles = $spawnlogfiles | where { (get-date).addhours(-172) -ge $_.lastwritetime}
if ($deletelogfiles){
  write-log -message "We found $($deletelogfiles.count) to clean out of $($spawnlogfiles.count) spawn Logfiles."
  foreach ($item in $deletelogfiles){
    remove-item $item.fullname -force -ea:0
  }
}

write-log -message "Cleaning Queue Files"
$systemQueuefiles = get-childitem "$($queuepath)"
$deleteQueuefiles = $systemQueuefiles | where { (get-date).addhours(-172) -ge $_.lastwritetime}
if ($deleteQueuefiles){
  write-log -message "We found $($deleteQueuefiles.count) to clean out of $($systemQueuefiles.count) Queuefiles."
  foreach ($item in $deleteQueuefiles){
    remove-item $item.fullname -force -ea:0
  }
}

write-log -message "Cleaning Outlook Temp Logging Files"
$systemtempfiles = get-childitem "C:\Windows\Temp\Outlook Logging\*.etl"
$deletetempfiles = $systemtempfiles | where { (get-date).addhours(-12) -ge $_.lastwritetime}
if ($deletetempfiles){
  write-log -message "We found $($deletetempfiles.count) to clean out of $($systemtempfiles.count) Temp files."
  foreach ($item in $deletetempfiles){
    remove-item $item.fullname -force -ea:0
  }
}


write-log -message "Checking Uptime"
$uptime = (gcim Win32_OperatingSystem).LastBootUpTime
if ((get-date).adddays(-5) -ge $uptime ){
  write-log -message "We require a reboot, last reboot $uptime"
  $time = (get-date).addhours(-24)
  $Statobjects      = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT * FROM [$($SQLDatabase)].[dbo].$($SQLDataStatsTableName) WHERE DateCreated >= '$time' order by DateCreated";
  [array]$active           = $Statobjects | where {$_.STatus -eq "Running"}
  if ($active.count -ge 1){
    write-log -message "We cannot reboot on running threads."
  } else {
    write-log -message "Lets go down! there are $($active.count) active tasks"
    get-scheduledtask "BackEndProcessor" | Stop-ScheduledTask
    get-scheduledtask "BackEndProcessor" | Disable-ScheduledTask
    write-log -message "Email Doors Closed now, lets see"
    sleep 120
    $time = (get-date).addhours(-24)
    $Statobjects      = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT * FROM [$($SQLDatabase)].[dbo].$($SQLDataStatsTableName) WHERE DateCreated >= '$time' order by DateCreated";
    [array]$active           = $Statobjects | where {$_.STatus -eq "Running"}
    if ($active.count -ge 1){
      write-log -message "Shit, someone slipped through."
    } else {
      write-log -message "All Clear Lets reboot."
      shutdown -r -t 5
    }
  }
} else {
  write-log -message "No reboot required, making sure we are running, last reboot $uptime"

  get-scheduledtask "BackEndProcessor" | Enable-ScheduledTask
  get-scheduledtask "BackEndProcessor" | Start-ScheduledTask
}


### Admin monitoring

$total4time = 0
$validatedCounter = 0
$startingCounter = 10
$threshold = $startingCounter - 3

[array]$Stats = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT * FROM [$($SQLDatabase)].[dbo].$($SQLDataStatsTableName) WHERE Status='Completed'"
$last10 = $Stats | sort DateCreated | where {$_.AHVVersion -match "Nutanix|AHV" }| select -last 10
foreach ($stat in $last10){
  $Validation = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLDataValidationTableName) WHERE QueueUUID='$($stat.QueueUUID)';"
  if (!$validation){
    $startingCounter = $startingCounter -1
    $threshold = $threshold - 1
  }
  if ($validation.ERA_Validated -eq 1 -and $validation.Calm_Validated -eq 1 -and $validation.Karbon_Validated -eq 1 -and $validation.Core_Validated -eq 1 -and $validation.Files_Validated -eq 1 -and $validation.Objects_Validated -eq 1){
    $validatedCounter ++
  }
 [timespan]$total4time += [timespan]$stat.buildtime
  
}
$averagesecond = [string]($total4time.totalseconds) / 10
$Averagetime = New-TimeSpan -Seconds $averagesecond

$Limitseconds = 10000
$limittime = New-TimeSpan -Seconds $Limitseconds
if ($Averagetime.totalseconds -ge $Limitseconds){
  $datagenTemp = $Validation = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLDataGenTableName) WHERE QueueUUID='$($last10[0].QueueUUID)';"
  $body = $null
  $body += "<br>";
  $body += "Average Build time is $Averagetime, threshold at $limittime<br>";
  foreach ($object in $last10){
    $body += "<br><h2>Build time for $($object.pocname) is $($object.BuildTime)<h2><br>"
    $body += "Error count is $($object.ErrorCount)<br>"
    $body += "Warning count is $($object.WarningCount)<br>"
  }

  write-log -message "Average Build time is $Averagetime, threshold at $limittime<br>" -sev "WARN"
  if ($env:computername -match "DEV"){
    $subject = "Dev 1CD Service Buildtime Monitoring"
  } else {
    $subject = "Prod 1CD Service Buildtime Monitoring"
  }
  if ($portable -eq 0){
    Send-MailMessage -BodyAsHtml -body $body -to $datagenTemp.supportemail -from $datagenTemp.smtpsender -port $datagenTemp.smtpport -smtpserver $datagenTemp.smtpserver -subject $subject
  }
} else {

  write-log -message "Average Build time is $Averagetime, threshold at $limittime<br>";

}

if ($validatedCounter -lt $threshold){
  $datagenTemp = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLDataGenTableName) WHERE QueueUUID='$($last10[0].QueueUUID)';"
  $body = $null
  $body += "<br>";
  $body += "Validation is $validatedCounter out of $($last10.count), alerting at $threshold.<br>";
  foreach ($object in $last10){
    $Validation = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLDataValidationTableName) WHERE QueueUUID='$($object.QueueUUID)';"
    $body += "<br><h2>Validation for POC $($object.pocname)<h2><br>"
    $body += "$($Validation.ERA_Result)<br>"
    $body += "$($Validation.Calm_Result)<br>"
    $body += "$($Validation.Karbon_Result)<br>"
    $body += "$($Validation.Core_Result)<br>"
    $body += "$($Validation.Files_Result)<br>"
    $body += "$($Validation.Objects_Result)<br>"
  }
  if ($env:computername -match "DEV"){
    $subject = "Dev 1CD Service Validation Monitoring"
  } else {
    $subject = "Prod 1CD Service Validation Monitoring"
  }
  if ($portable -eq 0){
    Send-MailMessage -BodyAsHtml -body $body -to $datagenTemp.supportemail -from $datagenTemp.smtpsender -port $datagenTemp.smtpport -smtpserver $datagenTemp.smtpserver -subject $subject
  }
} else {

  write-log -message "Validation is $validatedCounter out of $($last10.count), alerting at $threshold"

}

### Auto URL Config below.

$xrayURL = "https://portal.nutanix.com/api/v1/xrays"

$eraURL = "https://portal.nutanix.com/api/v1/releases?state=active&type=era"
$frameurl = "https://portal.nutanix.com/api/v1/frames"
  
$result = Invoke-RestMethod -Uri "https://downloads.frame.nutanix.com/FrameCCA-current.checksum"
$latest = $result.split(" ")[1].split("`n")[0]
$version = $latest.split("-")[1]
$cleanver = $version.Substring(0,$version.Length-4)
$full = "https://downloads.frame.nutanix.com/" + $latest
$Frame_CCAISO  = $full
$Frame_AgentISO= "http://download.nutanix.com/frame/2.1/FrameGuestAgentInstaller_1.0.2.2_7930.iso"

write-log -message "Writing Frame Connector $($cleanver);$($Frame_CCAISO)"
write "Version;Url`n$($cleanver);$($Frame_CCAISO)" | out-file "$basedir\AutoDownloadURLs\FrameC.urlconf"  

write-log -message "Writing Frame Agent $($cleanver);$($Frame_AgentISO)"
write "Version;Url`n$($cleanver);$($Frame_AgentISO)" | out-file "$basedir\AutoDownloadURLs\FrameA.urlconf"

write-log -message "Checking Latest Portal URLs Autodownload"
write-log -message "Getting XRAY"
  
$portalassets = REST-Portal-Query-AssetOtions
$LiveXrayVersion = ((((($portalassets | where {$_.id -eq "XRay"}).options).version | where {$_ -match "[0-9].*"}) -replace " ", '') | sort [version]$_ | select -last 1).tostring()
if ([version]$LiveXrayVersion){
  $XRayConf = "$($LiveXrayVersion);http://download.nutanix.com/XRay/$($LiveXrayVersion)/xray.qcow2;http://download.nutanix.com/xray/$($LiveXrayVersion)/xray.ova"
  write-log -message "Writing XRay $XRayConf"
  write "Version;UrlAHV;UrlVMWare`n$($XRayConf)" | out-file "$basedir\AutoDownloadURLs\Xray.urlconf"    
} else {
  write-log -message "Not updating"
}

write-log -message "Getting Move"
  
$portalassets = REST-Portal-Query-AssetOtions
$LiveMoveVersion = (($portalassets | where {$_.id -eq "xtract"}).options.version | select-string -pattern "[0-9].*" | sort [version]$_ | select -last 1).tostring()
if ([version]$LiveMoveVersion){
  $MoveConf = "$($LiveMoveVersion);http://download.nutanix.com/NutanixMove/$($LiveMoveVersion)/move-$($LiveMoveVersion).zip;http://download.nutanix.com/NutanixMove/$($LiveMoveVersion)/move-$($LiveMoveVersion)-esxi.ova"
  write-log -message "Writing Move $MoveConf"
  write "Version;UrlAHV;UrlVMWare`n$($MoveConf)" | out-file "$basedir\AutoDownloadURLs\Move.urlconf"    
} else {
  write-log -message "Not updating"
}

write-log -message "Getting ERA"
  
$portalassets = REST-Portal-Query-AssetOtions
$LiveERAversion = (($portalassets | where {$_.id -eq "era"}).options.version | select-string -pattern "[0-9].*" | sort [version]$_ | select -last 1).tostring()
$erarelease = REST-Portal-Query-ReleaseAPI-ERA
$LiveERA = $erarelease.releases | where { $_.version_id -eq $LiveERAversion }
$buildid = $liveera.manifest_json.id
$freshInstallURL1 = "http://download.nutanix.com/era/$($LiveERAversion)/ERA-Server-build-$($LiveERAversion)-$($buildid).qcow2"
$freshInstallURL2 = "http://download.nutanix.com/era/$($LiveERAversion)/ERA-Server-build-$($LiveERAversion)-$($buildid).ova"
if ($buildid.length -ge 5){
  write-log -message "Writing ERA $($LiveERAversion);$($freshInstallURL1);$($freshInstallURL2)"
  write "Version;UrlAHV;UrlVMWare`n$($LiveERAversion);$($freshInstallURL1);$($freshInstallURL2)" | out-file "$basedir\AutoDownloadURLs\ERA_VM.urlconf"
} else {
  write-log -message "Not updating"
}
