Function write-log {
  param (
  $message,
  $sev = "INFO",
  $slacklevel = 0
  )
  if ($sev -eq "INFO"){
    write-host "$(get-date -format "hh:mm:ss") | INFO  | $message"
  } elseif ($sev -eq "WARN"){
    write-host "$(get-date -format "hh:mm:ss") | WARN  | $message" -ForegroundColor "Yellow"
  } elseif ($sev -eq "ERROR"){
    write-host "$(get-date -format "hh:mm:ss") | ERROR | $message" -ForegroundColor "red"
  } elseif ($sev -eq "CHAPTER"){
    write-host "`n`n### $message`n`n" -ForegroundColor "DarkGreen"
  }
  if ($Type -match "Backend|WatchDog" -or $QueueUUID -eq $null){
         if ($debug -ge 3){
          write "Do nothing"
        }   
  } else {
    if ($Logginglevel -ge 2 -or $sev -ne "INFO"){
      try {
        if (!$LoggingIndex){
          $loggingindex = 0
        }
        if ($debug -ge 3){
          write "Arraycount = $($messagearray.count)"
        }
        #$Logging = Invoke-Sqlcmd -ServerInstance $SQLInstLog -Query "SELECT Top 1 * FROM [$($SQLDatabase)].[dbo].$($SQLLoggingTableName) WHERE QueueUUID='$($QueueUUID)' order by 'EntryIndex' DESC;" -QueryTimeout 100
        $global:LoggingIndex = $LoggingIndex + 1
        #$EntryIndex = $Logging.EntryIndex + 1
        $message2 = (($message -replace "'", " ") -replace "/", " ") -replace ",", " "
        $messageObject = $null
        $messageObject = New-Object PSObject;
        $messageObject | add-member Noteproperty QueueUUID      $QueueUUID
        $messageObject | add-member Noteproperty EntryIndex     $loggingindex;
        $messageObject | add-member Noteproperty EntryType      $Type;
        $messageObject | add-member Noteproperty LogType        $sev;
        $messageObject | add-member Noteproperty Debug          $debug;
        $messageObject | add-member Noteproperty Date           $(get-date);
        $messageObject | add-member Noteproperty Message        $message2;
        $messageObject | add-member Noteproperty SlackLevel     $SlackLevel;
        [array]$global:messagearray += $messageObject
        if ($messagearray.count -ge 20 -or $sev -ne "INFO"){
          #$messagearray | Write-SqlTableData -ServerInstance $SQLInstLog -DatabaseName $SQLDatabase -SchemaName "dbo" -TableName $SQLLoggingTableName -Force
          foreach ($item in $messagearray){
            $SQLQuery = "USE `"$SQLDatabase`"
              INSERT INTO dbo.$SQLLoggingTableName (QueueUUID, EntryIndex, EntryType, LogType, Debug, Date, Message, SlackLevel)
              VALUES('$($item.QueueUUID)','$($item.EntryIndex)','$($item.EntryType)','$($item.LogType)','$($item.debug)','$($item.Date)','$($item.message)','$($item.slacklevel)')"
            $SQLQueryOutput = Invoke-Sqlcmd -query $SQLQuery -ServerInstance $SQLInstLog -QueryTimeout 100
          }
          [array]$global:messagearray = $null
        }
      } catch{ }
    }
  }
} 