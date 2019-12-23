function Lib-Update-Stats{
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $ParentLogfile,
    [string] $basedir
  )
  ### Any updates to the stats table requires the create entry and the update entry to be updated below.
  ### Overhead in code!

  Write-log -message "Checking Base Percentage"

  $Chaptercount = get-content $ParentLogfile

  write-log -message "Using instance $SQLInstLog"
  write-log -message "Getting logs for $($datavar.QueueUUID)"

  $Logging = Invoke-Sqlcmd -ServerInstance $SQLInstLog -Query "SELECT * FROM [$($SQLDatabase)].[dbo].$($SQLLoggingTableName) WHERE QueueUUID='$($datavar.QueueUUID)' ORDER BY EntryIndex"
  
  write-log -message "Found $($Logging.count) entries"

  $percentage = (100/55) * ($Logging | where {$_.logtype -eq "Chapter" -and $_.entrytype -eq "Base"}).count
  If ($percentage -ge 100){
    $percentage = 100
  }
  $percentage = [math]::Round($percentage)

  if ($logging.message -match "Pending request"){
    $starttime = ($Logging | where {$_.message -match "pending request"} | select -last 1).date
    $buildtime = New-TimeSpan -Start $starttime
  } else {
    $buildtime = New-TimeSpan -Start $datavar.DateCreated
  }
  $lastchapter = $logging | where {$_.logtype -eq "chapter"} | select -last 1
  if ($Chaptercount -match "### Done"){
    $percentage = 100
    $status = "Completed"
    $DateStopped = get-date
    
    $buildstring = "$("{0:d2}" -f [int]$([math]::Round($buildtime.Hours))):$("{0:d2}" -f [int]$([math]::Round($buildtime.Minutes))):$("{0:d2}" -f [int]$([math]::Round($buildtime.Seconds)))"
    
  } elseif ($lastchapter.message -match "pending") {

    $status = "Pending"
    $DateStopped = ""

  } else {
    
    Write-log -message "Checking Base Running status for $ParentLogfile"
  
    $filestamps = get-item $ParentLogfile
    $temp = $filestamps.LastWriteTime -gt (get-date).addminutes(-16)
  
    if ($temp -eq $true){
  
      Write-log -message "Base is running"
  
      $status = "Running"
      $DateStopped = ""
      
      $buildstring = "$("{0:d2}" -f [int]$([math]::Round($buildtime.Hours))):$("{0:d2}" -f [int]$([math]::Round($buildtime.Minutes))):$("{0:d2}" -f [int]$([math]::Round($buildtime.Seconds)))"
    
    } else {
  
      Write-log -message "Base is not running??"
  
      $status = "Terminated"
      $DateStopped = get-date

    }    
  }
   
  Write-log -message "Checking Global Errors for $($datavar.queueuuid) in $basedir"

  $alllogitems = Get-ChildItem -recurse "$basedir\*$($datavar.queueuuid).log" | where {$_.name -notmatch "Watchdog"}

  Write-log -message "Procesing $($alllogitems.count) logfiles"

  $allcontent = $null
  Foreach ($Logitem in $alllogitems){
    [array]$allcontent += get-content $Logitem.fullname
  }
  $currentchapter = ($Logging | where {$_.logtype -eq "Chapter" -and $_.entrytype -eq "Base"} | select -last 1).message
  if ($status -eq "Completed"){
    $CurrentChapter = "Done"
  } elseif ($CurrentChapter -eq $null){
    $CurrentChapter = "Starting"
  } elseif ($CurrentChapter -match "Pending request"){
    $status = "Pending"
  }
  $TotalChapters = ($Logging | where {$_.logtype -eq "Chapter"}).count
  $threadcount = ($logging.entrytype | sort -unique).count * 2
  $warningcount = 0
  $PSErrorCount = 0
  $ErrorCount = 0
  $ERAFailureCount = 0
  $PCFailureCount = 0
  foreach ($line in $allcontent){
    if ($line -match "\| WARN  \|"){
      $warningcount ++
    } elseif ($line -match "TerminatingError"){
      $PSErrorCount ++
    } elseif ($line -match "\| ERROR \|"){
      $ErrorCount ++
    } elseif ($line -match "ERA is a super product yet still here i am"){
      $ERAFailureCount ++
    } elseif ($line -match "Prism Central needs help, cleaning"){
      $PCFailureCount ++
    } 
  }
  Write-log -message "Have i done this before?"
  $item = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLDataStatsTableName) WHERE QueueUUID='$($datavar.QueueUUID)';"

  if ($item){

    Write-log -message "Yes"

    try {
      $vms = REST-Get-VMs -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount
      $totalram = 0
      foreach ($vm in $vms.entities){
        $totalram += $vm.memoryReservedCapacityInBytes
      }
      $totalGBram = (($totalram / 1024) / 1024) /1024
      $totalGBram = [math]::Round($totalGBram)
      $containers = REST-Get-Containers -PEClusterIP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount
      $BytesDeployed = 0
      [decimal]$totalrambytescap = 0
      [int]$CoreCap = 0
      $hosts = REST-PE-Get-Hosts -datagen $datagen -datavar $datavar
      foreach ($Box in $hosts.entities){
        [decimal]$totalrambytescap += $Box.memoryCapacityInBytes
        [int]$CoreCap += $Box.numCpuThreads
      }
      $totalGBcap = (($totalrambytescap /1024) /1024) /1024
      $totalGBcap = [math]::Round($totalGBcap)
      foreach ($container in $containers.entities){
        $BytesDeployed += $container.usagestats.'storage.usage_bytes'
      }
      $GBsDeployed = ((($BytesDeployed / 1024) / 1024) /1024)
      $GBsDeployed = [math]::floor($GBsDeployed)
      $vmcount = $($vms.entities.count)
    } catch {

      
      if ($percentage -ge 32){
        $status = "HPOC is Expired, Cannot login anymore"

        Write-log -message "Wait what, i am dead at this point, no point to proceed."

      } else {

        Write-log -message "Cannot login yet. Next Round maybe"

      }
      $GBsDeployed = 0
      $totalGBram = 0
      $vmcount = 0
    }

  } else {

    Write-log -message "No, First Round, i cannot login."

    $GBsDeployed = 0
    $totalGBram = 0
    $vmcount = 0  

  }
  Write-log -message "Current status is $status"
  Write-log -message "Debug is $debug"
  Write-log -message "Current Percentage is $percentage %"
  Write-log -message "Current warningcount is $warningcount"
  Write-log -message "Current PSErrorCount is $PSErrorCount"
  Write-log -message "Current ErrorCount is $ErrorCount"
  Write-log -message "Current Chapter is $CurrentChapter"
  Write-log -message "Current ERA FailureCount is $ERAFailureCount"   
  Write-log -message "Current PC FailureCount is $PCFailureCount"
  Write-log -message "Total GB Ram used is $totalGBram"
  Write-log -message "Total VM Count is $vmcount"
  Write-log -message "Total GB Storage Used is $GBsDeployed"     
  Write-log -message "Updating Stats for queue uuid $($datavar.QueueUUID)"

  if ($item){ 
    Write-log -message "Stats Entry exists, updating that one."

    if ($item.Status -ne "Running"){
      ### Dont update stopped time if already stopped
      $DateStopped = $item.DateStopped
    }
    Write-log -message "Checking BuildTime"
    if ($buildtime -eq $null){

      Write-log -message "BuildTime is 0 keeping old value: $buildtime"

      $buildtime = $item.BuildTime
    } else {

      Write-log -message "BuildTime is not null ->$($BuildTime)<-"

    }
    if ([int]$threadcount -ge [int]$item.threadcount){

      Write-log -message "Threadcount $threadcount -gt $($item.threadcount)"
      
    } else {

      Write-log -message "Threadcount $threadcount -lt $($item.threadcount)"

      $threadcount = $item.threadcount
    }
    if ($status -eq "Expired"){
      $query ="UPDATE [$($SQLDatabase)].[dbo].[$($SQLDataStatsTableName)] 
        SET Status = '$status'
        WHERE QueueUUID='$($datavar.QueueUUID)';" 
    } else {
      $query ="UPDATE [$($SQLDatabase)].[dbo].[$($SQLDataStatsTableName)] 
        SET Status = '$status', 
        Percentage = '$percentage', 
        CurrentChapter = '$CurrentChapter',
        TotalChapters = '$TotalChapters',
        DateStopped = '$DateStopped', 
        ErrorCount = '$ErrorCount', 
        WarningCount = '$WarningCount', 
        PSErrorCount = '$PSErrorCount', 
        ERAFailureCount = '$ERAFailureCount', 
        PCInstallFailureCount = '$PCFailureCount', 
        ThreadCount = '$($threadcount)', 
        BuildTime = '$($buildstring)',
        Debug = '$debug', 
        AOSVersion = '$($datavar.AOSVersion)', 
        AHVVersion = '$($datavar.HyperVisor)', 
        PCVersion = '$($datavar.PCVersion)', 
        ObjectsVersion = '$($datagen.ObjectsVersion)', 
        CalmVersion = '$($datagen.CalmVersion)', 
        KarbonVersion = '$($datagen.KarbonVersion)', 
        FilesVersion = '$($datagen.FilesVersion)',
        AnalyticsVersion = '$($datagen.AnalyticsVersion)',
        NCCVersion = '$($datagen.NCCVersion)',
        ERAVersion = '$($datagen.ERAVersion)', 
        XRayVersion = '$($datagen.XRayVersion)', 
        MoveVersion = '$($datagen.MoveVersion)', 
        VMsDeployed = '$vmcount', 
        GBsDeployed = '$GBsDeployed',
        GBsRAMUsed = '$totalGBram',
        MemCapGB = '$totalGBcap',
        CoreCap = '$CoreCap'
        WHERE QueueUUID='$($datavar.QueueUUID)';" 
      
    } 
    write-host $query
    $Update = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query $query
  } else {

    Write-log -message "Everybody has to exprience the first time."

    $SQLQuery = "USE `"$SQLDatabase`"
      INSERT INTO dbo.$SQLDataStatsTableName (QueueUUID, Status, Percentage, CurrentChapter, TotalChapters, DateCreated, DateStopped, POCName, PEClusterIP, PCClusterIP, ErrorCount, WarningCount, PSErrorCount, ERAFailureCount, PCInstallFailureCount, ThreadCount, BuildTime, Debug, SENAME, Sender, AOSVersion, AHVVersion, PCVersion, ObjectsVersion, CalmVersion, KarbonVersion, FilesVersion, NCCVersion, ERAVersion, XRayVersion, MoveVersion, VMsDeployed, GBsDeployed, GBsRAMUsed)
      VALUES('$($datavar.QueueUUID)','$status','$percentage','$CurrentChapter','$TotalChapters','$($datavar.DateCreated)','$DateStopped','$($datavar.POCName)','$($datavar.PEClusterIP)','$($datagen.PCClusterIP)','$ErrorCount','$warningcount','$PSErrorCount','$ERAFailureCount','$PCFailureCount','$($alllogitems.count)','$($buildstring)','$debug','$($datagen.SENAME)','$($datavar.SenderEMail)','$($datavar.AOSVersion)','$($datavar.HyperVisor)','$($datavar.PCVersion)','$($datagen.ObjectsVersion)','$($datagen.CalmVersion)','$($datagen.KarbonVersion)','$($datagen.FilesVersion)','$($datagen.NCCVersion)','$($datagen.ERAVersion)','$($datagen.XRayVersion)','$($datagen.MoveVersion)','$vmcount','$GBsDeployed','$totalGBram')"
    write-host $SQLQuery

    $SQLQueryOutput = Invoke-Sqlcmd -query $SQLQuery -ServerInstance $SQLInstance

  }

  Write-log -message "Stats Update Fisished."
  return $status
} 

