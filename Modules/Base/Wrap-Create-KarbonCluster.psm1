Function Wrap-Create-KarbonCluster {
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $BlueprintsPath,
    $ServerSysprepfile


  ) 

  ### Enable Karbon is done in the POst PC wrapper    
  ### Karbon needs to be enabled before LCM detects this update

  write-log -message "Getting Subnet" 

  $subnet = (REST-Get-PE-Networks -datavar $datavar -datagen $datagen).entities | where {$_.name -eq $datagen.nw1name}

  write-log -message "This is where we do fancy Karbon 1.x API Calls."
  write-log -message "Taking a nap as PC is not ready yet."
  write-log -message "Wait for PostPC Task Complete, LCM + NTP"
  
  Wait-POSTPC-Task -datavar $datavar

  write-log -message "Ready to talk K8." -slacklevel 1
  write-log -message "Getting a Token first....."

  $token = REST-Karbon-Login -datagen $datagen -datavar $datavar
  $imagesP = REST-Karbon-Get-Images-Portal -datagen $datagen -datavar $datavar -token $token
  $imagesL = REST-Karbon-Get-Images-local -datagen $datagen -datavar $datavar -token $token

  $image = $imagesL | where {$_.image_description -match "Centos" } | sort release_date | select -last 1

  write-log -message "Downloading Image"

  try {
    $token = REST-Karbon-Login -datagen $datagen -datavar $datavar
    REST-Karbon-Download-Images -datagen $datagen -datavar $datavar -token $token -image $image
  } catch {

    write-log -message "Error caught on Karbon image download" -sev "WARN"

  }
  $imagesL = REST-Karbon-Get-Images-local -datagen $datagen -datavar $datavar -token $token
  $imagesL = $imagesL | where {$_.image_description -match "Centos" } | sort release_date | select -last 1

  $count = 0
  do {
    $count++
  
    write-log -message "Download status is $($imagesL.Status)"
    if ($imagesL.Status -eq "Available"){
      $token = REST-Karbon-Login -datagen $datagen -datavar $datavar
      REST-Karbon-Download-Images -datagen $datagen -datavar $datavar -token $token -image $image
    }
  
    sleep 60
    try {
      $token = REST-Karbon-Login -datagen $datagen -datavar $datavar
      $imagesL = REST-Karbon-Get-Images-local -datagen $datagen -datavar $datavar -token $token
      $imagesL = $imagesL | where {$_.image_description -match "Centos" } | sort release_date | select -last 1
    } catch {

      write-log -message "I should not be here, CALM Updates Failed???"
    
    }
  }until ($imagesL.status -eq "Downloaded" -or $count -ge 75)

  $subnet = (REST-Get-PE-Networks -datavar $datavar -datagen $datagen).entities | where {$_.name -eq $datagen.nw1name}
  $clusters = REST-Query-Cluster -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 

  $cluster = $clusters.entities | where { $_.spec.Resources.network -match "192.168.5"}
  
  $token = REST-Karbon-Login -datagen $datagen -datavar $datavar
  $image = $imagesL | where {$_.image_description -match "Centos" } | sort release_date | select -last 1
  
  write-log -message "Getting K8 Versions Portal" 

  
  $versions = REST-Karbon-Get-Versions-Portal -datagen $datagen -datavar $datavar -token $token
  Sleep 5

  write-log -message "Getting K8 Versions Local" 

  $array  = $null
  $versions = REST-Karbon-Get-Versions-Local -datagen $datagen -datavar $datavar -token $token
  foreach ($line in $versions.k8sversion) { 
    [array]$array += [version]($line -replace "-",'.')
  }
  $lastversion = "$(($array | SORT | select -LAST 1).tostring())"
  $lastversion = (($lastversion.split(".") | select -first 3 )-join ".") + "-$($lastversion.split(".")[3])"

  $UpgradeVersion = "$(($array | SORT | select -first 1).tostring())"
  $UpgradeVersion = (($UpgradeVersion.split(".") | select -first 3 )-join ".") + "-$($UpgradeVersion.split(".")[3])"


  write-log -message "Using K8 Version $lastversion + Lame pause to impove Karon Create stability."

  write-log -message "Creating K8 Cluster!" -slacklevel 1
      
  if ($ramcap -ge 1 -or $datavar.hypervisor -match "VMWare|ESX"){ 

    write-log -message "Creating 4GB Dev Instance" -slacklevel 1
    REST-Karbon-Create-Cluster-DEV -datagen $datagen -datavar $datavar -token $token -image $image -k8version $lastversion -subnet $subnet -PCcluster $cluster

  } else {

    write-log -message "Creating 8GB Prod Fannel Instance" -slacklevel 1

    REST-Karbon-Create-Cluster-Fannel -datagen $datagen -datavar $datavar -token $token -image $image -k8version $UpgradeVersion -subnet $subnet -PCcluster $cluster

    write-log -message "Creating 8GB Prod Calico Instance" -slacklevel 1

    $subnet2 = (REST-Get-PE-Networks -datavar $datavar -datagen $datagen).entities | where {$_.name -eq $datagen.nw2name}

    $VIP = (Get-CalculatedIP -IPAddress $datavar.Nw2DHCPStart -ChangeValue 2).IPAddressToString

    REST-Karbon-Create-Cluster-Calico -datagen $datagen -datavar $datavar -token $token -image $image -k8version $lastversion -subnet $subnet2 -PCcluster $cluster -VIP $VIP
    
  }

  sleep 10

  $token = REST-Karbon-Login -datagen $datagen -datavar $datavar
  $clusters = REST-Karbon-Get-Clusters -datagen $datagen -datavar $datavar -token $token  

  sleep 10

  $counter = 0
  do {
    $counter ++
    $token = REST-Karbon-Login -datagen $datagen -datavar $datavar
    $clusters = REST-Karbon-Get-Clusters -datagen $datagen -datavar $datavar -token $token

    write-log -message "Cycle $counter out of 20"

    if ($clusters.task_progress_percent  -ne 100 -and $clusters){

      write-log -message "Cluster is installing, status is $($clusters.task_progress_percent) %"

    } elseif ($clusters.task_progress_percent  -eq 100){

      write-log -message "Install Ready Checking health"

      sleep 15
      $token = REST-Karbon-Login -datagen $datagen -datavar $datavar
      $clusters = REST-Karbon-Get-Clusters -datagen $datagen -datavar $datavar -token $token  
      if ($clusters.task_status -eq 3){

        write-log -message "Cluster is Healthy"

      } elseif ($clusters.task_status -eq 2) {

        write-log -message "Cluster is NOT Healthy, repairing"

        REST-Karbon-Delete-Cluster -datagen $datagen -datavar $datavar -token $token -K8cluster $clusters
        sleep 180
        if ($ramcap -ge 1){ 
      
          write-log -message "Creating 4GB Dev Instance" -slacklevel 1
          REST-Karbon-Create-Cluster-DEV -datagen $datagen -datavar $datavar -token $token -image $image -k8version $lastversion -subnet $subnet -PCcluster $cluster
      
        } else {
      
          write-log -message "Creating 8GB Prod Instance" -slacklevel 1
          REST-Karbon-Create-Cluster -datagen $datagen -datavar $datavar -token $token -image $image -k8version $lastversion -subnet $subnet -PCcluster $cluster
      
        }

      } else {

        write-log -message "Cluster is in an unknown health state."

      }

    } elseif (!$clusters) {

      $token = REST-Karbon-Login -datagen $datagen -datavar $datavar
      if ($ramcap -ge 1){ 

        write-log -message "Creating 4GB Dev Instance" -slacklevel 1
        REST-Karbon-Create-Cluster-DEV -datagen $datagen -datavar $datavar -token $token -image $image -k8version $lastversion -subnet $subnet -PCcluster $cluster

      } else {

        write-log -message "Creating 8GB Prod Instance" -slacklevel 1
        REST-Karbon-Create-Cluster -datagen $datagen -datavar $datavar -token $token -image $image -k8version $lastversion -subnet $subnet -PCcluster $cluster

      }

    } else {

      write-log -message "I should not be here"

    }
    sleep 60

  } until ($clusters.task_progress_percent -eq 100 -and $clusters.task_status -eq 3 -or $counter -ge 20)
  
  if ($datavar.installfiles -eq 1 ){
    write-log -message "Adding Files Storage Class and Volume"
    
    write-log -message "Wait for FS"
    
    do { 

      $vfiler = REST-Query-FileServer -datagen $datagen -datavar $datavar
      $shares = REST-PE-GetShares -datavar $datavar -datagen $datagen

      if ($vfiler.entities.count -lt 1 -or $shares.entities.count -lt 2){
        write-log -message "Waiting .... we have $($vfiler.entities.count) File servers and $($shares.entities.count) shares"
        sleep 110
      } else {
        write-log -message "We have VFiller $($vfiler.entities.uuid) and $($shares.entities.count) shares"
      }

    } until (($shares.entities.count -ge 1 -and $shares.entities.count -ge 2) -or $counter -ge 5)

    write-log -message "Creating NFS Share"
    
    $share = REST-Add-FileServerShare-Karbon -datagen $datagen -datavar $datavar -vfiler $vfiler
    
    $token = REST-Karbon-Login -datagen $datagen -datavar $datavar

    write-log -message "Getting Karbon Cluster"
    
    $cluster = REST-Karbon-Get-Clusters -datagen $datagen -datavar $datavar -token $token

    write-log -message "Create Files Storage Class"
    
    $Class = REST-Karbon-Create-Files-StorageCloss -datagen $datagen -datavar $datavar -cluster $cluster -token $token
    
    $Classes = REST-Karbon-List-StorageCloss -datagen $datagen -datavar $datavar -cluster $cluster -token $token
    
    $class = $classes.entities | where {$_.metadata.name -eq "files-storageclass"}
      
    write-log -message "Creating Persistent Volume Using class $($class.metadata.name)"

    $Volume = REST-Karbon-ClaimFilesVolume -datagen $datagen -datavar $datavar -cluster $cluster -token $token -class $class

    ## Add Consult APP ? Trillerless Helm App? 
    
    write-log -message "Finished Creating Karbon Cluster" -slacklevel 1
  }
}
