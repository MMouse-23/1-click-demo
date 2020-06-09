Function REST-ERA-Create-Low-ComputeProfile {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datavar.peadmin):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Loading Json"
  $json = @"
{
  "type": "Compute",
  "topology": "ALL",
  "dbVersion": "ALL",
  "properties": [{
    "name": "CPUS",
    "value": "1",
    "description": "Number of CPUs in the VM"
  }, {
    "name": "CORE_PER_CPU",
    "value": 4,
    "description": "Number of cores per CPU in the VM"
  }, {
    "name": "MEMORY_SIZE",
    "value": 16,
    "description": "Total memory (GiB) for the VM"
  }],
  "name": "LOW_OOB_COMPUTE"
}
"@

  $URL = "https://$($datagen.ERA1IP):8443/era/v0.9/profiles"

  write-log -message "Creating Profile LOW_OOB_COMPUTE"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers
    Return $RespErr
  }

  Return $task
} 


Function REST-ERA-Create-UltraLow-ComputeProfile {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datavar.peadmin):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Loading Json"
  $json = @"
{
  "type": "Compute",
  "topology": "ALL",
  "dbVersion": "ALL",
  "properties": [{
    "name": "CPUS",
    "value": "1",
    "description": "Number of CPUs in the VM"
  }, {
    "name": "CORE_PER_CPU",
    "value": 4,
    "description": "Number of cores per CPU in the VM"
  }, {
    "name": "MEMORY_SIZE",
    "value": 8,
    "description": "Total memory (GiB) for the VM"
  }],
  "name": "LOW_OOB_COMPUTE"
}
"@

  $URL = "https://$($datagen.ERA1IP):8443/era/v0.9/profiles"

  write-log -message "Creating Profile LOW_OOB_COMPUTE"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers
    Return $RespErr
  }

  Return $task
} 

Function REST-ERA-GetProfiles {
  Param (
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Query All ERA Profiles"

  $URL = "https://$($EraIP):8443/era/v0.9/profiles"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "GET"  -headers $headers;
  }

  Return $task
} 


