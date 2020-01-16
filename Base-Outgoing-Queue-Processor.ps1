param (
  $prodmode = "1",
  $PQueueUUID = "bfa5f5bb-f872-40d5-ad71-080550940b5a"
)
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
if ((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain -eq $true){
  $global:portable = 0
} else {
  $global:portable = 1
}
$global:MasterPID = $pid
$logging                      = "C:\1-click-demo\Jobs\Prod"
$loggingdev                   = "C:\1-click-demo\Jobs\Dev"
$Archivelogingdir             = "C:\1-click-demo\Jobs\Archive"
$ModuleDir                    = "C:\1-click-demo\Modules\base"
$daemons                      = "C:\1-click-demo\Daemons"
$Lockdir                      = "C:\1-click-demo\Lock"
$queuepath                    = "C:\1-click-demo\Queue"
$global:basedir               = "C:\1-click-demo"
$BlueprintsPath               = "C:\1-click-demo\BluePrints"
$ArchiveQueue                 = "Archive"
$OutgoingQueue                = "Outgoing" 
$SingleModelck                = "$($Lockdir)\Single.lck"

### Loading assemblies
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
if ( (Get-PSSnapin -Name NutanixCmdletsPSSnapin -ErrorAction SilentlyContinue) -eq $null ) {
  Add-PsSnapin NutanixCmdletsPSSnapin -ErrorAction Stop
}
Get-SSHTrustedHost | Remove-SSHTrustedHost -ea:0

### Import Modules

Import-Module "$($ModuleDir)\CMD-Add-PEtoPC.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\CMD-AutoDetectVersions.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\CMDPSR-Create-VM.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\CMD-Create-VM.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\CMD-Set-DataServicesIP.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-Config-DetailedDataSet.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-Config-ISOurlData.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-CMD-VMware.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-Connect-NutanixVPN.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-Connect-PS.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Lib-Check-Thread.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-Get-OutgoingQueueItem.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Lib-Generate-SSHKey.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-PSR-Tools.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-Send-Confirmation.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-Server-SysprepXML.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-Spawn-Wrapper.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-REST-Tools-External.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-REST-Tools-Calm.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-REST-Tools-ERA.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-REST-Tools-Files.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-REST-Tools-Karbon.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-REST-Tools-Move.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-REST-Tools-Objects.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-REST-Tools-XRay.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-REST-Tools-Prism.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-SSH-Tools.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Lib-Update-DataX.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-Update-Stats.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-Test-ClusterPrereq.psm1"  -DisableNameChecking;
Import-Module "$($ModuleDir)\LIB-Write-Log.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Install-PC.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Create-SSP-Base.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Create-SSP-Customer.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Create-Marketplace.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Create-Management-Box.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Clean-Start.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Create-VMware-VM.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Install-XPlay-Demo.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Create-FS.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Install-Era-Base.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Upgrade-AOS.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-SideLoad-PC.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Lib-BPBackups.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Install-BPPack.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Install-Objects.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Install-Era-PostGresHA.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Install-Era-MSSQL.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Install-Era-MySQL.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Install-Era-Oracle.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Install-Splunk.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Install-HashiCorpVault.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Install-1CD.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Install-GoldenFrameImage.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Lib-BPBackups.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Join-PxtoADDomain.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Post-PC.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Create-VMware-Templates.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Update-LCMV2-PC.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Install-XRay.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Upload-ISOImages.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Create-ADForest-PC.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Create-KarbonCluster.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Validate-Build.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Watchdog.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Install-Move.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-AOS-Fubar-Test.psm1" -DisableNameChecking;
Import-Module "$($ModuleDir)\Wrap-Second-DC.psm1" -DisableNameChecking;
import-Module "$($ModuleDir)\Wrap-ESX-Finalize.psm1" -DisableNameChecking;
import-Module "$($ModuleDir)\Wrap-Install-XenDesktop.psm1" -DisableNameChecking;




#-----End Loader-----
# Type needs to be a global var outside the loader.
$global:QueueUUID = $PQueueUUID
$global:type = "Base"
$exit = 0 
$exitcount = 0
$daemonID = ([guid]::newguid()).guid

### Cleanup just at daemon start.
$items = get-item "$($daemons)\*.thread" | where {$_.lastwritetime -lt (Get-Date).addminutes(-10)}
if ($items){
  try {
    Remove-item $items -force
  } catch {
  }
}


### Loop until there is work for you, then you die.
do {
  $alive = $null
  $singleusermode = (get-item $SingleModelck -ea:0).lastwritetime | where {$_ -ge (get-date).addminutes(-90)}
  if (!$singleusermode){    
    $datavar = LIB-Get-OutgoingQueueItem -queuepath $queuepath -archive $ArchiveQueue -outgoing $OutgoingQueue -prodmode $prodmode
  }
  $exitcount++
  if ($datavar){
    if ($datavar.debug -le 1){
      $logfile= "$($logging)\$($datavar.pocname)-$($datavar.QueueUUID).log"
    } else {
      $logfile  = "$($loggingdev)\$($datavar.pocname)-$($datavar.QueueUUID).log"
    }
    if ($datavar.enableemail -eq 0){
      $global:EnableEmail = 0
    } else {
      $global:EnableEmail = 1
    }
    if ($portable -eq 1){
      $global:EnableEmail = 0
    } else {
      $global:EnableEmail = $EnableEmail
    }
    $global:Debug = $datavar.debug
    $lockfile = "$($Lockdir)\$($datavar.PEClusterIP)-base.lck"
    start-transcript -path $logfile
    ### Sysprep
    $ServerSysprepfile = LIB-Server-SysprepXML -Password $datavar.PEPass 

    ### ISO Dirs

    $global:ISOurlData1 = LIB-Config-ISOurlData -region $datavar.Location -datavar $datavar
    
    $global:ISOurlData2 = LIB-Config-ISOurlData -region "www" -datavar $datavar
    

    ### Full Data Set
    $datagen = LIB-Config-DetailedDataSet -datavar $datavar -basedir $basedir 


    # Type needs to be a global var outside the loader.
  
    
    write-log -message "Dataset Loaded" -sev "CHAPTER"
    
    $datavar | fl
    
    $datagen | fl
   
    ### Performance testing, high load disables info logging
    write-log -message "Getting Host CPU Load"
    
    $totalav = Test-CPUUsage
    
    write-log -message "Average CPU load is $totalav"
    
    if ($totalav -ge 70) {
      $global:Logginglevel = 1

      write-log -message "high load, disabling Info Logging sorry"

    } else {

      write-log -message "Logging fully enabled"

      $global:Logginglevel = 2
    }
    write-log -message "Thread Started" -sev "CHAPTER"  -slacklevel 1
    write-log -message "You are being served by Daemon ID $daemonID" -sev "CHAPTER"
    write-log -message "Processing queue item ID $($datavar.QueueUUID)" -slacklevel 1

    sleep 5     
    if ((get-item $lockfile -ea:0).lastwritetime -ge (get-date).addminutes(-90)){
      write-log -message "$($datavar.PEClusterIP) is still locked, what are you doing. Not accepting dual items in the queue, purging."
      LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "Locked" -logfile $logfile
      Lib-Get-Wrapper-Results -datavar $datavar -datagen $datagen -ModuleDir $ModuleDir -parentuuid "$($datavar.QueueUUID)" -basedir $basedir 
      stop-transcript
      break
    } else {
      write "Locked" | out-file $lockfile
    }

    write-log -message "Testing Connectivity" -sev "CHAPTER"

    $alive = LIB-Test-ClusterPrereq -PEClusterIP $datavar.PEClusterIP
    ### Try to build VPN if not reachable
    if ($alive.Result -eq "Failed" -and $portable -eq 1){;

      write-log -message "Cluster not reachable, entering single user mode to start VPN based provisioning.";
      write-log -message "Single User mode required, draining..."

      write "Locked" | out-file $SingleModelck
      
      do {
        $Active = (Get-item C:\HostedPocProvisioningService\Jobs\Active\*.log -ea:0) | where {$_.lastwritetime -gt (get-date).addminutes(-3) -and $_.fullname -ne $logfile} 
        if ($active) {

          write-log -message "Draining queue prior proceding in single user mode."
          write-log -message "Currently $($active.count) threads running, waiting."

        } else {

          write-log -message "Queue is drained, single user mode activated."

        }
        sleep 60 
      } until (!$Active)

      write-log -message "Starting VPN" -sev "CHAPTER"

      LIB-Connect-NutanixVPN -VPNUser $datavar.VPNUser -VPNPass $datavar.vpnpass -VPNURL $datavar.vpnurl -mode "start"
  
      $alive = LIB-Test-ClusterPrereq -PEClusterIP $datavar.PEClusterIP
    };

    if ($alive.Result -ne "Success"){
      write-log -message "1CD Cannot Connect" -sev "CHAPTER" -slacklevel 1
      ## Queue the request
      $queueingcounter = 0
      LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "FailedConnect" -debug $datavar.debug
      $failed = 1
    }

    if ($alive.Result -eq "Success" -or $datavar.destroy -eq 1){

      write-log -message "Starting WatchDog" -sev "CHAPTER" -slacklevel 1

      $LauchCommand = 'Wrap-Watchdog -datagen $datagen -type "Base" -datavar $datavar -basedir $basedir -ParentLogfile ' + "`"$logfile`"" + ' -parentPID ' + $PID
      Lib-Spawn-Wrapper -Type "Watchdog" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -psm1file "$($ModuleDir)\Wrap-WatchDog.psm1" -LauchCommand $LauchCommand
      
      LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "start"

      write-log -message "Starting 1-Click Demo build" -sev "CHAPTER" -slacklevel 1

      if ($datavar.destroy -eq 1){

        write-log -message "Attempting login to the CVM using default or given password." -slacklevel 1
        write-log -message "Recreating Cluster, this destroys all data!!!" -sev "CHAPTER" -slacklevel 1
  
        SSH-Destroy-Pe -datavar $datavar -datagen $datagen -Lockdir $Lockdir
  
        sleep 60
      }
      write-log -message "Reset PE Password" -sev "CHAPTER"

      $status = SSH-ResetPass-Px -PxClusterIP $datavar.PEClusterIP -clusername $datavar.peadmin -clpassword $datavar.PEPass -mode "PE"

      if ($status.result -eq "Failed"){

        write-log -message "1CD Cannot login to PE / Create SVC Accounts" -sev "CHAPTER" -slacklevel 1
        LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "FailedAOS" -debug $datavar.debug
        $failed = 1
        
      }
      ## Testing Load
      write-log -message "Getting Host RAM"
      $ram = Test-MemoryUsage
      $inuse = $ram.totalgb - $ram.freegb

      write-log -message "Getting Host CPU Load"
    
      $totalav = Test-CPUUsage
    
      write-log -message "Average CPU load is $totalav"
      write-log -message "Checking Running builds"
      $time = (get-date).addhours(-48)
      $Statobjects      = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 100 * FROM [$($SQLDatabase)].[dbo].$($SQLDataStatsTableName) WHERE DateCreated >= '$time' order by DateCreated";
      #$Statobjects      = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 100 * FROM [$($SQLDatabase)].[dbo].$($SQLDataStatsTableName) WHERE Status = 'Running' order by DateCreated";
      [array]$active    = $Statobjects | where {$_.Percentage -le 65 -and $_.status -eq "Running"}
      $ramfree = 25
      $totalCPUPerc = 70
      if ($env:computername -match "DEv"){
        $concurrent = 4
      } else {
        $concurrent = 6     
      }
      if ($ram.pctfree -le $ramfree -or $totalav -ge $totalCPUPerc -or $active.count -gt $concurrent){
        
        write-log -message "1CD Server load is full ATM, Pending request" -sev "CHAPTER" -slacklevel 1
        write-log -message "Rush Hour here, 1CD server is using $inuse GB out of $($ram.totalgb) Total RAM."
        write-log -message "Rush Hour here, 1CD server is using $totalav % CPU Usage."
        write-log -message "There are $($active.count) running builds below 80% completed." 

        ## Queue the request
        $queueingcounter = 0
        do{
          $queueingcounter ++ 
          sleep 119
          if ($queueingcounter % 8 -eq 0){
            $ram = Test-MemoryUsage
            $totalav = Test-CPUUsage
            $time = (get-date).addhours(-48)
            $Statobjects      = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 100 * FROM [$($SQLDatabase)].[dbo].$($SQLDataStatsTableName) WHERE DateCreated >= '$time' order by DateCreated";
            #$Statobjects      = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 100 * FROM [$($SQLDatabase)].[dbo].$($SQLDataStatsTableName) WHERE Status = 'Running' order by DateCreated";
            [array]$active    = $Statobjects | where {$_.Percentage -le 65 -and $_.status -eq "Running"}
          }
          if ($queueingcounter % 20 -eq 0){
            LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "Full" -debug $datavar.debug
          }
          $minutes = ($queueingcounter * 119) / 60
          $minutes = [math]::Round($minutes)

          write-log -message "1CD Server load is full ATM, Pending request, sleeping $($minutes) / 1440" 
          write-log -message "Sleeping for 2 minutes"
          write-log -message "1CD server is using $inuse GB out of $($ram.totalgb) Total RAM." 
          write-log -message "There are $($active.count) running builds below 80% completed." 

        } until (($ram.pctfree -gt $ramfree -and $totalav -le $totalCPUPerc -and $active.count -le $concurrent) -or $minutes -ge 1440)
        if ($minutes -ge 1440){
          ## If we ever hit this
          write-log -message "If we ever hit this, the server needs a reboot."
        } else {
          LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "start"
        }
      } else {
        write-log -message "Lets move, 1CD server is using $inuse GB out of $($ram.totalgb) Total RAM." 
        write-log -message "There are $($active.count) running builds below 80% completed." 
      }
      $countauto = 0
      do {
        $countauto++
 
        write-log -message "Creating Service Accounts" -sev "CHAPTER" -slacklevel 1

        $svcstatus = SSH-ServiceAccounts-Px -PxClusterIP $datavar.PEClusterIP -datavar $datavar -datagen $datagen

        write-log -message "Autodetecting versions" -sev "CHAPTER" -slacklevel 1
      
        $autodetect = CMD-AutoDetectVersions -peadmin $datavar.PEAdmin -pepass $datavar.PEPass -PEClusterIP $datavar.PEClusterIP
      } until ($countauto -ge 5 -or $autodetect.result -eq "Success")

      $autodetect = CMD-AutoDetectVersions -peadmin $datavar.PEAdmin -pepass $datavar.PEPass -PEClusterIP $datavar.PEClusterIP
      
      if ($autodetect.Hypervisor -match "ESX|VMware"){
        $VMcluster = CMD-Test-VCenter -datavar $datavar
        if (!$VMcluster){
  
          write-log -message "1CD Cannot login to Virtual Center" -sev "CHAPTER" -slacklevel 1
  
          LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "FailedVC" -debug $datavar.debug
          $failed = 1
        }        
      }
      
      if ($failed -eq 1){
        
        stop-transcript
        try {
          Remove-item $lockfile
          Remove-item $SingleModelck -ea:0
          Connect-NutanixVPN -VPNUser $datavar.VPNUser -VPNPass $datavar.vpnpass -VPNURL $datavar.vpnurl -mode "stop"
        }catch {}
        Lib-Get-Wrapper-Results -datavar $datavar -datagen $datagen -ModuleDir $ModuleDir -parentuuid "$($datavar.QueueUUID)" -basedir $basedir
        break
      }

      write-log -message "Cleaning up and checking state" -sev "CHAPTER" -slacklevel 2
  
      $CleanResult = Wrap-Clean-Start -datagen $datagen -datavar $datavar

      write-log -message $cleanresult

      if ($CleanResult.PCClusterIP -match "[0-9]"){

        $datagen = $CleanResult
          write-log -message "Reset PC Password $($datagen.PCClusterIP)" -slacklevel 1

          $status1 = SSH-ResetPass-Px -PxClusterIP $datagen.PCClusterIP -clusername $datavar.peadmin -clpassword $datavar.PEPass -mode "PC"
          sleep 30

          if ($status1.result -eq "Success"){

            write-log -message "Sleeping 2 minutes for pw reset"

            if ($datavar.pcmode -eq 3){
              
              write-log -message "Sleeping for PC Scaleout PC Sync"
  
              $count = 0
              do {
                $count++
  
                write-log -message "Sleeping 30 seconds for $count out of 3"
  
                sleep 30
              } until ($count -eq 3)
            }

            write-log -message "Creating Service Accounts" -slacklevel 1

            $svcstatus = SSH-ServiceAccounts-Px -PxClusterIP $datagen.PCClusterIP -datavar $datavar -datagen $datagen

            write-log -message "Prism Central Finalize Login" -slacklevel 1

            REST-Finalize-Px -clusername $datagen.buildaccount -clpassword $datavar.PEPass -ClusterPx_IP $datagen.PCClusterIP -sename $datagen.sename -serole $datagen.serole -SECompany $datagen.SECompany -EnablePulse $datagen.EnablePulse
 
            write-log -message "Add Prism Element cluster to Prism Central Cluster" -slacklevel 1

            $status2 = CMD-Add-PEtoPC -PEClusterIP $datavar.PEClusterIP -PCClusterIP $datagen.PCClusterIP -PEAdmin $datagen.buildaccount -PEPass $datavar.PEPass 
            sleep 60

          } else {

            write-log -message "SSH Reset failed, there is no point in proceding.."
            $PCfail = 1

          }

      } elseif ($datavar.pcsidebin -match "http") {

        write-log -message "SideLaoding PC" -sev "CHAPTER" -slacklevel 1

        $UrlBase = $ISOurlData1."$($datagen.PCSideLoadImage)"

        Wrap-SideLoad-PC -datavar $datavar -datagen $datagen -AOSVersion $autodetect.AOSVersion -UrlBase $UrlBase -jsonbase "$($basedir)\binaries\PC\euphrates-5.11-stable-prism_central-metadata.json"

      }

      $countupdate = 0


      do {
        $countupdate ++

        write-log -message "Downloading Prism Element Add-on Software SSH ncli" -sev "CHAPTER" -slacklevel 1
        
        $result = SSH-Manage-SoftwarePE -ClusterPE_IP $datavar.PEClusterIP -clusername $datavar.peadmin -clpassword $datavar.PEPass -PCversion $datavar.PCVersion -filesversion $datagen.FilesVErsion -MODEL $datavar.SystemModel -pcwait 0 -AOSVersion $autodetect.AOSVersion
        Lib-Check-Thread -status $Status.result -stage "Downloading Prism Element Addon Software SSH ncli" -lockfile $lockfile -SingleModelck $SingleModelck -SenderEMail $datavar.SenderEMail -logfile $logfile
          
        if ($result.pcversion -notmatch "[0-9]"){

          write-log -message "Cluster is having DNS issues" -sev "WARN"
          write-log -message "This happens moreoften on VMware based clusters"
          write-log -message "Hypervisor is $($datavar.hypervisor)"
          write-log -message "Adding DNS servers"
          
          [array]$dns += $datavar.dnsserver
          [array]$dns += "1.1.1.1"
          
          REST-Add-DNS-Servers -datagen $datagen -datavar $datavar -DNSArr $dns
          
          write-log -message "Checking DNS servers"
          
          REST-Get-DNS-Servers -datagen $datagen -datavar $datavar

        }

      } until ($countupdate -ge 5 -or $result.pcversion -match "[0-9]")

      write-log -message "Updating DataX" 

      $pcversion = $result.PCVersion -split ("`n") | select -last 1
      ## Available AOS HERE
      $FilesVErsion = $result.filesversion -split ("`n") | select -last 1
      $nccversion = $result.NCCversion -split ("`n") | select -last 1 
      $AnalyticsVersion = $result.AnalyticsVersion -split ("`n") | select -last 1
      $AvailableAOSversion = $result.AOSVersion -split ("`n") | select -last 1  
       
      if ($datavar.InstallObjects -eq 1){
        [version]$minimalversion = "5.11" 

        write-log -message "Objects is enabled, minimal AOS version lifted to 5.11"

      } elseif ($datavar.InstallFiles -eq 1){
        [version]$minimalversion = "5.10.4" 

        write-log -message "Files is enabled, minimal AOS version lifted to 5.10.4"

      } else {

        [version]$minimalversion = "5.9.1"
        write-log -message "Files is not enabled, minimal AOS version is 5.9.1"
      }

      if ($AvailableAOSversion -and $debug -ge 3){
        write-log -message "Checking Cluster Health on $AvailableAOSversion" -sev "CHAPTER" -slacklevel 1
  
  
        $cornercase = Wrap-AOS-Fubar-Test -datagen $datagen -datavar $datavar -AvailableAOSVersion $AvailableAOSVersion
        if ($cornercase.Result -eq "Failed"){
  
          write-log -message "1CD Has Detected a bad PE Cluster, contact 1CD or refoundation and restart" -sev "CHAPTER" -slacklevel 1
          
          LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "AOSFubar" -debug $datavar.debug
          stop-transcript
          try {
            Remove-item $lockfile
            Remove-item $SingleModelck -ea:0
            Connect-NutanixVPN -VPNUser $datavar.VPNUser -VPNPass $datavar.vpnpass -VPNURL $datavar.vpnurl -mode "stop"
          }catch {}
          Lib-Get-Wrapper-Results -datavar $datavar -datagen $datagen -ModuleDir $ModuleDir -parentuuid "$($datavar.QueueUUID)" -basedir $basedir
          break
        }
      } 

      if ([version]$autodetect.AOSVersion -lt $minimalversion -or $datavar.UpdateAOS -eq 1){
        if ([version]$autodetect.AOSVersion -lt $minimalversion){
          LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "UpgradeAOS" -debug $datavar.debug -stage "$($autodetect.AOSVersion)|$AvailableAOSversion"

          write-log -message "AOS version $([version]$autodetect.AOSVersion) is not supported for files 3.5 / Analytics 1.1 and up" -slacklevel 0

        }
        if ($AvailableAOSVersion -ne ""){
 
          $result = Wrap-Upgrade-AOS -datavar $datavar -datagen $datagen -AvailableAOSversion $AvailableAOSVersion -autodetectAOSVersion $autodetect.AOSVersion
          sleep 60
          $autodetect = CMD-AutoDetectVersions -peadmin $datavar.PEAdmin -pepass $datavar.PEPass -PEClusterIP $datavar.PEClusterIP

          if ($result.Result -eq "Failed"){
            if ($autodetect.AOSVersion -ne $AvailableAOSVersion){
  
              write-log -message "AOS Upgrade Failed" -sev "CHAPTER"
    
              LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "FailedUPgrade" -debug $datavar.debug
              stop-transcript
              try {
                Remove-item $lockfile
                Remove-item $SingleModelck -ea:0
                Connect-NutanixVPN -VPNUser $datavar.VPNUser -VPNPass $datavar.vpnpass -VPNURL $datavar.vpnurl -mode "stop"
              }catch {}
              Lib-Get-Wrapper-Results -datavar $datavar -datagen $datagen -ModuleDir $ModuleDir -parentuuid "$($datavar.QueueUUID)" -basedir $basedir
              break
            }
          }
        } else {

          write-log -message "There is no later version available for auto download on this AOS" -sev "WARN"

        }
        $autodetect = CMD-AutoDetectVersions -peadmin $datavar.PEAdmin -pepass $datavar.PEPass -PEClusterIP $datavar.PEClusterIP
        $hypervisor = $autodetect.HyperVisor
        if ($autodetect.HyperVisor -match "nutanix|ahv"){

          write-log -message "Upgrading AHV" -sev "CHAPTER"
  
          $result = REST-AHV-InventorySoftware -datagen $datagen -datavar $datavar
          $LatestAHV = $result.entities  | sort version | select -last 1
  
          if ($LatestAHV){
  
            write-log -message "We have an AHV Upgrade available Executing upgrade from $($autodetect.HyperVisor) towards $($LatestAHV.version), this causes a 30 minute delay"  -slacklevel 0
            LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "UpgradeAHV" -debug $datavar.debug -stage "$($autodetect.HyperVisor)|$($LatestAHV.version)"
  
            REST-AHV-Upgrade  -datagen $datagen -datavar $datavar -AHV $LatestAHV
            Wait-AHV-Upgrade -datagen $datagen -datavar $datavar
            sleep 60
            $autodetect = CMD-AutoDetectVersions -peadmin $datavar.PEAdmin -pepass $datavar.PEPass -PEClusterIP $datavar.PEClusterIP
  
          } else {
  
            write-log -message "There are no AHV Updates available, were using version $($autodetect.HyperVisor)"
            
          }
          
        }
        $hypervisor = $autodetect.HyperVisor
        write-log -message "Scanning Latest PC Version After Upgrade"

        if ($datavar.PCVersion -notmatch "Latest|autodetect"){
          $datavar.PCVersion = "Latest"
        }
        $result = SSH-Manage-SoftwarePE -ClusterPE_IP $datavar.PEClusterIP -clusername $datavar.peadmin -clpassword $datavar.PEPass -PCversion $datavar.PCVersion -filesversion $datagen.FilesVErsion -MODEL $datavar.SystemModel -pcwait 0 -AOSVersion $autodetect.AOSVersion
        $pcversion = $result.PCVersion -split ("`n") | select -last 1
        ## Available AOS HERE
        $FilesVErsion = $result.filesversion -split ("`n") | select -last 1
        $nccversion = $result.NCCversion -split ("`n") | select -last 1
        if ($nccversion -eq $null){

          write-log -message "NCC Already up to par."

        }
        
        $buildAOSversion = $AvailableAOSVersion 

      } else {

        $buildAOSversion = $autodetect.AOSVersion
        

        write-log -message "AOS $buildAOSversion is supported, lets roll"

      }
      
      $hypervisor = $autodetect.HyperVisor
      

      write-log -message "Updating datasets" -sev "CHAPTER" -slacklevel 1  

      $datavar = Lib-Update-DataX -mode "DataVar" -hypervisor $hypervisor -AOSVersion $buildAOSversion -SystemModel $autodetect.SystemModel -pcversion $pcversion -datavar $datavar -datagen $datagen
      if ($debug -ge 2){

        write-log -message "New datavar loaded:"

        $datavar | fl
      }
      #ramcap before datax
      $versions = REST-Px-Get-Versions -datagen $datagen -datavar $datavar
      $nccversion = $versions.nccVersion
      $datagen = Lib-Update-DataX -mode "DataGen" -AnalyticsVersion $AnalyticsVersion -filesversion $filesversion -nccversion $nccversion -Karbonversion $datagen.Karbonversion -calmversion $dtagen.calmversion -AvailableAOSversion $AvailableAOSversion -objectsversion $datagen.objectsversion -Hypervisor $autodetect.Hypervisor -datavar $datavar -datagen $datagen
      if ($debug -ge 2){

        write-log -message "New dataGen loaded:"

        $dataGen | fl
      }
      ## FIRST FIRST FIRST, Moving up requires AOS Upgrade retry etc
      write-log -message "Setting up Storage" -sev "CHAPTER"

      $status = SSH-Storage-Pe -PEClusterIP $datavar.PEClusterIP -clusername $datavar.peadmin -clpassword $datavar.PEPass -StoragePoolName $datagen.StoragePoolName -KarbonContainername $datagen.KarbonContainername -DisksContainerName $datagen.DisksContainerName -ImagesContainerName $datagen.ImagesContainerName -ERAContainerName $datagen.ERAContainerName
      Lib-Check-Thread -status $status.result -stage "Setting up Storage" -lockfile $lockfile -SingleModelck $SingleModelck -SenderEMail $datavar.SenderEMail -logfile $logfile

      if ($Hypervisor -match "ESX"){

        write-log -message "Mounting Containers on VMware" -sev "CHAPTER"

        $hosts = REST-Get-PE-Hosts -username "admin" -datavar $datavar

        REST-Add-DataStore -PEClusterIP $datavar.PEClusterIP -clusername $datavar.peadmin -clpassword $datavar.PEPass -hosts $hosts -containername "Default"
        REST-Add-DataStore -PEClusterIP $datavar.PEClusterIP -clusername $datavar.peadmin -clpassword $datavar.PEPass -hosts $hosts -containername "ERA_01"
        REST-Add-DataStore -PEClusterIP $datavar.PEClusterIP -clusername $datavar.peadmin -clpassword $datavar.PEPass -hosts $hosts -containername "Images"
        REST-Add-DataStore -PEClusterIP $datavar.PEClusterIP -clusername $datavar.peadmin -clpassword $datavar.PEPass -hosts $hosts -containername "Karbon_01"

        Wrap-ESX-Finalize -datagen $datagen -datavar $datavar

      }

      write-log -message "Uploading Hypervisor and ISO Images" -sev "CHAPTER" -slacklevel 1  

      $LauchCommand = 'Wrap-Upload-ISOImages -ISOurlData1 $ISOurlData1 -ISOurlData2 $ISOurlData2 -datavar $datavar -datagen $datagen -mode "Base"'
      Lib-Spawn-Wrapper -Type "ImageUpload-Pass-1-Base" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode  -LauchCommand $LauchCommand    
      if ($datavar.installera -ge 1 ){
        if ($Hypervisor -match "AHV|Nutanix"){
          $LauchCommand = 'Wrap-Upload-ISOImages -ISOurlData1 $ISOurlData1 -ISOurlData2 $ISOurlData2 -datavar $datavar -datagen $datagen -mode "MSSQL"'
          Lib-Spawn-Wrapper -Type "ImageUpload-Pass-1-MSSQL" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode  -LauchCommand $LauchCommand
        }
        $LauchCommand = 'Wrap-Upload-ISOImages -ISOurlData1 $ISOurlData1 -ISOurlData2 $ISOurlData2 -datavar $datavar -datagen $datagen -mode "Oracle"'
        Lib-Spawn-Wrapper -Type "ImageUpload-Pass-1-Oracle" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode  -LauchCommand $LauchCommand
      }
      
 
      if ($debug -ge 2) {

        write-log -message "Ill swallow anything in debugging mode"
        write-log -message "Using $($datavar.HyperVisor)"

      } elseif ($datavar.HyperVisor -notmatch "nutanix|AHV|VMware|ESXi"){
        write-log -message "HyperVisor $($datavar.HyperVisor) is not supported." -sev "CHAPTER"
        LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "FailedHV" -debug $datavar.debug
        stop-transcript
        try {
          Remove-item $lockfile
          Remove-item $SingleModelck -ea:0
          Connect-NutanixVPN -VPNUser $datavar.VPNUser -VPNPass $datavar.vpnpass -VPNURL $datavar.vpnurl -mode "stop"
        }catch {}
        Lib-Get-Wrapper-Results -datavar $datavar -datagen $datagen -ModuleDir $ModuleDir -parentuuid "$($datavar.QueueUUID)" -basedir $basedir
        break

      } else {

        write-log -message "HyperVisor $($datavar.HyperVisor) is supported, lets roll"

      }

      write-log -message "Setting up Networking and Networking" -sev "CHAPTER"
      write-log -message "Setting up Networking" -slacklevel 1

      if ($autodetect.hypervisor -match "Nutanix"){ 

        write-log -message "Doing AHV Only Networking stuff" -slacklevel 1

        $status = SSH-Networking-Pe -PEClusterIP $datavar.PEClusterIP -clusername $datavar.peadmin -clpassword $datavar.PEPass -Domainname $datagen.domainname -nw1dhcpstart $datagen.NW1DHCPStart -nw1gateway $datavar.InfraGateway -nw1subnet $datavar.InfraSubnetmask -nw1vlan $datavar.nw1vlan -nw1name $datagen.nw1name -nw2name $datagen.nw2name -nw2dhcpstart $datavar.nw2dhcpstart -nw2vlan $datavar.nw2vlan -nw2subnet $datavar.nw2subnet -nw2gateway $datavar.nw2gw -DC1IP $datagen.DC1IP -DC2IP $datagen.DC2IP -datavar $datavar
        
        if ($status.result -match "Failed"){

          write-log -message "Cannot create AHV Primary Network. Is this a default block?" -sev "CHAPTER"
  
          LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "FailedAHVNET" -debug $datavar.debug
          stop-transcript
          try {
            Remove-item $lockfile
            Remove-item $SingleModelck -ea:0
            Connect-NutanixVPN -VPNUser $datavar.VPNUser -VPNPass $datavar.vpnpass -VPNURL $datavar.vpnurl -mode "stop"
          }catch {}
          Lib-Get-Wrapper-Results -datavar $datavar -datagen $datagen -ModuleDir $ModuleDir -parentuuid "$($datavar.QueueUUID)" -basedir $basedir
          break

        }
      } elseif ($autodetect.hypervisor -match "ESXi"){

        write-log -message "Doing ESX Only Networking stuff" -slacklevel 1

        CMD-Rename-Network -datagen $datagen -datavar $datavar
        CMD-Add-Network2 -datagen $datagen -datavar $datavar

      
      }
      if ($CleanResult.PCClusterIP -notmatch "[0-9]"){

        write-log -message "Running Prism Central Installer wrapper for Stage 1" -sev "CHAPTER" -slacklevel 1
  
        Wrap-Install-PC -datagen $datagen -datavar $datavar -stage "1" -logfile $logfile
    
      }
      ##do not move see below
      write-log -message "Prism Element Prep" -sev "CHAPTER" -slacklevel 1
      
      $Status = REST-Finalize-Px -clusername $datagen.buildaccount -clpassword $datavar.PEPass -ClusterPx_IP $datavar.PEClusterIP -sename $datagen.sename -serole $datagen.serole -SECompany $datagen.SECompany -EnablePulse $datagen.EnablePulse
      Lib-Check-Thread -status $Status.result -stage "Prism Element Prep (REST)" -lockfile $lockfile -SingleModelck $SingleModelck -SenderEMail $datavar.SenderEMail -logfile $logfile 
      # the liines below match the above
      if ($Status.result -eq "Failed"){
        if ($datavar.destroy -eq 1){

          write-log -message "Known Limitation on Cluster destroy"

        } else {

          write-log -message "New Issue" -sev "WARN"

        }
        $servicecount = 0
        do {
          $servicecount++
          sleep 60
          $svcstatus = SSH-ServiceAccounts-Px -PxClusterIP $datavar.PEClusterIP -datavar $datavar -datagen $datagen
          $Status2 = REST-Finalize-Px -clusername $datagen.buildaccount -clpassword $datavar.PEPass -ClusterPx_IP $datavar.PEClusterIP -sename $datagen.sename -serole $datagen.serole -SECompany $datagen.SECompany -EnablePulse $datagen.EnablePulse
          
          if ($status2.result -eq "Failed"){

            write-log -message "How long does this take...." -sev "WARN"

          }
        } until ($status2.result -eq "Success" -or $servicecount -ge 5)
      }

      write-log -message "Set External Data Services IP" -sev "CHAPTER" -slacklevel 1

      CMD-Set-DataservicesIP -DataServicesIP $datagen.DataServicesIP -PEClusterIP $datavar.PEClusterIP -clusername $datagen.buildaccount -clpassword $datavar.PEPass


      write-log -message "Waiting for DC Image Upload" -sev "CHAPTER" -slacklevel 1

      if ($datavar.Hypervisor -match "ESX") {

        $LauchCommand = 'SSH-Wait-ImageUpload -datavar $datavar -datagen $datagen -ISOurlData $ISOurlData1 -image $datagen.DC_ImageName'
        Lib-Spawn-Wrapper -Type "WaitImage" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -psm1file "$($ModuleDir)\Wrap-Create-ADForest-PC.psm1" -LauchCommand $LauchCommand 

        sleep 60
        Wait-Image-Task -datavar $datavar

        write-log -message "Spawning ESX MGT Box" -sev "CHAPTER" -slacklevel 1

        $LauchCommand = 'Wrap-Create-Management-Box -datavar $datavar -datagen $datagen -ISOurlData $ISOurlData1 -VMname'
        Lib-Spawn-Wrapper -Type "mgmtVM" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -psm1file "$($ModuleDir)\Wrap-Create-ADForest-PC.psm1" -LauchCommand $LauchCommand 

      } else {

        REST-Wait-ImageUpload -imagename $datagen.DC_ImageName -datavar $datavar -datagen $datagen

      }
      
      write-log -message "Creating First DC VM" -sev "CHAPTER" -slacklevel 1

      if ($datavar.Hypervisor -match "ESX"){

        write-log -message "oh dear, all this bolt on crap VMware...."

        Wrap-Create-VMware-VM -datavar $datavar -datagen $datagen -vmname $datagen.DC1Name -VMIP $datagen.DC1IP -guestOS "windows9Server64Guest" -NDFSSource $datagen.DC_ImageName -DHCP $false -container $datagen.DisksContainerName -createTemplate $false

      } else {

        $ServerSysprepfileDC1 = LIB-IP-Server-SysprepXML -Password $datavar.PEPass -gw $datavar.InfraGateway -ip $datagen.DC1IP -mask $datavar.InfraSubnetmask -ifname "Ethernet0"
        $VM1 = CMDPSR-Create-VM -datagen $datagen -datavar $datavar -mode "Static" -DisksContainerName $datagen.DiskContainerName -Subnetmask $datavar.InfraSubnetmask -Sysprepfile $ServerSysprepfileDC1 -Networkname $datagen.Nw1Name -VMname $datagen.DC1Name -ImageName $datagen.DC_ImageName -cpu 4 -ram 4096 -VMip $datagen.DC1IP -VMgw $datavar.InfraGateway -DNSServer1 $datagen.DC1IP -DNSServer2 $datagen.DC2IP -SysprepPassword $datagen.SysprepPassword -PEClusterIP $datavar.PEClusterIP -clusername $datagen.buildaccount -clpassword $datavar.PEPass
    
      }  

      write-log -message "Spawning Create Forest" -sev "CHAPTER" -slacklevel 1

      $LauchCommand = 'Wrap-Create-ADForest-PC -datagen $datagen -datavar $datavar -ServerSysprepfile $ServerSysprepfile -basedir $basedir'
      Lib-Spawn-Wrapper -Type "Forest" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand 
      
      if ($datavar.InstallEra -ge 1){

        write-log -message "Spawning ERA Install" -sev "CHAPTER" -slacklevel 1

        $LauchCommand = 'Wrap-Install-Era-Base -datagen $datagen -datavar $datavar -ServerSysprepfile $ServerSysprepfile -basedir $basedir -BlueprintsPath' + " $BlueprintsPath"
        Lib-Spawn-Wrapper -Type "ERA_Base" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand

      }

      if ($datavar.Hypervisor -match "ESX"){

        write-log -message "Spawning Thread for Template conversion" -sev "CHAPTER" -slacklevel 1

        $LauchCommand = 'Wrap-Create-VMware-Templates -datagen $datagen -datavar $datavar'
        Lib-Spawn-Wrapper -Type "ImagesVmware" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand 
      
      }
      
      if ($CleanResult.PCClusterIP -notmatch "[0-9]"){
 
        write-log -message "Running PC Installer Wrapper for Stage 2" -sev "CHAPTER" -slacklevel 1
 
        Wrap-Install-PC -datagen $datagen -datavar $datavar -stage "2" -logfile $logfile
 
      }

      if ($datavar.InstallXRay -eq 1){
 
        write-log -message "Installing XRay" -sev "CHAPTER" -slacklevel 1
        $LauchCommand =' Wrap-Install-XRay -datavar $datavar -datagen $datagen'
        Lib-Spawn-Wrapper -Type "X-Ray" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand 

      }  
      
      if ($datavar.DemoXenDeskT -eq 1 ){

        write-log -message "Installing XenDesktop" -sev "CHAPTER" -slacklevel 1
        $LauchCommand =' Wrap-Install-XRay -datavar $datavar -datagen $datagen'
        Lib-Spawn-Wrapper -Type "X-Ray" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand 

      }

      write-log -message "Spanwing Second DC" -sev "CHAPTER"
    
      $LauchCommand = 'Wrap-Second-DC -datagen $datagen -datavar $datavar -ServerSysprepfile $ServerSysprepfile'
      Lib-Spawn-Wrapper -Type "Second_DC" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand 
  
      if ($datavar.Installkarbon -eq 1){

        write-log -message "Enable Karbon" -sev "CHAPTER"  -slacklevel 2

        REST-Enable-Karbon-PC -datavar $datavar -datagen $datagen
                    
      }
      ## Karbon needs to be enabled Prior to LCM Update, calm needs to be enabled before SSP

      write-log -message "Setting up Calm" -sev "CHAPTER" -slacklevel 1

      REST-Enable-Calm -clpassword $datavar.PEPass -clusername $datagen.buildaccount -PCClusterIP $datagen.PCClusterIP 
      ## Leave calm here.

      if ($datavar.enableflow -eq 1){

        write-log -message "Setting up Flow" -sev "CHAPTER" -slacklevel 1

        REST-Enable-Flow -datavar $datavar -datagen $datagen -mode "Full"
      } 

      If ($datavar.InstallObjects -eq 1 -or $debug -ge 2){
        ## Save time on LCM wait time.
        write-log -message "Setting up Objects" -sev "CHAPTER" -slacklevel 1
  
        $enable = REST-Enable-Objects -datagen $datagen -datavar $datavar

        write-log -message "Waiting till objects is enabled."
        $count = 0
        do {
          $count++
          sleep 10
          $status = REST-Query-Object-Install -datagen $datagen -datavar $datavar
          if ($status.service_enablement_status -eq "Enabled"){

            write-log -message "We are all done here. Objects is enabled."

          } else {

            write-log -message "Prism status is $($status.service_enablement_status), Waiting"
        
          }
        } until ($status.service_enablement_status -eq "Enabled" -or $count -ge 20)
      }

      # APP Enable task is not trackable yet, leave objects enable above.
      write-log -message "Update NCC on PE" -sev "CHAPTER" -slacklevel 1
       
      $downloadPE = REST-PC-Download-NCC -datavar $datavar -datagen $datagen -mode "PE"
      $TargetPE = $downloadPE.entities | sort [version]$_.version | select -last 1
      sleep 10
      REST-Px-Update-NCC -datavar $datavar -datagen $datagen -mode "PE" -target $TargetPE.version

      write-log -message "Running Full LCM Prism Central Updates (REST)" -sev "CHAPTER" -slacklevel 1

      $updates = Wrap-Update-LCMV2-PC -datagen $datagen -datavar $datavar -logfile $logfile

      write-log -message "Running PC Installer Wrapper for Post Install" -sev "CHAPTER" -slacklevel 1

      $LauchCommand = 'Wrap-Post-PC -datagen $datagen -datavar $datavar -ServerSysprepfile $ServerSysprepfile'
      Lib-Spawn-Wrapper -Type "POSTPC" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand 
  
      write-log -message "Getting Versions"

      $calmversion = ($updates | where {$_.Name -match "Calm"}).version
      $Karbonversion = ($updates | where {$_.Name -match "Karbon"}).version
      $Objectsversion = ($updates | where {$_.Name -match "MSP"}).version
      $filesversion = $datagen.filesversion 

      $versions = REST-Px-Get-Versions -datagen $datagen -datavar $datavar
      $nccversion = $versions.nccVersion

      $datagen = Lib-Update-DataX -mode "DataGen" -AnalyticsVersion $AnalyticsVersion -filesversion $filesversion -nccversion $nccversion -Karbonversion $Karbonversion -calmversion $calmversion -AvailableAOSversion $AvailableAOSversion -objectsversion $Objectsversion -Hypervisor $autodetect.Hypervisor -datavar $datavar
      if ($debug -ge 2){

        write-log -message "New dataGen loaded:"

        $dataGen | fl
      }
      if ($datavar.InstallKarbon -eq 1){

        write-log -message "Spawning Karbon Cluster" -sev "CHAPTER" -slacklevel 1
        $LauchCommand = 'Wrap-Create-KarbonCluster -datagen $datagen -datavar $datavar -ServerSysprepfile $ServerSysprepfile -BlueprintsPath ' + $BlueprintsPath
        Lib-Spawn-Wrapper -Type "Karbon" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode  -LauchCommand $LauchCommand

      }

      if ($datavar.InstallMove -eq 1){
        
        $LauchCommand = 'Wrap-Install-Move -datagen $datagen -datavar $datavar -ServerSysprepfile $ServerSysprepfile'
        Lib-Spawn-Wrapper -Type "Move" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand 
        
      }
      if ($datavar.SetupSSP -eq 1){

        write-log -message "Spawning SSP Portal with AD content" -sev "CHAPTER" -slacklevel 1
        $LauchCommand = 'Wrap-Create-SSP-Base -datagen $datagen -datavar $datavar'
        Lib-Spawn-Wrapper -Type "SSP_Base" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand 
        sleep 10

        write-log -message "Spawning MarketPlace" -sev "CHAPTER" -slacklevel 1
        $LauchCommand = 'Wrap-Create-Marketplace -datagen $datagen -datavar $datavar'
        Lib-Spawn-Wrapper -Type "Market" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand 
                  
      }
      ## Leave capped at 5.11 dumbass
      if ($datavar.InstallObjects -eq 1 ){ 
        # has to be after POST PC for NTP
        write-log -message "Spawning Objects Cluster" -sev "CHAPTER" -slacklevel 1

        $LauchCommand = 'Wrap-Install-Objects -datagen $datagen -datavar $datavar'
        Lib-Spawn-Wrapper -Type "Objects" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand

      }
      
      if ($datavar.hypervisor -match "nutanix"){

        write-log -message "Importing PC Images." -sev "CHAPTER" -slacklevel 1
  
        $imageimport = REST-Image-Import-PC -clpassword $datavar.PEPass -clusername $datagen.buildaccount -PCClusterIP $datagen.PCClusterIP

      }

      if ($datavar.DemoLab -eq 1){
 
        write-log -message "Installing Workshop Lab Settings Prism Central" -sev "CHAPTER" -slacklevel 1
       
        REST-WorkShopConfig-Px -ClusterPx_IP $datagen.PCClusterIP -clpassword $datavar.PEPass -clusername $datagen.buildaccount -POCName $datavar.POCname -VERSION $datavar.PCVersion -Mode "PC"

      } 

      if ($datavar.DemoXenDeskT -eq 1){

        write-log -message "Installing XenDesktop Demo" -sev "CHAPTER" -slacklevel 1
        write-log -message "Not implemented"    
      
      }

      if ($datavar.InstallFrame -eq 1 -and $debug -ge 2 -and $datavar.hypervisor -notmatch "ESX|VMware"){

        write-log -message "Installing Frame Golden Image" -sev "CHAPTER" -slacklevel 1
       
        $LauchCommand = 'Wrap-Install-GoldenFrameImage -datagen $datagen -datavar $datavar -ServerSysprepfile $ServerSysprepfile -basedir $basedir'
        Lib-Spawn-Wrapper -Type "Frame_Image" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand 
        sleep 60

      } 

      if ($datavar.DemoIISXPlay -eq 1){

        write-log -message "Installing XPlay IIS CPU Scaling" -sev "CHAPTER" -slacklevel 1
        
        $demo = Wrap-Install-XPlay-Demo -datagen $datagen -datavar $datavar -BlueprintsPath $BlueprintsPath -basedir $basedir 

      }
      if ($datavar.InstallSplunk -eq 1){

        write-log -message "Spawning Splunk Install" -sev "CHAPTER" -slacklevel 1

        $LauchCommand = 'Wrap-Install-Splunk -datagen $datagen -datavar $datavar -ServerSysprepfile $ServerSysprepfile -basedir $basedir -BlueprintsPath ' + $BlueprintsPath
        Lib-Spawn-Wrapper -Type "Splunk" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand 
      } 

      if ($datavar.InstallHashiVault -eq 1 ){

        write-log -message "Spawning HashiCorpVault Install" -sev "CHAPTER" -slacklevel 1

        $LauchCommand = 'Wrap-Install-HashiCorpVault -datagen $datagen -datavar $datavar -ServerSysprepfile $ServerSysprepfile -basedir $basedir -BlueprintsPath ' + $BlueprintsPath
        Lib-Spawn-Wrapper -Type "HashiCorpVault" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand 
      } 
      if ($datavar.Install1CD -eq 1){

        write-log -message "Spawning 1CD CI/CD Portable Edition" -sev "CHAPTER" -slacklevel 1

        $LauchCommand = 'Wrap-Install-1CD -datagen $datagen -datavar $datavar -ServerSysprepfile $ServerSysprepfile -basedir $basedir -BlueprintsPath ' + $BlueprintsPath
        Lib-Spawn-Wrapper -Type "Portable_1CD" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand 
      } 
      if ($datavar.InstallBPPack -eq 1){

        write-log -message "Spawning Install GTS 2019 BP Pack" -sev "CHAPTER" -slacklevel 1

        $LauchCommand = 'Wrap-Install-BPPack -datagen $datagen -datavar $datavar -BlueprintsPath ' + $BlueprintsPath
        Lib-Spawn-Wrapper -Type "BPPack" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand 
      }     
      if ($datavar.DemoLab -eq 1){
 
        write-log -message "Installing Workshop Lab Settings Prism Element" -sev "CHAPTER" -slacklevel 1
       
        REST-WorkShopConfig-Px -ClusterPx_IP $datavar.PEClusterIP -clpassword $datavar.PEPass -clusername $datagen.buildaccount -POCName $datavar.POCname -VERSION $datavar.PCVersion -Mode "PE" -datavar $datavar

      }
      write-log -message "Finalizing Build." -sev "CHAPTER" -slacklevel 1

      Lib-Get-Wrapper-Results -datavar $datavar -datagen $datagen -ModuleDir $ModuleDir -parentuuid "$($datavar.QueueUUID)" -basedir $basedir 
     
      write-log -message "Updating NCC on PE" -sev "CHAPTER" -slacklevel 1

      REST-Px-Update-NCC -datavar $datavar -datagen $datagen -mode "PE"

      write-log -message "Redundancy ISO Images" -sev "CHAPTER" -slacklevel 1   

      write-log -message "Done" -sev "CHAPTER" -slacklevel 1
      $basestatus = Lib-Update-Stats -datavar $datavar -datagen $datagen -ParentLogfile $logfile -basedir $basedir
      
      LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "end"  -logfile $logfile
      if ($datavar.EnableBlueprintBackup -eq 1 -and $portable -ne 1){

        write-log -message "Enable BluePrintBackup" -sev "CHAPTER" -slacklevel 1
        Wrap-BluePrintBackup-Scheduler -datavar $datavar -datagen $datagen -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir

      } 
      if ($datavar.EnableBlueprintBackup -ne 2 -and $portable -ne 1){

        write-log -message "Enable BluePrint Restore" -sev "CHAPTER" -slacklevel 1
        Wrap-BluePrintBackup-Restore -datavar $datavar -datagen $datagen   
      }
      ## Cleanup section, no chapter logging.
      if ($datavar.debug -ge 0){
        $count = 0
        do{
          $count ++
          $alerts = REST-Px-Query-Alerts -datagen $datagen -datavar $datavar -mode "PE"
          $UUIDs = ($alerts.group_results.entity_results.data |where {$_.name -eq "id"}).values.values | sort -unique
          write-log -message "We have $($uuids.count) alerts to be purged."
          if ($UUIDs.count -ge 1){
            REST-Px-Resolve-Alerts -datagen $datagen -datavar $datavar -mode "PE" -uuids $UUIDs 
          }
          sleep 60
        } until ($UUIDs.count -eq 0 -or $count -ge 5)
        $count = 0
        do{
          $count ++
          $alerts = REST-Px-Query-Alerts -datagen $datagen -datavar $datavar -mode "PC"
          $UUIDs = ($alerts.group_results.entity_results.data |where {$_.name -eq "id"}).values.values | sort -unique
          write-log -message "We have $($uuids.count) alerts to be purged."
          if ($UUIDs.count -ge 1){
            REST-Px-Resolve-Alerts -datagen $datagen -datavar $datavar -mode "PC" -uuids $UUIDs 
          }
          sleep 60
        } until ($UUIDs.count -eq 0 -or $count -ge 5)

        write-log -message "Updating NCC on PC" -slacklevel 1 -sev "Chapter"

        $downloadPC = REST-PC-Download-NCC -datavar $datavar -datagen $datagen -mode "PC"
        $TargetPC = $downloadPC.entities | sort [version]$_.version | select -last 1

        REST-Px-Update-NCC -datavar $datavar -datagen $datagen -mode "PC" -target $TargetPC.version
 
        REST-Px-Run-Full-NCC -datagen $datagen -datavar $datavar -mode "PE"
        sleep 300
        REST-Px-Run-Full-NCC -datagen $datagen -datavar $datavar -mode "PC"
          
        REST-Px-SMTP-Setup -datagen $datagen -datavar $datavar -mode "PE"
        
        REST-Px-SMTP-Setup -datagen $datagen -datavar $datavar -mode "PC"
      }
      REST-LCM-Perform-Inventory -datavar $datavar -datagen $datagen -mode "PE"
      write-log -message "Sleeping for Validation"
      do {
        $Looper++
        [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^ERA_MSSQL"} -ea:0
        [array]$tasks += Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^Objects"} -ea:0

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
      $tasks | unregister-scheduledtask -confirm:0 -ea:0
      Wrap-Validate-Build -datavar $datavar -datagen $datagen -basedir $basedir
         
    } 
    stop-transcript
    $exit = 1
    try {
      Remove-item $lockfile
      Remove-item $SingleModelck -ea:0
      Connect-NutanixVPN -VPNUser $datavar.VPNUser -VPNPass $datavar.vpnpass -VPNURL $datavar.vpnurl -mode "stop"
    }catch {}
  } else {
    write-log -message "UUID $QueueUUID does not exist or queue not in multi usermode, Production mode is $prodmode V2"
    write "Empty Daemon sleeping" | out-file "$($daemons)\$($daemonID).thread"
  };
  sleep 110
} until ($exit -eq 1 -or $exitcount -ge 350 )


