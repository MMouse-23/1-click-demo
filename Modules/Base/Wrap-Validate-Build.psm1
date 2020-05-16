
function Wrap-Validate-Build {
  param(
    $datavar,
    $datagen,
    $basedir
  )

  $SuccesImportedBPCount = 5 
  write-log -message "Validating Build" -sev "Chapter" -slacklevel 1

  write-log -message "Validating Calm" 

  $countFailedApps = 0
  sleep 10
  $blueprints = REST-Query-Calm-BluePrints -datavar $datavar -datagen $datagen
  sleep 10
  $applications = REST-Query-Calm-Apps -datavar $datavar -datagen $datagen
  if ($datavar.InstallBPPack -eq 1 -and $datavar.hypervisor -notmatch "ESX|VMware"){
    $minbp = 9
  } elseif ($datavar.DemoIISXPlay -eq 0 -and $datavar.InstallSplunk -eq 0 -and $datavar.InstallBPPack -eq 0 -and $datavar.InstallHashiVault -eq 0 -and $datavar.Install1CD -eq 0 -and $datavar.hypervisor -notmatch "ESX|VMware"){
    $minbp = 0
  } else {
    $minbp = 3
  }
  If ($datavar.DemoXenDeskT -eq 1){
    $count = 0
    do{
      $count ++
      $applications = REST-Query-Calm-Apps -datavar $datavar -datagen $datagen
      $state = ($applications.entities | where {$_.status.name -eq "XenDeskTop"}).status.state
      if (!$state){
        write-log -message "XenDesktop App is not present yet..." -SEV "WARN"
        $count + 5
        sleep 119
      } elseif ($state -eq "provisioning") {
        write-log -message "Waiting for XenDesktop Blueprint currently in state: $state Sleeping 2 minutes for $count out of 125"

        sleep 119
      } elseif ($state -eq "Running"){
        $exit = 1
      } elseif ($state -match "Error"){
        $exit = 1
      } 
    } until ( $exit -eq 1 -or $count -ge 125)
    write-log -message "XenDesktop is in state $state"
    $XenDesktopResult = "XenDestop App is in state $state"
    if ($state -eq "running"){
      $xdvalidated = 1 
    } else {
      $xdvalidated = 0
    }
  } else {
    $XenDesktopResult = "Only the XenDesktop BP is installed"
  }
  
  $marketplace = REST-Get-Calm-PublishedMarketPlaceItems -datavar $datavar -datagen $datagen
  
  if ($blueprints.entities.count -ge $minbp){
    foreach ($app in $applications.entities){
      if ($app.status.state -eq "error"){
        $countFailedApps++
      }
    }
    $projectcount = ($marketplace.group_results.entity_results[20].data | where {$_.name -eq "project_uuids"}).values.values.count
    if ($countFailedApps -ge 1){
      write-log -message "Broken Calm Apps detected" 
      $calmresult = "Calm is not healthy. $countFailedApps Broken Calm Apps detected"
      $calmvalidated = 0
    } elseif ($marketplace.group_results.entity_results.count -le 30){
      $calmresult = "Calm is not healthy. $($marketplace.group_results.entity_results.count) Marketplace Apps detected"
      $calmvalidated = 0
    } elseif ($projectcount -le 2){
      $calmresult = "Calm is not healthy. $projectcount Marketplace Projects detected"
      $calmvalidated = 0
    } elseif ($datavar.DemoXenDeskT -eq 1 -and $xdvalidated -eq 0){
      $calmresult = "Calm is not healthy. XenDesktop Blueprint failed, $XenDesktopResult"
    } else {
      $calmresult = "Calm is healthy. There are $($applications.entities.count) running apps, $($blueprints.entities.count) imported blueprints and $($marketplace.group_results.entity_results.count) Marketplace items spread over $projectcount Projects, $XenDesktopResult"
      $calmvalidated = 1
    }
  } else {
    $calmresult = "Calm is not healthy. There are only $($blueprints.entities.count) imported blueprints, this should be above $minbp"
    $calmvalidated = 0
  }
  write-log -message $calmresult
  $hosts = REST-Get-PE-Hosts -username "admin" -datavar $datavar
  if ($datavar.InstallEra -ge 1 ){
    write-log -message "Validating ERA" 

    [array]$databases = REST-ERA-GetDatabases -clusername $datavar.peadmin -clpassword $datavar.pepass -eraip $datagen.era1ip
  
    write-log -message "We found $($databases.count) Databases."
  
    [array]$clones = REST-ERA-GetClones -clusername $datavar.peadmin -clpassword $datavar.pepass -eraip $datagen.era1ip

    [array]$databaseservers = REST-ERA-GetDBServers -clusername $datavar.peadmin -clpassword $datavar.pepass -eraip $datagen.era1ip
    if ($hosts.entities.count -ge 3){
      $databaseserversthreshold = 10
    } else {
      $databaseserversthreshold = 9
    }
    if ($datavar.hypervisor -match "Nutanix|AHV" -and $datavar.InstallEra -eq 1 ){
      
      if ($databases.count -ge 6 -and $clones.count -ge 3 -and $databaseservers.count -ge $databaseserversthreshold){
  
        $eraresult = "ERA is healthy. There are $($databaseservers.count) Servers, $($databases.count) Databases and $($clones.count) Clones"
        $eravalidated = 1
  
      } else {
         
        $eraresult = "ERA is not healthy. There are $($databaseservers.count) out of $databaseserversthreshold Servers, $($databases.count) out of 6 Databases and $($clones.count) out of 3 Clones"
        $eravalidated = 0
  
      }
      write-log -message $eraresult   
    } elseif ($datavar.hypervisor -match "Nutanix|AHV" -and $datavar.InstallEra -eq 2 ) {
       if ($databases.count -ge 3 -and $clones.count -ge 2 -and $databaseservers.count -ge 5){
  
         $eraresult = "ERA is healthy. There are $($databaseservers.count) Servers, $($databases.count) Databases and $($clones.count) Clones"
         $eravalidated = 1
  
       } else {
         
         $eraresult = "ERA is not healthy. There are $($databaseservers.count) out of 5 Servers, $($databases.count) out of 4 Databases and $($clones.count) out of 2 Clones"
         $eravalidated = 0
  
      }
    } elseif ($datavar.hypervisor -match "ESX|VMware") {
       if ($databases.count -ge 4 -and $clones.count -ge 2 -and $databaseservers.count -ge 5){
  
         $eraresult = "ERA is healthy. There are $($databaseservers.count) Servers, $($databases.count) Databases and $($clones.count) Clones"
         $eravalidated = 1
  
       } else {
         
         $eraresult = "ERA is not healthy. There are $($databaseservers.count) out of 5 Servers, $($databases.count) out of 4 Databases and $($clones.count) out of 2 Clones"
         $eravalidated = 0
  
      }
    }

  } else {
    $eravalidated = 1
    $eraresult = "ERA was not selected for install"
  }

  write-log -message "Validating NGT"



  if ($datavar.InstallFiles -ge 1){

    write-log -message "Validating Files"
    
    $VFILERS = REST-Query-FileServer -datavar $datavar -datagen $datagen



    $FSUsedGB = (($VFILERS.entities.usagestats.fs_used_space_bytes /1024) /1024) /1024
    $fsusedround = [math]::Round($FSUsedGB)
    $shares = REST-PE-GetShares -datavar $datavar -datagen $datagen
    $ana  = REST-Get-AnalyticsServer -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount

    if ($shares.entities.count -ge 3 -and $ana.uuid -and $fsusedround -ge 7){
  
      $Filesresult = "Files is healthy, $fsusedround GB of content and pumping. There are $($shares.entities.count) out of 3 Shares, Analytics is Installed, version $($ana.version)"
      $Filesvalidated = 1
  
    } elseif ($fsusedround -le 7) {
  
      $Filesresult = "Files Content script did not run, there is only $($VFILERS.entities.usagestats.fs_used_space_bytes) Bytes / $fsusedround GB of content"
      $Filesvalidated = 0     

    } elseif (!$ana.uuid) {
  
      $Filesresult = "Analytics server is not installed. Files has $($shares.entities.count) out of 3 Shares"
      $Filesvalidated = 0     

    } else {
  
      $Filesresult = "Files is not healthy. There are $($shares.entities.count) out of 3 Shares"
      $Filesvalidated = 0
  
    }
    write-log -message $Filesresult
  } else {

    $Filesresult = "Files Was not selected for install"
    $Filesvalidated = 1  

  }
  if ($datavar.InstallKarbon){
    write-log -message "Validating Karbon"
  
    $token = REST-Karbon-Login -datagen $datagen -datavar $datavar
    $clusters = REST-Karbon-Get-Clusters -datagen $datagen -datavar $datavar -token $token

    $Classes = REST-Karbon-List-StorageCloss -datagen $datagen -datavar $datavar -cluster $clusters -token $token

    if ($datavar.installfiles -eq 1){
      $Minclasses = 2
    } else {
      $Minclasses = 1
    }
    
    if ($clusters.task_progress_percent  -eq 100 -and $clusters.task_status -eq 3 -and $Classes.entities.count -ge $Minclasses ){

      $Karbonresult = "Karbon is healthy. $($clusters.task_progress_message), and there are $($Classes.entities.count) Storage Classes"
      $Karbonvalidated = 1
       
    } elseif ($clusters.task_progress_percent  -eq 100 -and $clusters.task_status -eq 3 ) {

      $Karbonresult = "Karbon is healthy. $($clusters.task_progress_message), but there is only $($Classes.entities.count) Storage Class"
      $Karbonvalidated = 0 
  
    } else {
  
      $Karbonresult = "Karbon is not healthy. $($clusters.task_progress_message)"
      $Karbonvalidated = 0
  
    }
  } else {
    if ($datavar.hypervisor -match "ESX|VMware"){
      $Karbonresult = "Karbon is not supported on VMware"
    } else {
      $Karbonresult = "Karbon was not selected for install"    
    }
    $Karbonvalidated = 1 
  }

  $date =get-date
  Write-log -message "Creating Validation Entry."

  $vms = REST-Get-VMs -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount
  if ($datavar.InstallMove -eq 1){
    $move = $vms.entities | where {$_.vmname -eq $datagen.Move_VMName}
    $token = REST-Move-Login -datagen $datagen -datavar $datavar -mode "Second"
    $target = REST-Move-GetProvider -datagen $datagen -datavar $datavar -token $token
    if ($target.entities.metadata.uuid -match "[0-9]"){
      $movevalidated = 1
      $moveresult = "Move is present, target is configured."
    } elseif ($move) {
      $movevalidated = 0
      $moveresult = "Move is present, but no targets or cannot login."
    } else {
      $movevalidated = 0
      $moveresult = "Move is not present but enabled."      
    }
  } else {
    $movevalidated = 1
    $moveresult = "Move is not enabled"
  }
  if ($datavar.InstallXRay -eq 1){
    $xray = $vms.entities | where {$_.vmname -eq $datagen.XRay_VMName}
    if ($xray){
      $Xrayvalidated = 1
      $Xrayresult = "Xray is present"
    } else {
      $Xrayvalidated = 0
      $Xrayresult = "Xray is not present but enabled"      
    }
  } else {
    $Xrayvalidated = 1
    $Xrayresult = "Xray is not enabled"
  }
  try {
    $upnPC = REST-Query-Images -ClusterPC_IP $datagen.PCClusterIP -clusername $datagen.SEUPN -clpassword $datavar.pepass
    $UPNPCValidated = 1
    $UPNPCresult = "UPN PC Query successful"
  } catch {
    $UPNPCValidated = 0
    $UPNPCresult = "Prism Central UPN Login failed"
  }
  try {
    $upnPE = REST-Query-Images -ClusterPC_IP $datavar.PEClusterIP -clusername $datagen.SEUPN -clpassword $datavar.pepass
    $UPNPEValidated = 1
    $UPNPEresult = "UPN PE Query successful"
  } catch {
    $UPNPEValidated = 0
    $UPNPEresult = "Prism Element UPN Login failed"
  }
  if ($datavar.installSplunk -eq 1){
    $privatekeyresult =  ($applications.entities | where {$_.status.name -eq "Splunk Instance"}).status.state
    if ($privatekeyresult -eq "error"){
      $privatekeyvalidated = 0
      $privatekeyresult = "Private / Public Key pair error, Spunk cannot be deployed, please use password based deploymentys for this build, physical access to Maria and PostGres mostlikely fail, root cause is unknown."
    } elseif (!($applications.entities | where {$_.status.name -eq "Splunk Instance"}))  {
      $privatekeyvalidated = 0
      $privatekeyresult = "Splunk Import Error, there is no Splunk App Instance running.."

    } else {
      $privatekeyvalidated = 1
      $privatekeyresult = "Private / Public Key Working as expected. Splunk instance is running fine."
    }
  } else {

    $privatekeyvalidated = 1
    $privatekeyresult = "Private / Public cannot be tested if Splunk is not installed."

  }

  if ($datavar.InstallObjects -eq 1 ){
    $result = REST-Query-Objects-Store -datagen $datagen -datavar $datavar
    $ADmatch = ((REST-Get-Objects-AD -datagen $datagen -datavar $datavar).entities).metadata.kind -eq "directory_service"
    [int]$adcount = ((REST-Get-Objects-AD -datagen $datagen -datavar $datavar).entities).count
    [int]$percentage = ($result.group_results.Entity_results.data | where {$_.name -eq "Percentage_complete"}).values.values
    $State = ($result.group_results.Entity_results.data | where {$_.name -eq "State"}).values.values
    [int]$bucketcount = (($result.group_results.Entity_results.data | where {$_.name -eq "num_buckets"}).values.values).tostring()
    if ($bucketcount -le 20){
      $buckcounter = 0
      do {
        $buckcounter++
        sleep 60
        $result = REST-Query-Objects-Store -datagen $datagen -datavar $datavar
        [int]$bucketcount = (($result.group_results.Entity_results.data | where {$_.name -eq "num_buckets"}).values.values).tostring()
      } until ( $bucketcount -ge 20 -or $buckcounter -ge 5)
    }
    if ($percentage -ge 99 -and $bucketcount -ge 20 -and $ADmatch){
      $ObjectsValidated = 1
      $Objectsresult = "Objects OK: There are $bucketcount Buckets, state is $state at $percentage % and there is $adcount Directory configured"
    } else {
      $ObjectsValidated = 0
      $Objectsresult = "Objects Warning: There are $bucketcount Buckets, state is $state at $percentage % and there are $adcount Directories configured"
    }
  } else {
    $ObjectsValidated = 1
    $Objectsresult = "Objects was disabled on this build."    
  }

  if ($datavar.DemoIISXPlay -eq 1){
    $playbookx = REST-XPlay-Query-PlayBooks -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.PEPass -clusername $datagen.buildaccount
    if ($playbookx.entities.count -ge 6){
      $XplayValidated = 1
      $Xplayresult = "There are $($playbookx.entities.count) Playbooks, 5 are default."
    } else {
      $XplayValidated = 0
      $Xplayresult = "There are $($playbookx.entities.count) Playbooks, 5 are default (pre 5.11)."
    }
  } else {
    $XplayValidated = 1
    $Xplayresult = "XPlay was disabled on this build."    
  }
  if ($datavar.hypervisor -match "AHV|Nutanix"){
    $ngt = PSR-Validate-NGT -datavar $datavar -datagen $datagen -ip $datagen.DC1IP
  
    if ($ngt){
  
      $NGTvalidated = 1
      $NGTResult = "NGT CLI Is present, NGT is installed."
  
      write-log -message "NGT CLI Is present, NGT is installed."
  
    } else {
      sleep 60
      $ngt = PSR-Validate-NGT -datavar $datavar -datagen $datagen -ip $datagen.DC1IP
  
      if ($ngt){
  
        $NGTvalidated = 1
        $NGTResult = "NGT CLI Is present, NGT is installed."
  
         write-log -message "NGT CLI Is present, NGT is installed."
  
      } else {
        $NGTvalidated = 0
        $NGTResult = "NGT CLI Is not present? $ngt"
  
        write-log -message "NGT CLI Is present, NGT is installed."   
      }
    }
  } else {
    $NGTvalidated = 1
    $NGTResult = "VMware Tools is Installed"  
  }
  if ($datavar.hypervisor -notmatch "ESX|VMware") {
    $flow = REST-Enable-Flow -datavar $datavar -datagen $datagen -mode "SCAN"
  } 
  if ($flow.result -eq "Success" -and $datavar.enableflow -eq 1){

    $Flowvalidated = 1
    $FlowResult = "Flow Status Is Enabled"

    write-log -message "Flow Status Is Enabled"

  } elseif ($datavar.enableflow -eq 0) {

    if ($datavar.hypervisor -match "ESX|VMware"){
      $FlowResult = "Flow Is not supported on VMware"
    } else {
      $FlowResult = "Flow is not enabled in this build"
    }
    $Flowvalidated = 1

  } else {

    $Flowvalidated = 0
    $FlowResult = "Flow is requested but status is not enabled"

    write-log -message "Flow is requested but status is not enabled"
  
  }

  if ($Xrayvalidated -ne 1 -or $movevalidated -ne 1 -or $UPNPEValidated -ne 1 -or $UPNPCValidated -ne 1 -or $XplayValidated -ne 1 -or $privatekeyvalidated -ne 1 -or $NGTvalidated -ne 1 -or $Flowvalidated -ne 1){
    $Corevalidated = 0
  } else {
    $Corevalidated = 1
  }
  $Coreresult = $Xrayresult + "|" + $moveresult + "|" + $UPNPEresult + "|" + $UPNPCresult + "|" + $Xplayresult + "|" + $privatekeyresult + "|" + $NGTResult + "|" + $FlowResult
  $SQLQuery = "USE `"$SQLDatabase`"
    INSERT INTO dbo.$SQLDataValidationTableName (QueueUUID, DateCreated, ERA_Validated, ERA_Result, Calm_Validated, Calm_Result, Karbon_Validated, Karbon_Result, Core_Validated, Core_Result, Files_Validated, Files_Result, Objects_Validated, Objects_Result)
    VALUES('$($datavar.QueueUUID)','$date','$eravalidated','$eraresult','$calmvalidated','$calmresult','$Karbonvalidated','$Karbonresult','$Corevalidated','$Coreresult','$Filesvalidated','$Filesresult','$Objectsvalidated','$Objectsresult')"



  $token = get-content "$($basedir)\SlackToken.txt"
  if ($token -and $portable -ne 1){  
    
    Write-log -message "Sending Last Slack Message"
    
    $User = (Invoke-RestMethod -Uri https://slack.com/api/users.lookupByEmail -Body @{token="$Token"; email="$($datavar.SenderEmail)"}).user
    if ($user){
      $message = @"
*1 Click Demo Provisioning Validated for $($datavar.pocname)*\n
Useful Links:\n
Prism Element: <https://$($datavar.peclusterip):9440 \n
Prism Central: https://$($datagen.pcclusterip):9440 \n
Calm: https://$($datagen.pcclusterip):9440/console/#page/explore/calm \n
"@
        if ($datavar.InstallEra -ge 1){
          $message += "ERA https://$($datagen.ERA1IP) \n";
        } 
        if ($datavar.InstallKarbon -eq 1){  
          $message += "Karbon https://$($datagen.pcclusterip):7050 \n";
        }
        if ($datavar.InstallMove -eq 1){  
          $message += "Move http://$($datagen.MoveIP) \n";
        }
        if ($datavar.InstallXRay -eq 1){  
          $message += "XRay http://$($datagen.XRayIP) \n";
        }
        if ($datavar.InstallFiles -eq 1){
          $message += "Files & Analytics https://$($datavar.peclusterip):9440/console/#page/file_server  \n"
        } 
        if ($datavar.InstallObjects -eq 1){
          $message += "Objects https://$($datagen.pcclusterip):9440/console/#page/explore/ebrowser/objectstores/?entity_type=objectstore  \n"
        } 
        if ($datavar.hypervisor -match "VMware|ESX"){
          $message += "VCenter https://$($datavar.vcenterip)  \n"
        } 
        $message += "\n";
        $message += "Confluence Demo Instructions https://confluence.eng.nutanix.com:8443/display/SEW/2+-+Demo+Instructions  \n"
        $message +=  "\n";


    $item      = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 100 * FROM [$($SQLDatabase)].[dbo].$($SQLDataStatsTableName) WHERE QueueUUID='$QueueUUID'";

$text = @"
AOS Version:       $($item.AOSVersion)
PCVersion:           $($item.pcversion)
AHVVersion:        $($item.AHVVersion)
ObjectsVersion:   $($item.ObjectsVersion)
CalmVersion:        $($item.CalmVersion)
KarbonVersion:   $($item.KarbonVersion)
FilesVersion:        $($item.FilesVersion)
AnalyticsVersion:  $($item.FilesVersion)
NCCVersion:       $($item.NCCVersion)
ERAVersion:        $($item.ERAVersion)
XRayVersion:       $($item.XRayVersion)
MoveVersion:      $($item.MoveVersion)
"@

$Stats = @"
BuildTime:           $($item.BuildTime)
Debug:                    $($item.Debug)
VMs Deployed:     $($item.VMsDeployed)
GB Storage Used: $($item.GBsDeployed)
GB RAM Used:      $($item.GBsRAMUsed)
Chapters Done:     $($item.TotalChapters)
ThreadCount:         $($item.ThreadCount)
Errors:                    $($item.errorcount)
Warnings:              $($item.warningcount)
PS Errors:              $($item.pserrorcount)
Era Failures:          $($item.ERAFailureCount)
PC Failures:          $($item.PCInstallFailureCount)
"@ 


$ValidationText = @"
$Xplayresult
$privatekeyresult
$Xrayresult
$moveresult
$UPNPEresult
$UPNPCresult
$FlowResult
$eraresult
$calmresult
$Karbonresult
$Filesresult
$NGTResult
$Objectsresult
"@

$message += $text+ "\n"
$message += $stats + "\n"
$message += $ValidationText+ "\n"

    
        $message += "\n*Enjoy*"


      

      Slack-Send-DirectMessage -message $message -user $user.id -token $token
     
      
    }
  } 

  

  write-host $SQLQuery

  $SQLQueryOutput = Invoke-Sqlcmd -query $SQLQuery -ServerInstance $SQLInstance

  write-log -message "Validator Finished." -sev "Chapter" -slacklevel 1
}




