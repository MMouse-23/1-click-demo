Function Lib-Spawn-Base {
  param (
    [string] $basedir,
    [string] $ps1file,
    [string] $Type
  )
  write-log -message "Debug level is $debug";
  write-log -message "Building Base Launcher";

  $jobname = "Base-$($queueuuid)";
  Get-ScheduledTask $jobname -ea:0 | stop-scheduledtask -ea:0
  Get-ScheduledTask $jobname -ea:0 | unregister-scheduledtask -confirm:0 -ea:0
  [string]$script = "$($basedir)$($ps1file) -prodmode 1 -Pqueueuuid $($queueuuid)"
  $Update = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "UPDATE [$($SQLDatabase)].[dbo].$($SQLQueueTableName) SET QueueStatus = 'Spawned' WHERE QueueUUID='$($QueueUUID)';" 
  $action = New-ScheduledTaskAction -Execute "$pshome\powershell.exe" -Argument $script
  $trigger =New-ScheduledTaskTrigger -Once -At (Get-Date).Date 
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd;
  if ($type -eq "Background" -and $portable -ne 1){
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType "S4U" -RunLevel Highest
    $task = Register-ScheduledTask -TaskName $jobname -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
    sleep 10
    $task | start-scheduledtask
  } else {
    $task = Register-ScheduledTask -TaskName $jobname -Action $action -Trigger $trigger -Settings $settings;
    sleep 10
    $task | start-scheduledtask
  }
  sleep 10 
  $task = Get-ScheduledTask $jobname -ea:0
  if ($task.state -eq "Running"){
    write-log -message "Job Started Success";
  }
};
Export-ModuleMember *
 
