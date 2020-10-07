Function  LIB-Config-ISOurlData { 
  param (
    $region,
    $datavar
  )
  if ($portable -eq 1){
    $ip = (Get-NetIPAddress | where {$_.InterfaceAlias -notmatch "Loop|VPN" -aND $_.ipaddress -notmatch ":|^169"} | sort InterfaceIndex | Select -first 1).IPAddress
    Write-log -message "Using Portable mode, local vm is $ip"
  }
  if ($debug -ge 2){

    write-log "Setting up auto versioning for Xi-Frame, finding latest version"
  
  }

  $object = Import-Csv "$basedir\AutoDownloadURLs\FrameC.urlconf" -Delimiter ";"
  $FrameConnectorAutoUrl = $object.url

  $object = Import-Csv "$basedir\AutoDownloadURLs\FrameA.urlconf" -Delimiter ";"
  $FrameAgentAutoUrl = $object.url

  if ($debug -ge 2){

    write-log "We added Frame_CCAISO $FrameConnectorAutoUrl and Frame_AgentISO $FrameAgentAutoUrl to the download list."
    write-log "Setting up auto versioning for X-Ray, finding latest version"

  }

  $object = Import-Csv "$basedir\AutoDownloadURLs\XRAY.urlconf" -Delimiter ";"
  if ($datavar.Hypervisor -match "ESX"){
    $XRAYAutoUrl = $object.urlVMWare
  } else {
    $XRAYAutoUrl = $object.urlAHV
  }

  if ($debug -ge 2){

    write-log "Loaded dynamic config for XRay for version $($object.version)"
    write-log "We added $XRAYAutoUrl to the download list."
    write-log "Setting up auto versioning for Move, finding latest version"

  }

  $object = Import-Csv "$basedir\AutoDownloadURLs\Move.urlconf" -Delimiter ";"
  if ($datavar.Hypervisor -match "ESX"){
    $MoveAutoUrl = $object.urlVMWare
  } else {
    $MoveAutoUrl = $object.urlAHV
  }
  if ($debug -ge 2){

    write-log "Loaded dynamic config for Move for version $($object.version)"
    write-log "We added $MoveAutoUrl to the download list."
    write-log "Setting up auto versioning for ERA, finding latest version"

  }
  $object = Import-Csv "$basedir\AutoDownloadURLs\ERA_VM.urlconf" -Delimiter ";"
  if ($datavar.Hypervisor -match "ESX"){
    $ERAAutoUrl = $object.urlVMWare
  } else {
    $ERAAutoUrl = $object.urlAHV
  }
  if ($debug -ge 2){

    write-log "Loaded dynamic config for ERA for version $($object.version)"
    write-log "We added $ERAAutoUrl to the download list."

  }

  # VMWARE URLS First
  if ($datavar.Hypervisor -match "ESX") {
    if ($region -match "www|Backup" ){
 
      $SQL2014ISO    = "https://dl.dropboxusercontent.com/s/f7eju77487nsp1a/SQLServer2014SP3-FullSlipstream-x64-ENU.iso";
      $XENDESKTOP    = "https://dl.dropboxusercontent.com/s/0b90x6p2igvg4hj/Citrix_Virtual_Apps_and_Desktops_7_1912.iso";
      $office2016    = "https://dl.dropboxusercontent.com/s/vkr8kcsnhx4ubgd/SW_DVD5_Office_Professional_Plus_2016_64Bit_English_MLF_X20-42432.ISO";
      $Windows2016ISO= "https://dl.dropboxusercontent.com/s/0fafvu4c7rev1x5/Windows2016.iso";
      $Centos_1CD    = "https://dl.dropboxusercontent.com/s/4bi8xtwqmcq7e1m/Centos8x64V6.vmdk"
      $Windows2012   = "https://dl.dropboxusercontent.com/s/xzc1nog6t49pqpz/Windows2012V4.vmdk"
      $Windows10_1CD = "https://dl.dropboxusercontent.com/s/rfnc1zskmppcwab/Windows10V4.vmdk"
      $windows2016   = "https://dl.dropboxusercontent.com/s/48rqxg48txff7ad/Windows2016V5.tar.gz"
      $VirtIO1_1_4ISO= "https://dl.dropboxusercontent.com/s/36qgacn06pzjd5r/Nutanix-VirtIO-1.1.4.iso"
      $sqlSERVER     = "https://dl.dropboxusercontent.com/s/pkl10yanijotjc6/MSSQL-2016V5.tar.gz"
      $oracle1_0     = "https://dl.dropboxusercontent.com/s/vwmf5hbp3wi8tfd/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-1.vmdk"
      $oracle1_1     = "https://dl.dropboxusercontent.com/s/k0vqmxalxikccxz/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-2.vmdk"
      $oracle1_2     = "https://dl.dropboxusercontent.com/s/6lmrskwkq001qya/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-3.vmdk"
      $oracle1_3     = "https://dl.dropboxusercontent.com/s/spviwgzap34q0k9/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-4.vmdk"
      $oracle1_4     = "https://dl.dropboxusercontent.com/s/spviwgzap34q0k9/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-5.vmdk"
      $oracle1_5     = "https://dl.dropboxusercontent.com/s/utc9tnubh9e2mys/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-6.vmdk"
      $oracle1_6     = "https://dl.dropboxusercontent.com/s/7s0n4i33sb4djqu/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-7.vmdk"
      $oracle1_7     = "https://dl.dropboxusercontent.com/s/mwrxorrhj9ufqgt/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-8.vmdk"
      $oracle1_8     = "https://dl.dropboxusercontent.com/s/8t8qfihxva4k6nf/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-9.vmdk"
      $oracle1_9     = "https://dl.dropboxusercontent.com/s/67qbl24a053opqd/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-10.vmdk"

    } elseif ($region -eq "Local"){

      $SQL2014ISO    = "http://$($ip)/data/SQLServer2014SP3-FullSlipstream-x64-ENU.iso";
      $XENDESKTOP    = "http://$($ip)/data/Citrix_Virtual_Apps_and_Desktops_7_1912.iso";
      $office2016    = "http://$($ip)/data/SW_DVD5_Office_Professional_Plus_2016_64Bit_English_MLF_X20-42432.iso";
      $Windows2016ISO= "http://$($ip)/data/Windows2016.iso";
      $Centos_1CD    = "http://$($ip)/data/Centos8x64V6.vmdk"
      $Windows2012   = "http://$($ip)/data/Windows2012V4.vmdk"
      $Windows10_1CD = "http://$($ip)/data/Windows10V4.vmdk"
      $windows2016   = "http://$($ip)/data/Windows2016V5.tar.gz"
      $VirtIO1_1_4ISO= "http://$($ip)/data/Nutanix-VirtIO-1.1.4.iso"
      $sqlSERVER     = "http://$($ip)/data/MSSQL-2016V4.vmdk" 
      $oracle1_0     = "http://$($ip)/data/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-1.vmdk"
      $oracle1_1     = "http://$($ip)/data/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-2.vmdk"
      $oracle1_2     = "http://$($ip)/data/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-3.vmdk"
      $oracle1_3     = "http://$($ip)/data/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-4.vmdk"
      $oracle1_4     = "http://$($ip)/data/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-5.vmdk"
      $oracle1_5     = "http://$($ip)/data/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-6.vmdk"
      $oracle1_6     = "http://$($ip)/data/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-7.vmdk"
      $oracle1_7     = "http://$($ip)/data/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-8.vmdk"
      $oracle1_8     = "http://$($ip)/data/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-9.vmdk"
      $oracle1_9     = "http://$($ip)/data/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-10.vmdk"
    
    } else { 

      $IPsplit = $datavar.PEClusterIP.split(".")
      if ($IPsplit[1] -eq "55"){
        $IP =  "10.55.251.38"
        $Site = "RTP"
      } else {
        $IP =  "10.42.194.11"
        $Site = "PHX"
      }
      Write-log -message "Using Nutanix HPOC in VMware mode, this is a $Site build, IP is $IP"
      $SQL2014ISO    = "http://$($ip)/images/1-Click-Demo/SQLServer2014SP3-FullSlipstream-x64-ENU.iso";
      $XENDESKTOP    = "http://$($ip)/images/1-Click-Demo/Citrix_Virtual_Apps_and_Desktops_7_1912.iso";
      $office2016    = "http://$($ip)/images/1-Click-Demo/SW_DVD5_Office_Professional_Plus_2016_64Bit_English_MLF_X20-42432.ISO";
      $Windows2016ISO= "http://$($ip)/images/1-Click-Demo/Windows2016.iso";
      $Centos_1CD    = "http://$($ip)/images/1-Click-Demo/Centos8x64V6.vmdk"
      $Windows2012   = "http://$($ip)/images/1-Click-Demo/Windows2012V4.vmdk"
      $Windows10_1CD = "http://$($ip)/images/1-Click-Demo/Windows10V4.vmdk"
      $windows2016   = "http://$($ip)/images/1-Click-Demo/Windows2016V4.vmdk"
      $VirtIO1_1_4ISO= "http://$($ip)/images/1-Click-Demo/Nutanix-VirtIO-1.1.4.iso"
      $sqlSERVER     = "http://$($ip)/images/1-Click-Demo/MSSQL-2016V4.vmdk"
      $oracle1_0     = "http://$($ip)/images/1-Click-Demo/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-1.vmdk"
      $oracle1_1     = "http://$($ip)/images/1-Click-Demo/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-2.vmdk"
      $oracle1_2     = "http://$($ip)/images/1-Click-Demo/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-3.vmdk"
      $oracle1_3     = "http://$($ip)/images/1-Click-Demo/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-4.vmdk"
      $oracle1_4     = "http://$($ip)/images/1-Click-Demo/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-5.vmdk"
      $oracle1_5     = "http://$($ip)/images/1-Click-Demo/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-6.vmdk"
      $oracle1_6     = "http://$($ip)/images/1-Click-Demo/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-7.vmdk"
      $oracle1_7     = "http://$($ip)/images/1-Click-Demo/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-8.vmdk"
      $oracle1_8     = "http://$($ip)/images/1-Click-Demo/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-9.vmdk"
      $oracle1_9     = "http://$($ip)/images/1-Click-Demo/TEMPLATE_ORACLE_12.1_SIHA_VDISK_SOURCE-10.vmdk"

    } 

  } else {
  ## AHV URLS
    $IPsplit = $datavar.PEClusterIP.split(".")
    if ($IPsplit[1] -eq "136"){
      $region = "www"
    }
    if ($region -match "www|Backup" ){
      $SQL2014ISO    = "https://dl.dropboxusercontent.com/s/f7eju77487nsp1a/SQLServer2014SP3-FullSlipstream-x64-ENU.iso";
      $XENDESKTOP    = "https://dl.dropboxusercontent.com//s/0b90x6p2igvg4hj/Citrix_Virtual_Apps_and_Desktops_7_1912.iso";
      $office2016    = "https://dl.dropboxusercontent.com/s/vkr8kcsnhx4ubgd/SW_DVD5_Office_Professional_Plus_2016_64Bit_English_MLF_X20-42432.ISO";
      $Windows2016ISO= "https://dl.dropboxusercontent.com/s/0fafvu4c7rev1x5/Windows2016.iso";
      $Centos_1CD    = "https://dl.dropboxusercontent.com/s/eh5kx8sh5fr0b9x/CentOS-7-x86_64-GenericCloud.qcow2"
      $Windows2012   = "https://dl.dropboxusercontent.com/s/n4zuuymunbc5b8o/Windows2012.qcow2"
      $Windows10_1CD = "https://dl.dropboxusercontent.com/s/t2cdv7t9ov5f1wg/Windows10.qcow2"
      $windows2016   = "https://dl.dropboxusercontent.com/s/oxhzh5jfpav89r5/Windows2016.qcow2"
      $VirtIO1_1_4ISO= "https://dl.dropboxusercontent.com/s/36qgacn06pzjd5r/Nutanix-VirtIO-1.1.4.iso"
      $sqlSERVER     = "https://dl.dropboxusercontent.com/s/52hfb1g6wkbm4bj/MSSQL-2016v4.qcow2"
      $oracle1_0     = "https://dl.dropboxusercontent.com/s/tbakt69whliegmd/orcl12102_osdisk-0.qcow"
      $oracle1_1     = "https://dl.dropboxusercontent.com/s/3oo6pgrsr9rpadl/orcl12102_grid-1.qcow2"
      $oracle1_2     = "https://dl.dropboxusercontent.com/s/l9239cexdicr66q/orcl12102_crs-2.qcow2"
      $oracle1_3     = "https://dl.dropboxusercontent.com/s/mxgkjaxp028snab/orcl12102_database-3.qcow2"
      $oracle1_4     = "https://dl.dropboxusercontent.com/s/pz2db6npvuts20p/orcl12102_data-4.qcow2"
      $oracle1_5     = "https://dl.dropboxusercontent.com/s/1w8kyrwwtm3wo0i/orcl12102_reco-5.qcow2"
      $oracle1_6     = "https://dl.dropboxusercontent.com/s/clml562wya4z278/orcl12102_arch-6.qcow2"
      $oracle1_7     = "NA-AHV"
      $oracle1_8     = "NA-AHV"
      $oracle1_9     = "NA-AHV"

    } elseif ($region -eq "Local"){
      $SQL2014ISO    = "http://$($ip)/data/SQLServer2014SP3-FullSlipstream-x64-ENU.iso";
      $XENDESKTOP    = "http://$($ip)/data/Citrix_Virtual_Apps_and_Desktops_7_1912.iso";
      $office2016    = "http://$($ip)/data/SW_DVD5_Office_Professional_Plus_2016_64Bit_English_MLF_X20-42432.iso";
      $Windows2016ISO= "http://$($ip)/data/Windows2016.iso";
      $Centos_1CD    = "http://$($ip)/data/CentOS-7-x86_64-GenericCloud.qcow2"
      $Windows2012   = "http://$($ip)/data/Windows2012.qcow2"
      $Windows10_1CD = "http://$($ip)/data/Windows10_1CD.qcow2"
      $windows2016   = "http://$($ip)/data/Windows2016.qcow2"
      $VirtIO1_1_4ISO= "http://$($ip)/data/Nutanix-VirtIO-1.1.4.iso"
      $sqlSERVER     = "http://$($ip)/data/MSSQLv4.qcow2" 
      $oracle1_0     = "http://$($ip)/data/orcl12102_osdisk-0.qcow"
      $oracle1_1     = "http://$($ip)/data/orcl12102_grid-1.qcow2"
      $oracle1_2     = "http://$($ip)/data/orcl12102_crs-2.qcow2"
      $oracle1_3     = "http://$($ip)/data/orcl12102_database-3.qcow2"
      $oracle1_4     = "http://$($ip)/data/orcl12102_data-4.qcow2"
      $oracle1_5     = "http://$($ip)/data/orcl12102_reco-5.qcow2"
      $oracle1_6     = "http://$($ip)/data/orcl12102_arch-6.qcow2"
      $oracle1_7     = "NA-AHV"
      $oracle1_8     = "NA-AHV"
      $oracle1_9     = "NA-AHV"
  
    } else {
  
      $IPsplit = $datavar.PEClusterIP.split(".")
      if ($IPsplit[1] -eq "55"){
        $IP =  "10.55.251.38"
        $Site = "RTP"
      } else {
        $IP =  "10.42.194.11"
        $Site = "PHX"
      }
      Write-log -message "Using Nutanix HPOC mode, this is a $Site build, IP is $IP"

      $SQL2014ISO    = "http://$($ip)/images/1-Click-Demo/SQLServer2014SP3-FullSlipstream-x64-ENU.iso";
      $XENDESKTOP    = "http://$($ip)/images/1-Click-Demo/Citrix_Virtual_Apps_and_Desktops_7_1912.iso";
      $office2016    = "http://$($ip)/images/1-Click-Demo/SW_DVD5_Office_Professional_Plus_2016_64Bit_English_MLF_X20-42432.ISO";
      $Windows2016ISO= "http://$($ip)/images/1-Click-Demo/Windows2016.iso";
      $Centos_1CD    = "http://$($ip)/images/1-Click-Demo/CentOS-7-x86_64-GenericCloud.qcow2"
      $Windows2012   = "http://$($ip)/images/1-Click-Demo/Windows2012.qcow2"
      $Windows10_1CD = "http://$($ip)/images/1-Click-Demo/Windows10V4.qcow2"
      $windows2016   = "http://$($ip)/images/1-Click-Demo/Windows2016.qcow2"
      $VirtIO1_1_4ISO= "http://$($ip)/images/1-Click-Demo/Nutanix-VirtIO-1.1.4.iso"
      $sqlSERVER     = "http://$($ip)/images/1-Click-Demo/MSSQL-2016v4.qcow2"
      $oracle1_0     = "http://$($ip)/images/1-Click-Demo/orcl12102_osdisk-0.qcow"
      $oracle1_1     = "http://$($ip)/images/1-Click-Demo/orcl12102_grid-1.qcow2"
      $oracle1_2     = "http://$($ip)/images/1-Click-Demo/orcl12102_crs-2.qcow2"
      $oracle1_3     = "http://$($ip)/images/1-Click-Demo/orcl12102_database-3.qcow2"
      $oracle1_4     = "http://$($ip)/images/1-Click-Demo/orcl12102_data-4.qcow2"
      $oracle1_5     = "http://$($ip)/images/1-Click-Demo/orcl12102_reco-5.qcow2"
      $oracle1_6     = "http://$($ip)/images/1-Click-Demo/orcl12102_arch-6.qcow2"
      $oracle1_7     = "NA-AHV"
      $oracle1_8     = "NA-AHV"
      $oracle1_9     = "NA-AHV"
      $WS_WinTools   = "http://$($ip)/workshop_staging/WinToolsVM.qcow2" 
    }
  }
  $Object = New-Object PSObject;
  $Object | add-member Noteproperty Windows2016ISO      $Windows2016ISO; 
  $Object | add-member Noteproperty 'Windows 2016'      $Windows2016; 
  $Object | add-member Noteproperty 'Windows 2012'      $Windows2012;  
  $Object | add-member Noteproperty 'Windows 10_1CD'    $Windows10_1CD;     
  $Object | add-member Noteproperty VirtIO1_1_4ISO      $VirtIO1_1_4ISO;
  $Object | add-member Noteproperty SQL2014ISO          $SQL2014ISO;
  $Object | add-member Noteproperty 'Citrix_1912_ISO'   $XENDESKTOP;
  $Object | add-member Noteproperty office2016ISO       $office2016;
  $Object | add-member Noteproperty MoveAuto            $MoveAutoUrl;
  $Object | add-member Noteproperty CentOS_1CD          $CentOs_1CD;
  $Object | add-member Noteproperty XRAYAuto            $XRAYAutoUrl
  $Object | add-member Noteproperty ERAAuto             $ERAAutoUrl;
  $Object | add-member Noteproperty 'MSSQL-2016-VM'     $sqlSERVER;
  $Object | add-member Noteproperty Oracle_1_0          $oracle1_0;
  $Object | add-member Noteproperty Oracle_1_1          $oracle1_1;
  $Object | add-member Noteproperty Oracle_1_2          $oracle1_2;
  $Object | add-member Noteproperty Oracle_1_3          $oracle1_3;
  $Object | add-member Noteproperty Oracle_1_4          $oracle1_4;
  $Object | add-member Noteproperty Oracle_1_5          $oracle1_5;
  $Object | add-member Noteproperty Oracle_1_6          $oracle1_6;
  $Object | add-member Noteproperty Oracle_1_7          $oracle1_7;
  $Object | add-member Noteproperty Oracle_1_8          $oracle1_8;
  $Object | add-member Noteproperty Oracle_1_9          $oracle1_9;
  $Object | add-member Noteproperty WS_WinTools         $WS_WinTools;  

  return $object;
};