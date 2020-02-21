function Lib-Update-DataX {
	param(
    [object] $datavar,
    [object] $datagen,
    [string] $mode,
    [string] $AOSVersion,
    [string] $SystemModel,
    [string] $CalmVersion,
    [string] $objectsVersion,
    [string] $PCVersion,
    [string] $KarbonVersion,
    [string] $FilesVersion,
    [string] $HyperVisor,
    [string] $AvailableAOSVersion,
    [string] $AnalyticsVersion,
    [string] $NCCVersion
  )
  if ($mode -eq "DataVar"){
      #ramcap before datax
      write-log -message "Checking Block Capacity"
      #ramcap before datax
      $hosts = REST-PE-Get-Hosts -datagen $datagen -datavar $datavar
      foreach ($Box in $hosts.entities){
        [decimal]$totalrambytescap += $Box.memoryCapacityInBytes
        [int]$CoreCap += $Box.numCpuThreads
      }
      $totalGBcap = (($totalrambytescap /1024) /1024) /1024
      $totalGBcap = [math]::Round($totalGBcap)
      #ramcap before datax
      if ($totalGBcap -le 400){

        write-log -message "HashiCorpVault and Objects Will be disabled" -sev "WARN"
        write-log -message "WARNING Block has only $totalGBcap GB RAM, this will disable ERA MSSQL and Oracle, but also arbon Memory usage to sustain N+1" -sev "CHAPTER" -slacklevel 1
        
        $global:RAMCAP = 3

      } elseif ($totalGBcap -le 530) {

        write-log -message "HashiCorpVault and Objects will be disabled in this block" -sev "WARN"

        write-log -message "WARNING Block has only $totalGBcap GB RAM, this will limit ERA and Karbon Memory usage to sustain N+1" -sev "CHAPTER" -slacklevel 1

        $global:RAMCAP = 2

      } elseif ($totalGBcap -le 780) {
        ## Fix ERA message
        write-log -message "Objects will be disabled in this block" -sev "WARN"
        write-log -message "WARNING Block has only $totalGBcap GB RAM, this will limit ERA and Karbon Memory usage to sustain N+1" -sev "CHAPTER" -slacklevel 1

        $global:RAMCAP = 1

      } else {

        write-log -message "This block has $totalGBcap GB of RAM, should be just enough for 1CD" -sev "CHAPTER" -slacklevel 1

        $global:RAMCAP = 0

      }
    If ($AOSVersion -eq $null){
      $AOSVersion = "Cannot Connect"
    }

    $flow = $datavar.EnableFlow
    $intstallFiles = $datavar.InstallFiles
    
    if ($HyperVisor -match "ESX"){
      $flow = 0
      $karbon = 0
      $InstallObjects = 0
      $InstallHashiVault = 0
      $Install1CD = 0
      $InstallEra = $datavar.InstallERA
      $InstallXenDesktop = 0
    } else {
      $flow = $datavar.EnableFlow
      $InstallEra = $datavar.InstallERA
      $karbon = $datavar.InstallKarbon
      if ([version]$AOSVersion -ge [version]"5.11"){
        $InstallObjects = $datavar.InstallObjects
      } else {

        write-log -message "AOS version too low, disabling objects."

        $InstallObjects = 0
      }
      $InstallXenDesktop = $datavar.DemoXenDeskT
      $InstallHashiVault = $datavar.InstallHashiVault
      $Install1CD = $datavar.Install1CD
    }
    if ($ramcap -ge 1 -or $datagen.hostcount -eq 1 -and $datavar.InstallObjects -eq 1){
      $InstallObjects = 2
      $InstallXenDesktop = 0
    } 
    if ($ramcap -ge 2 -and $datavar.InstallERA -eq 0 -and $datavar.InstallObjects -eq 1 -and $InstallObjects -ne 0 -and $hosts.entities -gt 1){

      write-log -message "Objects will be enabled as ERA is disabled in this block"
      $InstallObjects = 1

    }  
    if ($ramcap -ge 2){
      $InstallHashiVault = 0
    } 
    if ($ramcap -ge 3 -and $datavar.InstallERA -ne 0){
      $InstallEra = 2
    }
    if ($InstallXenDesktop -eq 1 ){
      $InstallHashiVault = 0
      $intstallFiles = 1
       write-log -message "Forcing files on and disabling HashiCorpVault as XenDesktop will be deployed."

    }
    write-log -message "DataVar Mode Updating:"
    write-log -message "AOS Version      : $AOSVersion"
    write-log -message "System Model     : $SystemModel"
    write-log -message "HyperVisor       : $HyperVisor"
    write-log -message "EnableFlow       : $flow"
    write-log -message "InstallKarbon    : $karbon"
    write-log -message "InstallObject    : $InstallObjects"
    write-log -message "InstallHashiVault: $InstallHashiVault"
    write-log -message "Install1CD       : $Install1CD"
    write-log -message "InstallERA       : $InstallEra"
    write-log -message "InstallXenDestkop: $InstallXenDesktop"
    write-log -message "InstallFiles     : $intstallFiles"

    $query ="UPDATE [$($SQLDatabase)].[dbo].[$($SQLDataVarTableName)] 
     SET PCVersion = '$($PCVersion)', 
     AOSVersion = '$($AOSVersion)',
     SystemModel = '$($SystemModel)',
     HyperVisor = '$($HyperVisor)',
     EnableFlow = '$($Flow)',
     InstallKarbon = '$($karbon)',
     InstallObjects = '$($InstallObjects)',
     InstallHashiVault = '$($InstallHashiVault)',
     InstallEra = '$($InstallERA)',
     Install1CD = '$($Install1CD)',
     DemoXenDeskT = '$($InstallXenDesktop)',
     InstallFiles = '$($intstallFiles)'
     WHERE QueueUUID='$($QueueUUID)';"
    if ($debug -ge 2){ 
      write-host $query
    } 
    $Update = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query $query
    sleep 5
    $newdatavar = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLDataVarTableName) WHERE QueueUUID='$QueueUUID';"
    return $newdatavar
  } else {

    write-log -message "DataGen Mode Updating:"
    write-log -message "Calm Version   : $CalmVersion"
    write-log -message "Karbon Version : $KarbonVersion"
    write-log -message "Objects Version : $objectsversion"

    $query ="UPDATE [$($SQLDatabase)].[dbo].[$($SQLDataGenTableName)] 
     SET CalmVersion = '$($CalmVersion)',
     AvailableAOSVersion = '$($AvailableAOSVersion)',
     Filesversion = '$($filesversion)',
     AnalyticsVersion = '$($AnalyticsVersion)',
     NCCVersion = '$($NCCVersion)', 
     KarbonVersion = '$($KarbonVersion)', 
     ObjectsVersion = '$($objectsVersion)'
     WHERE QueueUUID='$($QueueUUID)';"
    if ($debug -ge 2){ 
      write-host $query
    } 
    $Update = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query $query
    sleep 5
    $newdatagen = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLDataGenTableName) WHERE QueueUUID='$QueueUUID';"
    return $newdatagen
  }
}