Function REST-ERA-ProvisionDatabase {
  Param (
    [object] $dbserver,
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername,
    [object] $ERACluster,
    [object] $SLA,
    [string] $debug,
    [string] $publicSSHKey,
    [string] $networkProfileId,
    [string] $SoftwareProfileID,
    [string] $computeProfileId,
    [string] $dbParameterProfileId,
    [string] $Type,
    [string] $Port,
    [string] $Databasename,
    [string] $NodeCount = 1
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Using databasename DB_$($dbservername)"
  write-log -message "Using NetworkID $($networkProfileId)"
  write-log -message "Using ComputeID $($computeProfileId)"
  write-log -message "Using DBParamID $($dbParameterProfileId)"
  write-log -message "Using Databasename  $($Databasename)"
  write-log -message "Using Type $($Type)"
  write-log -message "Using Port $($Port)"

  $URL = "https://$($EraIP):8443/era/v0.9/databases/provision"
  $JSON = @"
{
  "databaseType": "$($Type)",
  "databaseName": "$($databasename)",
  "clusterId": "$($ERACluster.id)",
  "dbParameterProfileId": "$($dbParameterProfileId)",
  "useExistingDBserver": true,
  "newDbServerTimeZone": "Europe/Amsterdam",
  "timeMachineInfo": {
    "name": "$($databasename)_TM",
    "description": "",
    "slaId": "$($SLA.ID)",
    "schedule": {
      "snapshotTimeOfDay": {
        "hours": 1,
        "minutes": 0,
        "seconds": 0
      },
      "continuousSchedule": {
        "enabled": true,
        "logBackupInterval": 30,
        "snapshotsPerDay": 1
      },
      "weeklySchedule": {
        "enabled": true,
        "dayOfWeek": "FRIDAY"
      },
      "monthlySchedule": {
        "enabled": true,
        "dayOfMonth": "8"
      },
      "quartelySchedule": {
        "enabled": true,
        "startMonth": "JANUARY",
        "dayOfMonth": "8"
      },
      "yearlySchedule": {
        "enabled": false,
        "dayOfMonth": 31,
        "month": "DECEMBER"
      }
    },
    "tags": [],
    "autoTuneLogDrive": true
  },
  "provisionInfo": [{
    "name": "application_type",
    "value": "$($Type)"
  }, {
    "name": "listener_port",
    "value": "$($Port)"
  }, {
    "name": "database_size",
    "value": "200"
  }, {
    "name": "working_dir",
    "value": "/tmp"
  }, {
    "name": "auto_tune_staging_drive",
    "value": true
  }, {
    "name": "host_ip",
    "value": "$($dbserver.ip)"
  }, {
    "name": "db_password",
    "value": "$($Clpassword)"
  }]
}
"@
  if ($debug -ge 2){
    $json | out-file c:\temp\ERAMDBcr.json
  }
  try {
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  } catch{

    write-log -message "Going once." -sev "WARN"

    sleep 60
    try {
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
    } catch {
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
    }
  }
  Return $task
} 



Function REST-ERA-RegisterOracle-ERA {
  Param (
    $dbname,
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername,
    [object] $ERACluster,
    [string] $OracleIP,
    [object] $SLA
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building Oracle Server Registration JSON"
  write-log -message "Using databasename $($dbname) using ip $OracleIP"
  write-log -message "Using Cluster ID $($ERACluster.id)"
  write-log -message "Using SLA ID $($SLA.ID)"

  $URL = "https://$($EraIP):8443/era/v0.9/databases"
  $JSON = @"
{
  "vmAdd": true,
  "applicationInfo": [{
    "name": "application_type",
    "value": "oracle_database"
  }, {
    "name": "listener_port",
    "value": "1521"
  }, {
    "name": "working_dir",
    "value": "/tmp"
  }, {
    "name": "era_deploy_base",
    "value": "/opt/era_base"
  }, {
    "name": "create_era_drive",
    "value": true
  }, {
    "name": "vm_ip",
    "value": "$($OracleIP)"
  }, {
    "name": "vm_username",
    "value": "oracle"
  }, {
    "name": "grid_home",          
    "value": "/u01/app/12.1.0/grid"
  }, {
    "name": "oracle_home",
    "value": "/u02/app/oracle/product/12.1.0/dbhome_1"
  }, {
    "name": "vm_password",
    "value": "$($clpassword)"
  }, {
    "name": "oracle_sid",
    "value": "$($dbname)"
  }],
  "forcedInstall": true,
  "clusterId": "$($ERACluster.id)",
  "tags": [],
  "timeMachineInfo": {
    "name": "$($dbname)_TM",
    "description": "$($dbname)_TM",
    "slaId": "$($SLA.ID)",
    "schedule": {
      "snapshotTimeOfDay": {
        "hours": 1,
        "minutes": 0,
        "seconds": 0
      },
      "continuousSchedule": {
        "enabled": true,
        "logBackupInterval": 30,
        "snapshotsPerDay": 1
      },
      "weeklySchedule": {
        "enabled": true,
        "dayOfWeek": "THURSDAY"
      },
      "monthlySchedule": {
        "enabled": true,
        "dayOfMonth": "21"
      },
      "quartelySchedule": {
        "enabled": true,
        "startMonth": "JANUARY",
        "dayOfMonth": "21"
      },
      "yearlySchedule": {
        "enabled": false,
        "dayOfMonth": 31,
        "month": "DECEMBER"
      }
    },
    "tags": [],
    "autoTuneLogDrive": true
  },
  "applicationSlaName": "$($sla.name)",
  "applicationType": "oracle_database",
  "autoTuneStagingDrive": true,
  "eraBaseDirectory": "/opt/era_base",
  "applicationHost": "$($OracleIP)",
  "vmIp": "$($OracleIP)",
  "vmUsername": "oracle",
  "vmPassword": "$($clpassword)",
  "applicationName": "$($dbname)",
  "vmDescription": "Oracle 12 Server"
}
"@
  if ($debug -ge 2){
    $json | out-file c:\temp\ERAOracle.json
  }
  try {
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  } catch{

    write-log -message "Going once." -sev "WARN"

    sleep 60
    try {
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
    } catch {
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
    }
  }
  Return $task
} 


Function REST-ERA-ProvisionServer {
  Param (
    [string] $dbservername,
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername,
    [object] $ERACluster,
    [object] $SLA,
    [string] $debug,
    [string] $publicSSHKey,
    [string] $networkProfileId,
    [string] $SoftwareProfileID,
    [string] $computeProfileId,
    [string] $dbParameterProfileId,
    [string] $Type,
    [string] $POCNAME
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building $Type Server Provision JSON"
  write-log -message "Using databasename DB_$($dbservername)"
  write-log -message "Using NetworkID $($networkProfileId)"
  write-log -message "Using ComputeID $($computeProfileId)"
  write-log -message "Using DBParamID $($dbParameterProfileId)"
  write-log -message "Using POC Name  $($POCNAME)"  
  write-log -message "Using SoftwareProfile $($SoftwareProfileID)"
  write-log -message "Using Type $($Type)"

  $URL = "https://$($EraIP):8443/era/v0.9/dbservers/create"
  $JSON = @"
{
  "actionArguments": [{
    "name": "vm_name",
    "value": "$($dbservername)"
  }, {
    "name": "working_dir",
    "value": "/tmp"
  }, {
    "name": "era_deploy_base",
    "value": "/opt/era_base"
  }, {
    "name": "compute_profile_id",
    "value": "$($computeProfileId)"
  }, {
    "name": "client_public_key",
    "value": "$($publicSSHKey)"
  }, {
    "name": "network_profile_id",
    "value": "$($networkProfileId)"
  }],
  "description": "Launches the rocket",
  "clusterId": "$($ERACluster.id)",
  "softwareProfileId": "$($SoftwareProfileID)"
}
"@
  if ($debug -ge 2){
    $json | out-file c:\temp\ERADB.json
  }
  try {
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  } catch{

    write-log -message "Going once." -sev "WARN"

    sleep 60
    try {
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
    } catch {
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
    }
  }
  Return $task
} 





Function REST-ERA-AcceptEULA {
  Param (
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername,
    [string] $uuid
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building EULA Accept JSON"

  $URL = "https://$($EraIP):8443/era/v0.9/auth/validate"
  $Payload= @{
    eulaAccepted="true"
  } 
  $JSON = $Payload | convertto-json
  try {
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 60
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $JSON -ContentType 'application/json' -headers $headers;
  }  
  Return $task
} 

Function REST-ERA-GetDBServers {
  Param (
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Get ERA DB Servers"

  $URL = "https://$($EraIP):8443/era/v0.9/dbservers"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "GET"  -headers $headers;
  }

  Return $task
} 

Function REST-ERA-GetDatabases {
  Param (
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Get ERA DB Servers"

  $URL = "https://$($EraIP):8443/era/v0.9/databases"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "GET"  -headers $headers;
  }

  Return $task
} 

Function REST-ERA-GetClones {
  Param (
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Get ERA Clones"

  $URL = "https://$($EraIP):8443/era/v0.9/clones"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "GET"  -headers $headers;
  }

  Return $task
} 

Function REST-PE-GetShares {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($datagen.buildaccount):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }


  write-log -message "Get FS Shares"

  $URL = "https://$($datavar.peclusterip):9440/PrismGateway/services/rest/v1/vfilers/shares"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "GET"  -headers $headers;
  }

  Return $task
} 


Function REST-ERA-MySQLNWProfileCreate {
  Param (
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername,
    [string] $NetworkName
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building PostGres Network Creation JSON"

  $URL = "https://$($EraIP):8443/era/v0.9/profiles"
  $JSON = @"
{
  "engineType": "mysql_database",
  "type": "Network",
  "topology": "ALL",
  "dbVersion": "ALL",
  "properties": [{
    "name": "VLAN_NAME",
    "value": "$($NetworkName)",
    "description": "Name of the vLAN"
  }],
  "name": "MySQL",
  "description": "MySQL Network Profile"
}
"@
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-ERA-PostGresNWProfileCreate {
  Param (
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername,
    [string] $NetworkName
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building PostGres Network Creation JSON"

  $URL = "https://$($EraIP):8443/era/v0.9/profiles"
  $JSON = @"
{
  "engineType": "postgres_database",
  "type": "Network",
  "topology": "ALL",
  "dbVersion": "ALL",
  "properties": [{
    "name": "VLAN_NAME",
    "value": "$($NetworkName)",
    "description": "Name of the vLAN"
  }],
  "name": "PostGresNW"
}
"@
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-ERA-Oracle-SW-ProfileCreate {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $database
  )

  $credPair = "$($datavar.peadmin):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Loading Json"
  $json = @"
{
  "engineType": "oracle_database",
  "type": "Software",
  "dbVersion": "ALL",
  "properties": [{
    "name": "SOURCE_DBSERVER_ID",
    "value": "$($database.primaryHost)",
    "description": "ID of the database server that should be used as a reference to create the software profile"
  }],
  "name": "Oracle"
}
"@
  $URL = "https://$($datagen.ERA1IP):8443/era/v0.9/profiles"

  write-log -message "Creating Profile Oracle Software"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers
    Return $RespErr
  }

  Return $task
} 

Function REST-ERA-MSSQL-SW-ProfileCreate {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $database
  )

  $credPair = "$($datavar.peadmin):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Loading Json"
  $json = @"
{
  "engineType": "sqlserver_database",
  "type": "Software",
  "dbVersion": "ALL",
  "properties": [{
    "name": "SOURCE_DBSERVER_ID",
    "value": "$($database.primaryHost)",
    "description": "ID of the database server that should be used as a reference to create the software profile"
  }],
  "name": "MSSQL",
  "description": "MSSQL"
}
"@
  $URL = "https://$($datagen.ERA1IP):8443/era/v0.9/profiles"

  write-log -message "Creating Profile MSSQL Software"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers
    Return $RespErr
  }

  Return $task
} 

Function REST-ERA-Oracle-NW-ProfileCreate {
  Param (
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername,
    [string] $NetworkName
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building Oracle Network Creation JSON"

  $URL = "https://$($EraIP):8443/era/v0.9/profiles"
  $JSON = @"
{
  "engineType": "oracle_database",
  "type": "Network",
  "topology": "single",
  "dbVersion": "ALL",
  "properties": [{
    "name": "VLAN_NAME",
    "value": "$($Networkname)",
    "description": "Name of the vLAN"
  }],
  "name": "Oracle",
  "description": "Launches the rocket"
}
"@
  try {
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }

  Return $task
} 


Function REST-ERA-MSSQL-NW-ProfileCreate {
  Param (
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername,
    [string] $NetworkName
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building MSSQL Network Creation JSON"

  $URL = "https://$($EraIP):8443/era/v0.9/profiles"
  $JSON = @"
{
  "engineType": "sqlserver_database",
  "type": "Network",
  "topology": "ALL",
  "dbVersion": "ALL",
  "properties": [{
    "name": "VLAN_NAME",
    "value": "$($NetworkName)",
    "description": "Name of the vLAN"
  }],
  "name": "MSSQL",
  "description": "MSSQL"
}
"@
  try {
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }

  Return $task
} 

Function REST-ERA-GetLast-SnapShot {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $database
  )

  $credPair = "$($datavar.peadmin):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  $URL = "https://$($datagen.Era1IP):8443/era/v0.9/tms/$($database.timeMachineId)/capability"

  write-log -message "Getting Snapshots for Database"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers
  }

  Return $task
} 


Function REST-ERA-MSSQL-Clone {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $database,
    [object] $snapshot,
    [object] $profiles
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($datavar.peadmin):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $networkprofile = $profiles | where {$_.type -eq "network" -and $_.enginetype -eq "sqlserver_database"}
  $computeprofile = $profiles | where {$_.type -eq "compute" -and $_.name -match "LOW"}
  $domainProfile  = $profiles | where {$_.type -eq "WindowsDomain"}

  write-log -message "Building MSSQL Clone JSON"
  write-log -message "Using $($Profiles.count) Profiles"
  write-log -message "Using $($networkprofile.ID) as Network Profile"
  write-log -message "Using $($computeprofile.ID) as Compute Profile"
  write-log -message "Using $($domainProfile.ID) as Domain Profile"
  write-log -message "Using $($database.timeMachineId) as TimeMachine Source ID"
  write-log -message "Using $($snapshot.id) as Snapshot Source ID"

  write-log -message "Creating new database server MSSQL2-$($datavar.pocname)"

  $URL = "https://$($datagen.ERA1IP):8443/era/v0.9/tms/$($database.timeMachineId)/clones"
  $JSON = @"
{
  "cloneName": "WideWorldImportersDEV",
  "cloneDescription": "WideWorldImportersDEV",
  "timeMachineId": "$($database.timeMachineId)",
  "snapshotId": "$($snapshot.id)",
  "pitrTimestamp": null,
  "timeZone": "Europe/Amsterdam",
  "newDbServerTimeZone": "Central European Standard Time",
  "latestSnapshot": false,
  "newImplementation": false,
  "tags": [],
  "cloneInfo": [{
    "name": "vm_name",
    "value": "MSSQL2-$($datavar.pocname)"
  }, {
    "name": "vm_win_lang_settings",
    "value": "en-US"
  }, {
    "name": "sql_user_name",
    "value": "sa"
  }, {
    "name": "authentication_mode",
    "value": "windows"
  }, {
    "name": "working_dir",
    "value": "C:\\temp"
  }, {
    "name": "era_deploy_base",
    "value": "C:\\NTNX\\ERA_BASE"
  }, {
    "name": "create_era_drive",
    "value": true
  }, {
    "name": "create_dbserver",
    "value": "true"
  }, {
    "name": "drives_to_mountpoints",
    "value": false
  }, {
    "name": "instance_name",
    "value": "MSSQLSERVER"
  }, {
    "name": "database_name",
    "value": "WideWorldImportersDEV"
  }, {
    "name": "cluster_only",
    "value": false
  }, {
    "name": "cluster_db",
    "value": false
  }, {
    "name": "compute_profile_id",
    "value": "$($computeprofile.ID)"
  }, {
    "name": "network_profile_id",
    "value": "$($networkprofile.ID)"
  }, {
    "name": "vm_dbserver_admin_password",
    "value": "$($datavar.PEPass)"
  }, {
    "name": "vm_dbserver_user",
    "value": "$($datagen.Domainname)\\Domain Users"
  }],
  "applicationType": "sqlserver_database",
  "windowsDomainProfileId": "$($domainProfile.ID)"
}
"@
  if ($debug -ge 2){
    $json | out-file c:\temp\MSSQLClone.json
  } 
  try {
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 30
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }

  Return $task
} 


Function REST-ERA-Create-WindowsDomain-Profile {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datavar.peadmin):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Loading Json"
  $json = @"
{
  "type": "WindowsDomain",
  "topology": "ALL",
  "dbVersion": "ALL",
  "systemProfile": false,
  "properties": [{
    "name": "DOMAIN_NAME",
    "value": "$($datagen.Domainname)",
    "description": "Name of the Windows domain"
  }, {
    "name": "DOMAIN_USER_NAME",
    "value": "$($datagen.Domainname)\\administrator",
    "description": "Username with permission to join computer to domain"
  }, {
    "name": "DOMAIN_USER_PASSWORD",
    "value": "$($datavar.PEPass)",
    "description": "Password for the username with permission to join computer to domain"
  }, {
    "name": "DB_SERVER_OU_PATH",
    "value": "",
    "description": "Custom OU path for database servers"
  }, {
    "name": "CLUSTER_OU_PATH",
    "value": "",
    "description": "Custom OU path for server clusters"
  }, {
    "name": "ADD_PERMISSION_ON_OU",
    "value": "",
    "description": "Grant server clusters permission on OU"
  }],
  "name": "$($datagen.Domainname)",
  "description": "Domain Profile"
}
"@

  $URL = "https://$($datagen.ERA1IP):8443/era/v0.9/profiles"

  write-log -message "Creating Profile Windows Domain"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers
    Return $RespErr
  }

  Return $task
} 


