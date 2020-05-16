#### UserVariables
$global:Debug                      = 2
if ((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain -eq $true){
  $global:portable = 0
} else {
  $global:portable = 1
}

#### Program Variables
$logingdir                  = "C:\1-click-demo\System\Logging"
$BaseThreadlogingdir        = "C:\1-click-demo\Jobs\Prod"
$ArchiveThreadlogingdir     = "C:\1-click-demo\Jobs\Archive"
$ModuleDir                  = "C:\1-click-demo\Modules"
$daemons                    = "C:\1-click-demo\Daemons"
$Lockdir                    = "C:\1-click-demo\Lock"
$global:BaseDir             = "C:\1-click-demo\"
$queuepath 			            = "C:\1-click-demo\Queue"
$incomingqueue              = "Incoming"
$Manualqueue                = "Manual"
$Outgoing                   = "Outgoing"
$ready                      = "Ready"
$AutoQueueTimer             = 15
$datequeue                  = (get-date).adddays(-2)
$datelogs                   = (get-date).adddays(-30)
$datetasks                  = (get-date).adddays(-2) ## Dont go lower then 2 or risk deleting running tasks over midnight.
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
#### Loading
Import-Module "$($ModuleDir)\Queue\Get-IncommingQueueItem.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Queue\Validate-QueueItem.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Queue\Lib-Spawn-Base.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Queue\Lib-PortableMode.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Base\Lib-Send-Confirmation.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Base\LIB-PSR-Tools.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Base\LIB-REST-Tools-Prism.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Base\LIB-Config-DetailedDataSet.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Base\LIB-Write-Log.psm1" -DisableNameChecking;

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

$global:type = "Backend"
$Guid = [guid]::newguid()
$logfile  = "$($logingdir)\Backend-$($Guid.guid).log"
#if ((get-date).hour -eq 1 -and (get-date).minute -lt 3 -and $portable -ne 1 -and $env:computername -notmatch "dev"){
#  write-log -message "Refreshing GIT"
#  rm "$($BaseDir)\System\Temp\Git" -force -confirm:0 -recurse
#  mkdir "$($BaseDir)\System\Temp\Git"
#
#  git clone "https://github.com/MMouse-23/1-click-demo/" "$($BaseDir)\System\Temp\Git"
#  rm "$($BaseDir)\Modules\" -force -recurse -confirm:0 -ea:0
#  rm "$($BaseDir)\Blueprints\" -force -recurse -confirm:0 -ea:0
#  mv "$($BaseDir)\System\Temp\Git\BluePrints\" "$($BaseDir)" -force -ea:0
#  mv "$($BaseDir)\System\Temp\Git\Modules\" "$($BaseDir)" -force -ea:0
#  mv "$($BaseDir)\System\Temp\Git\Backend-Processsor.ps1" "$($BaseDir)Backend-Processsor.ps1" -force -ea:0
#  mv "$($BaseDir)\System\Temp\Git\Base-Outgoing-Queue-Processor.ps1" "$($BaseDir)Base-Outgoing-Queue-Processor.ps1" -force -ea:0
#}

start-transcript -path $logfile

# Program log cleanup

write-log -message "Starting Log Cleanup"

$oldFiles = get-item "$($logingdir)\Backend-*.log" | where {$_.lastwritetime -le ((get-date).adddays(-5))}
if ($oldfiles){

  write-log -message "Removing $($oldfiles.count) logfiles"

  remove-item $oldFiles -force -ea:0
}

$date = get-date

#### If portable check if images exist locally
if ($portable -eq 1){
  Lib-PortableMode -basedir $basedir
}

# Program is on a one minute loop

write-log -message "Backend Process active"

do {
  if ($portable -eq 0){
    write-log -message "Checking Outlook"
    $singleusermode = (get-item $SingleModelck -ea:0).lastwritetime | where {$_ -ge (get-date).addminutes(-90)}
    if ($env:computername -notmatch "dev"){
      $object = Get-IncommingueueItem
    }
    if ($object.QueueStatus -eq "Manual"){
      write-log -message "Sending Manual Queue EMAIL"
      $global:EnableEmail = 0
      try {
        $datagen = LIB-Config-DetailedDataSet -datavar $object -mode "BackEnd"
        Lib-Send-Confirmation -reciever $object.SenderEMail -datavar $object -mode "Queued" -datagen $datagen
      } catch {}
    }
  }
  write-log -message "Validating Ready Queue"
  $object = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLQueueTableName) WHERE QueueStatus='Ready'"
  if ($object){
    $global:queueuuid = $object.queueuuid
    $datagen = LIB-Config-DetailedDataSet -datavar $object -mode "BackEnd"
    if ($portable -eq 0){
      $global:EnableEmail = $datavar.EnableEmail
    } else {
      $global:EnableEmail = 0
    }
    if ($object.queuestatus -eq "Manual"){
      write-log -message "Sending Mail for Manual queue"
      $datagen = LIB-Config-DetailedDataSet -datavar $object -mode "BackEnd"
      Lib-Send-Confirmation -reciever $object.SenderEMail -datavar $object -mode "Queued" -datagen $datagen
    }
    if ($object.debug -ge 2){
  
      write-log -message "Setting Launcher for debug mode"
  
      $ps1file = "Base-Outgoing-Queue-Processor.ps1"
      $tasktype = "Foreground"
    } else {
  
      write-log -message "Setting Launcher for normal mode"
  
      $ps1file = "Base-Outgoing-Queue-Processor.ps1"
      $tasktype = "Background" 
    }
    $validation = Validate-QueueItem -processingmode "NOW"
    if ($validation -notmatch "Nothing to Process"){
      if ($validation -match "Error"){
        $global:EnableEmail = 1
        write-log -message "Validation Error"
        Lib-Send-Confirmation -reciever $object.SenderEMail -datavar $object -mode "QueueError" -validation $validation -datagen $datagen
      } else {

        if ($Object){
          Lib-Spawn-Base -basedir $basedir -ps1file $ps1file -Type $tasktype 
          sleep 119
          $tasktype = "Sleeping 2 minutes after launch" 
        }
      }
    }
  }
  sleep 10

  #write-log -message "Validating Manual Queue"

 #$object = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLQueueTableName) WHERE QueueStatus='Manual' AND QueueValid='ToBeValidated'"
 #if ($object){
 #  $validation = Validate-QueueItem -processingmode "Manual"
 #  if ($validation -notmatch "Nothing to Process"){
 #    if ($validation -match "Error"){
 #      $global:EnableEmail = 1
 #      Lib-Send-Confirmation -reciever $object.SenderEMail -datavar $object -mode "QueueError" -validation $validation -datagen $datagen
 #    } 
 #  }
 #} 
  $count++
  if ($date.hour -match "04"){
    $items = get-item "$($BaseThreadlogingdir)\*.log" -ea:0| where {$_.lastwritetime -lt (get-date).addhours(-22)}
    if ($items){
      $items | % { move-item -path $_.fullname -destination "$($ArchiveThreadlogingdir)\" -force}
    }
  } 



} until ($count -eq 3)

