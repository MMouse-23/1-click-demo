function Lib-Update-Version{
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $ParentLogfile,
    [string] $basedir
  )

  Write-log -message "Inserting Version Table Record."

  $SQLQuery = "USE `"$SQLDatabase`"
    INSERT INTO dbo.$SQLDataVersionTableName (QueueUUID, AOSVersion, AHVVersion, PCVersion, CalmVersion, KarbonVersion, FilesVersion, NCCVersion, ERAVersion, XRayVersion, MoveVersion, AnalyticsVersion, ObjectsVersion)
    VALUES('$($datavar.QueueUUID)','$($datavar.AOSVersion)','$($datavar.HyperVisor)','$($datavar.PCVersion)','$($datagen.CalmVersion)','$($datagen.KarbonVersion)','$($datagen.FilesVersion)','$($datagen.NCCVersion)','$($datagen.ERAVersion)','$($datagen.XRayVersion)','$($datagen.MoveVersion)','$($datagen.MoveVersion)','$($datagen.ObjectsVersion)')"
  
  write-host $SQLQuery

  $Update = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query $SQLQuery

  Write-log -message "Version Update Fisished."
} 

