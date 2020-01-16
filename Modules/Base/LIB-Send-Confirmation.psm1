Function LIB-Send-Confirmation{
  param(
    [string] $reciever,
    [object] $datavar,
    [object] $datagen,
    $Logfile,
    $validation,
    $stage,
    $mode
  )
  do {
    $failed = $false
    try {
      ## ADD mode BackUpEnd input stats.
      if ($env:computername -match "Dev"){
        $url = "http://1-click-dev.corp.nutanix.com"
      } else {
        $url = "http://1-click-demo.corp.nutanix.com"
      }
      $ip = (Get-NetIPAddress | where {$_.InterfaceAlias -notmatch "Loop|VPN" -aND $_.ipaddress -notmatch "::|^169"} | sort InterfaceIndex | Select -first 1).IPAddress
      
      if ($mode -eq "Start"){
        $emaillevel = 1
        $MailSubject = "1 Click Demo Provisioning Started for $($datavar.pocname)";
        $body += "<h2>1 Click Demo Provisioning Started for $($datavar.pocname)</h2>";
        [array]$slackmessage += (("\n$($datavar.pocname) 1-click-demo build has started"))
      } elseif($mode -eq "FailedVPN" ) {
        $emaillevel = 0
        $MailSubject = "1 Click Demo Provisioning Failed for $($datavar.pocname): VPN Issue";
        $body += "<h2>1 Click Demo Provisioning Failed for $($datavar.pocname)</h2>";
        $body += "<b>No VPN Active</b>"
        [array]$slackmessage += (("\n$($datavar.pocname) 1 Click Demo Provisioning Failed") + "\n")
        [array]$slackmessage += (("\nNo VPN Active"))
      } elseif($mode -eq "UpgradeAOS" ) {
        $emaillevel = 5
        $MailSubject = "1 Click Demo Provisioning AOS Upgrade required";
        $Versions = $stage.split("|")
        $body += "<h2>Upgrading AOS $($Versions[0]) towards  $($Versions[1]) on $($datavar.pocname)</h2>";
        $body += "<b>Please submit above minimal version to avoid delays</b>"
        [array]$slackmessage += (("Upgrading AOS $($Versions[0]) towards  $($Versions[1]) on $($datavar.pocname)") + "\n")
        [array]$slackmessage += (("Please submit above minimal version to avoid delays"))
      } elseif($mode -eq "UpgradeAHV" ) {
        $emaillevel = 5
        $MailSubject = "1 Click Demo Provisioning AHV Upgrade required";
        $Versions = $stage.split("|")
        $body += "<h2>Upgrading AHV $($Versions[0]) towards $($Versions[1]) on $($datavar.pocname)</h2>";
        [array]$slackmessage += (("Upgrading AHV $($Versions[0]) towards $($Versions[1]) on $($datavar.pocname)"))
      } elseif($mode -eq "FailedConnect") {
        $emaillevel = 0
        $MailSubject = "1 Click Demo Provisioning Failed for $($datavar.pocname): PE Cluster Down";
        $body += "<h2>1 Click Demo Provisioning Failed for $($datavar.pocname)</h2>";
        $body += "<b>No connection possible to the PE Cluster please check and try again.</b>"
        [array]$slackmessage += (("$($datavar.pocname) 1 Click Demo Provisioning Failed") + "\n")
        [array]$slackmessage += (("No connection possible to the PE Cluster please check and try again"))
      } elseif($mode -eq "LCMInstallLoop") {
        $emaillevel = 0
        $MailSubject = "LCM Install Loop, More updates are required for $($datavar.pocname)";
        $body += "<h2>LCM Install Loop, More updates are required. for $($datavar.pocname)</h2>";
        $body += "LCM can require several loops to get to the last known version."
        [array]$slackmessage += (("$($datavar.pocname) LCM Install Loop, More updates are required") + "\n")
        [array]$slackmessage += (("LCM can require several loops to get to the last known version."))
      } elseif($mode -eq "LCMFailed") {
        $emaillevel = 0
        $MailSubject = "LCM Failed Task, we are rebooting Prism Central for $($datavar.pocname)";
        $body += "<h2>LCM Failed Task, we are rebooting Prism Central for $($datavar.pocname)</h2>";
        $body += "LCM tasks can fail, Rebooting PC out of precaucion."
        $body += "This causes a 40 minute delay."
        [array]$slackmessage += (("$($datavar.pocname) LCM Hung Task, we are rebooting Prism Central") + "\n")
        [array]$slackmessage += (("LCM tasks sometimes hang, if this occurs a PC reboot is reqruired to resolve the issue."))
      } elseif($mode -eq "LCMHung") {
        $emaillevel = 0
        $MailSubject = "LCM Hung Task, we are rebooting Prism Central for $($datavar.pocname)";
        $body += "<h2>LCM Hung Task, we are rebooting Prism Central for $($datavar.pocname)</h2>";
        $body += "LCM tasks sometimes hang, if this occurs a PC reboot is reqruired to resolve the issue."
        $body += "This causes a 40 minute delay."
        [array]$slackmessage += (("$($datavar.pocname) LCM Hung Task, we are rebooting Prism Central") + "\n")
        [array]$slackmessage += (("LCM tasks sometimes hang, if this occurs a PC reboot is reqruired to resolve the issue."))
      } elseif($mode -eq "FailedStage") {
        $emaillevel = 0
        $MailSubject = "1 Click Demo Provisioning Failed for $($datavar.pocname): VPN Issue";
        $body += "<h2>1 Click Demo Provisioning Failed for $($datavar.pocname)</h2>";
        $body += "<b>System failed on $stage</b>"
      } elseif($mode -eq "FailedAOS") {
        $emaillevel = 0
        $MailSubject = "1 Click Demo Provisioning Failed for $($datavar.pocname): Cannot Login to PE.";
        $body += "<h2>1 Click Demo Provisioning Failed for $($datavar.pocname)</h2>";
        [array]$slackmessage += (("$($datavar.pocname) 1 Click Demo Provisioning Failed") + "\n")
        [array]$slackmessage += (("No login possible to the PE Cluster please check and try again"))
      } elseif($mode -eq "Pending") {
        $emaillevel = 0
        $MailSubject = "1 Click Demo Provisioning is Pending for $($datavar.pocname): Cannot Login to PE yet.";
        $body += "<h2>1 Click Demo Provisioning is Pending for $($datavar.pocname) , max 1440 minutes.</h2>";
        [array]$slackmessage += (("$($datavar.pocname) 1 Click Demo Provisioning is pending") + "\n")
        [array]$slackmessage += (("No login possible to the PE Cluster yet, we are sleeping, max 1440 minutes."))
      } elseif($mode -eq "FailedVC") {
        $emaillevel = 0
        $MailSubject = "1 Click Demo Provisioning Failed for $($datavar.pocname): Cannot Login to VMware VCenter.";
        $body += "<h2>1 Click Demo Provisioning Failed for $($datavar.pocname)</h2>";
        [array]$slackmessage += (("$($datavar.pocname) 1 Click Demo Provisioning Failed") + "\n")
        [array]$slackmessage += (("No login possible to the Virtual Center, HPOC VMWare only, please refoundation block."))
      } elseif($mode -eq "Locked") {
        $emaillevel = 0
        $MailSubject = "1 Click Demo Provisioning Failed for $($datavar.pocname): IP is locked";
        $body += "<h2>1 Click Demo Provisioning Failed for $($datavar.pocname)</h2>";
        $body += "<br>The Prism Element IP address has an active lock file. You cannot run 2 builds on the same active IP.";
        $body += "<br>Please open the <a href=$($URL)>Website to</a> to terminate and clean your active build.<br>";
        [array]$slackmessage += (("$($datavar.pocname) 1 Click Demo Provisioning Failed") + "\n")
        [array]$slackmessage += (("The Prism Element IP address has an active lock file. You cannot run 2 builds on the same active IP."))
      }elseif($mode -eq "FailedHV" ) {
        $emaillevel = 0
        $MailSubject = "1 Click Demo Provisioning Failed for $($datavar.pocname): Only AHV HyperVisor is officialy supported.";
        $body += "<h2>1 Click Demo Provisioning Failed for $($datavar.pocname)</h2>";
        $body += "<b>System failed on unsupported hypervisor.<br>$($datavar.hypervisor) is not officialy supported.</b>"
        if ($datavar.hypervisor -match "VMware|esx"){
          $body += "<b>However operable code is present, please foward the email again with Debug:2 in the body of the email.</b>"
          $body += "<b>Ssst, dont tell anyone and enjoy.</b>" 
        }
        $datadisable = 1
        [array]$slackmessage += (("$($datavar.pocname) 1 Click Demo Provisioning Failed") + "\n")
        [array]$slackmessage += (("No login possible to the Virtual Center, HPOC VMWare only, please refoundation block."))
      } elseif($mode -eq "FailedPC" ) {
        $emaillevel = 0
        $MailSubject = "1 Click Demo Provisioning Failed for $($datavar.pocname): Prism Central is already installed.";
        $body += "<h2>1 Click Demo Provisioning Failed for $($datavar.pocname)</h2>";
        $body += "<b>Please RTFM</b>"
        $body += "<a href=https://confluence.eng.nutanix.com:8443/display/SEW/0+%29+Requirements>Confluence: 1CD Requirements</a><br>";
      } elseif($mode -eq "CalmSuccess" ) {
        $emaillevel = 2
        $MailSubject = "1CD update for $($datavar.pocname) PC LCM Updates were successful";
        $body += "<h2>PC LCM  Updates were successful</h2>";
        [array]$slackmessage += (("\n$($datavar.pocname) LCM Updates are a success") + "\n")
        if ($datavar.hypervisor -match "Nutanix|AHV"){
          $body += "Completion time will ~25 minutes from now";
          [array]$slackmessage += (("1-Click-Demo is expected to finish in 25 minutes"))
        } else {
          $body += "Completion time will ~80 minutes from now";
          [array]$slackmessage += (("1-Click-Demo is expected to finish in ~80 minutes"))          
        }
      } elseif($mode -eq "CalmFailed" ) {
        $emaillevel = 1
        $MailSubject = "1CD delayed for $($datavar.pocname) PC LCM Updates failed.";
        $body += "<h2>1CD delayed for $($datavar.pocname) PC LCM Updates failed.</h2>";
        $body += "The system will retry updates, this will cause a 25 minute delay";
        [array]$slackmessage += (("$($datavar.pocname) PC is facing LCM issues") + "\n")
        [array]$slackmessage += (("Restarting PC to remove hung task"))
      }elseif($mode -eq "BackUpEnd")  {
        $emaillevel = 0
        $MailSubject = "Backup stoppped for $($datavar.pocname) PC is offline for a full hour.";
        $body += "<h2>Backup stoppped for $($datavar.pocname) PC is offline for a full hour.</h2>";
      } elseif($mode -eq "PCSuccess" ){
        $emaillevel = 2
        $MailSubject = "1CD update for $($datavar.pocname) PC was successfully installed";
        $body += "<h2>1CD update for $($datavar.pocname) PC was successfully installed</h2>";
        [array]$slackmessage += (("$($datavar.pocname) PC was successfully installed") + "\n")
        if ($datavar.hypervisor -match "Nutanix|AHV"){
          [array]$slackmessage += (("Completion time will be ~50 minutes from now."))
          $body += "Completion time will be ~50 minutes from now.";
        } else {
          [array]$slackmessage += (("Completion time will be ~120 minutes from now."))
          $body += "Completion time will be ~120 minutes from now.";         
        }
      } elseif($mode -eq "Full"){
        $emaillevel = 1
        $MailSubject = "1CD Server is full atm, the system will retry and keep you posted.";
        $body += "The $($datavar.pocname) request is in pending state."
        $body += "Your build will resume shortly.";
        [array]$slackmessage += (("$($datavar.pocname) is in Pending state, server is full.") + "\n")
        [array]$slackmessage += (("Please wait in line.:)"))
      } elseif($mode -eq "PCFailed"){
        $emaillevel = 1
        $MailSubject = "1CD delayed for $($datavar.pocname) PC Install failed.";
        $body += "<h2>1CD delayed for $($datavar.pocname) PC Install failed.</h2>";
        $body += "The system will retry updates, this will cause a 25-35 minute delay";
        [array]$slackmessage += (("$($datavar.pocname) PC install failed") + "\n")
        [array]$slackmessage += (("This will cause auto upgrades if possible."))
      } elseif($mode -eq "FailedImages") {
        $emaillevel = 0
        $MailSubject = "1CD Failed for $($datavar.pocname): Images not present.";
        $body += "<h2>1 Click Demo Provisioning Failed for $($datavar.pocname)</h2>";
        $body += "<b>Image not present</b>"
      } elseif($mode -eq "FailedAHVNET") {
        $emaillevel = 0
        $MailSubject = "1CD Provisioning Failed for $($datavar.pocname): Cannot create AHV Primary Network.";
        $body += "<h2>1 Click Demo Provisioning Failed for $($datavar.pocname)</h2>";
        $body += "<b>Cannot create AHV Primary Network. Is this a default block?</b>"
        $body += "<b>Specified VLAN needs to be HPOC default or not existing e.g. foundation default.</b>"
      } elseif($mode -eq "FailedUpgrade") {
        $emaillevel = 0
        $MailSubject = "1CD Provisioning Failed for $($datavar.pocname): AOS Prescan Failed";
        $body += "<h2>1CD Provisioning Failed for $($datavar.pocname)</h2>";
        $body += "<b>AOS Upgrade prescan failed after 3 attempts.</b>"
        $body += "Is the DNS server reachable, is there an internet connection?"
        $body += "Is the NTP server reachable?"
      } elseif($mode -eq "AOSFubar") {
        $emaillevel = 0
        $MailSubject = "1CD Provisioning Failed for $($datavar.pocname): Unstable AOS";
        $body += "<h2>1CD Provisioning Failed for $($datavar.pocname)</h2>";
        $body += "<b>AOS is unstable.</b>"
        $body += "Ask the 1CD team for support, or re1CD and restart 1CD"
      } elseif($mode -eq "queued"){
        $emaillevel = 0
        $MailSubject = "1CD Provisioning is queued for $($datavar.pocname)";
        $body += "<h2>1 Click Demo Provisioning is queued for $($datavar.pocname)</h2>";
        $body += "<br>";
        $body += "<b>If queue:manual was specified, please open the <a href=$($URL)>Website</a><br>"
        $body += "<b>This item needs to be manually corrected.</b>"
        $body += "<br>";
        [array]$slackmessage += (("$($datavar.pocname) Build is queued") + "\n")
        [array]$slackmessage += (("Please visit $($URL)"))
      } elseif($mode -eq "QueueError"){
        $emaillevel = 0
        $MailSubject = "1CD Provisioning failed validation for $($datavar.pocname)";
        $body += "<h2>1 Click Demo Provisioning failed validation for $($datavar.pocname)</h2>";
        $body += "<b>This item needs to be manually corrected.</b>"
        $body += "Please open the <a href=$($URL)>Website to</a> to correct the error.<br>"
        $body += "Please read the error below:<br>"
        [array]$slackmessage += (("$($datavar.pocname) Validation Failed") + "\n")
        [array]$slackmessage += (("Please read the error below."))
        foreach ($line in $validation){
          $body += "$line <br>"
          [array]$slackmessage += (("\n$line") + "\n")
        }
      } elseif($mode -eq "SingleUser"){
        $MailSubject = "1CD Single Threaded mode active, request $($datavar.pocname) queued";
        $body += "<h2>1 Click Demo Provisioning is queued for $($datavar.pocname)</h2>";
        $body += "<b>The item will be submitted for auto queue once validated.</b>"
        $body += "<b>There are other provisioning instances running that have locked multithreaded execution.</b>"
        $body += "<b>You will be notified once it starts.</b>"   
      } else {
        $emaillevel = 0
        $MailSubject = "1 Click Demo Provisioning Finished for $($datavar.pocname)";
        $body += "<h2>1 Click Demo Provisioning Finished for $($datavar.pocname)</h2>";
        $body += "<br>";
        $body += "<b>Useful Links:</b>";
        $body += "<br>";
        $body += "<a href=https://$($datavar.peclusterip):9440>Prism Element</a><br>"; 
        $body += "<a href=https://$($datagen.pcclusterip):9440>Prism Central</a><br>";
        $body += "<a href=https://$($datagen.pcclusterip):9440/console/#page/explore/calm>Calm</a><br>";
        [array]$slackmessage += (("\n$($datavar.pocname) 100% Completed") + "\n")
        [array]$slackmessage += (("\nPlease standby for validation in the next 15 minutes.") + "\n")
        if ($datavar.InstallEra -ge 1){
          $body += "<a href=https://$($datagen.ERA1IP)>ERA</a><br>";
        } 
        if ($datavar.InstallKarbon -eq 1){  
          $body += "<a href=https://$($datagen.pcclusterip):7050>Karbon</a><br>";
        }
        if ($datavar.InstallMove -eq 1){  
          $body += "<a href=http://$($datagen.MoveIP)>Move</a><br>";
        }
        if ($datavar.InstallXRay -eq 1){  
          $body += "<a href=http://$($datagen.XRayIP)>XRay</a><br>";
        }
        if ($datavar.InstallFiles -eq 1){
          $body += "<a href=https://$($datavar.peclusterip):9440/console/#page/file_server>Files & Analytics</a><br>";
        } 
        if ($datavar.InstallObjects -eq 1 -and ($ramcap -lt 1 -or ($ramcap -eq 1 -and $datavar.installERA -eq 0))){
          $body += "<a href=https://$($datagen.pcclusterip):9440/console/#page/explore/ebrowser/objectstores/?entity_type=objectstore>Objects</a><br>";
        } 
        $body += "<br>";
        $body += "<a href=https://confluence.eng.nutanix.com:8443/display/SEW/2+-+Demo+Instructions>Confluence Demo Instructions</a><br>";
        $body += "<br>";
        $body += "<b>Enjoy</b>"  
      }
      $MailTo = $reciever;
      $body += "<br>";
      $body += "<b>Variable Data:</B>";
      $body += $datavar | ConvertTo-Html -As List;
      $body += "<br>";
      $body += "<br>";
      if ($mode -notmatch "queue"){
        $body += "<b>Deducted Data:</B>";
        $body += $datagen | ConvertTo-Html -As List;
        $body += "<br>";
      }
      $body += "<br>";
      if ($debug -ge 1 -and $mode -match "end|FailedVPN"){
        $body += "<br>";
        $body += "<br>";
        $body += "Logging:"; 
        foreach ($line in (get-content $logfile)){;
          $body += $line;
          $body += "<br>";
        };
      };
      if ($Portable -eq 1){

      } else {
        $token = get-content "$($basedir)\SlackToken.txt"
        $User = (Invoke-RestMethod -Uri https://slack.com/api/users.lookupByEmail -Body @{token="$Token"; email="$($datavar.SenderEmail)"}).user
      } 
      if (!$user){
        Write-log -message "User not found, disabling slackbot."
        $slackbot = 0
        
      } else {
        try{
         Write-log -message "Sending Slack Message to $($user.id)" 
         Slack-Send-DirectMessage -message $slackmessage -user $user.id -token $token
        } catch {

        } 
      }
      write-log -message "Global Email is $enableemail"
      if ($env:computername -match "Dev"){
        $subject = "1CD-DEV-$($MailSubject)"
      } else {
        $subject = $MailSubject
      }
      if ($reciever -ne $datagen.supportemail -or $enableemail -lt $emaillevel -and $portable -ne 1){
        Send-MailMessage -BodyAsHtml -body $body -to $datagen.supportemail -from $datagen.smtpsender -port $datagen.smtpport -smtpserver $datagen.smtpserver -subject "AdminCopy-$($MailSubject)"
      }   

      if ($enableemail -ge $emaillevel -and $portable -ne 1){
        Send-MailMessage -BodyAsHtml -body $body -to $reciever -from $datagen.smtpsender -port $datagen.smtpport -smtpserver $datagen.smtpserver -subject $subject

        sleep 15
      } 
    } catch {
      $failed -eq $true
    }
  } until ($failed -eq $false)
};
