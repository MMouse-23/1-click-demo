Function Wrap-Create-KarbonCluster-Calico {
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $BlueprintsPath,
    $ServerSysprepfile


  ) 
  write-log -message "Sleeping 10 mins for AAG." 

  Wait-MSSQL-Task -datavar $datavar

  $clusters = REST-Query-Cluster -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 
  $cluster = $clusters.entities | where { $_.spec.Resources.network -match "192.168.5"}
  $token = REST-Karbon-Login -datagen $datagen -datavar $datavar
  $AllImagesLocal = REST-Karbon-Get-Images-local -datagen $datagen -datavar $datavar -token $token
  $imagesL = $AllImagesLocal | where {$_.image_description -match "Centos" } | sort version | select -last 1
  
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

  write-log -message "Creating 8GB Prod Calico Instance" -slacklevel 1

  $subnet2 = (REST-Get-PE-Networks -datavar $datavar -datagen $datagen).entities | where {$_.name -eq "Network-03"}
  
  $VIP = (Get-CalculatedIP -IPAddress $datavar.Nw2DHCPStart -ChangeValue 2).IPAddressToString
  $token = REST-Karbon-Login -datagen $datagen -datavar $datavar

  REST-Karbon-Create-Cluster-Calico -datagen $datagen -datavar $datavar -token $token -image $image -k8version $lastversion -subnet $subnet2 -PCcluster $cluster -VIP $VIP

  write-log -message "Finished Creating Karbon Cluster" -slacklevel 1
  
}
