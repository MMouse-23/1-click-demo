
Function LIB-Config-DetailedDataSet {
  param (
    [object] $datavar,
    [string] $mode = "Base"
  )
  $BuildAccount       = "svc_build"
  $ERAAPIAccount      = "svc_era"
  $MoveAPIAccount     = "svc_move"
  $Nw1name            = "Network-01";
  $Nw2name            = "Network-02";
  $StoragePoolName    = "SP01";
  $ImagesContainerName= "Images";
  $DisksContainerName = "Default";
  $EraContainerName   = "ERA_01";
  $KarbonContainerName= "Karbon_01"
  $DC_ImageName       = "Windows 2016";
  $Frame_WinImage     = "Windows 10_1CD";
  $Frame_CCAISO       = "Frame_CCAISO2_0";
  $Frame_AgentISO     = "Frame_AgentISO2_0";  
  $MoveImageName      = "MoveAuto";
  $oracle1_0Image     = "Oracle_1_0"
  $oracle1_1Image     = "Oracle_1_1"
  $oracle1_2Image     = "Oracle_1_2"
  $oracle1_3Image     = "Oracle_1_3"
  $oracle1_4Image     = "Oracle_1_4"
  $oracle1_5Image     = "Oracle_1_5"
  $oracle1_6Image     = "Oracle_1_6"
  $oracle1_7Image     = "Oracle_1_7"
  $oracle1_8Image     = "Oracle_1_8"
  $oracle1_9Image     = "Oracle_1_9"
  $Mgmt1_VMname       = "MGT1-$($datavar.POCname)";
  $Mgmt1_ImageName    = "Windows 2016";
  $MSSQLImage         = "MSSQL-2016-VM"
  $XRAYImage          = "XRAYAuto"
  $ERA_ImageName      = "ERAAuto";
  $SysprepPassword    = "$($datavar.PEPass)"
  $SENAME             = "$($datavar.Sendername)";
  $SEROLE             = "Systems Engineer";
  $SESlackID          = "Systems Engineer";
  $SEUPN              = (($datavar.SenderEMail -split "@")[0]) + "@" + $datavar.pocname + ".nutanix.local"
  $SECompany          = "Nutanix";
  $EnablePulse        = 0;
  $ObjectsVersion     = "AutoDetect"
  $Filesversion       = "Latest"
  $Analyticsversion   = "Latest"
  $Files1_ImageName   = "AFS3_5_0Basexx"
  $Files2_ImageName   = "AFS2_0_0Anxx"
  $CALMversion        = "AutoDetect"
  $Karbonversion      = "AutoDetect"
  $ERAVersion         = (Import-Csv "$basedir\AutoDownloadURLs\ERA_VM.urlconf" -Delimiter ";").version
  $MoveVersion        = (Import-Csv "$basedir\AutoDownloadURLs\Move.urlconf" -Delimiter ";").version
  $XRayVersion        = (Import-Csv "$basedir\AutoDownloadURLs\XRAY.urlconf" -Delimiter ";").version
  $ntpserver1         = "0.pool.ntp.org"
  $ntpserver2         = "1.pool.ntp.org"
  $ntpserver3         = "2.pool.ntp.org"
  $ntpserver4         = "3.pool.ntp.org"
  $splunkName         = "Splunk-$($datavar.POCname)"
  $splunkImage        = "Centos 8"
  $PCsideloadimage    = "PC511xx"
  $NCCVersion         = "AutoDetect"
  $smtpSender         = "1-click-demo@nutanix.com"
  $smtpport           = "25"
  $smtpServer         = "mxb-002c1b01.gslb.pphosted.com"
  $Supportemail       = "Michell.Grauwmans@nutanix.com"

  [int]$startingIP = $($datavar.PEClusterIP).split(".") | select -last 1;
  [Array]$mask = $($datavar.PEClusterIP).split(".") | select -first 3;
  if ($mode -ne "Backend"){
    $SSHKeys = Lib-Generate-SSHKey -datavar $datavar -basedir $basedir
  }
  
  write-log -message "Deducting IPs";
  write-log -message "Generating names";

  try{
    $hosts = REST-Get-PE-Hosts -datavar $datavar -username "admin"
    $hypervisor = ($hosts.entities | select -first 1).hypervisorFullName
  } catch {
    write-log -message "NONE HPOC"
  }
  if (($hosts.entities.count -ge 2 -and $hypervisor -match "AHV|Nutanix") -or !$hosts){
    $hostcount = $hosts.entities.count
    if ($hostcount -eq $null){
      $hostcount = 4
    }

    write-log -message "Setting IP stack based on AHV Full stack."

    $DataIPoctet         = $startingIP + 1;
    $ERA1IPoctet         = $startingIP + 2;
    $PCCLIPoctet         = $startingIP + 3;
    $FS1IntIPoctetstart  = $startingIP + 4;
    #Range
    $FS1IntIPoctetend    = $startingIP + 7;
    $DC1IPoctet          = $startingIP + 8;
    $DC2IPoctet          = $startingIP + 9;
    #regardless if objects is enabled
    $objectsint1oc       = $startingIP + 10;
    $objectsint2oc       = $startingIP + 11;  
    $objectsext1oc       = $startingIP + 12;
    $objectsext2oc       = $startingIP + 13;  
    $objectsext3oc       = $startingIP + 14;
    $objectsext4oc       = $startingIP + 15;   
    $FS2IPoctet          = $startingIP + 16;
    $KarbonIPOctet       = $startingIP + 17;
    $XRAYIPoctet         = $startingIP + 18;
    $MOVEIPoctet         = $startingIP + 19;
    $OracleIPOctet       = $startingIP + 20;
    $XRAYIPoctet         = $startingIP + 21;
    $MSSQLIPoctet        = $startingIP + 22;
    $FRAMELIPoctet       = $startingIP + 23;
    $mgmtoct             = $startingIP + 24;
    $NLBIPOctet          = $startingIP + 25;
    $FS1extIPoctetstart  = $startingIP + 26;
    #Range
    $FS1extIPoctetend    = $startingIP + 28;
    #3node PC
    if ($datavar.PCmode -eq 3){
      $PCN1IPoctet         = $startingIP + 29;
      $PCN2IPoctet         = $startingIP + 30;
      $PCN3IPoctet         = $startingIP + 31;
      #DHCP is always last
      $DHCPNW1Octetstart   = $startingIP + 32;
    } else {
      #DHCP is always last
      $DHCPNW1Octetstart   = $startingIP + 29;        
    }


  } elseif ($hosts.entities.count -lt 2 ) {
    $hostcount = $hosts.entities.count
    write-log -message "Setting IP stack based on Single Node AHV Full stack."

    $DataIPoctet         = $startingIP + 1;
    $ERA1IPoctet         = $startingIP + 2;
    $PCCLIPoctet         = $startingIP + 3;
    $FS1IntIPoctetstart  = $startingIP + 4;
    #Range
    $FS1IntIPoctetend    = $startingIP + 7;
    $DC1IPoctet          = $startingIP + 8;
    $DC2IPoctet          = $startingIP + 9;
    #regardless if objects is enabled
    $XRAYIPoctet         = $startingIP + 10;
    $FS2IPoctet          = $startingIP + 11;
    $KarbonIPOctet       = $startingIP + 12;
    $MOVEIPoctet         = $startingIP + 13;
    $OracleIPOctet       = $startingIP + 14;
    $XRAYIPoctet         = $startingIP + 15;
    $MSSQLIPoctet        = $startingIP + 16;
    $FRAMELIPoctet       = $startingIP + 17;
    $mgmtoct             = $startingIP + 18;
    $wintemplateoct      = $startingIP + 19;
    $Lintemplateoct      = $startingIP + 20;
    $XPlay2012oct        = $startingIP + 21;
    $NLBIPOctet          = $startingIP + 22;
    $FS1extIPoctetstart  = $startingIP + 23;
    #Range
    $FS1extIPoctetend    = $startingIP + 25;
    #Objects disabled for now.
   #$objectsint1oc       = $startingIP + 26;
   #$objectsint2oc       = $startingIP + 27;  
   #$objectsext1oc       = $startingIP + 28;
   #$objectsext2oc       = $startingIP + ;  
   #$objectsext3oc       = $startingIP + 14;
   #$objectsext4oc       = $startingIP + 15;   
    $DHCPNW1Octetstart   = $startingIP + 26;


  } elseif ( $hypervisor -match "ESX|VMWare"){

    write-log -message "Setting IP stack based on ESX Limited stack."

    $DataIPoctet         = $startingIP + 1;
    $PCCLIPoctet         = $startingIP + 2;
    # nr 3 is Vcenter
    $FS1IntIPoctetstart  = $startingIP + 4;
    #Range
    $FS1IntIPoctetend    = $startingIP + 7;
    $DC1IPoctet          = $startingIP + 8;
    $DC2IPoctet          = $startingIP + 9;
    # 10 is where HPOC starts to play evil
    $ERA1IPoctet         = $startingIP + 16;
    $FS2IPoctet          = $startingIP + 17;
    $XRAYIPoctet         = $startingIP + 18;
    $MOVEIPoctet         = $startingIP + 19;
    $OracleIPOctet       = $startingIP + 20;
    $XRAYIPoctet         = $startingIP + 21;
    $MSSQLIPoctet        = $startingIP + 22;
    $FRAMELIPoctet       = $startingIP + 23;
    $mgmtoct             = $startingIP + 24;
    $wintemplateoct      = $startingIP + 25;
    $Lintemplateoct      = $startingIP + 26;
    $XPlay2012oct        = $startingIP + 27;
    $NLBIPOctet          = $startingIP + 28;
    $FS1extIPoctetstart  = $startingIP + 29;
    #Range
    $FS1extIPoctetend    = $startingIP + 31;
    $objectsint1oc       = $startingIP + 32;
    $objectsint2oc       = $startingIP + 33;  
    $objectsext1oc       = $startingIP + 34;
    $objectsext2oc       = $startingIP + 35;  
    $objectsext3oc       = $startingIP + 36;
    $objectsext4oc       = $startingIP + 37;
    $PCN1IPoctet         = $startingIP + 38;
    $PCN2IPoctet         = $startingIP + 39;
    $PCN3IPoctet         = $startingIP + 40;
    $KarbonIPOctet       = $startingIP + 41;
    $SplunkIPOctet       = $startingIP + 42;
    #DHCP is always last
    $DHCPNW1Octetstart   = $startingIP + 43;

  } else {


  }

  if ($hypervisor -notmatch "Nutanix|AHV|auto"){

  } else {

  }

  
  

  $FS1_IntName = "FS1I-$($datavar.POCname)";
  $FS1_ExtName = "FS1E-$($datavar.POCname)";
  $PC1Name = "PC1-$($datavar.POCname)";
  $PC2Name = "PC2-$($datavar.POCname)";
  $PC3Name = "PC3-$($datavar.POCname)";
  $ERA1Name= "ERA1-$($datavar.POCname)";
  $xrayname= "XRAY1-$($datavar.POCname)";
  $MoveName= "Move1-$($datavar.POCname)";
  $MSSQL1  = "MSSQL1-$($datavar.POCname)";
  $SRVMaria= "Maria1-$($datavar.POCname)";
  $Frame_GoldenVMName = "Frame1-$($datavar.POCname)";
  $SRVMYSql= "MySQL1-$($datavar.POCname)";
  $SRVOracl= "Oracle1-$($datavar.POCname)";
  $PostGres= "PostG1-$($datavar.POCname)";
  $DC1Name = "DC1-$($datavar.POCname)";
  $DC2Name = "DC2-$($datavar.POCname)";
  $Domainname = "$($datavar.POCname).nutanix.local";
  $Files2VM_Name      = "FSAnalitics-$($datavar.POCname)";
  [string]$DataIP     = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $DataIPoctet
  [string]$PCCLIP     = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $PCCLIPoctet
  [string]$PCN1IP     = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $PCN1IPoctet
  [string]$PCN2IP     = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $PCN2IPoctet
  [string]$PCN3IP     = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $PCN3IPoctet
  [string]$ERA1IP     = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $ERA1IPoctet
  [string]$moveIP     = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $MOVEIPoctet
  [string]$MSSQLIP    = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $MSSQLIPoctet
  [string]$OracleIP   = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $OracleIPOctet
  [string]$DC1IP      = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $DC1IPoctet
  [string]$DC2IP      = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $DC2IPoctet
  [string]$FS1IntIPst = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $FS1IntIPoctetstart
  [string]$FS1IntIPend= $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $FS1IntIPoctetend
  [string]$FS1ExtIPst = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $FS1extIPoctetstart
  [string]$FS1ExtIPend= $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $FS1extIPoctetend
  [string]$KarbonIP   = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $KarbonIPOctet 
  [string]$NW1DHCPStar= $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $DHCPNW1Octetstart
  [string]$IISNLBIP   = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $NLBIPOctet
  [string]$XRAYIP     = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $XRAYIPoctet
  [string]$Files2IP   = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $FS2IPoctet
  [string]$FrameGVMIP = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $FRAMELIPoctet
  [string]$objectsint1= $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $objectsint1oc
  [string]$objectsint2= $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $objectsint2oc
  [string]$objectsext1= $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $objectsext1oc
  [string]$objectsext2= $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $objectsext2oc
  [string]$objectsext3= $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $objectsext3oc
  [string]$objectsext4= $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $objectsext4oc
  [string]$Wintemplip = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $wintemplateoct
  [string]$Lintemplip = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $Lintemplateoct
  [string]$XPlay2012ip= $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $XPlay2012oct
  [string]$SplunkIP   = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $SplunkIPOctet
  [string]$Mgmt1_VMIP = $mask[0] + '.' + $mask[1] + '.' + $mask[2] + '.' + $mgmtoct
  $objectsIntRange = "$($objectsint1)|$($objectsint2)" #YES NO COMMA
  $objectsExtRange = "$($objectsext1)" + '"' + ', ' + '"' + "$($objectsext2)" + '"' + ', ' + '"' + "$($objectsext3)" + '"' + ', ' + '"' + "$($objectsext4)"
  $FS1IntRange  = "$FS1IntIPst $FS1IntIPend";
  $FS1ExtRange  = "$FS1ExtIPst $FS1ExtIPend";
  $Object = New-Object PSObject;
  $Object | add-member Noteproperty DataServicesIP      $DataIP;
  $Object | add-member Noteproperty HostCount           $HostCount;
  $Object | add-member Noteproperty BuildAccount        $BuildAccount    
  $Object | add-member Noteproperty ERAAPIAccount       $ERAAPIAccount   
  $Object | add-member Noteproperty MoveAPIAccount      $MoveAPIAccount  
  $Object | add-member Noteproperty PCClusterIP         $PCCLIP;
  $Object | add-member Noteproperty PCNode1IP           $PCN1IP;
  $Object | add-member Noteproperty PCnode2IP           $PCN2IP;
  $Object | add-member Noteproperty PCnode3IP           $PCN3IP;
  $Object | add-member Noteproperty PCNode1Name         $PC1Name;
  $Object | add-member Noteproperty PCNode2Name         $PC2Name;
  $Object | add-member Noteproperty PCNode3Name         $PC3Name;
  $Object | add-member Noteproperty ERA1Name            $ERA1Name;
  $Object | add-member Noteproperty ERA1IP              $ERA1IP;
  $Object | add-member Noteproperty DC1IP               $DC1IP;
  $Object | add-member Noteproperty DC2IP               $DC2IP;
  $Object | add-member Noteproperty DC1Name				      $DC1Name;
  $Object | add-member Noteproperty DC2Name				      $DC2Name;   
  $Object | add-member Noteproperty Domainname			    $Domainname;   
  $Object | add-member Noteproperty Nw1name             $Nw1name;
  $Object | add-member Noteproperty Nw2name             $Nw2name;
  $Object | add-member Noteproperty MoveIP              $moveIP;
  $Object | add-member Noteproperty Move_ImageName      $MoveImageName;
  $Object | add-member Noteproperty Move_VMName         $MoveName  
  $Object | add-member Noteproperty XRay_IP             $XRAYIP;
  $Object | add-member Noteproperty XRAY_Image          $XRAYImage;
  $Object | add-member Noteproperty XRAY_VMName         $xrayname;
  $Object | add-member Noteproperty DC_ImageName        $DC_ImageName;
  $Object | add-member Noteproperty ERA_ImageName       $ERA_ImageName;
  $Object | add-member Noteproperty ERA_MSSQLIP         $MSSQLIP;
  $Object | add-member Noteproperty ERA_MSSQLName       $MSSQL1;
  $Object | add-member Noteproperty ERA_MSSQLImage      $MSSQLImage;    
  $Object | add-member Noteproperty ERA_MariaName       $SRVMaria;
  $Object | add-member Noteproperty ERA_PostGName       $PostGres;
  $Object | add-member Noteproperty ERA_MySQLName       $SRVMYSql;
  $Object | add-member Noteproperty EraContainerName    $EraContainerName;
  $Object | add-member Noteproperty Oracle1_0Image      $oracle1_0Image  
  $Object | add-member Noteproperty Oracle1_1Image      $oracle1_1Image  
  $Object | add-member Noteproperty Oracle1_2Image      $oracle1_2Image 
  $Object | add-member Noteproperty Oracle1_3Image      $oracle1_3Image  
  $Object | add-member Noteproperty Oracle1_4Image      $oracle1_4Image  
  $Object | add-member Noteproperty Oracle1_5Image      $oracle1_5Image 
  $Object | add-member Noteproperty Oracle1_6Image      $oracle1_6Image 
  $Object | add-member Noteproperty OracleIP            $OracleIP
  $Object | add-member Noteproperty Oracle_VMName       $SRVOracl
  $Object | add-member Noteproperty KarbonContainerName $KarbonContainerName;
  $Object | add-member Noteproperty KarbonIP            $KarbonIP;
  $Object | add-member Noteproperty SysprepPassword     $SysprepPassword;
  $Object | add-member Noteproperty SENAME              $SENAME;
  $Object | add-member Noteproperty SEROLE              $SEROLE;
  $Object | add-member Noteproperty SESlackID           $SESlackID
  $Object | add-member Noteproperty SEUPN               $SEUPN;
  $Object | add-member Noteproperty SECompany           $SECompany;
  $Object | add-member Noteproperty EnablePulse         $EnablePulse;
  $Object | add-member Noteproperty XRayVersion         $XRayVersion;
  $Object | add-member Noteproperty MoveVersion         $MoveVersion;
  $object | add-member Noteproperty Filesversion        $Filesversion;
  $object | add-member Noteproperty Analyticsversion    $Analyticsversion;
  $object | add-member Noteproperty CALMversion         $CALMversion;
  $object | add-member Noteproperty Karbonversion       $Karbonversion;
  $object | add-member Noteproperty ObjectsVersion      $ObjectsVersion;
  $object | add-member Noteproperty ERAVersion          $ERAVersion;
  $object | add-member Noteproperty NCCVersion          $NCCVersion;
  $object | add-member Noteproperty FS1_IntName         $FS1_IntName;
  $object | add-member Noteproperty FS1_ExtName         $FS1_ExtName;
  $Object | add-member Noteproperty FS1IntRange         $FS1IntRange;
  $object | add-member Noteproperty FS1ExtRange         $FS1ExtRange;
  $object | add-member Noteproperty Files2IP            $Files2IP
  $object | add-member Noteproperty Files2VM_Name       $Files2VM_Name
  $Object | add-member Noteproperty Files2_ImageName    $Files2_ImageName
  $object | add-member Noteproperty Files1_ImageName    $Files1_ImageName
  $object | add-member Noteproperty Frame_WinImage      $Frame_WinImage
  $Object | add-member Noteproperty Frame_CCAISO        $Frame_CCAISO    
  $object | add-member Noteproperty Frame_AgentISO      $Frame_AgentISO
  $object | add-member Noteproperty Frame_GoldenVMName  $Frame_GoldenVMName
  $object | add-member Noteproperty objectsExtRange     $objectsExtRange
  $object | add-member Noteproperty objectsintRange     $objectsintRange
  $object | add-member Noteproperty PCSideLoadImage     $PCSideLoadImage
  $Object | add-member Noteproperty NW1DHCPStart        $NW1DHCPStar; 
  $Object | add-member Noteproperty StoragePoolName     $StoragePoolName;
  $object | add-member Noteproperty ImagesContainerName $ImagesContainerName;
  $Object | add-member Noteproperty DisksContainerName  $DisksContainerName;
  $Object | add-member Noteproperty NTPServer1          $ntpserver1;
  $Object | add-member Noteproperty NTPServer2          $ntpserver2;
  $Object | add-member Noteproperty NTPServer3          $ntpserver3;
  $Object | add-member Noteproperty NTPServer4          $ntpserver4;
  $Object | add-member Noteproperty smtpSender          $smtpSender  
  $Object | add-member Noteproperty SplunkName          $splunkname;
  $Object | add-member Noteproperty SplunkImage         $splunkimage;
  $Object | add-member Noteproperty SplunkIP            $splunkip;
  $object | add-member Noteproperty smtpport            $smtpport    
  $Object | add-member Noteproperty smtpServer          $smtpServer  
  $Object | add-member Noteproperty IISNLBIP            $IISNLBIP
  $Object | add-member Noteproperty XPlay2012IP         $XPlay2012IP 
  $Object | add-member Noteproperty Supportemail        $Supportemail
  $Object | add-member Noteproperty Mgmt1_VMname        $Mgmt1_VMname     
  $Object | add-member Noteproperty Mgmt1_ImageName     $Mgmt1_ImageName
  $Object | add-member Noteproperty Mgmt1_VMIP          $Mgmt1_VMIP
  $Object | add-member Noteproperty WinTemplateIP       $Wintemplip
  $Object | add-member Noteproperty LinTemplateIP       $Lintemplip
  $Object | add-member Noteproperty PrivateKey          $SSHKeys.Private 
  $Object | add-member Noteproperty PublicKey           $SSHKeys.Public
  if ($mode -eq "Base"){
    $SQLQuery = "USE `"$SQLDatabase`"
      INSERT INTO dbo.$SQLDataGenTableName (QueueUUID, DataServicesIP, BuildAccount, ERAAPIAccount, MoveAPIAccount, PCClusterIP, PCNode1IP, PCnode2IP, PCnode3IP, PCNode1Name, PCNode2Name, PCNode3Name, ERA1Name, ERA1IP, DC1IP, DC2IP, DC1Name, DC2Name, Domainname, Nw1name, Nw2name, MoveIP, Move_ImageName, Move_VMName, XRayIP, XRay_ImageName, XRay_VMName, DC_ImageName, ERA_ImageName, ERA_MSSQLIP, ERA_MSSQLName, ERA_MSSQLImage, ERA_MariaName, ERA_PostGName, EraContainerName, Oracle1_0Image, Oracle1_1Image, Oracle1_2Image, OracleIP, Oracle_VMName, KarbonContainerName, KarbonIP, SysprepPassword, SENAME, SEROLE, SESlackID, SEUPN, SECompany, EnablePulse, XRayVersion, MoveVersion, Filesversion, CALMversion, Karbonversion, ObjectsVersion, ERAVersion, NCCVersion, FS1_IntName, FS1_ExtName, FS1IntRange, FS1ExtRange, Files2IP, Files2VM_Name, Files2_ImageName, Files1_ImageName, NW1DHCPStart, StoragePoolName, ImagesContainerName, DisksContainerName, NTPServer1, NTPServer2, NTPServer3, NTPServer4, smtpSender, smtpport, smtpServer, IISNLBIP, Supportemail, ERA_MySQLName, PrivateKey, PublicKey, Frame_WinImage, Frame_CCAISO, Frame_AgentISO, Frame_GoldenVMName, oracle1_3Image , oracle1_4Image, oracle1_5Image, oracle1_6Image, oracle1_7Image, oracle1_8Image, oracle1_9Image, Frame_GoldenVMIP, PCSideLoadImage, ObjectsIntRange, ObjectsExtRange, Analyticsversion, Mgmt1_VMname, Mgmt1_ImageName, Mgmt1_VMIP, WinTemplateIP, LinTemplateIP,XPlay2012IP,SplunkName, SplunkIP, SplunkImage, HostCount)
                  VALUES('$($datavar.QueueUUID)','$DataIP','$BuildAccount','$ERAAPIAccount','$MoveAPIAccount','$PCCLIP','$PCN1IP','$PCN2IP','$PCN3IP','$PC1Name','$PC2Name','$PC3Name', '$ERA1Name','$ERA1IP','$DC1IP','$DC2IP','$DC1Name','$DC2Name','$Domainname','$Nw1name','$Nw2name','$moveIP','$MoveImageName','$MoveName','$XRAYIP','$XRAYImage','$xrayname','$DC_ImageName','$ERA_ImageName','$MSSQLIP','$MSSQL1','$MSSQLImage','$SRVMaria','$PostGres','$EraContainerName','$oracle1_0Image','$oracle1_1Image','$oracle1_2Image','$OracleIP','$SRVOracl','$KarbonContainerName','$KarbonIP','$SysprepPassword','$SENAME','$SEROLE','$SESlackID','$SEUPN','$SECompany','$EnablePulse','$XRayVersion','$MoveVersion','$Filesversion','$CALMversion','$Karbonversion','$ObjectsVersion','$ERAVersion','$NCCVersion','$FS1_IntName','$FS1_ExtName','$FS1IntRange','$FS1ExtRange','$Files2IP','$Files2VM_Name','$Files2_ImageName','$Files1_ImageName','$NW1DHCPStar','$StoragePoolName','$ImagesContainerName','$DisksContainerName','$ntpserver1','$ntpserver2','$ntpserver3','$ntpserver4','$smtpSender','$smtpport','$smtpServer','$IISNLBIP','$Supportemail','$SRVMYSql','$($SSHKeys.Private)','$($SSHKeys.Public)','$($Frame_WinImage)','$($Frame_CCAISO)','$($Frame_AgentISO)','$($Frame_GoldenVMName)','$oracle1_3Image','$oracle1_4Image','$oracle1_5Image','$oracle1_6Image','$oracle1_7Image','$oracle1_8Image','$oracle1_9Image','$FrameGVMIP','$PCSideLoadImage','$objectsintRange','$objectsExtRange', '$Analyticsversion', '$Mgmt1_VMname', '$Mgmt1_ImageName', '$Mgmt1_VMIP', '$Wintemplip', '$Lintemplip', '$XPlay2012IP', '$SplunkName', '$SplunkIP', '$splunkimage', '$HostCount'  )"
  
    $SQLQueryOutput = Invoke-Sqlcmd -query $SQLQuery -ServerInstance $SQLInstance
  } 
  return $object
}
Export-ModuleMember *