Function REST-ERA-Oracle-Clone {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $database,
    [object] $snapshot,
    [object] $profiles
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($datavar.peadmin):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $networkprofile = $profiles | where {$_.type -eq "network" -and $_.enginetype -eq "oracle_database"}
  $computeprofile = $profiles | where {$_.type -eq "compute" -and $_.name -match "DEFAULT"} 
  $parameterPRofile = $profiles | where {$_.type -eq "Database_Parameter" -and $_.enginetype -eq "oracle_database"}

  write-log -message "Building Oracle Clone JSON"
  write-log -message "Using $($Profiles.count) Profiles"
  write-log -message "Using $($networkprofile.ID) as Network Profile"
  write-log -message "Using $($computeprofile.ID) as Compute Profile"
  write-log -message "Using $($database.timeMachineId) as TimeMachine Source ID"
  write-log -message "Using $($snapshot.id) as Snapshot Source ID"
  write-log -message "Creating new Database TESTDB_DEV + Database server Oracle2-$($datavar.pocname)"
  write-log -message "Using ParameterProfileID $($parameterPRofile.ID)"

  $URL = "https://$($datagen.ERA1IP):8443/era/v0.9/tms/$($database.timeMachineId)/clones"
  $JSON = @"
{
  "cloneName": "TESTDB_DEV",
  "cloneDescription": "Development instance for TESTDB",
  "timeMachineId": "$($database.timeMachineId)",
  "snapshotId": "$($snapshot.id)",
  "pitrTimestamp": null,
  "timeZone": "Europe/Amsterdam",
  "latestSnapshot": false,
  "newImplementation": false,
  "tags": [],
  "cloneInfo": [{
    "name": "new_db_sid",
    "value": "TESTDB"
  }, {
    "name": "vm_name",
    "value": "Oracle2-$($datavar.pocname)"
  }, {
    "name": "working_dir",
    "value": "/tmp"
  }, {
    "name": "era_deploy_base",
    "value": "/opt/era_base"
  }, {
    "name": "create_era_drive",
    "value": true
  }, {
    "name": "create_dbserver",
    "value": "true"
  }, {
    "name": "compute_profile_id",
    "value": "$($computeprofile.ID)"
  }, {
    "name": "network_profile_id",
    "value": "$($networkprofile.ID)"
  }, {
    "name": "client_public_key",
    "value": "$($datagen.PublicKey)"
  }, {
    "name": "db_password",
    "value": "$($datavar.PEPass)"
  }, {
    "name": "db_parameter_profile_id",
    "value": "$($parameterPRofile.ID)"
  }]
}
"@
  if ($debug -ge 2){
    $json | out-file c:\temp\ORAClone.json
  } 
  try {
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 30
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }

  Return $task
} 

