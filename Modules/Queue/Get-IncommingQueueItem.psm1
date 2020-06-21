Function Get-IncommingueueItem{
  param (
    [string] $mode
  )
  ## Version 3.0 Only Params are SQL, but are global
  $item = $null
  write-log -message "Terminating leftover outlook."

  get-process outlook -ea:0 | stop-process -ea:0

  write-log -message "Applying Outlook Settings."

  regedit /s "$($basedir)\Binaries\Outlook.reg"

  write-log -message "Starting outlook."

  Add-type -assembly "Microsoft.Office.Interop.Outlook" | out-null 
  $olFolders = "Microsoft.Office.Interop.Outlook.olDefaultFolders" -as [type]

  write-log -message "Assemblies set, starting COM." 

  $outlook = new-object -comobject outlook.application 
  $namespace = $outlook.GetNameSpace("MAPI") 

  write-log -message "COMS started, locating folders."

  $folders = $namespace.Folders | where {$_.folderpath -match "michell" -and $_.folderpath -notmatch "Openbare" }
  if ($env:computername -match "Dev"){
    $folder = $folders.folders | where {$_.FolderPath -eq "\\michell.grauwmans@nutanix.com\FoundationDev"}
    write-log -message "Using Dev Folder"
  } else {
    $folder = $folders.folders | where {$_.FolderPath -eq "\\michell.grauwmans@nutanix.com\Foundation"}
    write-log -message "Using Prod Folder"
  }
  

  write-log -message "Mailbox loaded checking items."

  $item = $folder.items | select -last 1
  if ($item){

    write-log -message "We found 1 item to process."
    $destroy = 0
    $DemoLab = 1
    $EnableFlow = 1
    $DemoXen = 1
    $InstallEra = 1
    $DemoExchange = 1
    $InstallKarbon = 1
    $DemoIISXPlay = 1
    $InstallFiles = 1
    $InstallSplunk = 1
    $backup = 1
    $xray = 1
    $UpdateAOS = 0
    $InstallHashiVault = 1
    $Install1CD = 1
    $slackbot = 0
    $frame = 1
    $objects = 1
    $SSP = 1
    $Move = 1
    $debug = 1
    $pcm = 3
    $bpp = 1
    $Body = $item.body
    $Body = $Body -split "\n"
    $Sender = $item.SENDERname
    $email = $item.SenderEmailAddress
    if ($email -match "="){
      $email = ($item.sender.GetExchangeUser()).primarysmtpaddress
    }
    $separator = @(': ')
    $PECreds = ($Body | where {$_ -match "(^||`t)Prism UI Credentials"}).replace('Prism UI Credentials: ', '') 
    $PEAdmin = $PECreds.split("/",2)[0] -replace ("`t",'')
    $PEPass  = $PECreds.split("/",2)[1] -replace ("`r",'') -replace ("`t",'')
    $CVM1 = ($Body | where {$_ -match ".*Position: . CVM IP: (.*) Hypervisor IP"})[0] -replace ".*Position: . CVM IP: (.*) Hypervisor IP.*", '$1'
    $CVM2 = ($Body | where {$_ -match ".*Position: . CVM IP: (.*) Hypervisor IP"})[1] -replace ".*Position: . CVM IP: (.*) Hypervisor IP.*", '$1'
    $CVM3 = ($Body | where {$_ -match ".*Position: . CVM IP: (.*) Hypervisor IP"})[2] -replace ".*Position: . CVM IP: (.*) Hypervisor IP.*", '$1'
    $CVM4 = ($Body | where {$_ -match ".*Position: . CVM IP: (.*) Hypervisor IP"})[3] -replace ".*Position: . CVM IP: (.*) Hypervisor IP.*", '$1'
    if ($cvm4 -match "1"){
      $cvms = "$($CVM1),$($CVM2),$($CVM3),$($CVM4)"
    } else {
      $cvms = "$($CVM1),$($CVM2),$($CVM3)"
    }
    $VPNUser = ($Body | where {$_ -match ".*VPN User Accounts: (.*),"}) -replace ".*VPN User Accounts: (.*),.*", '$1'
    $VPNPass = ($Body | where {$_ -match ".*VPN User Password: (.*)`r|`n"}) -replace ".*VPN User Password: (.*)`r|`n", '$1'
    $VPNURL = ((($Body | where {$_ -match "(^||`t)Server URL: (.*)`r|`n"}) -replace ".*Server URL: (.*)`r|`n", '$1') -split (" "))[0]
    $VCenterCreds = ($Body | where {$_ -match "(^||`t)vCenter Credentials"}).replace('vCenter Credentials: ', '')    
    $VCenterUser = "administrator@vsphere.local"
    $VCenterPass  = $VCenterCreds.split("/",2)[1] -replace ("`r",'') -replace ("`t",'') -replace ("^ ", '') 
    $VCenterIP = ((($Body | where {$_ -match "(^||`t)vCenter IP: (.*)`r|`n"}) -replace ".*vCenter IP: (.*)`r|`n", '$1') -split (" "))[0]
    $InfraSubnet = ($Body | where {$_ -match "(^||`t)Subnet Mask:"}).replace('Subnet Mask: ', '') -replace ("`r",'') -replace ("`t",'')
    $InfraGW = ($Body | where {$_ -match "(^||`t)Gateway:"}).replace('Gateway: ', '') -replace ("`r",'') -replace ("`t",'') | select -first 1
    $DnsSRV = ($Body | where {$_ -match "(^||`t)Nameserver IP"}).replace('Nameserver IP: ', '') -replace ("`r",'') -replace ("`t",'')
    $nw1vlan = 0 
    $nw2vl = ($Body | where {$_ -match "(^||`t)Secondary VLAN"}).replace('Secondary VLAN: ', '') -replace ("`r",'') -replace ("`t",'')
    $nw2subnet =  ($Body | where {$_ -match "(^||`t)Secondary Subnet"}).replace('Secondary Subnet: ', '') -replace ("`r",'') -replace ("`t",'')
    $nw2gw = ($Body | where {$_ -match "(^||`t)Secondary Gateway"}).replace('Secondary Gateway: ', '') -replace ("`r",'') -replace ("`t",'')
    $nw2dhcp =  ($Body | where {$_ -match "(^||`t)Secondary IP Range"}).replace('Secondary IP Range: ', '') -replace ("`r",'') -replace ("`t",'')
    $nw2dhcpst = ($nw2dhcp -split ("-"))[0]
    if ($body -match "cluster (RTP|PHX|BLR)-"){
      $POCname = ($Body | where {$_ -match "(^||`t)Your Reservation Information for"}) -replace ('.*Your Reservation Information for.*(PHX|RTP|BLR)-(.*)\s\(.*', '$1-$2')
      if ($POCname -MATCH "SPOC"){
        $POCname = $POCname -replace "PHX-", ''
      }
    } else {
      $POCname = (($Body | where {$_ -match "(^|`t)Your Reservation Information for"}) -replace('.*Your Reservation Information for.*POC', 'POC')) -replace (" \(.*",'')
    }
    $Model = (($Body | where {$_ -match "(^||`t)Your Reservation Information for"}) -replace ('.*Your Reservation Information for.*\((.*)\).*', '$1')) 
    [string]$PEClusterIP = ($Body | where {$_ -match "(^||`t)Cluster IP: https"}).split("/")[2].split(":")[0];
    [int]$debug = 0;

    $Params = $body | select -first 25
    foreach ($line in $params){
      if ($line -match "^pcsidebin:[0-9]"){
        $pcsidebin = $line -replace("^pcsidebin:(.*)", '$1')
      }
      if ($line -match "^senderemail:"){

        write-log -message "Replacing Sender"
        write-log -message "Old Sender is $Sender"
        write-log -message "Old EMail is $email"

        $senderemail = $line -replace("^senderemail:([0-9a-zA-Z@.-]+)", '$1')
        $senderemail = Remove-StringSpecialCharacter -string $SenderEMail -SpecialCharacterToKeep '@','.'
        $email = $senderemail
        $Sender = ($email -split "@")[0]
        $Sender = $sender.replace(".", ' ')

        write-log -message "New Sender is $Sender"
        $Senderemailconstruct = $sender.replace(" ", '.')
        $email = $Senderemailconstruct + "@nutanix.com"
        write-log -message "New EMail is ->$($email)<-"

      }
      if ($line -match "^pcsidemeta:[0-9]"){
        $pcsidemeta = $line -replace("^pcsidemeta:(.*)", '$1')
      }
      if ($line -match "^Debug:[0-9]"){
        $debug = $line -replace("^Debug:([0-9]).*", '$1')
      }      
      if ($line -match "^pcmode:[0-9]"){
        $pcm = $line -replace("^pcmode:([0-9]).*", '$1')
      } 
      if ($line -match "^queue:manual"){
        $queue = "manual"
      } 
      if ($line -match "^karbon:[0-9]"){
        $InstallKarbon = $line -replace("^karbon:([0-9]).*", '$1')
      }
      if ($line -match "^era:[0-9]"){
        $InstallEra = $line -replace("^era:([0-9]).*", '$1')
      }
      if ($line -match "^exchange:[0-9]"){
        $DemoExchange = $line -replace("^exchange:([0-9]).*", '$1')
      }
      if ($line -match "^files:[0-9]"){
        $InstallFiles = $line -replace("^files:([0-9]).*", '$1')
      }
      if ($line -match "^flow:[0-9]"){
        $EnableFlow = $line -replace("^flow:([0-9]).*", '$1')
      }
      if ($line -match "^backup:[0-9]"){
        $backup = $line -replace("^backup:([0-9]).*", '$1')
      }
      if ($line -match "^ssp:[0-9]"){
        $SSP = $line -replace("^ssp:([0-9]).*", '$1')
      }
      if ($line -match "^bpp:[0-9]"){
        $bpp = $line -replace("^bpp:([0-9]).*", '$1')
      }
      if ($line -match "^destroy:[0-9]"){
        $destroy = $line -replace("^destroy:([0-9]).*", '$1')
      }
      if ($line -match "^iis:[0-9]"){
        $DemoIISXPlay = $line -replace("^iis:([0-9]).*", '$1')
      }
      if ($line -match "^xd:[0-9]"){
        $DemoXen = $line -replace("^xd:([0-9]).*", '$1')
      }
      if ($line -match "^xray:[0-9]"){
        $xray = $line -replace("^xray:([0-9]).*", '$1')
      }
      if ($line -match "^lab:[0-9]"){
        $DemoLab = $line -replace("^lab:([0-9]).*", '$1')
      }
      if ($line -match "^slackbot:[0-9]"){
        $slackbot = $line -replace("^slackbot:([0-9]).*", '$1')
      }
      if ($line -match "^installframe:[0-9]"){
        $frame = $line -replace("^installframe:([0-9]).*", '$1')
      }
      if ($line -match "^installobjects:[0-9]"){
        $Objects = $line -replace("^installobjects:([0-9]).*", '$1')
      }
      if ($line -match "^move:[0-9]"){
        $move = $line -replace("^move:([0-9]).*", '$1')
      }
      if ($line -match "^Splunk:[0-9]"){
        $InstallSplunk = $line -replace("^Splunk:([0-9]).*", '$1')
        write-log -message "Using Splunk $InstallSplunk"
      }
      if ($line -match "^HcV:[0-9]"){
        $InstallHashiVault = $line -replace("^HcV:([0-9]).*", '$1')
        write-log -message "Using HCV $InstallHashiVault"
      }
      if ($line -match "^1CD:[0-9]"){
        $Install1CD  = $line -replace("^1CD:([0-9]).*", '$1')
        write-log -message "Using 1CD $Install1CD"
      }
      if ($line -match "^3TLamp:[0-9]"){
        $Install3TierLamp  = $line -replace("^3TLamp:([0-9]).*", '$1')
      }
      if ($line -match "^UpdateAOS:[0-9]"){
        $UpdateAOS  = $line -replace("^UpdateAOS:([0-9]).*", '$1')
      }
      if ($line -match "^UpgradeAOS:[0-9]"){
        $UpdateAOS  = $line -replace("^UpgradeAOS:([0-9]).*", '$1')
      }
      if ($line -match "^pcversion:"){
        $PCVersion = $line.split(":")[1];
        $pcversion = $pcversion -replace ("`r",'')
      } elseif (!$pcversion) {
        $PCVersion = "Latest"
      }
      write-log -message "Using PC version $PCVersion"
      if ($line -match "^Email:" -and $line -notmatch "@"){
        [int]$enableEmail = $line -replace("^Email:([0-9]).*", '$1')
      } else {
        $enableEmail = "1"
      }

    }


    $HYPERvISOR = $body | where { $_ -match "Hypervisor Version:"};
    $HYPERvISOR = ($HYPERvISOR -split(": "))[1];
    if ($hypervisor -match "AHV"){;
      $hypervisor = $hypervisor -replace (".*\((.*)\)", 'AHV $1');
      $hypervisor = $hypervisor -replace ("`r",'');
    };
    $aos = $body | where { $_ -match "AOS Version:"};
    $AOSVersion = ($aos -split(": "))[1];
    $AOSVersion = $AOSVersion -replace ("`r",'');
    if ($AOSVersion -eq $null -or $AOSVersion.length -lt 3){;
      $AOSVersion = "GPU Node";
    };

    $nw1vlan = 0
    $Region = "US"
    $Ver = "AOS"
    $datecre = get-date;
    $queueUuid = [guid]::newguid();
    
    if ($queue -eq "Manual"){
      $qstatus = "Manual"
    } else {
      $qstatus = "Ready"
    }
    if ($mode -ne "scan"){
      $SQLQuery = "USE `"$SQLDatabase`"
      INSERT INTO dbo.$SQLQueueTableName (QueueUUID, QUEUEStatus, QUEUEValid, QueueSource, DateCreated, PEClusterIP, SenderName, SenderEMail, PEAdmin, PEPass, debug, AOSVersion, PCVersion, Hypervisor, InfraSubnetmask, CVMIPs, InfraGateway, DNSServer, POCname, PCmode, SystemModel, Nw1Vlan, Nw2DHCPStart, Nw2Vlan, Nw2subnet, Nw2gw, Destroy, Location, VersionMethod, VPNUser, VPNPass, VPNURL, SetupSSP, DemoLab, EnableFlow, DemoXenDeskT, EnableBlueprintBackup, InstallEra, InstallFrame, InstallMove, InstallXRay, InstallObjects, UpdateAOS, DemoExchange, InstallKarbon, DemoIISXPlay, InstallFiles, InstallSplunk, InstallHashiVault, Install1CD, Slackbot, InstallBPPack, Portable, EnableEmail, Install3TierLAMP, VCenterUser, VCenterPass, VCenterIP, pcsidebin, pcsidemeta )
                VALUES('$queueUuid','$qstatus','ToBeValidated','E-Mail','$datecre','$PEClusterIP','$Sender','$email','$PEAdmin','$PEPass','$debug','$AOSVersion','$PCVersion','$Hypervisor','$InfraSubnet','$cvms','$InfraGW','$DnsSRV','$POCname','$PCM','$model','$nw1vlan','$nw2dhcpst','$nw2vl','$nw2subnet','$nw2gw','$destroy','$Region','$ver','$VPNUser','$VPNPass','$VPNURL','$SSP','$DemoLab','$EnableFlow','$DemoXen','$backup','$InstallEra','$frame','$move','$xray','$objects','$UpdateAOS','$DemoExchange','$installKarbon','$DemoIISXPlay','$InstallFiles','$InstallSplunk','$InstallHashiVault','$Install1CD','$Slackbot','$bpp','0','$enableEmail','$Install3TierLAMP','$VCenterUser','$VCenterPass','$VCenterIP','$pcsidebin','$pcsidemeta')"
      write-host $SQLQuery
      $SQLQueryOutput = Invoke-Sqlcmd -query $SQLQuery -ServerInstance $SQLInstance 

      write-log -message "Creating Queue entry with status $qstatus and ID $queueUuid"
      $item.delete()
      sleep 5
      $outlook.quit()
      $object = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLQueueTableName) WHERE QueueUUID='$queueUuid';"
      return $object
    } else {
      $outlook.quit()
      return $email
    }
  };
};

