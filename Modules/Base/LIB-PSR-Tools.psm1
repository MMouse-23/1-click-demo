function Get-FunctionName {
  param (
    [int]$StackNumber = 1
  ) 
    return [string]$(Get-PSCallStack)[$StackNumber].FunctionName
}

Function Test-MemoryUsage {
  Param()
 
  $os = Get-Ciminstance Win32_OperatingSystem
  $pctFree = [math]::Round(($os.FreePhysicalMemory/$os.TotalVisibleMemorySize)*100,2)
 
  if ($pctFree -ge 45) {
    $Status = "OK"
  } elseif ($pctFree -ge 15 ) {
    $Status = "Warning"
  } else {
    $Status = "Critical"
  }
 
  $os | Select @{Name = "Status";Expression = {$Status}},
  @{Name = "PctFree"; Expression = {$pctFree}},
  @{Name = "FreeGB";Expression = {[math]::Round($_.FreePhysicalMemory/1mb,2)}},
  @{Name = "TotalGB";Expression = {[int]($_.TotalVisibleMemorySize/1mb)}}
 
}

function Remove-StringSpecialCharacter{
  param(
    [Parameter(ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [Alias('Text')]
    [System.String[]]$String,
    
    [Alias("Keep")]
    #[ValidateNotNullOrEmpty()]
    [String[]]$SpecialCharacterToKeep
  )
  PROCESS
  {
    IF ($PSBoundParameters["SpecialCharacterToKeep"])
    {
      $Regex = "[^\p{L}\p{Nd}"
      Foreach ($Character in $SpecialCharacterToKeep)
      {
        IF ($Character -eq "-"){
          $Regex +="-"
        } else {
          $Regex += [Regex]::Escape($Character)
        }
        #$Regex += "/$character"
      }
      
      $Regex += "]+"
    } #IF($PSBoundParameters["SpecialCharacterToKeep"])
    ELSE { $Regex = "[^\p{L}\p{Nd}]+" }
    
    FOREACH ($Str in $string)
    {
      Write-Verbose -Message "Original String: $Str"
      $Str -replace $regex, ""
    }
  } #PROCESS
}

Function Test-CPUUsage {
  Param()
 
  $sample1 = (Get-Counter -Counter "\Processor(_Total)\% Processor Time").countersamples.cookedvalue
  sleep 15
  $sample2 = (Get-Counter -Counter "\Processor(_Total)\% Processor Time").countersamples.cookedvalue
  $totalav = ($sample1 + $sample2)/2
  return $totalav
}

function Wait-Project-Save-State {
  param(
    [object] $datavar,
    [object] $datagen,
    [object] $project
  )
  write-log -message "Waiting for Project $($project.metadata.uuid) save state"
  sleep 10
  $createcount = 0
  do {
    $createcount ++
    $projectdetail = REST-Get-ProjectDetail -datavar $datavar -datagen $datagen -project $project
    if ($projectdetail.status.state -ne "COMPLETE"){

      write-log -message "Project is still in state: $($projectdetail.status.state) sleeping 30 seconds"

      Sleep 30
    } else {

      write-log -message "Project is in state: $($projectdetail.status.state), this is my exit."
    }
  } until ($projectdetail.status.state  -eq "COMPLETE" -or $createcount -ge 20)
  if ($createcount -ge 20){

    write-log -message "Project is still in state: $($projectdetail.status.state) after waiting for 600 seconds" -sev "ERROR"

  }
}

Function Wait-ImageUpload-Task{
  param(
    $datavar
  )
  write-log -message "Wait for Image Upload Task with ID $($datavar.queueuuid)"
  do {
    $Looper++
    try{
      [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^ImageUpload" }
    } catch {
      try {
        [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^ImageUpload" }
      } catch {}
    }
    if ($Looper % 4 -eq 0){
      write-log -message "We found $($tasks.count) task";
    }
    [array] $allready = $null
    if ($Looper % 4 -eq 0){
      write-log "Cycle $looper out of 200"
    }
    if ($tasks){
      Foreach ($task in $tasks){
        if ($task.state -eq "ready"){
          
          if ($Looper % 4 -eq 0){
            write-log -message "Task $($task.taskname) is ready."
          }
          $allReady += 1
      
        } else {
      
          $allReady += 0

          if ($Looper % 4 -eq 0){
            write-log -message "Task $($task.taskname) is $($task.state)."
          }
        };
      };
      sleep 20
    } else {
      $allReady = 0
      sleep 20
      if ($Looper % 4 -eq 0){
        write-log -message "There are no jobs to process."
      }
    }
  } until ($Looper -ge 200 -or $allReady -notcontains 0)
}


Function PSR-MulticlusterPE-PC {
  param(
    [object] $datagen,
    [object] $datavar
  )

  write-log "Checking current status"
  do {
    $count ++
    $current = REST-PE-GET-MultiCluster -datavar $datavar -datagen $datagen
    if ($current.clusterUuid){
      if ($current.clusterUuid.length -ge 5 ){
        $result = "Success"

        write-log -message "Cluster is added to $($current.clusterDetails.ipAddresses)";

      }
    } else {
      write-log -message "Adding Multicluster to PE Cluster";
        
      $hide = REST-PE-Add-MultiCluster -datavar $datavar -datagen $datagen

    }
    write-log -message "Waiting for the registration process";
    sleep 90
    $current = REST-PE-GET-MultiCluster -datavar $datavar -datagen $datagen
    if ($current.clusterUuid){
      if ($current.clusterUuid.length -ge 5 ){
        $result = "Success"

        write-log -message "Cluster is added to $($current.clusterDetails.ipAddresses)";

      }
    } else {

      write-log -message "Error While adding, resetting PE Gateway, lets wait for Depending / Running PE tasks" -sev "WARN"

      wait-ImageUpload-Task -datavar $datavar

      write-log -message "All Paralel threads should be in the correct state for an AOS Cluster restart.";
      write-log -message "Preparing Restart, Build SSH connection to cluster";

      $Securepass = ConvertTo-SecureString $datavar.pepass -AsPlainText -Force;
      $credential = New-Object System.Management.Automation.PSCredential ('nutanix', $Securepass);
      try {
        $session = New-SSHSession -ComputerName $datavar.PEClusterIP -Credential $credential -AcceptKey;
      } catch {
        sleep 30
        $session = New-SSHSession -ComputerName $datavar.PEClusterIP -Credential $credential -AcceptKey;
      }
      write-log -message "Building a stream session";

      $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)

      write-log -message "Restarting Prism";

      $hide = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "allssh genesis stop prism ; cluster start"

      write-log -message "Sleeping 3 minutes after restart Prism";

      sleep 119

      write-log -message "Reattempting to join";

      sleep 20

      $hide = REST-PE-Add-MultiCluster -datavar $datavar -datagen $datagen

      write-log -message "Waiting for the registration process";

      sleep 90
      $current = REST-PE-GET-MultiCluster -datavar $datavar -datagen $datagen     
      if ($current.clusterUuid){
        if ($current.clusterUuid.length -ge 5 ){
          $result = "Success"
          $status = "Success"
          write-log -message "Cluster is added to $($current.clusterDetails.ipAddresses)";

        }
      } 
    }
  } until ($result -eq "Success" -or $count -ge 3)
  sleep 20
  if ($result -match "Success"){
    $status = "Success"

    write-log -message "Pe has been Joined to PC";
    write-log -message "Loving it";

  } else {

    $status = "Failed"

    write-log -message "Danger Will Robbinson." -sev "ERROR";

  }
  $resultobject =@{
    Result = $status
  };
  return $resultobject
}



Function Wait-Forest-Task{
  param(
    $datavar
  )
  write-log -message "Wait for Forest Task with ID $($datavar.queueuuid)"
  do {
    $Looper++
    try{
      [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^Forest" }
    } catch {
      try {
        [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^Forest" }
      } catch {}
    }

    write-log -message "We found $($tasks.count) task";

    [array] $allready = $null
    write-log "Cycle $looper out of 200"
    if ($tasks){
      Foreach ($task in $tasks){
        if ($task.state -eq "ready"){
    
          write-log -message "Task $($task.taskname) is ready."
    
          $allReady += 1
      
        } else {
      
          $allReady += 0

          write-log -message "Task $($task.taskname) is $($task.state)."
      
        };
      };
      sleep 60
    } else {
      $allReady = 1

      write-log -message "There are no jobs to process."

    }
  } until ($Looper -ge 200 -or $allReady -notcontains 0)
}


Function Wait-Files-Task{
  param(
    $datavar
  )
  write-log -message "Wait for Files Task with ID $($datavar.queueuuid)"
  do {
    $Looper++
    try{
      [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^Files" }
    } catch {
      try {
        [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^Files" }
      } catch {}
    }

    write-log -message "We found $($tasks.count) task";

    [array] $allready = $null
    write-log "Cycle $looper out of 200"
    if ($tasks){
      Foreach ($task in $tasks){
        if ($task.state -eq "ready"){
    
          write-log -message "Task $($task.taskname) is ready."
    
          $allReady += 1
      
        } else {
      
          $allReady += 0

          write-log -message "Task $($task.taskname) is $($task.state)."
      
        };
      };
      sleep 60
    } else {
      $allReady = 0

      write-log -message "There are no jobs to process."

    }
  } until ($Looper -ge 200 -or $allReady -notcontains 0)
}


Function Wait-Templates-Task{
  param(
    $datavar
  )
  write-log -message "Wait for Templates Task with ID $($datavar.queueuuid)"
  do {
    $Looper++
    try{
      [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^ImagesVmware" }
    } catch {
      try {
        [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^ImagesVmware" }
      } catch {}
    }

    write-log -message "We found $($tasks.count) task";

    [array] $allready = $null
    write-log "Cycle $looper out of 200"
    if ($tasks){
      Foreach ($task in $tasks){
        if ($task.state -eq "ready"){
    
          write-log -message "Task $($task.taskname) is ready."
    
          $allReady += 1
      
        } else {
      
          $allReady += 0

          write-log -message "Task $($task.taskname) is $($task.state)."
      
        };
      };
      sleep 60
    } else {
      $allReady = 1

      write-log -message "There are no jobs to process."

    }
  } until ($Looper -ge 200 -or $allReady -notcontains 0)
}

Function PSR-Generate-DomainContent {
  param (
    [string] $SysprepPassword,
    [string] $IP,
    [object] $datagen,
    [object] $datavar,
    [string] $Domainname,
    [string] $Sename,
    [object] $hosts
  )
  $netbios = $Domainname.split(".")[0]

  write-log -message "Debug level is $debug";
  write-log -message "Building credential object.";

  $password = $SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $credential = New-Object System.Management.Automation.PsCredential("administrator",$password);
  $sesplit = ($datagen.SEUPN -split "@")[0]
  $seupn = $datagen.SEUPN
  write-log -message "Populating AD content";
  write-log -message "5 Customers";
  write-log -message "5 Admins per customer";
  write-log -message "5 Service accounts per customer";
  write-log -message "3 Groups per customer";
  write-log -message "105 User accounts per customer"; 
  write-log -message "Groups Populated per customer";
  write-log -message "Admin $sesplit created as Domain and PC/PE Admin";
  write-log -message "Domain name is $Domainname"
  write-log -message "Building DNS Entries"
  write-log -message "Datagen $($datagen.SENAME) SE"
  write-log -message "Datagen $($datagen.SEUPN) UPN"
  write-log -message "Using $($hosts.entities.count) hosts."
  $DNSEntries = $null
  foreach ($box in $hosts.entities){
    $Entity = [PSCustomObject]@{
      Name        = "CVM-$($box.name)"
      IP          = $box.serviceVMExternalIP
    }
    [array]$DNSEntries += $Entity
    $Entity = [PSCustomObject]@{
      Name        = "$($box.name)"
      IP          = $box.hypervisorAddress
    }
    [array]$DNSEntries += $Entity
    $Entity = [PSCustomObject]@{
      Name        = "IPMI-$($box.name)"
      IP          = $box.ipmiAddress
    }
    [array]$DNSEntries += $Entity
  }
  $Entity = [PSCustomObject]@{
    Name        = "Karbon"
    IP          = $datagen.KarbonIP
  }
  [array]$DNSEntries += $Entity
  $Entity = [PSCustomObject]@{
    Name        = $datagen.ERA1Name
    IP          = $datagen.ERA1IP
  }
  [array]$DNSEntries += $Entity
  $Entity = [PSCustomObject]@{
    Name        = $datagen.Move_VMName
    IP          = $datagen.MoveIP
  }
  [array]$DNSEntries += $Entity
  $Entity = [PSCustomObject]@{
    Name        = $datagen.Oracle_VMName
    IP          = $datagen.OracleIP
  }
  [array]$DNSEntries += $Entity
  $Entity = [PSCustomObject]@{
    Name        = "PE-$($datavar.pocname)"
    IP          = $datavar.peclusterip
  }
  [array]$DNSEntries += $Entity
  $Entity = [PSCustomObject]@{
    Name        = "PC-$($datavar.pocname)"
    IP          = $datagen.pcclusterip
  }
  [array]$DNSEntries += $Entity
  $Entity = [PSCustomObject]@{
    Name        = "IISNLBIP"
    IP          = $datagen.IISNLBIP
  }
  [array]$DNSEntries += $Entity
  if ($datavar.pcmode -eq 1){
    $Entity = [PSCustomObject]@{
      Name        = $datagen.PCNode1Name
      IP          = $datagen.pcclusterip
    }
    [array]$DNSEntries += $Entity    
  } else {
    $Entity = [PSCustomObject]@{
      Name        = $datagen.PCNode1Name
      IP          = $datagen.PCNode1IP
    }
    [array]$DNSEntries += $Entity
    $Entity = [PSCustomObject]@{
      Name        = $datagen.PCNode2Name
      IP          = $datagen.PCNode2IP
    }
    [array]$DNSEntries += $Entity
    $Entity = [PSCustomObject]@{
      Name        = $datagen.PCNode3Name
      IP          = $datagen.PCNode3IP
    }
    [array]$DNSEntries += $Entity   
  }
  write-log -message "Creating $($DNSEntries.count) DNS records"

  $connect = invoke-command -computername $ip -credential $credential { 
    $DomainParts = $Args[0].split(".");
    $Customers = "Customer-A","Customer-B","Customer-C","Customer-D"
    $OUs = "User-Accounts","Groups","Service-Accounts","Admin-Accounts","Resources","Disabled-Users";
    $users = "User-1","User-2","User-3","User-4","User-5";
    $ServiceAccounts = "ntnx-sql-svc","ntnx-xda-svc","ntnx-exc-svc","ntnx-bck-svc","ntnx-psr-svc","ntnx-ntx-svc";
    $adminaccounts = "adm-User-1","adm-User-2","adm-User-3","adm-User-4","adm-User-5";
    try {
      New-ADOrganizationalUnit -Name "Customers" -Path "DC=$($($DomainParts)[0]),DC=$($($DomainParts)[1]),DC=$($($DomainParts)[2])";
    } catch {
    };
    Foreach ($machine in $args[3]){
      $hide =Add-DnsServerResourceRecordA -name $machine.name -IPv4Address $machine.ip -confirm:0 -zonename $args[0] -ea:0 | out-null;
    }
    $hide = new-aduser -name $args[2] -AccountPassword $args[1] -PasswordNeverExpires $true -userPrincipalName "$($args[4])" -EmailAddress "$($args[4])" -Office "Hoofddorp" -ea:0 | out-null;
    add-ADGroupMember "Domain Admins" $args[2] -ea:0 | out-null;
    function Generate-Name {;
      $lastnames  = "Smith Johnson Williams Jones Brown Davis Miller Wilson Moore Taylor Anderson Thomas Jackson White Harris Martin Thompson Garcia Martinez Robinson Clark Wright Rodriguez Lopez Lewis Perez Hill Roberts Lee Scott Turner Walker Green Phillips Hall Adams Campbell Allen Baker Parker Young Gonzalez Evans Hernandez Nelson Edwards King Carter Collins";
      $firstnames = "James Christopher Ronald Mary Lisa Michelle John Daniel Anthony Patricia Nancy Laura Robert Paul Kevin Linda Karen Sarah Michael Mark Jason Barbara Betty Kimberly William Donald Jeff Elizabeth Helen Deborah David George Jennifer Sandra Richard Kenneth Maria Donna Charles Steven Susan Carol Joseph Edward Margaret Ruth Thomas Brian Dorothy Sharon";
      $first = $firstnames.split(" ");
      $Last = $lastnames.split(" ");
      $f = $first[ (Get-Random $first.count ) ];
      $l = $last[ (Get-Random $last.count) ];
      $full = $f+"."+$l;
      return $full
    };
    Foreach ($customer in $customers){;
      $cusshort = $customer.split("-")[1]
      $count1 = 0;
      $count2 = 0;
      $names = $null;
      do {;
        [array]$names += Generate-name;
        $count1++;
      } until ($count1 -eq 1000);
      New-ADOrganizationalUnit -Name "$customer" -Path "OU=Customers,DC=$($($DomainParts)[0]),DC=$($($DomainParts)[1]),DC=$($($DomainParts)[2])" -DisplayName "$customer Cloud";
      foreach ($ou in $ous){
        New-ADOrganizationalUnit -Name "$ou" -Path "OU=$($customer),OU=Customers,DC=$($($DomainParts)[0]),DC=$($($DomainParts)[1]),DC=$($($DomainParts)[2])";
      }

      new-adgroup -groupscope 1 -name "$($customer)-Service-Accounts-Group" -path "OU=Groups,OU=$($customer),OU=Customers,DC=$($($DomainParts)[0]),DC=$($($DomainParts)[1]),DC=$($($DomainParts)[2])" -ea:0 | out-null;
      new-adgroup -groupscope 1 -name "$($customer)-Admin-Accounts-Group" -path "OU=Groups,OU=$($customer),OU=Customers,DC=$($($DomainParts)[0]),DC=$($($DomainParts)[1]),DC=$($($DomainParts)[2])" -ea:0 | out-null;
      new-adgroup -groupscope 1 -name "$($customer)-User-Accounts-Group" -path "OU=Groups,OU=$($customer),OU=Customers,DC=$($($DomainParts)[0]),DC=$($($DomainParts)[1]),DC=$($($DomainParts)[2])" -ea:0 | out-null;

      foreach ($user in $users){;
        new-aduser -name "$($user)-$($cusshort)" -AccountPassword $args[1] -PasswordNeverExpires $true -userPrincipalName "$($Customer)-$($user)@$($args[0])" -EmailAddress "$($Customer)-$($user)@$($args[0])" -Office "Hoofddorp" -path "OU=User-Accounts,OU=$($customer),OU=Customers,DC=$($($DomainParts)[0]),DC=$($($DomainParts)[1]),DC=$($($DomainParts)[2])" -ea:0 | out-null;
        add-ADGroupMember  "$($customer)-User-Accounts-Group" "$($user)-$($cusshort)" -ea:0 | out-null;
      };
      foreach ($user in $names){;
        $first = $user.split(".")[0];
        $last = $user.split(".")[1];
        try {;
          if ($count2 -le 100){;
            new-aduser -name "$user" -Surname $last -givenname $first -AccountPassword $args[1] -PasswordNeverExpires $true -userPrincipalName "$($user)@$($args[0])" -displayname "$first $last" -Office "Hoofddorp" -EmailAddress "$($user)@$($args[0])" -path "OU=User-Accounts,OU=$($customer),OU=Customers,DC=$($($DomainParts)[0]),DC=$($($DomainParts)[1]),DC=$($($DomainParts)[2])";
            add-ADGroupMember  "$($customer)-User-Accounts-Group" "$user" -ea:0 | out-null;
            $count2 = $count2 + 1;
          };
        } catch {;
          $count2 = $count2 - 1;
        };
      };
      foreach ($serviceaccount in $ServiceAccounts){;
        new-aduser -name "$($serviceaccount)-$($cusshort)" -AccountPassword $args[1] -PasswordNeverExpires $true -userPrincipalName "$($serviceaccount)-$($cusshort)@$($args[0])" -path "OU=Service-Accounts,OU=$($customer),OU=Customers,DC=$($($DomainParts)[0]),DC=$($($DomainParts)[1]),DC=$($($DomainParts)[2])";
        add-ADGroupMember  "$($customer)-Service-Accounts-Group" "$($serviceaccount)-$($cusshort)" -ea:0 | out-null;
      };
      foreach ($adminaccount in $adminaccounts){;
        new-aduser -name "$($adminaccount)-$($cusshort)" -AccountPassword $args[1] -PasswordNeverExpires $true -userPrincipalName "$($adminaccount)-$($cusshort)@$($args[0])" -path "OU=Admin-Accounts,OU=$($customer),OU=Customers,DC=$($($DomainParts)[0]),DC=$($($DomainParts)[1]),DC=$($($DomainParts)[2])"
        add-ADGroupMember "$($customer)-Admin-Accounts-Group" "$($adminaccount)-$($cusshort)" -ea:0 | out-null;
      };

    };
    Get-ADUser -filter * | Enable-ADAccount -ea:0
    sleep 15
  } -args $domainname,$password,$sesplit,$DNSEntries,$seupn,$dcname
  sleep 15

  $Test = invoke-command -computername $ip -credential $credential { 
    Get-ADUser -filter * 
  } 
  return $test
}

Function PSR-ERA-ConfigureMSSQL {
  param (
    [string]$SysprepPassword,
    [string]$IP,
    [string]$clusername,
    [string]$clpassword,
    [string]$PEClusterIP,
    [string]$containername,
    [string]$Domainname,
    [string]$eraSQLservername,
    [string]$sename,
    [object]$datavar
  )
  write-log -message "Debug level is $debug";
  write-log -message "Building credential object";

  $password = $SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $LocalCreds = New-Object System.Management.Automation.PsCredential("administrator",$password);
  $DomainCreds = New-Object System.Management.Automation.PsCredential("$($Domainname)\administrator",$password);
  $netbios = ($domainname.split("."))[0]
  $se = $sename -replace (" ",'.')
  $sesplit = ($datavar.SenderEmail -split "@")[0]

  $finalizesuccess = $false
  $finalizecount = 0
  $createDBsuccess = $false
  $createDBcount = 0 
  $counttask = 0

  write-log -message "Executing Final ERA Script.";
 
  do{
    $finalizecount++
    write-log -message "Attempt $finalizecount"
    if ($finalizecount -ge 2){
      if($debug -ge 2){

        write-log -message "Debug Level dictates Panick, exiting."

        break
      }
    }
    try {
      $connect = invoke-command -computername $ip -credential $localcreds {
        $script = get-content C:\NTNX-Setup\completebuild.ps1
        $script2 = $script -replace "Stop", 'silentlycontinue'
        $script2 = $script2 -replace "Restart-Computer", 'write "i dont think so"'
        $script2 | out-file C:\NTNX-Setup\completebuild2.ps1
        $argumentList = "-file C:\NTNX-Setup\completebuild2.ps1 -ClusterIP $($args[0]) -UserName $($args[1]) -Password $($args[2]) -containername $($args[3])"
        $jobname = "PowerShell SQL Install";
        $action = New-ScheduledTaskAction -Execute "$pshome\powershell.exe" -Argument  "$argumentList";
        $trigger =New-ScheduledTaskTrigger -Once -At (Get-Date).Date
        #$principal = New-ScheduledTaskPrincipal -UserId "$($env:USERDOMAIN)\$($env:USERNAME)" -LogonType "Interactive"
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd;
        $task = Register-ScheduledTask -TaskName $jobname -Action $action -Trigger $trigger -Settings $settings -runlevel "Highest"
        #-User "administrator" -Password $($args[5]) 
        Get-ScheduledTask "PowerShell SQL Install" | start-scheduledtask


      } -args $PEClusterIP,$clusername,$clpassword,$containername,$debug,$SysprepPassword
      
      write-log -message "Executing scheduled task";

    } catch {

      write-log -message "Error Creating / Running scheduled task" -sev "ERROR";

      $connect = invoke-command -computername $ip -credential $localcreds {
        Get-ScheduledTask "PowerShell SQL Install" | Unregister-ScheduledTask
      } 
    };
    sleep 30
    try {
      do{
        $counttask++
        sleep 30
        $connect2 = invoke-command -computername $ip -credential $localcreds {
          Get-ScheduledTask "PowerShell SQL Install"
        }    
        if ($connect2.state -eq "4") {
          write-log -message "Task is not ready yet, current state is $($connect2.state), waiting 30 seconds for $counttask times out of 20"
        } else {
          write-log -message "Task is ready, checking results"
        }

      } until ($connect2.state -ne "4" -or $counttask -ge 20)
      $connect3 = invoke-command -computername $ip -credential $localcreds {
        Get-ScheduledTaskinfo "PowerShell SQL Install"
      }     
      if ($connect3.LastTaskResult -eq 0 -or ($connect3.LastTaskResult -eq 1 -and $counttask -ge 2)){
        $finalizesuccess = $true

        write-log -message "SQL Server is finalized with Exit with code $($connect3.LastTaskResult)";

        if ($connect3.LastTaskResult -eq 1){

          write-log -message "The script is known to error with exit 1 after a few cycles, the end result is validated.";

        }

      } else {

        write-log -message "Task Exit with code $($connect3.LastTaskResult)"

      }
    
    } catch {

      write-log -message "Error query task, i dont want to be here." -sev "ERROR";

    }
  } until ($finalizecount -ge 5 -or $finalizesuccess -eq $true)

  write-log -message "Allowing SQL Domain Logins";
  write-log -message "Creating explicit Sysadmin login for $($netbios)\$($se)"
  write-log -message "Creating explicit Sysadmin login for $($netbios)\Domain Admins"

  try{

    write-log -message "Adding Domain Admins"

    $connect4 = invoke-command -computername $ip -credential $localcreds {
      $cn2= new-object System.Data.SqlClient.SqlConnection "server=$($eraSQLservername);database=master;Integrated Security=sspi"
      $cn2.Open()
      $sql2 = $cn2.CreateCommand()
      $sql2.CommandText = @"

EXEC master..sp_addsrvrolemember @loginame = N'$($args[0])\Domain Admins', @rolename = N'sysadmin'

"@
      $rdr2 = $sql2.ExecuteReader()
      $cn2.Close()


      $cn2= new-object System.Data.SqlClient.SqlConnection "server=$($eraSQLservername);database=master;Integrated Security=sspi"
      $cn2.Open()
      $sql2 = $cn2.CreateCommand()
      $sql2.CommandText = @"

EXEC master..sp_addsrvrolemember @loginame = N'$($args[0])\$($args[1])', @rolename = N'sysadmin'

"@
      $rdr2 = $sql2.ExecuteReader()
      $cn2.Close()

      $hide = get-scheduledtask "test" -ea:0 | Unregister-ScheduledTask -confirm:0 -ea:0
      shutdown -r -t 5
    } -args $netbios,$sesplit

    write-log -message "Domain Logins granted, system reboot executed";

    $DomainLogin = $true

  } catch {

    write-log -message "Domain Login Error" -sev "ERROR";

  }

write-log -message "System is being rebooted";

sleep 90
 try{
    write-log -message "Creating Sample databases"
    
    $connect5 = invoke-command -computername $ip -credential $localcreds {
      invoke-sqlcmd -inputFile "C:\NTNX-Setup\RestoreWWIDatabases.sql" -QueryTimeout 1000
    } -args $netbios,$se

    write-log -message "Database create script executed";

    $Tables = $true

  } catch {

    write-log -message "Damn were too fast" -sev "WARN"

    sleep 110

    try{
      write-log -message "Creating Sample databases"
    
      $connect5 = invoke-command -computername $ip -credential $localcreds {
        invoke-sqlcmd -inputFile "C:\NTNX-Setup\RestoreWWIDatabases.sql" -QueryTimeout 1000
      } -args $netbios,$se

      write-log -message "Database create script executed";

      $Tables = $true

    } catch {

      write-log -message "Create databases Error" -sev "ERROR";

    }

  }

  try{
    write-log -message "Setting recoverymode new databases"

    $connect6 = invoke-command -computername $ip -credential $localcreds {
      Import-Module -Name SQLPS
      Get-ChildItem -Path SQLSERVER:\SQL\Localhost\DEFAULT\Databases |
      Where {$_.name -match "WideWorld" } |
      ForEach-Object {
        $_.RecoveryModel = 'Full'
        $_.Alter()
        $_.Refresh()
      }
    } 

    write-log -message "Recovery Mode set";

    $Recovery = $true

  } catch {

    write-log -message "Setting recoverymode Error" -sev "ERROR";

  }

  if ($finalizesuccess -eq $true -and $DomainLogin -eq $true -and $Tables -eq $true -and $Recovery -eq $true){
    $status = "Success"

    write-log -message "All Done here, full of DB Content";
    write-log -message "Please play with me.";

  } else {
    $status = "Failed"
    write-log -message "Danger Will Robbinson." -sev "ERROR";
  }
  $resultobject =@{
    Result = $status
  };
  return $resultobject
};


Function PSR-Join-Domain {
  param (
    [string]$SysprepPassword,
    [string]$IP,
    [string]$DNSServer,
    [string]$Domainname
  )
  write-log -message "Debug level is $debug";
  write-log -message "Building credential objects (2).";

  $password = $SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $LocalCreds = New-Object System.Management.Automation.PsCredential("administrator",$password);
  $DomainCreds = New-Object System.Management.Automation.PsCredential("$($Domainname)\administrator",$password);

  $installsuccess = $false
  $installcount = 0
  $promotesuccess = $false
  $promotecount = 0
  $Joincount = 0
  $JoinSuccess = $true

  write-log -message "Joining the machine to the domain.";
 
  do{
    $Joincount++
    write-log -message "How many times am i doing this $Joincount"
    try {
      if (-not (Test-Connection -ComputerName $IP -Quiet -Count 1)) {
      
        write-log -message "Could not reach $IP" -sev "WARN"
      
      } else {
      
        write-log -message "$IP is being added to domain $Domainname..."
      
        try {
          Add-Computer -ComputerName $IP -Domain $Domainname -restart -Localcredential $LocalCreds -credential $DomainCreds -force 

        } catch {
          
          sleep 70

          try {
            $connect = invoke-command -computername $ip -credential $DomainCreds {
              (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain
            } -ea:0
          }  catch {  
            write-log -message "I dont want to be here."
          }
        }
        while (Test-Connection -ComputerName $IP -Quiet -Count 1 -or $countrestart -le 30) {
          
          write-log -message "Machine is restarting"

          $countrestart++
          Start-Sleep -Seconds 2
          }
      
          write-log -message "$IP was added to domain $Domain..."
          sleep 20
       }

    } catch {

      write-log -message "Join domain almost always throws an error..."

      sleep 40
      try {
        $connect = invoke-command -computername $ip -credential $DomainCreds {
          (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain
        } -ea:0
      } catch {
        $connect = $false 
      }
      if ($connect -eq $true ){
        $Joinsucces = $true

        write-log -message "Machine Domain Join Confirmed"

      } else {

        write-log -message "If you can read this.. $Joincount"

      }
    };
    sleep 30
  } until ($Joincount -ge 3 -or $connect -eq $true)

  


  if ($Joinsucces -eq $true ){
    $status = "Success"

    write-log -message "All Done here, ready for some Content";
    write-log -message "Please pump me full of lead.";

  } else {
    $status = "Failed"
    write-log -message "Danger Will Robbinson." -sev "ERROR";
  }
  $resultobject =@{
    Result = $status
  };
  return $resultobject
};


Function PSR-Generate-FilesContent {
  param (
    [object]$datagen,
    [object]$datavar,
    [string]$dc
  )
  write-log -message "Debug level is $debug";
  write-log -message "Building credential object";

  $password = $datagen.SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $DomainCreds = New-Object System.Management.Automation.PsCredential("$($datagen.SEUPN)",$password);
  $username =  $datagen.SEUPN
  $password = $datagen.SysprepPassword
  write-log -message "Executing Files Content Generation.";
  write-log -message "This will take a while.";
  $fsname = "$($datagen.FS1_IntName)"
  write-log -message "Using File Server $fsname";
  $domainname = $datagen.domainname
    invoke-command -computername $dc -credential $DomainCreds {
    
      $username = $args[1]
      $password = $args[2]
      $domainname = $args[3]
      $fsname = $args[0]
      [ARRAY]$OUTPUT += [STRING]'start-transcript c:\windows\temp\content.log'
      [ARRAY]$OUTPUT += [STRING]'$Username = ' + '"' + $username + '"'
      [ARRAY]$OUTPUT += [STRING]'$password = ' + '"' + $password + '"'
      [ARRAY]$OUTPUT += [STRING]'$domainname = ' + '"' + $domainname + '"'
      [ARRAY]$OUTPUT += [STRING]'$fsname = ' + '"' + $fsname + '"'
      [ARRAY]$OUTPUT += [STRING]'$secpassword = $password | ConvertTo-SecureString -asplaintext -force;'
      [ARRAY]$OUTPUT += [STRING]'$DomainCreds = New-Object System.Management.Automation.PsCredential($Username,$secpassword);'
      [ARRAY]$OUTPUT += [STRING]'write "Content Indexing Starting"'
      [ARRAY]$OUTPUT += [STRING]'$Wavfiles = get-childitem -recurse "c:\*.wav" -ea:0'
      [ARRAY]$OUTPUT += [STRING]'write "Wav Files $($Wavfiles.count) Done, doing doc"'
      [ARRAY]$OUTPUT += [STRING]'$docfiles = get-childitem -recurse "c:\*.doc" -ea:0'
      [ARRAY]$OUTPUT += [STRING]'write "doc Files $($docfiles.count) Done, doing jpg"'
      [ARRAY]$OUTPUT += [STRING]'$jpgfiles = get-childitem -recurse "c:\*.jpg" -ea:0'
      [ARRAY]$OUTPUT += [STRING]'write "JPG Files $($jpgfiles.count) Done, doing cab"'
      [ARRAY]$OUTPUT += [STRING]'$Cabfiles = get-childitem -recurse "c:\*.cab" -ea:0 | select -first 20'
      [ARRAY]$OUTPUT += [STRING]'write "CAB Files $($Cabfiles.count) Done, doing zip"'
      [ARRAY]$OUTPUT += [STRING]'$zipfiles = get-childitem -recurse "c:\*.zip" -ea:0'
      [ARRAY]$OUTPUT += [STRING]'write "Zip Files $($zipfiles.count) Done, doing Txt"'
      [ARRAY]$OUTPUT += [STRING]'$txtfiles = get-childitem -recurse "c:\*.txt" -ea:0'
      [ARRAY]$OUTPUT += [STRING]'write "TXT Files $($txtfiles.count) Done, doing AVI"'
      [ARRAY]$OUTPUT += [STRING]'$avifiles = get-childitem -recurse "c:\*.avi" -ea:0'
      [ARRAY]$OUTPUT += [STRING]'write "Content Indexing Completed, $($avifiles.count)"'
      [ARRAY]$OUTPUT += [STRING]'Get-ADUser -Filter * | Foreach-Object{'
      [ARRAY]$OUTPUT += [STRING]'  $user = $_'
      [ARRAY]$OUTPUT += [STRING]'  $sam = $_.SamAccountName'
      [ARRAY]$OUTPUT += [STRING]'  write "Working on $sam"'
      [ARRAY]$OUTPUT += [STRING]'  Set-ADuser -Identity $_ -HomeDrive "H:" -HomeDirectory "\\$($fsname)\$sam" -ea:0'
      [ARRAY]$OUTPUT += [STRING]'  $homeShare = new-item -path "\\$($fsname)\UserHome\$sam" -ItemType Directory -force'
      [ARRAY]$OUTPUT += [STRING]'  $acl = Get-Acl $homeShare -ea:0'
      [ARRAY]$OUTPUT += [STRING]'  $FileSystemRights = [System.Security.AccessControl.FileSystemRights]"Modify"'
      [ARRAY]$OUTPUT += [STRING]'  $AccessControlType = [System.Security.AccessControl.AccessControlType]::Allow'
      [ARRAY]$OUTPUT += [STRING]'  $InheritanceFlags = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"'
      [ARRAY]$OUTPUT += [STRING]'  $PropagationFlags = [System.Security.AccessControl.PropagationFlags]"InheritOnly"'
      [ARRAY]$OUTPUT += [STRING]'  $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule ($User.SID, $FileSystemRights, $InheritanceFlags, $PropagationFlags, $AccessControlType)'
      [ARRAY]$OUTPUT += [STRING]'  $acl.AddAccessRule($AccessRule)'
      [ARRAY]$OUTPUT += [STRING]'  Set-Acl -Path $homeShare -AclObject $acl -ea:0'
      [ARRAY]$OUTPUT += [STRING]'  foreach ($file in $Wavfiles){'
      [ARRAY]$OUTPUT += [STRING]'    [int]$number =get-random -max 3'
      [ARRAY]$OUTPUT += [STRING]'    [int]$count = 0'
      [ARRAY]$OUTPUT += [STRING]'    do {'
      [ARRAY]$OUTPUT += [STRING]'      [int]$count++'
      [ARRAY]$OUTPUT += [STRING]'      $targetfilename = Get-Random'
      [ARRAY]$OUTPUT += [STRING]'      copy-item "$($file.fullname)" "\\$($fsname)\UserHome\$($sam)\$($targetfilename).wav"'
      [ARRAY]$OUTPUT += [STRING]'    } until ([int]$count -ge [int]$number)'
      [ARRAY]$OUTPUT += [STRING]'  }'
      [ARRAY]$OUTPUT += [STRING]'  foreach ($file in $cabfiles){'
      [ARRAY]$OUTPUT += [STRING]'    [int]$number =get-random -max 10'
      [ARRAY]$OUTPUT += [STRING]'    [int]$count = 0'
      [ARRAY]$OUTPUT += [STRING]'    do {'
      [ARRAY]$OUTPUT += [STRING]'      [int]$count++'
      [ARRAY]$OUTPUT += [STRING]'      $targetfilename = Get-Random'
      [ARRAY]$OUTPUT += [STRING]'      copy-item "$($file.fullname)" "\\$($fsname)\UserHome\$($sam)\$($targetfilename).cab"'
      [ARRAY]$OUTPUT += [STRING]'    } until ([int]$count -ge [int]$number)'
      [ARRAY]$OUTPUT += [STRING]'  }'
      [ARRAY]$OUTPUT += [STRING]'  foreach ($file in $docfiles){'
      [ARRAY]$OUTPUT += [STRING]'    [int]$number =get-random -max 50'
      [ARRAY]$OUTPUT += [STRING]'    [int]$count = 0'
      [ARRAY]$OUTPUT += [STRING]'    do {'
      [ARRAY]$OUTPUT += [STRING]'      [int]$count++'
      [ARRAY]$OUTPUT += [STRING]'      $targetfilename = Get-Random'
      [ARRAY]$OUTPUT += [STRING]'      copy-item "$($file.fullname)" "\\$($fsname)\UserHome\$($sam)\$($targetfilename).doc"'
      [ARRAY]$OUTPUT += [STRING]'    } until ([int]$count -ge [int]$number)'
      [ARRAY]$OUTPUT += [STRING]'  }'
      [ARRAY]$OUTPUT += [STRING]'  foreach ($file in $jpgfiles){'
      [ARRAY]$OUTPUT += [STRING]'    [int]$number =get-random -max 19'
      [ARRAY]$OUTPUT += [STRING]'    [int]$count = 0'
      [ARRAY]$OUTPUT += [STRING]'    do {'
      [ARRAY]$OUTPUT += [STRING]'      [int]$count++'
      [ARRAY]$OUTPUT += [STRING]'      $targetfilename = Get-Random'
      [ARRAY]$OUTPUT += [STRING]'      copy-item "$($file.fullname)" "\\$($fsname)\UserHome\$($sam)\$($targetfilename).jpg"'
      [ARRAY]$OUTPUT += [STRING]'    } until ([int]$count -ge [int]$number)'
      [ARRAY]$OUTPUT += [STRING]'  }'
      [ARRAY]$OUTPUT += [STRING]'  foreach ($file in $zipfiles){'
      [ARRAY]$OUTPUT += [STRING]'    [int]$number =get-random -max 20'
      [ARRAY]$OUTPUT += [STRING]'    [int]$count = 0'
      [ARRAY]$OUTPUT += [STRING]'    do {'
      [ARRAY]$OUTPUT += [STRING]'      [int]$count++'
      [ARRAY]$OUTPUT += [STRING]'      $targetfilename = Get-Random'
      [ARRAY]$OUTPUT += [STRING]'      copy-item "$($file.fullname)" "\\$($fsname)\UserHome\$($sam)\$($targetfilename).zip"'
      [ARRAY]$OUTPUT += [STRING]'    } until ([int]$count -ge [int]$number)'
      [ARRAY]$OUTPUT += [STRING]'  }'
      [ARRAY]$OUTPUT += [STRING]'  foreach ($file in $txtfiles){'
      [ARRAY]$OUTPUT += [STRING]'    [int]$number =get-random -max 20'
      [ARRAY]$OUTPUT += [STRING]'    [int]$count = 0'
      [ARRAY]$OUTPUT += [STRING]'    do {'
      [ARRAY]$OUTPUT += [STRING]'      [int]$count++'
      [ARRAY]$OUTPUT += [STRING]'      $targetfilename = Get-Random'
      [ARRAY]$OUTPUT += [STRING]'      copy-item "$($file.fullname)" "\\$($fsname)\UserHome\$($sam)\$($targetfilename).txt"'
      [ARRAY]$OUTPUT += [STRING]'    } until ([int]$count -ge [int]$number)'
      [ARRAY]$OUTPUT += [STRING]'  }'
      [ARRAY]$OUTPUT += [STRING]'  foreach ($file in $avifiles){'
      [ARRAY]$OUTPUT += [STRING]'    [int]$number =get-random -max 30'
      [ARRAY]$OUTPUT += [STRING]'    [int]$count = 0'
      [ARRAY]$OUTPUT += [STRING]'    do {'
      [ARRAY]$OUTPUT += [STRING]'      [int]$count++'
      [ARRAY]$OUTPUT += [STRING]'      $targetfilename = Get-Random'
      [ARRAY]$OUTPUT += [STRING]'      copy-item "$($file.fullname)" "\\$($fsname)\UserHome\$($sam)\$($targetfilename).avi"'
      [ARRAY]$OUTPUT += [STRING]'    } until ([int]$count -ge [int]$number)'
      [ARRAY]$OUTPUT += [STRING]'  }'
      [ARRAY]$OUTPUT += [STRING]'}'
      [ARRAY]$OUTPUT += [STRING]''
      [ARRAY]$OUTPUT += [STRING]'[array]$array += "Finance"'
      [ARRAY]$OUTPUT += [STRING]'[array]$array += "IT"'
      [ARRAY]$OUTPUT += [STRING]'[array]$array += "HR"'
      [ARRAY]$OUTPUT += [STRING]'[array]$array += "Factory"'
      [ARRAY]$OUTPUT += [STRING]'[array]$array += "RnD"'
      [ARRAY]$OUTPUT += [STRING]'[array]$array += "Management"'
      [ARRAY]$OUTPUT += [STRING]'foreach ($item in $array){'
      [ARRAY]$OUTPUT += [STRING]'  copy-item -type "Directory" "\\$($fsname)\Department\$item"'
      [ARRAY]$OUTPUT += [STRING]'  foreach ($file in $Wavfiles){'
      [ARRAY]$OUTPUT += [STRING]'    $count =0'
      [ARRAY]$OUTPUT += [STRING]'    $number =get-random -max 100'
      [ARRAY]$OUTPUT += [STRING]'    do {'
      [ARRAY]$OUTPUT += [STRING]'      $count++'
      [ARRAY]$OUTPUT += [STRING]'      $targetfilename = Get-Random'
      [ARRAY]$OUTPUT += [STRING]'      write $targetfilename'
      [ARRAY]$OUTPUT += [STRING]'      copy-item "$($file.fullname)" "\\$($fsname)\Department\$item\$($targetfilename).wav"'
      [ARRAY]$OUTPUT += [STRING]'    } until ($count -ge $number)'
      [ARRAY]$OUTPUT += [STRING]'  }'
      [ARRAY]$OUTPUT += [STRING]'  $count =0'
      [ARRAY]$OUTPUT += [STRING]'  foreach ($file in $docfiles){'
      [ARRAY]$OUTPUT += [STRING]'    $count =0'
      [ARRAY]$OUTPUT += [STRING]'    $number =get-random -max 100'
      [ARRAY]$OUTPUT += [STRING]'    do {'
      [ARRAY]$OUTPUT += [STRING]'      $count++'
      [ARRAY]$OUTPUT += [STRING]'      $targetfilename = Get-Random'
      [ARRAY]$OUTPUT += [STRING]'      write $targetfilename'
      [ARRAY]$OUTPUT += [STRING]'      copy-item "$($file.fullname)" "\\$($fsname)\Department\$item\$($targetfilename).doc"'
      [ARRAY]$OUTPUT += [STRING]'    } until ($count -ge $number)'
      [ARRAY]$OUTPUT += [STRING]'  }'
      [ARRAY]$OUTPUT += [STRING]'  foreach ($file in $jpgfiles){'
      [ARRAY]$OUTPUT += [STRING]'    $count =0'
      [ARRAY]$OUTPUT += [STRING]'    $number =get-random -max 100'
      [ARRAY]$OUTPUT += [STRING]'    do {'
      [ARRAY]$OUTPUT += [STRING]'      $count++'
      [ARRAY]$OUTPUT += [STRING]'      $targetfilename = Get-Random'
      [ARRAY]$OUTPUT += [STRING]'      write $targetfilename'
      [ARRAY]$OUTPUT += [STRING]'      copy-item "$($file.fullname)" "\\$($fsname)\Department\$item\$($targetfilename).jpg"'
      [ARRAY]$OUTPUT += [STRING]'    } until ($count -ge $number)'
      [ARRAY]$OUTPUT += [STRING]'  }'
      [ARRAY]$OUTPUT += [STRING]'  foreach ($file in $Cabfiles){'
      [ARRAY]$OUTPUT += [STRING]'    $count =0'
      [ARRAY]$OUTPUT += [STRING]'    $number =get-random -max 100'
      [ARRAY]$OUTPUT += [STRING]'    do {'
      [ARRAY]$OUTPUT += [STRING]'      $count++'
      [ARRAY]$OUTPUT += [STRING]'      $targetfilename = Get-Random'
      [ARRAY]$OUTPUT += [STRING]'      write $targetfilename'
      [ARRAY]$OUTPUT += [STRING]'      copy-item "$($file.fullname)" "\\$($fsname)\Department\$item\$($targetfilename).cab"'
      [ARRAY]$OUTPUT += [STRING]'    } until ($count -ge $number)'
      [ARRAY]$OUTPUT += [STRING]'  }'
      [ARRAY]$OUTPUT += [STRING]'  foreach ($file in $zipfiles){'
      [ARRAY]$OUTPUT += [STRING]'    $count =0'
      [ARRAY]$OUTPUT += [STRING]'    $number =get-random -max 100'
      [ARRAY]$OUTPUT += [STRING]'    do {'
      [ARRAY]$OUTPUT += [STRING]'      $count++'
      [ARRAY]$OUTPUT += [STRING]'      $targetfilename = Get-Random'
      [ARRAY]$OUTPUT += [STRING]'      write $targetfilename'
      [ARRAY]$OUTPUT += [STRING]'      copy-item "$($file.fullname)" "\\$($fsname)\Department\$item\$($targetfilename).zip"'
      [ARRAY]$OUTPUT += [STRING]'    } until ($count -ge $number)'
      [ARRAY]$OUTPUT += [STRING]'  }'
      [ARRAY]$OUTPUT += [STRING]'  foreach ($file in $txtfiles){'
      [ARRAY]$OUTPUT += [STRING]'    $count =0'
      [ARRAY]$OUTPUT += [STRING]'    $number =get-random -max 100'
      [ARRAY]$OUTPUT += [STRING]'    do {'
      [ARRAY]$OUTPUT += [STRING]'      $count++'
      [ARRAY]$OUTPUT += [STRING]'      $targetfilename = Get-Random'
      [ARRAY]$OUTPUT += [STRING]'      copy-item "$($file.fullname)" "\\$($fsname)\Department\$item\$($targetfilename).txt"'
      [ARRAY]$OUTPUT += [STRING]'    } until ($count -ge $number)'
      [ARRAY]$OUTPUT += [STRING]'  }'
      [ARRAY]$OUTPUT += [STRING]'  foreach ($file in $avifiles){'
      [ARRAY]$OUTPUT += [STRING]'    $count =0'
      [ARRAY]$OUTPUT += [STRING]'    $number =get-random -max 100'
      [ARRAY]$OUTPUT += [STRING]'    do {'
      [ARRAY]$OUTPUT += [STRING]'      $count++'
      [ARRAY]$OUTPUT += [STRING]'      $targetfilename = Get-Random'
      [ARRAY]$OUTPUT += [STRING]'      copy-item "$($file.fullname)" "\\$($fsname)\Department\$item\$($targetfilename).avi"'
      [ARRAY]$OUTPUT += [STRING]'    } until ($count -ge $number)'
      [ARRAY]$OUTPUT += [STRING]'  }'
      [ARRAY]$OUTPUT += [STRING]'}'
      $OUTPUT | OUT-FILE C:\windows\temp\content.ps1
      $argumentList = "-file C:\Windows\Temp\Content.ps1"
      $jobname = "PowerShell Content Generate";
      $action = New-ScheduledTaskAction -Execute "$pshome\powershell.exe" -Argument  "$argumentList";
      $trigger =New-ScheduledTaskTrigger -Once -At (Get-Date).Date
      $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd;
      $SecurePassword = $password | ConvertTo-SecureString -AsPlainText -Force
      #$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword
      #$CredPassword = $Credentials.GetNetworkCredential().Password 
      $task = Register-ScheduledTask -TaskName $jobname -Action $action -Trigger $trigger -Settings $settings -runlevel "Highest" -User $username -Password $password
      # 
      Get-ScheduledTask "PowerShell Content Generate" | start-scheduledtask
      sleep 60
      Get-ScheduledTask "PowerShell Content Generate" | start-scheduledtask

    } -args $FSname,$username,$password,$domainname
  $counter = 0
  write-log -message "Tailing the log from the remote session to capture success"

     $status = "Success"
 



  write-log -message "All Done here, full of File Content";
  write-log -message "Please play with me.";

  $resultobject =@{
    Result = $status
  };
  return $resultobject
};


Function Wait-Mgt-Task{
  param(
    $datavar
  )
  write-log -message "Wait for Management Task with ID $($datavar.queueuuid)"
  do {
    $Looper++
    try{
      [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^mgmtVM" }
    } catch {
      try {
        [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^mgmtVM" }
      } catch {}
    }

    write-log -message "We found $($tasks.count) task";

    [array] $allready = $null
    write-log "Cycle $looper out of 200"
    if ($tasks){
      Foreach ($task in $tasks){
        if ($task.state -eq "ready"){
    
          write-log -message "Task $($task.taskname) is ready."
    
          $allReady += 1
      
        } else {
      
          $allReady += 0

          write-log -message "Task $($task.taskname) is $($task.state)."
      
        };
      };
      sleep 60
    } else {
      $allReady = 0
      # Dont ever change this or ERA will start too soon
      write-log -message "There are no jobs to process."
      sleep 60
    }
  } until ($Looper -ge 200 -or $allReady -notcontains 0)
}


Function Wait-Image-Task{
  param(
    $datavar
  )
  write-log -message "Wait for Immage Convert Task with ID $($datavar.queueuuid)"
  do {
    $Looper++
    try{
      [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^WaitImage" }
    } catch {
      try {
        [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^WaitImage" }
      } catch {}
    }

    write-log -message "We found $($tasks.count) task";

    [array] $allready = $null
    write-log "Cycle $looper out of 200"
    if ($tasks){
      Foreach ($task in $tasks){
        if ($task.state -eq "ready"){
    
          write-log -message "Task $($task.taskname) is ready."
    
          $allReady += 1
      
        } else {
      
          $allReady += 0

          write-log -message "Task $($task.taskname) is $($task.state)."
      
        };
      };
      sleep 60
    } else {
      $allReady = 0

      write-log -message "There are no jobs to process."
      sleep 60
    }
  } until ($Looper -ge 200 -or $allReady -notcontains 0)
}

Function Wait-ESX-OVF-Task{
  param(
    $datavar
  )
  write-log -message "Wait for OVF Task with ID $($datavar.queueuuid)"
  do {
    $Looper++
    try{
      CMD-Connect-VMware -datavar $datavar
      $tasks = get-task | where {$_.name -eq "Deploy OVF template"}
    } catch {
      try {
        CMD-Connect-VMware -datavar $datavar
        $tasks = get-task | where {$_.name -eq "Deploy OVF template"}
      } catch {}
    }

    write-log -message "We found $($tasks.count) OVF Deploy task(s)";

    [array] $allready = $null
    write-log "Cycle $looper out of 200"
    if ($tasks){
      Foreach ($task in $tasks){
        if ($task.finishtime -eq $null){
          $timeago = 0
        } else {
          $timeago = (new-timespan -start $task.FinishTime -End (get-date) -ea:0).TotalMinutes
        }
        
        if ($task.state -ne "Running" -and $timeago -le 2){
    
          write-log -message "Task $($task.name) is $($task.state)."
    
          $allReady += 1
      
        } else {
      
          $allReady += 0

          
          if ($task.state -eq "Succcess"){

            write-log -message "Task $($task.name) is $($task.state), Task Finished before i started, it finished $timeago minutes ago."

          } else {

            write-log -message "Task $($task.name) is $($task.state). Task is Running. This is probobally it."

          }
        };
      };
      sleep 60
    } else {
      $allReady = 0
      $looper = $looper + 10
      sleep 30
      write-log -message "There are no jobs to process. Increasing loop counter $Looper / 60"

    }
  } until ($Looper -ge 100 -or $allReady -notcontains 0)
}

Function Wait-POSTPC-Task{
  param(
    $datavar
  )
  write-log -message "Wait for POST PC Task with ID $($datavar.queueuuid)"
  do {
    $Looper++
    try{
      [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^POSTPC" }
    } catch {
      try {
        [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^POSTPC" }
      } catch {}
    }
    if ($Looper % 4 -eq 0){
      write-log -message "We found $($tasks.count) task";
    }
    [array] $allready = $null
    if ($Looper % 4 -eq 0){
      write-log "Cycle $looper out of 200"
    }
    if ($tasks){
      Foreach ($task in $tasks){
        if ($task.state -eq "ready"){
          
          if ($Looper % 4 -eq 0){
            write-log -message "Task $($task.taskname) is ready."
          }
          $allReady += 1
      
        } else {
      
          $allReady += 0

          if ($Looper % 4 -eq 0){
            write-log -message "Task $($task.taskname) is $($task.state)."
          }
        };
      };
      sleep 60
    } else {
      $allReady = 0
      sleep 60
      if ($Looper % 4 -eq 0){
        write-log -message "There are no jobs to process."
      }
    }
  } until ($Looper -ge 200 -or $allReady -notcontains 0)
}

Function Wait-MySQL-Task{
  param(
    $datavar
  )
  write-log -message "Wait for MySQL Task with ID $($datavar.queueuuid), OVF is single threaded. If MySQL is running ERA OVF is done"
  do {
    $Looper++
    try{
      [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^ERA_MySQL" }
    } catch {
      try {
        [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^ERA_MySQL" }
      } catch {}
    }
    if ($Looper % 4 -eq 0){
      write-log -message "We found $($tasks.count) task";
    }
    [array] $allready = $null
    if ($Looper % 4 -eq 0){
      write-log "Cycle $looper out of 200"
    }
    if ($tasks){
      Foreach ($task in $tasks){
        if ($task.state -eq "ready"){
          
          if ($Looper % 4 -eq 0){
            write-log -message "Task $($task.taskname) is ready."
          }
          $allReady += 1
      
        } else {
      
          $allReady += 1

          if ($Looper % 4 -eq 0){
            write-log -message "Task $($task.taskname) is $($task.state)."
          }
        };
      };
      sleep 60
    } else {
      $allReady = 0
      sleep 60
      if ($Looper % 4 -eq 0){
        write-log -message "There are no jobs to process."
      }
    }
  } until ($Looper -ge 200 -or $allReady -notcontains 0)
}


Function Wait-XRAY-Task{
  param(
    $datavar
  )
  write-log -message "Wait for XRAY Task with ID $($datavar.queueuuid), OVF is single threaded."
  do {
    $Looper++
    try{
      [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^X-Ray" }
    } catch {
      try {
        [array]$tasks = Get-ScheduledTask | where {$_.taskname -match $datavar.queueuuid -and $_.taskname -match "^X-Ray" }
      } catch {}
    }
    if ($Looper % 4 -eq 0){
      write-log -message "We found $($tasks.count) task";
    }
    [array] $allready = $null
    if ($Looper % 4 -eq 0){
      write-log "Cycle $looper out of 200"
    }
    if ($tasks){
      Foreach ($task in $tasks){
        if ($task.state -eq "ready"){
          
          if ($Looper % 4 -eq 0){
            write-log -message "Task $($task.taskname) is ready."
          }
          $allReady += 1
      
        } else {
      
          $allReady += 0

          if ($Looper % 4 -eq 0){
            write-log -message "Task $($task.taskname) is $($task.state)."
          }
        };
      };
      sleep 60
    } else {
      $allReady = 0
      sleep 60
      if ($Looper % 4 -eq 0){
        write-log -message "There are no jobs to process."
      }
    }
  } until ($Looper -ge 200 -or $allReady -notcontains 0)
}

Function Wait-LCM-Task{
  param(
    $datagen,
    $datavar,
    [int]$modecounter = 15,
    [string] $taskid = $null
  )
  do {
    try{
      $counter++
      write-log -message "Wait for LCM Task Cycle $counter out of $($modecounter)(minutes)."
  
      $tasks = REST-PE-ProgressMonitor -datagen $datagen -datavar $datavar -mode "PC" 
      $LCMTasks = $tasks.entities | where { $_.operation -eq "LcmRootTask"} 
      $Inventorycount = 0
      [array]$Results = $null
      foreach ($item in $LCMTasks){
        if ( $item.percentageCompleted -eq 100) {
          $Results += "Done"
   
          write-log -message "LCM Task $($item.id) is completed."
        } elseif ($item.percentageCompleted -ne 100){
          $Inventorycount ++
  
          write-log -message "LCM Task $($item.id) is still running."
          write-log -message "We found 1 LCM task $($item.status) and is $($item.percentageCompleted) % complete"
  
          $Results += "BUSY"
  
        }
      }
      if ($Results -notcontains "BUSY" -or !$LCMTasks){

        write-log -message "Task is done."
   
        $Inventorycheck = "Success"
   
      } else{
        sleep 60
      }
  
    }catch{
      write-log -message "Error caught in loop."
    }
  } until ($Inventorycheck -eq "Success" -or $counter -ge $modecounter)
  $task = $LCMTasks | sort createTimeUsecs | select -last 1
  return $task
}

Function Wait-AHV-Upgrade{
  param(
    $datagen,
    $datavar
  )
  write-log -message "Checking Upgrade status"
  $installcounter = 0
  do{
    [array]$notready = $null
    $installcounter++
    sleep 60
    try{
      $tasks = REST-Get-AOS-LegacyTask -datagen $datagen -datavar $datavar
  
      write-log -message "We found $($tasks.entities.count) total tasks"
      write-log -message "Waiting $installcounter out of 60 for AHV Upgrade"
  
      $upgrades = $tasks.entities | where {$_.operation -eq "upgrade_hypervisor"}

      write-log -message "We found $($upgrades.count) Upgrade tasks"
      foreach ($upgrade in $upgrades){

        write-log -message "AHV Upgrade is $($upgrade.status) at $($upgrade.percentageCompleted) %"

        if ($upgrade.status -eq "Running"){
          $notready += 1
        } 
      }
    } catch {
      $notready += 1
      write-log -message "I Should not be here, or CVM is restarting" -sev "warn"
    }
  } until (($notready -eq $null) -or $installcounter -ge 60)
  sleep 60
}

Function PSR-Reboot-PC {
  param (
    [object] $datagen,
    [object] $datavar
  )
  
  write-log -message "Rebooting PC" -SEV "WARN"
  if ($datavar.Hypervisor -match "Nutanix|AHV"){
    $hide = LIB-Connect-PSNutanix -ClusterName $datavar.PEClusterIP -NutanixClusterUsername $datagen.buildaccount -NutanixClusterPassword $datavar.PEPass
    $hide = get-ntnxvm | where {$_.vmname -match "^PC"} | Set-NTNXVMPowerState -transition "ACPI_REBOOT" -ea:0    
  } else {
    $hide = CMD-Connect-VMware -datavar $datavar
    $hide = get-vm | Where {$_.name -match "^PC" } | restart-vm -confirm:0 -ea:0
  }
 
  $rebootsleeper = 0
  do {
    $rebootsleeper ++
    sleep 115
    write-log -message "Keep Calm : $rebootsleeper / 8 "
  } until ($rebootsleeper -ge 8)
}

Function PSR-LCM-ListUpdates-PC {
  param (
    $datagen,
    $datavar,
    $minimalupdates = 1
  )
  write-log -message "Working with update requirement of $minimalupdates updates."
  $maxgroupcallLoops = 3
  
  $groupcall = 0
  $AvailableUpdatesList = $null
  $InstalledSoftwareList = $null
  
  $groupcall = 0
  do {
    $groupcall ++
    sleep 10
    if ($minimalupdates -eq 0){
      $AvailableUpdatesGroup = REST-LCMV2-Query-Updates -datagen $datagen -datavar $datavar -mode "PC" -silent $true
    } else {
      $AvailableUpdatesGroup = REST-LCMV2-Query-Updates -datagen $datagen -datavar $datavar -mode "PC"
    }
    $ExistingSoftwareGroup = REST-LCMV2-Query-Versions -datagen $datagen -datavar $datavar -mode "PC"
  } until (($result.group_results.entity_results.count -ge $minimalupdates -and $names.group_results.entity_results.count -ge $minimalupdates) -or $groupcall -ge $maxgroupcallLoops)
  
  $UUIDS = ($ExistingSoftwareGroup.group_results.entity_results.data | where {$_.name -eq "uuid"}).values.values
  
  write-log -message "Getting Installed Software"
  
  foreach ($app in $UUIDS){
    $nodeUUID = (((($ExistingSoftwareGroup.group_results.entity_results | where {$_.data.values.values -eq $app}).data | where {$_.name -eq "location_id"}).values.values | select -last 1) -split ":")[1]
    $PHhost = $hosts.entities | where {$_.uuid -match $nodeuuid}
    $Entity = [PSCustomObject]@{
      Version     = (($ExistingSoftwareGroup.group_results.entity_results | where {$_.data.values.values -eq $app}).data | where {$_.name -eq "version"}).values.values | select -last 1
      Class       = (($ExistingSoftwareGroup.group_results.entity_results | where {$_.data.values.values -eq $app}).data | where {$_.name -eq "entity_class"}).values.values | select -last 1
      Name        = (($ExistingSoftwareGroup.group_results.entity_results | where {$_.data.values.values -eq $app}).data | where {$_.name -eq "entity_model"}).values.values | select -last 1
      SoftwareUUID= $app
    }
    [array]$InstalledSoftwareList += $entity     
  }  
  
  write-log -message "Building Update table"
  
  foreach ($app in $UUIDs){
    $version = (($AvailableUpdatesGroup.group_results.entity_results | where {$_.data.values.values -eq $app}).data | where {$_.name -eq "version"}).values.values | select -last 1
    $nodeUUID = (((($ExistingSoftwareGroup.group_results.entity_results | where {$_.data.values.values -eq $app}).data | where {$_.name -eq "location_id"}).values.values | select -last 1) -split ":")[1]
    $PHhost = $hosts.entities | where {$_.uuid -match $nodeuuid}
    $Entity = [PSCustomObject]@{
      SoftwareUUID= $app
      Version     = $version
      Class       = (($AvailableUpdatesGroup.group_results.entity_results | where {$_.data.values.values -eq $app}).data | where {$_.name -eq "entity_class"}).values.values | select -last 1
      Name        = (($ExistingSoftwareGroup.group_results.entity_results | where {$_.data.values.values -eq $app}).data | where {$_.name -eq "entity_model"}).values.values | select -last 1
    }
    [array]$AvailableUpdatesList += $entity     
  }

  $Output = [PSCustomObject]@{
    AvailableUpdatesList        = $AvailableUpdatesList
    InstalledSoftwareList       = $InstalledSoftwareList
    Updatecount                 = $AvailableUpdatesGroup.total_entity_count
  }
  return $Output
}


Function Wait-PE-Reboot-Task{
  param(
    $datagen,
    $datavar,
    [int]$modecounter = 45
  )
  do {
    try{
      $counter++
      write-log -message "Wait for LCM Task Cycle $counter out of $($modecounter)(minutes)."
  
      $tasks = REST-PE-ProgressMonitor -datagen $datagen -datavar $datavar -mode "PE" 
      $LCMTasks = $tasks.entities | where { $_.operation -eq "Hypervisor rolling restart"} 
      $RebootCount = 0
      [array]$Results = $null
      foreach ($item in $LCMTasks){
        if ( $item.percentageCompleted -eq 100) {
          $Results += "Done"
   
          write-log -message "PE Reboot Task $($item.id) is completed."
        } elseif ($item.percentageCompleted -ne 100){
          $RebootCount ++
  
          write-log -message "PE Reboot Task $($item.id) is still running."
          write-log -message "We found 1 PE Reboot Task $($item.status) and is $($item.percentageCompleted) % complete"
  
          $Results += "BUSY"
  
        }
      }
      if ($Results -notcontains "BUSY" -or !$LCMTasks){

        write-log -message "Task is done."
   
        $Reboot = "Success"
   
      } else{
        sleep 60
      }
  
    }catch{
      write-log -message "Error caught in loop."
    }
  } until ($Reboot -eq "Success" -or $counter -ge $modecounter)
  $task = $LCMTasks |sort createdtimeusecs | select -last 1
  return $task
}

Function PSR-Install-NGT {
  param (
    [object]$datagen,
    [object]$datavar,
    [string]$ip
  )
  write-log -message "Debug level is $debug";
  write-log -message "Building credential object";


  $username = "administrator"
  $password = $datagen.SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $Creds = New-Object System.Management.Automation.PsCredential($username,$password);
  $password = $datagen.SysprepPassword
  invoke-command -computername $ip -credential $creds {
    $username = $args[0]
    $password = $args[1]

    [ARRAY]$OUTPUT += [STRING]'$driveletter = (Get-CimInstance Win32_LogicalDisk | ?{ $_.DriveType -eq 5} | select DeviceID).deviceid'
    [ARRAY]$OUTPUT += [STRING]'& "$($driveletter)\setup.exe" /quiet ACCEPTEULA=yes /norestart'
    $OUTPUT | OUT-FILE C:\windows\temp\NGT.ps1
    $argumentList = "-file C:\Windows\Temp\NGT.ps1"
    $jobname = "PowerShell NGT Install";
    $action = New-ScheduledTaskAction -Execute "$pshome\powershell.exe" -Argument  "$argumentList";
    $trigger =New-ScheduledTaskTrigger -Once -At (Get-Date).Date
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd;
    $SecurePassword = $password | ConvertTo-SecureString -AsPlainText -Force
    $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword
    $CredPassword = $Credentials.GetNetworkCredential().Password 
    $task = Register-ScheduledTask -TaskName $jobname -Action $action -Trigger $trigger -Settings $settings -runlevel "Highest" -User "administrator" -Password $CredPassword
    # 
    Get-ScheduledTask $jobname | start-scheduledtask
  } -args $username,$password
  $status = "Success"

  write-log -message "All Done here, NGT Done";

  $resultobject =@{
    Result = $status
  };
  return $resultobject
};


Function PSR-Install-FrameAgent {
  param (
    [object]$datagen,
    [object]$datavar,
    [string]$ip
  )
  write-log -message "Debug level is $debug";
  write-log -message "Building credential object";


  $username = "administrator"
  $password = $datagen.SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $Creds = New-Object System.Management.Automation.PsCredential($username,$password);
  $password = $datagen.SysprepPassword
  invoke-command -computername $ip -credential $creds {
    $username = $args[0]
    $password = $args[1]

    [ARRAY]$OUTPUT += [STRING]'$driveletter = (Get-CimInstance Win32_LogicalDisk | ?{ $_.DriveType -eq 5} | select DeviceID).deviceid'
    [ARRAY]$OUTPUT += [STRING]'& "$($driveletter)\setup.exe" /quiet ACCEPTEULA=yes /norestart'
    $OUTPUT | OUT-FILE C:\windows\temp\NGT.ps1
    $argumentList = "-file C:\Windows\Temp\NGT.ps1"
    $jobname = "PowerShell NGT Install";
    $action = New-ScheduledTaskAction -Execute "$pshome\powershell.exe" -Argument  "$argumentList";
    $trigger =New-ScheduledTaskTrigger -Once -At (Get-Date).Date
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd;
    $SecurePassword = $password | ConvertTo-SecureString -AsPlainText -Force
    $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword
    $CredPassword = $Credentials.GetNetworkCredential().Password 
    $task = Register-ScheduledTask -TaskName $jobname -Action $action -Trigger $trigger -Settings $settings -runlevel "Highest" -User "administrator" -Password $CredPassword
    # 
    Get-ScheduledTask $jobname | start-scheduledtask
  } -args $username,$password
  $status = "Success"

  write-log -message "All Done here, NGT Done";

  $resultobject =@{
    Result = $status
  };
  return $resultobject
};

Function PSR-Install-Office {
  param (
    [object]$datagen,
    [object]$datavar,
    [string]$ip
  )
  write-log -message "Debug level is $debug";
  write-log -message "Building credential object";




  $username = "administrator"
  $password = $datagen.SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $Creds = New-Object System.Management.Automation.PsCredential($username,$password);
  $password = $datagen.SysprepPassword
  invoke-command -computername $ip -credential $creds {
    $username = $args[0]
    $password = $args[1]
    [ARRAY]$OUTPUT += [STRING]'$Path = $env:TEMP;'
    [ARRAY]$OUTPUT += [STRING]'$Installer = "chrome_installer.exe";'    
    [ARRAY]$OUTPUT += [STRING]'Invoke-WebRequest "http://dl.google.com/chrome/install/375.126/chrome_installer.exe" -OutFile $Path\$Installer;'
    [ARRAY]$OUTPUT += [STRING]'Start-Process -FilePath $Path\$Installer -Args "/silent /install" -Verb RunAs -Wait; '
    [ARRAY]$OUTPUT += [STRING]'Remove-Item $Path\$Installer; '
    [ARRAY]$OUTPUT += [STRING]'$MSP = "Office2016.msp";'
    [ARRAY]$OUTPUT += [STRING]'$xml = "Office2016.msp.xml";'
    [ARRAY]$OUTPUT += [STRING]'Invoke-WebRequest "https://dl.dropboxusercontent.com/s/06ttdbg13nz0lpc/Office2016.MSP" -OutFile $Path\$MSP;'
    [ARRAY]$OUTPUT += [STRING]'Invoke-WebRequest "https://dl.dropboxusercontent.com/s/x9axoo0dnl7nfwp/Office2016.MSP.xml" -OutFile $Path\$xml;'
    [ARRAY]$OUTPUT += [STRING]'$driveletter = (Get-CimInstance Win32_LogicalDisk | ?{ $_.DriveType -eq 5} | select DeviceID).deviceid'
    [ARRAY]$OUTPUT += [STRING]'& "$($driveletter)\setup.exe" /adminfile $Path\$MSP'
    
    $OUTPUT | OUT-FILE C:\windows\temp\Office.ps1
    $argumentList = "-file C:\Windows\Temp\Office.ps1"
    $jobname = "PowerShell Office Install";
    $action = New-ScheduledTaskAction -Execute "$pshome\powershell.exe" -Argument  "$argumentList";
    $trigger =New-ScheduledTaskTrigger -Once -At (Get-Date).Date
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd;
    $SecurePassword = $password | ConvertTo-SecureString -AsPlainText -Force
    $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword
    $CredPassword = $Credentials.GetNetworkCredential().Password 
    $task = Register-ScheduledTask -TaskName $jobname -Action $action -Trigger $trigger -Settings $settings -runlevel "Highest" -User "administrator" -Password $CredPassword
    # 
    Get-ScheduledTask $jobname | start-scheduledtask
  } -args $username,$password
  $status = "Success"

  write-log -message "All Done here, Office Install Running";

  $resultobject =@{
    Result = $status
  };
  return $resultobject
};

Function PSR-Set-Time {
  param (
    [object] $datagen,
    [object] $datavar,
    [string] $ip
  )
  write-log -message "Debug level is $debug";
  write-log -message "Building credential object";
  $localdatetime = "$($(get-date).addseconds(30))"
  $localtimezone = (get-timezone).id
  $username = "administrator"
  $password = $datagen.SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $Creds = New-Object System.Management.Automation.PsCredential($username,$password);
  invoke-command -computername $ip -credential $creds {
    $localtimezone = $args[0]
    [datetime]$localdatetime = $args[1]
    set-timezone -id $localtimezone
    set-date $localdatetime
  } -args $localtimezone,$localdatetime 
}

Function PSR-Install-WindowsUpdates {
  param (
    [object] $datagen,
    [object] $datavar,
    [string] $ip
  )
  write-log -message "Debug level is $debug";
  write-log -message "Building credential object";


  $username = "administrator"
  $password = $datagen.SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $Creds = New-Object System.Management.Automation.PsCredential($username,$password);
  $password = $datagen.SysprepPassword
  invoke-command -computername $ip -credential $creds {
    $username = $args[0]
    $password = $args[1]
    [ARRAY]$OUTPUT += [STRING]'Install-PackageProvider -Name NuGet -Force -confirm:0'
    [ARRAY]$OUTPUT += [STRING]'Install-Module PSWindowsUpdate -confirm:0 -force'
    [ARRAY]$OUTPUT += [STRING]'Add-WUServiceManager -ServiceID 7971f918-a847-4430-9279-4a52d1efe18d -confirm:0'
    [ARRAY]$OUTPUT += [STRING]'Get-WUInstall -MicrosoftUpdate -AcceptAll –AutoReboot -download -install -confirm:0'
    
    $OUTPUT | OUT-FILE C:\windows\temp\Updates.ps1
    $argumentList = "-file C:\Windows\Temp\Updates.ps1"
    $jobname = "PowerShell Updates Install";
    $action = New-ScheduledTaskAction -Execute "$pshome\powershell.exe" -Argument  "$argumentList";
    $trigger =New-ScheduledTaskTrigger -Once -At (Get-Date).Date
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd;
    $SecurePassword = $password | ConvertTo-SecureString -AsPlainText -Force
    $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword
    $CredPassword = $Credentials.GetNetworkCredential().Password 
    $task = Register-ScheduledTask -TaskName $jobname -Action $action -Trigger $trigger -Settings $settings -runlevel "Highest" -User "administrator" -Password $CredPassword
    # 
    Get-ScheduledTask $jobname | start-scheduledtask
  } -args $username,$password
  $status = "Success"

  write-log -message "All Done here, Updates are running Leave it now, this should be our last step.";

  $resultobject =@{
    Result = $status
  };
  return $resultobject
};

Function PSR-Validate-NGT {
  param (
    [object] $datagen,
    [object] $datavar,
    [string] $ip
  )
  write-log -message "Debug level is $debug";
  write-log -message "Building credential object";
  $username = "administrator"
  $password = $datagen.SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $Creds = New-Object System.Management.Automation.PsCredential($username,$password);
  $Present = invoke-command -computername $ip -credential $creds {
    get-item "c:\progra~1\Nutanix\ngtcli\ngtcli.cmd"
  }
  return $Present
}

Function Test-SameSubnet { 
  param ( 
  [parameter(Mandatory=$true)] 
  [Net.IPAddress] 
  $ip1, 
  
  [parameter(Mandatory=$true)] 
  [Net.IPAddress] 
  $ip2, 
  
  [parameter()] 
  [alias("SubnetMask")] 
  [Net.IPAddress] 
  $mask ="255.255.255.0" 
  ) 
  
  if (($ip1.address -band $mask.address) -eq ($ip2.address -band $mask.address)) {
    return $true
  } else {
    return $false
  } 
}

function Convert-IpAddressToMaskLength {
  Param(
    [string] $dottedIpAddressString
    )
  $result = 0; 
  # ensure we have a valid IP address
  [IPAddress] $ip = $dottedIpAddressString;
  $octets = $ip.IPAddressToString.Split('.');
  foreach($octet in $octets)
  {
    while(0 -ne $octet) 
    {
      $octet = ($octet -shl 1) -band [byte]::MaxValue
      $result++; 
    }
  }
  return $result;
}

function Get-LastAddress{
  param(
    $IPAddress,
    $SubnetMask
  )
  filter Convert-IP2Decimal{
      ([IPAddress][String]([IPAddress]$_)).Address
  }
  filter Convert-Decimal2IP{
    ([System.Net.IPAddress]$_).IPAddressToString 
  }
  [UInt32]$ip = $IPAddress | Convert-IP2Decimal
  [UInt32]$subnet = $SubnetMask | Convert-IP2Decimal
  [UInt32]$broadcast = $ip -band $subnet 
  $secondlast = $broadcast -bor -bnot $subnet | Convert-Decimal2IP
  $bc = $secondlast.tostring()
  [int]$Ending = ($bc.split(".") | select -last 1) -2
  [Array]$Prefix = $bc.split(".") | select -first 3;
  $EndingIP = [string]($Prefix -join(".")) + "." + $Ending
  return $endingIP
}

Function PSR-Create-DHCP {
  param(
    [object] $datavar,
    [object] $datagen
  )
  write-log -message "This module is only used for VMware, Creates DHCP on the First DC."
  write-log -message "Debug level is $debug";
  write-log -message "Building credential object";
  $lastIP = Get-LastAddress -IPAddress $datavar.PEClusterIP -SubnetMask $datavar.InfraSubnetmask
  write-log -message "Last IP will be $lastIP";
  write-log -message "Building DHCP Server due to the lack of proper IPAM in VMware";

  $password = $datagen.SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $DomainCreds = New-Object System.Management.Automation.PsCredential("$($datagen.domainname)\administrator",$password);
  invoke-command -computername $datagen.DC1IP -credential $DomainCreds {
      [object] $datavar = $args[0] 
      [object] $datagen = $args[1]
      write "Installing on $($datagen.DC1Name)"
      write "Last IP is $($args[3])"
      write "Installing"
      Install-WindowsFeature -Name 'DHCP' -IncludeManagementTools -confirm:0
      netsh dhcp add securitygroups
      write "Sec Groups set, restarting service"
      Restart-Service dhcpserver
      $password = $datagen.SysprepPassword | ConvertTo-SecureString -asplaintext -force;
      $netbios = ($($datagen.domainname).split("."))[0]
      $DomainCreds1 = New-Object System.Management.Automation.PsCredential("$netbios\administrator",$password);
      Get-DhcpServerInDC
      write "Authorizing DHCP for Dynamic updates" 
      Add-DhcpServerInDC -DnsName "$($datagen.DC1Name)" -IPAddress "$($datagen.DC1IP)"
      write "Marking Role install as completed" 
      Set-ItemProperty -Path "registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12" -Name ConfigurationState -Value 2
      write "Enabling Dynamic Updates" 
      Set-DhcpServerv4DnsSetting -DynamicUpdates "Always" -DeleteDnsRRonLeaseExpiry $True
      write "Authorizing Dynamic Updates" 
      Set-DhcpServerDnsCredential -ComputerName "$($datagen.DC1Name)" -credential $DomainCreds1
      write "Creating Scope"
      if (!(get-DhcpServerv4Scope)){
        Add-DhcpServerv4Scope -StartRange $datavar.peclusterip -EndRange $args[3] -SubnetMask $datavar.InfraSubnetmask -State Active -name $datavar.pocname
        Get-DhcpServerv4Scope | Add-DhcpServerv4ExclusionRange -StartRange $datavar.peclusterip -EndRange $datagen.NW1DHCPStart 
      } else {
        get-DhcpServerv4Scope
        write "Scope exists, debugging are we?"
      }
      write "Setting global Options" 
      Set-DhcpServerv4OptionValue -DnsDomain $($datagen.DomainName) -DnsServer "$($datagen.DC1IP)" -Router $datavar.InfraGateway
      write "PSR is the best!"
  } -args $datavar,$datagen,$DomainCreds,$lastIP 
  
}

Function PSR-Get-DHCP-IP {
  param(
    [object] $datavar,
    [object] $datagen

  )

  write-log -message "This module is only used for VMware, Creates DHCP on the First DC."
  write-log -message "Debug level is $debug";
  write-log -message "Building credential object";

  $password = $datagen.SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $DomainCreds = New-Object System.Management.Automation.PsCredential("$($datagen.domainname)\administrator",$password);
  $leases = invoke-command -computername $datagen.DC1IP -credential $DomainCreds { 
      
      [object] $datavar = $args[0] 
      [object] $datagen = $args[1]
      $scope = Get-DhcpServerv4Scope
      Get-DhcpServerv4Lease -scopeid $scope.scopeid

  } -args $datavar,$datagen
  return $leases
}

Function PSR-Add-DHCP-Reservation {
  param(
    [object] $datavar,
    [object] $datagen,
    [string] $source,
    [string] $targetip,
    [string] $mode

  )

  write-log -message "This module is only used for VMware, Creates DHCP on the First DC."
  write-log -message "Debug level is $debug";
  write-log -message "Building credential object";


  
  $password = $datagen.SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $DomainCreds = New-Object System.Management.Automation.PsCredential("$($datagen.domainname)\administrator",$password);
  invoke-command -computername $datagen.DC1IP -credential $DomainCreds { 
      
      [object] $datavar  = $args[0]
      [object] $datagen  = $args[1]
      [string] $source   = $args[2]
      [string] $targetip = $args[3]
      [string] $Mode     = $args[4]

      if ($mode -eq "name"){
    
        write "Creating a reservation for what is now $source"
        write "Setting that reservation towards $targetip"
        
        Get-DhcpServerv4Scope | Get-DhcpServerv4Lease | where {$_.name -match $source} | Add-DhcpServerv4Reservation -IPAddress $targetip

      } else {
    
        write "Creating a reservation for what is now $source"
        write "Setting that reservation towards $targetip"

        Get-DhcpServerv4Scope | Get-DhcpServerv4Lease | where {$_.ipaddress -eq $source} | Add-DhcpServerv4Reservation -IPAddress $targetip
    
      }

      


  } -args $datavar,$datagen,$source,$targetip

}

Function PSR-Install-Choco {
  param (
    [object] $datagen,
    [object] $datavar,
    [string] $ip
  )
  write-log -message "Debug level is $debug";
  write-log -message "Building credential object";
  $username = "administrator"
  $password = $datagen.SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $Creds = New-Object System.Management.Automation.PsCredential($username,$password);
  invoke-command -computername $ip -credential $creds {
    Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    get-pssession | remove-pssession
  } 
}

Function PSR-Install-PowerCLI {
  param (
    [object] $datagen,
    [object] $datavar,
    [string] $ip
  )
  write-log -message "Debug level is $debug";
  write-log -message "Building credential object";
  $username = "administrator"
  $password = $datagen.SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $Creds = New-Object System.Management.Automation.PsCredential($username,$password);
  invoke-command -computername $ip -credential $creds {
    C:\ProgramData\chocolatey\bin\choco.exe install vmware-powercli-psmodule --version 11.3.0.13990089 -y
  }
  get-pssession | remove-pssession 
}



Function PSR-Install-OVA-Template-IA {
  param (
    [object] $datagen,
    [object] $datavar,
    [string] $mgtip,
    [string] $container,
    [string] $vmname,
    [string] $vmIP,
    [string] $imageURL

  )
  write-log -message "Debug level is $debug";
  write-log -message "Building credential object"
  
  $username = "administrator"
  $password = $datagen.SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $Creds = New-Object System.Management.Automation.PsCredential($username,$password);
  write-log -message "Image URL is $imageURL"
  $filename = "$($imageURL)" -split "/" | select -last 1
  write-log -message "Filename is $filename"
  write-log -message "VMName is $vmname"
  write-log -message "VMIP is $VMIP"
  write-log -message "Container is $Container"
  write-log -message "VCenter User is $($datavar.VCenterUser)"
  write-log -message "Cleaning and downloading image"
  invoke-command -computername $mgtip -credential $creds {
    $datavar   = $args[0]
    $datagen   = $args[1]
    $mgtip     = $args[2]
    $container = $args[3]
    $vmname    = $args[4]
    $vmIP      = $args[5]
    $imageURL  = $args[6]
    $filename = "$($imageURL)" -split "/" | select -last 1

    write "Image URL is $imageURL"
    write "Filename is $filename"
    write "VMName is $vmname"
    write "VMIP is $VMIP"
    write "Container is $Container"
    write "VCenter User is $($datavar.VCenterUser)"
    write "Cleaning and downloading image"

    $path = test-path "c:\temp\" -ea:0
    if (!$path){
      mkdir c:\temp\
    }
    $ovfPath = "c:\temp\$($filename)"
    $outexits = get-item $ovfPath -ea:0
    if ($outexits){
      rm $outexits -force -confirm:0 -ea:0

      write "Removing existing file $output"

    }

    write "Writing towards destination: $output"

    $wc = New-Object net.webclient
    $wc.Downloadfile($imageURL, $ovfPath)
    $item = get-item $ovfPath
    $size = $item.length /1gb

    write "Download completed, $size GB downloaded"

    Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Scope AllUsers -confirm:0
    Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCeip $false -InvalidCertificateAction Ignore -confirm:0
    Connect-VIServer $datavar.VCenterIP -username $($datavar.VCenterUser) -password $($datavar.VCenterPass)

    write "PowerCLI Started and connected, sending commands"

    $cluster = get-cluster
    $VMHost = get-vmhost | select -last 1

    if ($cluster){
      
      write "Something"
    
    } else {
      write "No Vmware Connection..."
    }
    $datastore = get-datastore -name $container
    $ovfConfig = Get-OvfConfiguration -Ovf $ovfPath
    $ovfConfig.Common
    $ovfConfig.Common.varoot_password
    $ovfConfig.Common.varoot_password.Value = "$($datavar.pepass)"
    $ovfConfig.IpAssignment.IpProtocol.Value = "IPv4"
    $ovfConfig.NetworkMapping.Network_1.Value = "$($datagen.Nw1name)"
    $ovfConfig.vami.VMware_vCenter_Support_Assistant_Appliance.gateway.Value = $datavar.InfraGateway
    $ovfConfig.vami.VMware_vCenter_Support_Assistant_Appliance.domain.Value = $datagen.Domainname
    $ovfConfig.vami.VMware_vCenter_Support_Assistant_Appliance.DNS.Value = "$($datagen.dc1IP)", "$($datagen.dc2ip)"
    $ovfConfig.vami.VMware_vCenter_Support_Assistant_Appliance.ip0.Value = $vmip
    $ovfConfig.vami.VMware_vCenter_Support_Assistant_Appliance.netmask0.Value = $datavar.InfraSubnetmask
    ## Deleting if exists
    $machine = get-vm -Name $VMName
    if ($machine){
      write "Machine exists, deleting."
      $machine | stop-vm -confirm:0
      sleep 10
      $machine | remove-vm -confirm:0
      sleep 30
    }
    write "Importing vAPP"
    Import-VApp -Source $ovfpath -OvfConfiguration $ovfConfig -Name $VMName -VMHost $VMHost -Location $Cluster -Datastore $Datastore -DiskStorageFormat "Thin" -Confirm:$false


  } -args $datavar,$datagen,$mgtip,$container,$vmname,$vmIP,$imageURL,$filename -ea:0
  return $job
}


Function PSR-Install-OVA-Template {
  param (
    [object] $datagen,
    [object] $datavar,
    [string] $mgtip,
    [string] $container,
    [string] $vmname,
    [string] $vmIP,
    [string] $imageURL

  )
  $filename = "$($imageURL)" -split "/" | select -last 1
  write-log -message "Debug level is $debug";
  write-log -message "Building credential object"
  write-log -message "Image URL is $imageURL"
  write-log -message "Filename is $filename"
  write-log -message "VMName is $vmname"
  write-log -message "VMIP is $VMIP"
  write-log -message "Container is $Container"
  write-log -message "VCenter User is $($datavar.VCenterUser)"
  write-log -message "Cleaning and downloading image"

  $username = "administrator"
  $password = $datagen.SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $Creds = New-Object System.Management.Automation.PsCredential($username,$password);
  $job = invoke-command -computername $mgtip -credential $creds {
    start-transcript -path "c:\windows\temp\OVF.log"
    $datavar   = $args[0]
    $datagen   = $args[1]
    $mgtip     = $args[2]
    $container = $args[3]
    $vmname    = $args[4]
    $vmIP      = $args[5]
    $imageURL  = $args[6]
    $filename = "$($imageURL)" -split "/" | select -last 1

    write "Image URL is $imageURL"
    write "Filename is $filename"
    write "VMName is $vmname"
    write "VMIP is $VMIP"
    write "Container is $Container"
    write "VCenter User is $($datavar.VCenterUser)"
    write "Cleaning and downloading image"

    $path = test-path "c:\temp\" -ea:0
    if (!$path){
      mkdir c:\temp\
    }
    $ovfPath = "c:\temp\$($filename)"
    $outexits = get-item $ovfPath -ea:0
    if ($outexits){
      rm $outexits -force -confirm:0 -ea:0

      write "Removing existing file $output"

    }

    write "Writing towards destination: $output"

    $wc = New-Object net.webclient
    $wc.Downloadfile($imageURL, $ovfPath)
    $item = get-item $ovfPath
    $size = $item.length /1gb

    write "Download completed, $size GB downloaded"

    Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Scope AllUsers -confirm:0
    Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCeip $false -InvalidCertificateAction Ignore -confirm:0
    Connect-VIServer $datavar.VCenterIP -username $($datavar.VCenterUser) -password $($datavar.VCenterPass)

    write "PowerCLI Started and connected, sending commands"

    $cluster = get-cluster
    $VMHost = get-vmhost | select -last 1

    if ($cluster){
      
      write "Something"
    
    } else {
      write "No Vmware Connection..."
    }
    $datastore = get-datastore -name $container
    $ovfConfig = Get-OvfConfiguration -Ovf $ovfPath
    $ovfConfig.Common
    $ovfConfig.Common.varoot_password
    $ovfConfig.Common.varoot_password.Value = "$($datavar.pepass)"
    $ovfConfig.IpAssignment.IpProtocol.Value = "IPv4"
    $ovfConfig.NetworkMapping.Network_1.Value = "$($datagen.Nw1name)"
    $ovfConfig.vami.VMware_vCenter_Support_Assistant_Appliance.gateway.Value = $datavar.InfraGateway
    $ovfConfig.vami.VMware_vCenter_Support_Assistant_Appliance.domain.Value = $datagen.Domainname
    $ovfConfig.vami.VMware_vCenter_Support_Assistant_Appliance.DNS.Value = "$($datagen.dc1IP)", "$($datagen.dc2ip)"
    $ovfConfig.vami.VMware_vCenter_Support_Assistant_Appliance.ip0.Value = $vmip
    $ovfConfig.vami.VMware_vCenter_Support_Assistant_Appliance.netmask0.Value = $datavar.InfraSubnetmask
    ## Deleting if exists
    $machine = get-vm -Name $VMName
    if ($machine){
      write "Machine exists, deleting."
      $machine | stop-vm -confirm:0
      sleep 10
      $machine | remove-vm -confirm:0
    }
    write "Importing vAPP"
    Import-VApp -Source $ovfpath -OvfConfiguration $ovfConfig -Name $VMName -VMHost $VMHost -Location $Cluster -Datastore $Datastore -DiskStorageFormat "Thin" -Confirm:$false
    sleep 60
    stop-transcript

  } -args $datavar,$datagen,$mgtip,$container,$vmname,$vmIP,$imageURL,$filename -asjob -ea:0
  return $job
}

Function PSR-Create-Domain {
  param (
    [string] $SysprepPassword,
    [string] $IP,
    [string] $DNSServer,
    [string] $Domainname
  )
  $netbios = $Domainname.split(".")[0]

  write-log -message "Debug level is $debug";
  write-log -message "Building credential object.";

  $password = $SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $credential = New-Object System.Management.Automation.PsCredential("administrator",$password);

  write-log -message "Installing AD software";
  write-log -message "Awaiting completion install AD software";

  try {  
    $connect = invoke-command -computername $ip -credential $credential { Install-WindowsFeature -Name AD-Domain-Services,GPMC,DNS,RSAT-ADDS -IncludeManagementTools -Restart};
  } catch {

    write-log -message "Retry Promote First DC." -sev "WARN";

    $connect = invoke-command -computername $ip -credential $credential { Install-WindowsFeature -Name AD-Domain-Services,GPMC,DNS,RSAT-ADDS -IncludeManagementTools -Restart};
  }
  write-log -message "Waiting in a 15 second loop before the machine is online again.";
  do {;
    sleep 15;
    $test = test-connection -computername $ip -ea:0;
    $count++;
  } until ($test[0].statuscode -eq 0 -or $count -eq 6 );
  write-log -message "Creating Forest";
  try {
    $connect = invoke-command -computername $ip -credential $credential { 
      $hide = Install-ADDSForest -DomainNetbiosName $Args[2] -DomainName $args[0] -SafeModeAdministratorPassword $Args[1] -force -NoRebootOnCompletion -ea:0;
      shutdown -r -t 30
    } -args $Domainname,$password,$netbios;
  } catch {
    write-log -message "Retry Promote First DC." -sev "WARN"
    sleep 60
    $connect = invoke-command -computername $ip -credential $credential { 
      Install-ADDSForest -DomainNetbiosName $Args[2] -DomainName $args[0] -SafeModeAdministratorPassword $Args[1] -force -NoRebootOnCompletion;
      shutdown -r -t 15
    } -args $Domainname,$password,$netbios;
  }
  write-log -message "Sleeping 300 seconds additional to the completion.";
  sleep 420 ## Minimal stupid Windows leave it 
  write-log -message "Setting DNS Server Forwarder $DNSServer.";

  try{
    $connect = invoke-command -computername $ip -credential $credential { 
      net accounts /maxpwage:unlimited /domain;
      $dns = set-dnsserverforwarder -ipAddress $args[0]
      Get-AdUser -Filter *  | Set-ADUser -PasswordNeverExpires $true
    } -args $DNSServer;
  } catch {
    write-log -message "Retry DNS Record.";
    sleep 119;
    write-log -message "Awaiting completion Forest creation";
    sleep 119;
    $connect = invoke-command -computername $ip -credential $credential { 
      net accounts /maxpwage:unlimited /domain;
      $dns = set-dnsserverforwarder -ipAddress $args[0]
      Get-AdUser -Filter *  | Set-ADUser -PasswordNeverExpires $true
    } -args $DNSServer;
  }
  write-log -message "Rebooting final round for settings to apply";
  try{
    sleep 15
    restart-computer -computername $ip -credential $credential -force -confirm:0 -ea:0
    sleep 60
  } catch {

    write-log -message "Hmm.";

  } 
  write-log -message "Checking DNS Server Forwarder";
  try {
    $result = invoke-command -computername $ip -credential $credential {
      (get-dnsserverforwarder ).ipAddress[0].ipAddresstostring
    } 
  } catch {
    sleep 119
    $result = invoke-command -computername $ip -credential $credential {
      (get-dnsserverforwarder ).ipAddress[0].ipAddresstostring
    } 
  }
  if ($result -match $DNSServer){
    $status = "Success"

    write-log -message "We are all done here, one to beam up.";

  } else {
    $status = "Failed"
    Write-host $result
    write-log -message "Danger Will Robbinson." -sev "ERROR";

  }
  $resultobject =@{
    Result = $status
    Object = $result
  };
  return $resultobject
};

Function PSR-Add-DomainController {
  param (
    [string]$SysprepPassword,
    [string]$IP,
    [string]$DNSServer,
    [string]$Domainname
  )
  write-log -message "Debug level is $debug";
  write-log -message "Building credential objects (2).";

  $password = $SysprepPassword | ConvertTo-SecureString -asplaintext -force;
  $LocalCreds = New-Object System.Management.Automation.PsCredential("administrator",$password);
  $DomainCreds = New-Object System.Management.Automation.PsCredential("$($Domainname)\administrator",$password);

  $installsuccess = $false
  $installcount = 0
  $promotesuccess = $false
  $promotecount = 0
  $Joincount = 0
  $JoinSuccess = $true

  write-log -message "Joining the machine to the domain.";
 
  do{
    $Joincount++
    write-log -message "How many times am i doing this $Joincount"
    try {
      if (-not (Test-Connection -ComputerName $IP -Quiet -Count 1)) {
      
        write-log -message "Could not reach $IP" -sev "WARN"
      
      } else {
      
        write-log -message "$IP is being added to domain $Domainname..."
      
        try {
          Add-Computer -ComputerName $IP -Domain $Domainname -restart -Localcredential $LocalCreds -credential $DomainCreds -force 

        } catch {
          
          sleep 70

          try {
            $connect = invoke-command -computername $ip -credential $DomainCreds {
              (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain
            } -ea:0
          }  catch {  
            write-log -message "I dont want to be here."
          }
        }
        while (Test-Connection -ComputerName $IP -Quiet -Count 1 -or $countrestart -le 30) {
          
          write-log -message "Machine is restarting"

          $countrestart++
          Start-Sleep -Seconds 2
          }
      
          write-log -message "$IP was added to domain $Domain..."
          sleep 20
       }

    } catch {

      write-log -message "Join domain almost always throws an error..."
      
      sleep 20
      try {
        $connect = invoke-command -computername $ip -credential $DomainCreds {
          (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain
        } -ea:0
      } catch {
        $connect = $false 
      }
      if ($connect -eq $true ){
        $Joinsucces = $true

        write-log -message "Machine Domain Join Confirmed"

      } else {

        write-log -message "If you can read this.. $Joincount"

      }
    };
    sleep 30
  } until ($Joincount -ge 5 -or $connect -eq $true)

  write-log -message "Installing AD software";
  write-log -message "Awaiting completion install AD software";
  sleep 30
  do{
    $installcount++
    try {
      $connect = invoke-command -computername $ip -credential $DomainCreds { 
        try {
          Install-WindowsFeature -Name AD-Domain-Services,GPMC,DNS,RSAT-ADDS -IncludeManagementTools;
          shutdown -r -t 10;
        } catch {;
          sleep 60;
        };
      };
      sleep 180
      if ($connect.Success -eq $true){
  
        write-log -message "Install success";
        write-log -message "Wait for reboot in 45 sec loop.";
  
        $installsuccess = $true;
      };
    } catch {

      write-log -message "NGT is slowing windows down a bit , causing new timing issues... ";
      write-log -message "Another error bites the dust!!, Retry, this was Attempt $installcount out of 5, 3 min sleep";

    }
  } until ($installcount -ge 5 -or $connect.Success -eq $true)
  
  do {;
    $test = test-connection -computername $ip -ea:0;
    sleep 45;
    $count++;
  } until ($test[0].statuscode -eq 0 -or $count -eq 6 );
  sleep 45

  do{
    $promotecount++

    write-log -message "Promoting next DC in the domain";

    $connect = invoke-command -computername $IP -credential $DomainCreds { 
      try {
        Install-ADDSDomainController -DomainName $args[0] -SafeModeAdministratorPassword $Args[1] -force -credential $args[2] -NoRebootOnCompletion;
        shutdown -r -t 30
      } catch {
        "ERROR"
      }
      sleep 180
    } -args $Domainname,$password,$DomainCreds -ea:0

    if ($connect -notmatch "ERROR"){
      $promotesuccess = $true

      write-log -message "Promote Success, confirmed the end result." 

    } else {
      
      write-log -message "Promote failed, retrying." -sev "WARN"

    }
  } until ($promotecount -ge 5 -or $promotesuccess -eq $true)

  write-log -message "Sleeping 60 sec";

  if ($promotesuccess -eq $true -and $installsuccess -eq $true){
    $status = "Success"

    write-log -message "All Done here, ready for AD Content";
    write-log -message "Please pump me full of lead.";

  } else {
    $status = "Failed"
    write-log -message "Danger Will Robbinson." -sev "ERROR";
  }
  $resultobject =@{
    Result = $status
  };
  return $resultobject
};


Export-ModuleMember *