Function REST-ERA-Oracle-Provision {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $cluster,
    [object] $SoftwareProfile,
    [object] $profiles
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($datavar.peadmin):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }
  $networkprofile = $profiles | where {$_.type -eq "network" -and $_.enginetype -eq "Oracle_database"}
  $computeprofile = $profiles | where {$_.type -eq "compute" -and $_.name -match "LOW"} 
  $softwareprofile = $profiles | where {$_.type -eq "software" -and $_.enginetype -eq "Oracle_database"}

  write-log -message "Building Oracle Clone JSON"
  write-log -message "Using $($Profiles.count) Profiles"
  write-log -message "Using $($networkprofile.ID) as Network Profile"
  write-log -message "Using $($computeprofile.ID) as Compute Profile"
  write-log -message "Using $($cluster.Id) as Cluster Source ID"
  write-log -message "Using $($SoftwareProfile.id) as Software Source ID"
  write-log -message "Creating new database server Oracle2-$($datavar.pocname)"

  $URL = "https://$($datagen.ERA1IP):8443/era/v0.9/dbservers/create"
  $JSON = @"
{
  "actionArguments": [{
    "name": "vm_name",
    "value": "Oracle2-$($datavar.pocname)"
  }, {
    "name": "working_dir",
    "value": "/tmp"
  }, {
    "name": "era_deploy_base",
    "value": "/opt/era_base"
  }, {
    "name": "create_era_drive",
    "value": true
  }, {
    "name": "compute_profile_id",
    "value": "$($computeprofile.ID)"
  }, {
    "name": "network_profile_id",
    "value": "$($networkprofile.ID)"
  }, {
    "name": "sys_asm_password",
    "value": "Welkom1"
  }, {
    "name": "client_public_key",
    "value": "$($datagen.PublicKey)"
  }],
  "description": "Oracle Clone",
  "clusterId": "$($cluster.Id)",
  "softwareProfileId": "$($SoftwareProfile.id)"
}
"@
  if ($debug -ge 2){
    $json | out-file c:\temp\ORacleCreate.json
  } 
  try {
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 30
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }

  Return $task
} 

