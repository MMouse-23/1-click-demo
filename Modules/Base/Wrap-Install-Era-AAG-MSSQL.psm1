Function Wrap-Install-Era-MSSQL {
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $basedir,
    $ServerSysprepfile

  )
  
  if ($datavar.Hypervisor -match "ESX") {

    break

  } else {

    $PEnetworks = Rest-get-pe-networks -datagen $datagen -datavar $datavar
    if ($PEnetworks.entities.name -contains $datagen.nw2name) {

      write-log -message "Secondary network is present. We can deploy SQL AAG"

    } else {

      write-log -message "There is no secondary network present, we cannot deploy AAG on an IPAM managed network."
      break
    }
    
    $lastIP = Get-LastAddress -IPAddress $datavar.Nw2DHCPStart -SubnetMask $datavar.nw2subnet
    
    write-log -message "Using last IP: $lastIP"

    write-log -message "Creating Secondary ERA Managed Network"  

    REST-ERA-Attach-ERAManaged-PENetwork -datagen $datagen -datavar $datavar -lastIP $lastIP
    sleep 2

    write-log -message "Creating ERA IP Managed Network Profile" 

    $MSSQLProfile = REST-ERA-MSSQL-ERA-NW-ProfileCreate  -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin -Networkname $datagen.Nw2name

  } 
  write-log -message "Network Prep Done, getting databases"

  $databases = REST-ERA-GetDatabases -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.PEadmin
  $database = $databases | where {$_.name -eq "WideWorldImporters"}

  write-log -message "Using Database ID $($database.id), Getting Snapshots" 

  $snapshots = REST-ERA-GetLast-SnapShot -datagen $datagen -datavar $datavar -database $database
  $snapshot = ($snapshots.capability | where {$_.mode -eq "MANUAL"}).snapshots | select -last 1
  
  write-log -message "Alright thats snap ID $($Snapshot.id) were are using."
  write-log -message "Getting all profiles."

  $profiles = REST-ERA-GetProfiles -EraIP $datagen.ERA1IP -clpassword $datavar.PEPass -clusername $datavar.peadmin

  write-log -message "Using $($profiles.count) Profiles in ERA"
  write-log -message "Getting ERA Cluster Object"

  $cluster = REST-ERA-GetClusters -datavar $datavar -datagen $datagen

  write-log -message "Using ERA Cluster UUID $($cluster.id)"  

  REST-ERA-MSSQL-AAG-Cluster `
    -datagen $datagen `
    -datavar $datavar `
    -snapshot $snapshot `
    -profiles $profiles `
    -EraCluster $cluster `
    -ClusterName "AAG1-$($datavar.pocname)" `
    -database $database `
    -nodePrefix "AAGN-$($datavar.pocname)" `
    -NewDatabaseName "WideWorldImporters_AAG" `
    -NewInstanceName "MSSQLSERVER_AAG"

  write-log -message "ERA MSSQL AAG Installation Finished" -slacklevel 1
}


