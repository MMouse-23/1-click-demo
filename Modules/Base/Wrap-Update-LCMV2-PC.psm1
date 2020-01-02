Function Wrap-Update-LCMV2-PC {
  param (
    [object] $datavar,
    [object] $datagen
  )
  $loops = 0
  do {
    $loops++

    write-log -message "Running LCM Inventory" -sev "Chapter"
    write-log -message "Lets see if there are any updates"

    try {
      $output = PSR-LCM-ListUpdates-PC -datagen $datagen -datavar $datavar -minimalupdates 0
      [array]$updates = $output.availableupdateslist | where {$_.version  -and ($_.class -eq "PC" -or $_.class -eq "PC Service" -or $_.class -eq "MSP") }
    } catch {
      [array]$updates = $null
    }
    if ($updates.count -notin 1..99){
      REST-LCM-Perform-Inventory -datavar $datavar -datagen $datagen -mode "PC"
      sleep 119
      $inventory = Wait-LCM-Task -datagen $datagen -datavar $datavar
      if ($inventory.status -eq "Failed"){
    
        write-log -message "New LCM version new errors LOL" -sev "WARN"
    
        do {
          $inventorycounter ++
          REST-LCM-Perform-Inventory -datavar $datavar -datagen $datagen -mode "PC"
          $inventory = Wait-LCM-Task -datagen $datagen -datavar $datavar
        } until ($inventorycounter -ge 2 -or $inventory.status -eq "succeeded")
      }
      Sleep 119
      write-log -message "Checking Which version we have now."
  
      $output = PSR-LCM-ListUpdates-PC -datagen $datagen -datavar $datavar
      [array]$updates = $output.availableupdateslist | where {$_.version  -and ($_.name -notmatch "AOS|PC") }
    }
    
    write-log -message "We found $($updates.count) update(s)" 
  
    if ($updates.count -ge 1){
      #foreach ($update in $updates){

        write-log -message "Building a LCM update Plan" -slacklevel 1
    
        REST-LCM-BuildPlan -datavar $datavar -datagen $datagen -mode "PC" -updates $updates
        sleep 30
        write-log -message "Installing $($updates.count) PC LCM Update(s)." -sev "Chapter"
      
        $InstallTASKID = (REST-LCM-Install -datavar $datavar -datagen $datagen -mode "PC" -updates $Updates).value
        $installtask = Wait-LCM-Task -datagen $datagen -datavar $datavar -modecounter 45
        
        if ($installtask.status -match "FAILED|ABORTED" -or $installtask.status -eq "Running" ){
          write-log -message "Failed Install Task" -SEV "WARN"
  
          LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "LCMFailed" -logfile $logfile
          PSR-Reboot-PC -datagen $datagen -datavar $datavar
          #we know we are not done yet
  
          [array]$updates += 1
  
        } else {
  
          $output = PSR-LCM-ListUpdates-PC -datagen $datagen -datavar $datavar -minimalupdates 0
          [array]$updates = $output.availableupdateslist | where {$_.version  -and ($_.name -notmatch "AOS|PC") }
        }
      #}
  
    } else {
      
      if ($loops -ge 3){
        write-log -message "Hung LCM Inventory Task" -SEV "WARN"
  
        LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "LCMHung" -logfile $logfile
        PSR-Reboot-PC -datagen $datagen -datavar $datavar
        #we know we are not done yet
        [array]$updates += 1
      
      } else {

        write-log -message "Getting DNS servers";
        
        try{
          [array]$DNS =REST-Get-DNS-Servers -datagen $datagen -datavar $datavar -mode $mode
          
          if ($dns){
    
            write-log -message "We have $($Dns.count) DNS servers to remove";
    
            $hide = REST-Remove-DNS-Servers -datagen $datagen -datavar $datavar -DNSArr $dns -mode $mode
            
          } else {
    
            write-log -message "There are no DNS Servers to Remove";
    
          }
          $DNS =$null
          [array]$DNS += $datagen.DC1IP
          [array]$DNS += $datagen.DC2IP
          $hide = REST-Add-DNS-Servers -datagen $datagen -datavar $datavar -DNSArr $dns -mode $mode   
    
          write-log -message "Checking DNS servers"
              
          REST-Get-DNS-Servers -datagen $datagen -datavar $datavar -mode $mode
    
          write-log -message "DNS Setup Success";

        } catch {
      
          write-log -message "DNS Setup Failure" -sev "WARN"

        }

        write-log -message "Let me try the inventory again!" -SEV "WARN"

        REST-LCM-Perform-Inventory -datavar $datavar -datagen $datagen -mode "PC"
        $inventory = Wait-LCM-Task -datagen $datagen -datavar $datavar
        $output = PSR-LCM-ListUpdates-PC -datagen $datagen -datavar $datavar
        [array]$updates = $output.availableupdateslist | where {$_.version  -and ($_.name -ne "PC") }

      }
    
    }

    ## Last Control
    ## Control below makes sure that the loop exits only when cycle has been completed.
    ## No remediating actions below, just validation

    $Statobjects      = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT * FROM [$($SQLDatabase)].[dbo].$($SQLDataStatsTableName)"
    $Statobjects      = $Statobjects | where {$_.PCVersion -eq $datavar.PCVersion}

    $output = PSR-LCM-ListUpdates-PC -datagen $datagen -datavar $datavar -minimalupdates 0
    $Installedcalmversion = ($output.InstalledSoftwareList | where {$_.Name -match "Calm"}).version
    
    $LastknowncalmVersion = [string]($statobjects.CalmVersion | % {try{[version]$_}catch{} } | sort | select -last 1)

    write-log -message "Last Known Calm Version is: $LastknowncalmVersion"
    write-log -message "Installed Calm Version is: $Installedcalmversion"

    $InstalledKarbonversion = ($output.InstalledSoftwareList | where {$_.Name -match "karbon"}).version
    $LastknownkarbonVersion = [string]($statobjects.KarbonVersion | % {try{[version]$_}catch{} } | sort | select -last 1)

    write-log -message "Last Known Karbon Version is: $LastknownkarbonVersion"
    write-log -message "Installed Karbon Version is: $InstalledKarbonversion"

    $InstalledObjectsversion = ($output.InstalledSoftwareList | where {$_.Name -match "MSP"}).version
    $LastknownObjectsVersion = [string]($statobjects.ObjectsVersion | % {try{[version]$_}catch{} } | sort | select -last 1)

    write-log -message "Last Known Objects Version is: $LastknownObjectsVersion"
    write-log -message "Installed Objects Version is: $InstalledObjectsversion"

    ## IF the task is hung, installed versions are also not reported.
    ## Second loop will catch hung tasks, therefor we cannot exit if versions are not up to datagen
    ## Or we do not exit if current reported version is unreadable, that indicates a hung task.

    if ($datavar.Installkarbon -eq 1 -and $datavar.InstallObjects -eq 1 -and $statobjects){

      if (([version]$Installedkarbonversion -ge [version]$LastknownkarbonVersion) -and ([version]$Installedcalmversion -ge [version]$LastknowncalmVersion) -and ([version]$Installedobjectsversion -ge [version]$LastknownobjectsVersion)){
        $exit = 1

        write-log -message "Both Karbon, Objects and Calm are greater or equal to their last known version."
        write-log -message "That is assumed a success."

       } else {

        write-log -message "Karbon, Objects or Calm Versions are not up to par. Taking a red pill."
        LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "LCMInstallLoop" -logfile $logfile

        $exit = 0

       }

    } elseif ($datavar.Installkarbon -eq 1 -and $statobjects){

      if (([version]$Installedkarbonversion -ge [version]$LastknownkarbonVersion) -and ([version]$Installedcalmversion -ge [version]$LastknowncalmVersion)){
        $exit = 1

        write-log -message "Both Karbon and Calm are greater or equal to their last known version."
        write-log -message "That is assumed a success."

       } else {

        write-log -message "Karbon or Calm Versions are not up to par. Taking a red pill."
        LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "LCMInstallLoop" -logfile $logfile

        $exit = 0

       }

    } elseif ( $statobjects ) {

      if ([version]$Installedcalmversion -ge [version]$LastknowncalmVersion){
        $exit = 1

        write-log -message "Both Calm is greater or equal to its last known version."
        write-log -message "That is assumed a success, which is a risk just on Calm."

      } else {

        write-log -message "Calm Versions are not up to par. Taking a red pill."

        $exit = 0

      }

    } else {

      write-log -message "This version is new, as we do not have stats for this PC Build."
      write-log -message "We cannot compare versions, assuming there are no issues."

      $exit = 1

    }

  } until ($loops -ge 3 -or $exit -eq 1)
  
  if ($updates.count -eq 0){
    LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "CalmSuccess" -logfile $logfile
  } 
  return $output.installedsoftwarelist
}

