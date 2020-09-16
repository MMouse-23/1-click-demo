Function Wrap-Create-SSP-Base{
   param (
    $datagen,
    $datavar
   ) 
  
  $Customers = "Customer-A","Customer-B","Customer-C","Customer-D"
  if ($datavar.Hypervisor -match "ESX|VMware") {
    $networkname = $datagen.nw2name
  } else {
    $networkname = $datagen.nw1name
  }
  $subnet = (REST-Get-PE-Networks -datavar $datavar -datagen $datagen).entities | where {$_.name -eq $networkname}


  sleep 10
  $cluster = REST-Query-Cluster -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -targetIP $datagen.PCClusterIP
  sleep 10
  if ($cluster.count -ge 2){
    $cluster = $cluster | where {!$_.spec.resources.network.external_data_services_ip}
  }
  write-log -message "Using Cluster $($cluster.metadata.uuid)"
  write-log -message "Using Subnet $($subnet.uuid)"

  # Assuming images are always ready at this point (ESX only?
  $projects = REST-Query-Projects -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.PEPass -clusername $datagen.BuildAccount
  $project = $projects.entities | where {$_.spec.name -eq "Default"}

  if ($datavar.Hypervisor -match "ESX") {

    write-log -message "Creating VMware Account / Provider"

    try {
      $account = REST-Create-SSP-VMwareAccount -datavar $datavar -datagen $datagen
    } catch {
      $accounts = REST-List-SSP-Account -datagen $datagen -datavar $datavar
      $account = $accounts.entities | where {$_.Status.resources.type -eq "vmware"} | select -first 1
    }

  } else {

    REST-Wait-ImageUpload -imagename "CentOS_1CD" -datavar $datavar -datagen $datagen

    if ($datavar.installkarbon -eq 1){
      $counter = 0
      do {
        $counter ++
        $token = REST-Karbon-Login -datagen $datagen -datavar $datavar
        $KarbonClusters = REST-Karbon-Get-Clusters -datagen $datagen -datavar $datavar -token $token
        $KarbonCluster =  $KarbonClusters | where {$_.task_progress_percent -eq 100 } | select -first 1
        write-log -message "Cycle $counter out of 200"
  
        if ($KarbonCluster.task_progress_percent  -ne 100 -and $clusters){
  
          write-log -message "Cluster is installing, status is $($clusters.task_progress_percent) %"
  
        } elseif ($KarbonCluster.task_progress_percent  -eq 100){
  
          write-log -message "Install Ready, using $($KarbonCluster.cluster_metadata.uuid)"
  
        } else {
  
          write-log -message "Cluster has not finished installing yet."
  
          sleep 60
  
        }
      } until ($KarbonCluster.task_progress_percent -eq 100 -and $KarbonCluster.task_status -eq 3 -or $counter -ge 200)

      write-log -message "Creating Karbon Account"

      REST-Create-SSP-KarbonAccount -datagen $datagen -datavar $datavar -karbonClusterUUID $KarbonCluster.cluster_metadata.uuid

    }

  }  
  #getting Projects again for new SPEC

  write-log -message "Verifying All accounts."

  foreach ($account in $accounts.entities){ 
    REST-Verify-SSP-Account -datagen $datagen -datavar $datavar -Account $account 
  }

  write-log -message "Adding All accounts to default project."

  $accounts = REST-List-SSP-Account -datagen $datagen -datavar $datavar

  $projectdetail = REST-Get-ProjectDetail -datavar $datavar -datagen $datagen -project $project

  REST-update-project-Account -datavar $datavar -datagen $datagen -accounts $accounts -projectdetail $projectdetail
  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project

  write-log -message "We need prism AD so we wait for Post PC now."

  Wait-POSTPC-Task -datavar $datavar

  $projects = REST-Query-Projects -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.PEPass -clusername $datagen.BuildAccount
  $project = $projects.entities | where {$_.spec.name -eq "Default"}
  $ProjectAdmin = REST-Query-Role-List -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -rolename "Project Admin"
  try {
    $domainadmin = REST-Create-AdninGroup -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -grouptype "admin-accounts-group" -customer $customer -domainname $datagen.Domainname
  } catch {
    write-log -message "Not the first round i guess."
  }
  # Post PC Issue below. 
  $count = 0
  do {
    $count ++
    $groups = REST-Query-ADGroups -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.PEPass -clusername $datagen.BuildAccount
    $domainadmingroup = $groups.entities | where {$_.status.resources.directory_service_user_group.distinguished_name -match "Domain Admins"}
    if ($domainadmingroup.metadata.uuid.length -lt 2){
      write-log -message "We have seen this before, 0 admin groups, let me sleep on that for 60 sec."
      sleep 60
    } 
    if ($count -ge 3){
      try {

        write-log -message "Hoping this is timebound, Admin group create should work after a while." -sev "WARN"

        $domainadmin = REST-Create-AdninGroup -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -grouptype "admin-accounts-group" -customer $customer -domainname $datagen.Domainname
      } catch {
        write-log -message "Not the first round i guess."
      }
    }
  } until ($domainadmingroup.metadata.uuid.length -ge 2 -or $count -ge 20)

  if ($datavar.Hypervisor -match "ESX") {
    $esxcounter = 0
    $exit = 0
    Wait-Templates-Task -datavar $datavar
    do {
      $esxcounter ++
      try {
        write-log -message "Using VMware Provider / Account UUID $($account.metadata.uuid)"
        write-log -message "Getting VMware Templates"
    
        $count = 0
        do {
          $count ++
          sleep 15
          try {

            $accounts = REST-List-SSP-Account -datagen $datagen -datavar $datavar
            $account = $accounts.entities | where {$_.Status.resources.type -eq "vmware"} | select -first 1
            $Templates =REST-LIST-SSP-VMwareImages -datagen $datagen -datavar $datavar -Accountuuid $account.metadata.uuid
    
            write-log -message "We found $($Templates.entities.count) VMware Templates"
    
          } catch {}
        } until ($templates.entities.count -ge 3 -or $count -ge 4)
     
        $winimage = $Templates.entities.status.resources | where {$_.name -eq "Windows 2016"}
        $linimage = $Templates.entities.status.resources | where {$_.name -eq "CentOS 8"}
    
        $projects = REST-Query-Projects -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.PEPass -clusername $datagen.BuildAccount
        $project = $projects.entities | where {$_.spec.name -eq "Default"}
    
        $environments = REST-LIST-Environments -datagen $datagen -datavar $datavar;sleep 2
        $environment = $environments.entities| where {$_.status.name -match"Default"}
        $environmentUUID  = $environment.metadata.uuid 
    
        REST-create-Environment-ESX -datagen $datagen -project $project -subnet $subnet -linimage $linimage -winimage $winimage -datavar $datavar -accountuuid $account.metadata.uuid -environment $environment
    
        $environments = REST-LIST-Environments -datagen $datagen -datavar $datavar;sleep 2
        $environment = $environments.entities| where {$_.status.name -match"Default"}
        $environmentUUID  = $environment.metadata.uuid 
    
        write-log -message "Env UUID is $environmentUUID" 
        write-log -message "Updating Default Project Env Only"
    
        $projects = REST-Query-Projects -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.PEPass -clusername $datagen.BuildAccount
        $project = $projects.entities | where {$_.spec.name -eq "Default"}
        
        REST-Update-DefaultProject-ESX -datavar $datavar -datagen $datagen -project $project -environmentUUID $environmentUUID -adminroleuuid $ProjectAdmin.metadata.uuid -Domainadminuuid $domainadmingroup.metadata.uuid -VMwareAccount $account
        Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project

        $exit = 1
      } catch {
        $exit = 0

        write-log -message "ESX Default Project in retry."

      }
    } until ($exit -eq 1 -or $esxcounter -ge 5)
    #END OF VMWARE
  } else {

    $images = REST-Query-Images -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 
    $linimage = $images.entities | where {$_.spec.name -eq "CentOS_1CD" }
    $winimage = $images.entities | where {$_.spec.name -eq "Windows 2016" }

    write-log -message "Handling Default Project First" 
    write-log -message "Creating Environment" 

    $environment = REST-create-Environment-AHV -datagen $datagen -project $project -subnet $subnet -linimage $linimage -winimage $winimage -datavar $datavar
    $environments = REST-LIST-Environments -datagen $datagen -datavar $datavar;sleep 2
    $environment = $environments.entities| where {$_.status.name -match "Default"}
    $environmentUUID  = $environment.metadata.uuid 

    $projects = REST-Query-Projects -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.PEPass -clusername $datagen.BuildAccount
    $project = $projects.entities | where {$_.spec.name -eq "Default"}
    
    write-log -message "Env UUID is $environmentUUID" 
    write-log -message "Updating Default Project Env Only" 

    REST-Update-DefaultProject-AHV -datavar $datavar -datagen $datagen -subnet $subnet -project $project -environmentUUID $environmentUUID
    Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project
    
    $accounts = REST-List-SSP-Account -datagen $datagen -datavar $datavar

    $projectdetail = REST-Get-ProjectDetail -datavar $datavar -datagen $datagen -project $project

    REST-update-project-Account -datavar $datavar -datagen $datagen -accounts $accounts -projectdetail $projectdetail
    Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project
    #END OF AHV
  }

  ## We need to set accounts once more as the last step whipes the account



  foreach ($customer in $customers){
  
      $LauchCommand = 'Wrap-Create-SSP-Customer -datavar $datavar -datagen $datagen -customer ' + $customer
      Lib-Spawn-Wrapper -Type "SSP_$($customer)" -datavar $datavar -datagen $datagen -parentuuid "$($datavar.QueueUUID)" -sysprepfile $sysprepfile -ModuleDir $ModuleDir -basedir $basedir -ProdMode $ProdMode -LauchCommand $LauchCommand 
  
  }
  
  write-log -message "Self Service Portal configuration Finished" -slacklevel 1

  write-log -message "Setting up Showback" -slacklevel 1

  $accounts = REST-List-SSP-Account -datagen $datagen -datavar $datavar
  foreach ($account in $accounts.entities){
    $accountdetail = REST-List-SSP-AccountDetail -datagen $datagen -datavar $datavar -account $account
    try {
      $updateaccount = REST-Update-SSP-AccountCost -datagen $datagen -datavar $datavar -accountdetail $accountdetail
    } catch {
      if ($debug -ge 2){
        write-log "This account cannot have costs..."
      }
    }
  }
  $showback = REST-Enable-ShowBack -datagen $datagen -datavar $datavar 
  write-log -message "ShowBack Setup finished." -slacklevel 1
  
}
Export-ModuleMember *