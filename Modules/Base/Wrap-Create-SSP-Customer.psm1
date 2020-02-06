Function Wrap-Create-SSP-Customer{
   param (
    [object] $datagen,
    [object] $datavar,
    [string] $customer
   ) 
  
  if ($datavar.Hypervisor -match "ESX|VMware") {
    ###PreLoad
    $networkname = $datagen.nw2name
    $accounts = REST-List-SSP-Account -datagen $datagen -datavar $datavar
    $account = $accounts.entities | where {$_.Status.resources.type -eq "vmware"} | select -first 1
    $Templates =REST-LIST-SSP-VMwareImages -datagen $datagen -datavar $datavar -Accountuuid $account.metadata.uuid
    $Templates =REST-LIST-SSP-VMwareImages -datagen $datagen -datavar $datavar -Accountuuid $account.metadata.uuid
    $winimage = $Templates.entities.status.resources | where {$_.name -eq "Windows 2016"}
    $linimage = $Templates.entities.status.resources | where {$_.name -eq "CentOS 8"}
  } else {
    ###PreLoad
    $networkname = $datagen.nw1name
    $images = REST-Query-Images -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 
    $linimage = $images.entities | where {$_.spec.name -eq "CentOS_1CD" }
    $winimage = $images.entities | where {$_.spec.name -eq "Windows 2016" }
  }
  $subnet = (REST-Get-PE-Networks -datavar $datavar -datagen $datagen).entities | where {$_.name -eq $networkname}

  sleep 10
  $clusters = REST-Query-Cluster -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 

  $cluster = $cluster.entities | where { $_.spec.Resources.network -match "192.168.5"}

  write-log -message "Using Cluster $($cluster.metadata.uuid)"
  write-log -message "Using Subnet $($subnet.uuid)"
  write-log -message "Working on $customer" -slacklevel 1
  write-log -message "Creating Admin Group for $customer" 
    
  try {
    $admingroup = REST-Create-UserGroup -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -grouptype "admin-accounts-group" -customer $customer -domainname $datagen.Domainname
  } catch {

  write-log -message "Admin Group for $customer exists"

  $result = REST-Query-ADGroups -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount
  sleep 10
  $admingroup = $result.entities | where {$_.spec.resources.directory_service_user_group.distinguished_name -match $customer -and $_.spec.resources.directory_service_user_group.distinguished_name -match "admin-accounts-group"}

  }
  sleep 10
  write-log -message "Creating User Group for $customer"

  try { 
    $usergroup = REST-Create-UserGroup -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -grouptype "user-accounts-group" -customer $customer -domainname $datagen.Domainname
  } catch{

    write-log -message "User Group for $customer exists"

    $result = REST-Query-ADGroups -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount
    sleep 10
    $usergroup = $result.entities | where {$_.spec.resources.directory_service_user_group.distinguished_name -match $customer -and $_.spec.resources.directory_service_user_group.distinguished_name -match "user-accounts-group"}
    sleep 10
  }

  write-log -message "Using Admingroup $($admingroup.metadata.uuid)"
  write-log -message "Using Usergroup $($usergroup.metadata.uuid)"

  try {

    $project = REST-Create-Project -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -UserGroupName $usergroup.metadata.name -UserGroupUUID $usergroup.metadata.uuid -clusername $datagen.buildaccount -customer $customer -AdminGroupName $admingroup.metadata.name -AdminGroupUUID $admingroup.metadata.uuid -SubnetName $subnet.spec.name -subnetuuid $subnet.uuid

  } catch {

    $resultproject = REST-Query-Projects -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount 
    $project = $resultproject.entities | where {$_.spec.name -match $customer}

    write-log -message "Project already exists for $customer.."

  }

  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project

  write-log -message "Adding All accounts to $customer project."
    
  $accounts = REST-List-SSP-Account -datagen $datagen -datavar $datavar

  $projectdetail = REST-Get-ProjectDetail -datavar $datavar -datagen $datagen -project $project

  REST-update-project-Account -datavar $datavar -datagen $datagen -accounts $accounts -projectdetail $projectdetail
  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project

  write-log -message "Project UUID is $($project.metadata.uuid)"
  write-log -message "Getting Role uuids"

  $consumer = REST-Query-Role-List -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -rolename "Consumer"
  sleep 10
  $ProjectAdmin = REST-Query-Role-List -ClusterPC_IP $datagen.PCClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -rolename "Project Admin"
  sleep 10

  if ($datavar.Hypervisor -match "ESX|VMWare"){

    write-log -message "Adding $($account.metadata.uuid) account to the current project"
    write-log -message "Creating Environment" 

    $environments = REST-LIST-Environments -datagen $datagen -datavar $datavar;sleep 2
    $environment = $environments.entities| where {$_.status.name -match $customer}
    $environmentUUID  = $environment.metadata.uuid 
      
    $accounts = REST-List-SSP-Account -datagen $datagen -datavar $datavar
    $account = $accounts.entities | where {$_.Status.resources.type -eq "vmware"} | select -first 1

    REST-create-Environment-ESX -datagen $datagen -project $project -subnet $subnet -linimage $linimage -winimage $winimage -datavar $datavar -accountuuid $account.metadata.uuid -environment $environment
      
    $environments = REST-LIST-Environments -datagen $datagen -datavar $datavar;sleep 2
    $environment = $environments.entities| where {$_.status.name -match $customer}
    $environmentUUID  = $environment.metadata.uuid 
      
  } else {

    write-log -message "Creating Environment" 

    $environments = REST-LIST-Environments -datagen $datagen -datavar $datavar;sleep 2
    $environment = $environments.entities| where {$_.status.name -match $customer}
    $environmentUUID  = $environment.metadata.uuid
    sleep 5
    REST-create-Environment-AHV -datagen $datagen -project $project -subnet $subnet -linimage $linimage -winimage $winimage -datavar $datavar
    $environments = REST-LIST-Environments -datagen $datagen -datavar $datavar;sleep 2
    $environment = $environments.entities| where {$_.status.name -match $customer}
    $environmentUUID  = $environment.metadata.uuid

  }

     
  $environments = REST-LIST-Environments -datagen $datagen -datavar $datavar;sleep 2
  $environment = $environments.entities| where {$_.status.name -match $customer}

  sleep 5
  write-log -message "Updating Project with Environment with ID $($environment.metadata.uuid) for $customer" 
  $exit1 = 0
  $upenvcount = 0
  do {
    $upenvcount++
    try {

      write-log -message "Updating Project with Environment with ID $($environment.metadata.uuid) for $customer" 

      $projectdetail = REST-Get-ProjectDetail -datavar $datavar -datagen $datagen -project $project
      REST-update-project-Environment -datavar $datavar -datagen $datagen -environment $environment -projectdetail $projectdetail
      Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project

      $exit1 = 1
    } catch {

      write-log -message "Lets do ENV again"

      sleep 60
    }
  } until ($upenvcount -ge 5 -or $exit1 -eq 1)

  write-log -message "Updating Project with RBAC"
  
  $projectdetail = REST-Get-ProjectDetail -datavar $datavar -datagen $datagen -project $project
  REST-update-project-RBAC -datavar $datavar -datagen $datagen -environment $environment -projectdetail $projectdetail -usergroup $usergroup -admingroup $admingroup
  Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project

  ## ACP Has to go last
    
  $counter = 0
  $exit2 = 0
  do{
    $counter++
    try {
      
      write-log -message "Updating Project with ACP"
        
      $projectdetail = REST-Get-ProjectDetail -datavar $datavar -datagen $datagen -project $project ;sleep 15
      REST-update-project-ACP -datavar $datavar -datagen $datagen -projectdetail $projectdetail -customer $customer -usergroup $usergroup -admingroup $admingroup -consumer $consumer -ProjectAdmin $projectadmin -cluster $cluster
      Wait-Project-Save-State -datavar $datavar -datagen $datagen -project $project
      $exit2 = 1
    } catch {

      write-log -message "Lets do ACP again"

      sleep 60
      $exit2 = 0
    }  
  } until ($exit2 -eq 1 -or $counter -ge 5)
}
Export-ModuleMember *