Function REST-ERA-Provision-HA-Database {
  Param (
    [object] $dbserver,
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername,
    [object] $ERACluster,
    [object] $SLA,
    [string] $debug,
    [string] $publicSSHKey,
    [string] $networkProfileId,
    [object] $SoftwareProfile,
    [string] $computeProfileId,
    [string] $dbParameterProfileId,
    [string] $Type,
    [string] $Port,
    [string] $Databasename,
    [string] $postgresclustername,
    [string] $postgresserverprefix
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Using NetworkID $($networkProfileId)"
  write-log -message "Using ComputeID $($computeProfileId)"
  write-log -message "Using DBParamID $($dbParameterProfileId)"
  write-log -message "Using Databasename $($Databasename)"
  write-log -message "Using SoftwareProfile $($SoftwareProfile.id)"
  write-log -message "Using SLA with ID $($SLA.ID)"
  write-log -message "Using Type $($Type)"
  write-log -message "Using Port $($Port)"

  $URL = "https://$($EraIP):8443/era/v0.9/databases/provision"
  $JSON = @"
{
  "databaseType": "$($Type)",
  "databaseName": "$($Databasename)",
  "clusterId": "$($ERACluster.id)",
  "softwareProfileId": "$($SoftwareProfile.ID)",
  "softwareProfileVersionId": "$($SoftwareProfile.latestVersionid)",
  "computeProfileId": "$($computeProfileId)",
  "networkProfileId": "$($networkProfileId)",
  "dbParameterProfileId": "$($dbParameterProfileId)",
  "newDbServerTimeZone": "Europe/Berlin",
  "timeMachineInfo": {
    "name": "$($Databasename)_TM",
    "description": "",
    "slaId": "$($SLA.ID)",
    "schedule": {
      "snapshotTimeOfDay": {
        "hours": 1,
        "minutes": 0,
        "seconds": 0
      },
      "continuousSchedule": {
        "enabled": true,
        "logBackupInterval": 30,
        "snapshotsPerDay": 1
      },
      "weeklySchedule": {
        "enabled": true,
        "dayOfWeek": "WEDNESDAY"
      },
      "monthlySchedule": {
        "enabled": true,
        "dayOfMonth": "13"
      },
      "quartelySchedule": {
        "enabled": true,
        "startMonth": "JANUARY",
        "dayOfMonth": "13"
      },
      "yearlySchedule": {
        "enabled": false,
        "dayOfMonth": 31,
        "month": "DECEMBER"
      }
    },
    "tags": [],
    "autoTuneLogDrive": true
  },
  "provisionInfo": [{
      "name": "application_type",
      "value": "postgres_database"
    },
    {
      "name": "cluster_database",
      "value": true
    },
    {
      "name": "nodes",
      "value": "3"
    },
    {
      "name": "deploy_haproxy",
      "value": true
    },
    {
      "name": "proxy_write_port",
      "value": "5000"
    },
    {
      "name": "listener_port",
      "value": "5432"
    },
    {
      "name": "proxy_read_port",
      "value": "5001"
    },
    {
      "name": "database_size",
      "value": "200"
    },
    {
      "name": "working_dir",
      "value": "/tmp"
    },
    {
      "name": "auto_tune_staging_drive",
      "value": true
    },
    {
      "name": "dbserver_name",
      "value": "PostGresHA"
    },
    {
      "name": "cluster_name",
      "value": "PostGresCL"
    },
    {
      "name": "dbserver_description",
      "value": "PostGresHA"
    },
    {
      "name": "ssh_public_key",
      "value": "$($publicSSHKey)"
    },
    {
      "name": "db_password",
      "value": "$($Clpassword)"
    }
  ]
}
"@
  if ($debug -ge 2){
    $json | out-file c:\temp\ERAPostGHA.json
  }
  try {
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  } catch{

    write-log -message "Going once." -sev "WARN"

    sleep 60
    try {
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
    } catch {
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
    }
  }
  Return $task
} 

Function REST-ERA-MariaNWProfileCreate {
  Param (
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername,
    [string] $NetworkName
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building MariaDB Network Creation JSON"

  $URL = "https://$($EraIP):8443/era/v0.9/profiles"
  $JSON = @"
{
  "engineType": "mariadb_database",
  "type": "Network",
  "topology": "ALL",
  "dbVersion": "ALL",
  "properties": [{
    "name": "VLAN_NAME",
    "value": "$($NetworkName)",
    "description": "Name of the vLAN"
  }],
  "name": "MariaNW"
}
"@
  try {
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }

  Return $task
} 

Function REST-ERA-RegisterMSSQL-ERA {
  Param (
    $dbname,
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername,
    [object] $ERACluster,
    [string] $MSQLVMIP,
    [object] $SLA,
    [string] $sysprepPass
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building MSSQL Server Registration JSON"
  write-log -message "Using databasename $($dbname)"

  $URL = "https://$($EraIP):8443/era/v0.9/databases"
  $JSON = @"
{
  "vmAdd": true,
  "applicationInfo": [{
    "name": "application_type",
    "value": "sqlserver_database"
  }, {
    "name": "era_manage_log",
    "value": true
  }, {
    "name": "sql_login_used",
    "value": false
  }, {
    "name": "same_as_admin",
    "value": true
  }, {
    "name": "create_era_drive",
    "value": true
  }, {
    "name": "recovery_model",
    "value": "Full-logged"
  }, {
    "name": "era_deploy_base",
    "value": "C:\\NTNX\\ERA_BASE"
  }, {
    "name": "vm_ip",
    "value": "$($MSQLVMIP)"
  }, {
    "name": "vm_username",
    "value": "administrator"
  }, {
    "name": "vm_password",
    "value": "$($sysprepPass)"
  }, {
    "name": "instance_name",
    "value": "MSSQLSERVER"
  }, {
    "name": "database_name",
    "value": "$($dbname)"
  }, {
    "name": "sysadmin_username_win",
    "value": "administrator"
  }, {
    "name": "sysadmin_password_win",
    "value": "$($sysprepPass)"
  }],
  "forcedInstall": true,
  "clusterId": "$($ERACluster.id)",
  "tags": [],
  "timeMachineInfo": {
    "name": "$($dbname)_TM",
    "description": "",
    "slaId": "$($SLA.ID)",
    "schedule": {
      "snapshotTimeOfDay": {
        "hours": 1,
        "minutes": 0,
        "seconds": 0
      },
      "continuousSchedule": {
        "enabled": true,
        "logBackupInterval": 30,
        "snapshotsPerDay": 1
      },
      "weeklySchedule": {
        "enabled": true,
        "dayOfWeek": "SUNDAY"
      },
      "monthlySchedule": {
        "enabled": true,
        "dayOfMonth": "3"
      },
      "quartelySchedule": {
        "enabled": true,
        "startMonth": "JANUARY",
        "dayOfMonth": "3"
      },
      "yearlySchedule": {
        "enabled": false,
        "dayOfMonth": 31,
        "month": "DECEMBER"
      }
    },
    "tags": [],
    "autoTuneLogDrive": true
  },
  "applicationSlaName": "$($sla.name)",
  "applicationType": "sqlserver_database",
  "autoTuneStagingDrive": false,
  "eraBaseDirectory": "C:\\NTNX\\ERA_BASE",
  "applicationHost": "$($MSQLVMIP)",
  "vmIp": "$($MSQLVMIP)",
  "vmUsername": "administrator",
  "vmPassword": "$($sysprepPass)",
  "applicationName": "$($dbname)"
}
"@
  if ($debug -ge 2){
    $json | out-file c:\temp\ERAMSSQL.json
  }
  try {
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
  } catch{

    write-log -message "Going once." -sev "WARN"

    sleep 60
    try {
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
    } catch {
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $json -ContentType 'application/json' -headers $headers;
    }
  }
  Return $task
} 





Function REST-ERA-GetSLAs {
  Param (
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername,
    [string] $uuid
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  $URL = "https://$($EraIP):8443/era/v0.9/slas"

  try {
    $task = Invoke-RestMethod -Uri $URL -method "GET" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "GET" -body $JSON -ContentType 'application/json' -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }  
  Return $task
} 

Function REST-ERA-Operations {
  Param (
    [string] $EraIP,
    [string] $clpassword,
    [string] $clusername,
    [string] $uuid
  )
  #this is a silent module on purpose
  $credPair = "$($clusername):$($clpassword)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  $URL = "https://$($EraIP):8443/era/v0.9/operations/short-info?user-triggered=true&system-triggered=true"

  try {
    $task = Invoke-RestMethod -Uri $URL -method "GET" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "GET" -body $JSON -ContentType 'application/json' -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }  
  Return $task
} 

Function REST-ERA-CreateSnapshot {
  Param (
    [string] $DBUUID,
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datavar.peadmin):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Loading Json"
  $json = @"
{
  "actionHeader": [{
    "name": "snapshotName",
    "value": "Dev_Start"
  }]
}
"@

  $URL = "https://$($datagen.ERA1IP):8443/era/v0.9/tms/$($DBUUID)/snapshots"

  write-log -message "Creating Snapshot for $DBUUID"
  write-log -message "Using URL $URL"

  if ($debug -ge 2){
    write-log -message "Using Credpair $credPair"
  }
    
  try{
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $json -ContentType 'application/json' -headers $headers
    Return $RespErr
  }

  Return $task
} 

Function REST-ERA-RegisterClusterStage1 {
  Param (
    [object] $datavar,
    [object] $datagen
  )

  write-log -message "Debug level is $debug";
  write-log -message "Building Credential object"
  $credPair = "$($datavar.peadmin):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building Cluster Registration JSON"

  $URL = "https://$($datagen.ERA1IP):8443/era/v0.9/clusters"

  write-log -message "Using URL $URL"
  write-log -message "Using IP $($datagen.era1ip)"

  $Json = @"
{
  "name": "EraCluster",
  "description": "Era Cluster Description",
  "ip": "$($datavar.peclusterip)",
  "username": "$($datagen.ERAAPIAccount)",
  "password": "$($datavar.pepass)",
  "status": "UP",
  "version": "v2",
  "cloudType": "NTNX",
  "properties": [
    {
      "name": "ERA_STORAGE_CONTAINER",
      "value": "$($datagen.EraContainerName)"
    }
  ]
}
"@ 
  try {
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 60
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $JSON -ContentType 'application/json' -headers $headers;
  }  
  Return $task
} 



Function REST-ERA-AttachPENetwork {
  Param (
    [object] $datavar,
    [object] $datagen,
    [string] $ClusterUUID,
    [string] $NetworkName
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($datavar.peadmin):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building ERA Network Registration JSON"

  $URL = "https://$($datagen.ERA1IP):8443/era/v0.9/resources/networks"

  write-log -message "Using URL $URL"
  write-log -message "Using IP $($datagen.era1ip)"
  write-log -message "Registering Cluster: $ClusterUUID"
  write-log -message "Using Network $($NetworkName)"

  $Json = @"
{
    "name":  "$($NetworkName)",
    "type":  "DHCP",
    "clusterId":  "$($ClusterUUID)",
    "managed":  true,
    "properties":  [

                   ],
    "propertiesMap":  {

                      }
}
"@ 
  try {
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    sleep 119
    $task = Invoke-RestMethod -Uri $URL -method "POST" -body $JSON -ContentType 'application/json' -headers $headers; 
  }  
  Return $task
} 

Function REST-ERA-GetClusters {
  Param (
    [object] $datavar,
    [object] $datagen,
    [string] $ClusterUUID
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($datavar.peadmin):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Query ERA Clusters"

  $URL = "https://$($datagen.ERA1IP):8443/era/v0.9/clusters"

  write-log -message "Using URL $URL"
  write-log -message "Using IP $($datagen.era1ip)"

  try {
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }  
  Return $task
} 

Function REST-ERA-GetNetworks {
  Param (
    [object] $datavar,
    [object] $datagen
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($datavar.peadmin):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Query ERA Networks"

  $URL = "https://$($datagen.ERA1IP):8443/era/v0.9/resources/networks"

  write-log -message "Using URL $URL"
  write-log -message "Using IP $($datagen.era1ip)"

  try {
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }  
  Return $task
} 

Function REST-ERA-RegisterClusterStage2 {
  Param (
    [object] $datavar,
    [object] $datagen,
    [string] $ClusterUUID
  )

  write-log -message "Debug level is $($debug)";
  write-log -message "Building Credential object"
  $credPair = "$($datavar.peadmin):$($datavar.pepass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Building Stage 2 JSON"

  $URL = "https://$($datagen.ERA1IP):8443/era/v0.9/clusters/$($ClusterUUID)/json"

  write-log -message "Using URL $URL"
  write-log -message "Using IP $($datagen.era1ip)"

  $Json = @"
{
  "protocol": "https",
  "ip_address": "$($datavar.peclusterip)",
  "port": "9440",
  "creds_bag": {
    "username": "$($datagen.buildaccount)",
    "password": "$($datavar.pepass)"
  }
}
"@

  $filename = "$((get-date).ticks).json"
  $json | out-file $filename
  $filepath = (get-item $filename).fullname

  $fileBin = [System.IO.File]::ReadAlltext($filePath)
  #$fileEnc = [System.Text.Encoding]::GetEncoding('UTF-8').GetString($fileBytes);
  $boundary = [System.Guid]::NewGuid().ToString(); 
  $LF = "`r`n";
  
  $bodyLines = ( 
      "--$boundary",
      "Content-Disposition: form-data; name=`"file`"; filename=`"$filename`"",
      "Content-Type: application/json$LF",
      $fileBin,
      "--$boundary--$LF" 
  ) -join $LF

 
  #remove-item $filename -force -ea:0

  try {
    $task = Invoke-RestMethod -Uri $URL -method POST -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $bodyLines -headers $headers;
  } catch {
    sleep 10
    $task = Invoke-RestMethod -Uri $URL -method POST -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $bodyLines -headers $headers;

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  }  
  Return $task
} 

