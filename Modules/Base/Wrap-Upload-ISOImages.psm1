Function Wrap-Upload-ISOImages {
  param (
    [Object] $ISOurlData1,
    [Object] $ISOurlData2,
    [Object] $datavar,
    [Object] $datagen,
    [string] $mode
  )
  write-log -message "Getting Image Container"
  $maxFails = 3 

  $Failcount = 0
  $Failednames = $null
  $containers = REST-Get-Containers -clusername $datagen.buildaccount -clpassword $datavar.pepass -PEClusterIP $datavar.PEClusterIP

  ### Sorry poor mans coding, all changes have to be replicated, 2 different loops, Prio images and rest
  ### Added VMware to the same module, to remove additional overhead.

  if ($datavar.Hypervisor -match "ESX"){

    write-log -message "Picking the ESX Host Target"

    $hosts = REST-PE-Get-Hosts -datagen $datagen -datavar $datavar
    $ESXHost = ($hosts.entities.hypervisorKey)[0]
    $maxFails = 1
  }

  write-log -message "Picking the Image Container"

  $Imagecontainer = $containers.entities | where {$_.name -eq $datagen.ImagesContainerName}

  write-log -message "There we go, the image container is $($Imagecontainer.containerUuid)"
  $namelist = ($ISOurlData1 | gm | where {$_.membertype -eq "noteproperty"}).name
  $ISOurlData = $ISOurlData1
  $mainloop = 0
  do {
    if ($Failcount -ge $maxFails -or $Backup -eq 1){
        
      write-log -message "We should be done but have more than $maxFails Failures, $Failcount out of $($namelist.count)" -sev "WARN"
      write-log -message $Failednames
      write-log -message "Changing to Backup URL"

      $ISOurlData = $ISOurlData2
  
      $namelist = ($ISOurlData2 | gm | where {$_.membertype -eq "noteproperty"}).name
      $backupmode = 1
    } 
    $mainloop ++
    write-log -message "Building Prio Waitlist"
    #### KEEP IN MIND THE Same items are added to the base below to avoid duplicate uploads
    $Priowaitlist= $null
    if ($mode -eq "oracle"){
      if ($datavar.Hypervisor -match "ESX"){
        $ESXHost = ($hosts.entities.hypervisorKey)[2]
        sleep 90
      }
      [array]$Priowaitlist += $namelist | where {$_ -eq $datagen.Oracle1_0Image}
      [array]$Priowaitlist += $namelist | where {$_ -eq $datagen.Oracle1_1Image}
      [array]$Priowaitlist += $namelist | where {$_ -eq $datagen.Oracle1_2Image}
      [array]$Priowaitlist += $namelist | where {$_ -eq $datagen.Oracle1_3Image}
      [array]$Priowaitlist += $namelist | where {$_ -eq $datagen.Oracle1_4Image}
      [array]$Priowaitlist += $namelist | where {$_ -eq $datagen.Oracle1_5Image}
      [array]$Priowaitlist += $namelist | where {$_ -eq $datagen.Oracle1_6Image} 
      [array]$Priowaitlist += $namelist | where {$_ -eq $datagen.Oracle1_7Image}
      [array]$Priowaitlist += $namelist | where {$_ -eq $datagen.Oracle1_8Image}
      [array]$Priowaitlist += $namelist | where {$_ -eq $datagen.Oracle1_9Image} 

    } elseif ($mode -eq "MSSQL"){
      if ($datavar.Hypervisor -match "ESX"){
        $ESXHost = ($hosts.entities.hypervisorKey)[1]
        sleep 90
      }
      [array]$Priowaitlist += $namelist | where {$_ -eq $datagen.ERA_MSSQLImage}

    } else {
      
      [array]$Priowaitlist += $namelist | where {$_ -eq $datagen.DC_ImageName}
      if ($datavar.installera -ge 1){
        [array]$Priowaitlist += $namelist | where {$_ -eq $datagen.ERA_ImageName}
      }
      [array]$Priowaitlist += $namelist | where {$_ -eq $datagen.Move_ImageName}
      [array]$Priowaitlist += $namelist | where {$_ -eq $datagen.Frame_WinImage}
      [array]$Priowaitlist += $namelist | where {$_ -eq $datagen.XRAY_Imagename}
      [array]$Priowaitlist += "CentOS_1CD"
      [array]$Priowaitlist += "Windows 2012"
      

      if ($datavar.Hypervisor -match "ESX"){

        write-log -message "ESX Uploads are always sequential. using 3 threads."

        [array]$Difflist = $namelist | where {$_ -notin $Priowaitlist -and $_ -notmatch "MSSQL|Oracle"}
        [array]$Priowaitlist += $Difflist

      } else{

        write-log -message "Uploading WaitList First"

      }

    }
    write-log -message "There are $($Priowaitlist.count) images in the (wait) list"
    
  
    foreach ($image in $Priowaitlist){
  
      write-log -message "Working on $image"
      write-log -message "URL is $($ISOurlData.$($image))"
      write-log -message "Hypervisor is $($datavar.Hypervisor)"
  
      $maxloops = 8000
      $imageobj = $null
      if ($datavar.Hypervisor -notmatch "ESX"){
        $images = REST-Query-Images -ClusterPC_IP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -silent 1
        $imageobj = $images.entities | where {$_.spec.name -eq $image }
    
        if (!$imageobj -and ($Failcount -le $maxFails -or $backupmode -eq 1 -and $ISOurlData.$($image) -ne "NA-AHV")){
          $task = REST-Upload-Image -datavar $datavar -datagen $datagen -imageContainerUUID $Imagecontainer.containerUuid -ImageName $image -ImageURL $ISOurlData.$($image)
    
          write-log -message "Uploaded started for $image, using taskID $($task.taskUuid)"
          write-log -message "This is the wait list, so guess what, where waiting..."
          write-log -message "Checking every 15sec, max $maxloops times"
    
          $count = 0
          do {
            $count ++
            if ($count % 4 -eq 0){  
    
              write-log -message "cycle $count out of $maxloops"
    
            }
            $tasks = REST-Get-AOS-LegacyTask -datagen $datagen -datavar $datavar
            $uploadstatus = $tasks.entities | where {$_.id -eq $task.taskUuid}
            
            if ($uploadstatus.percentagecompleted -ne 100){
              sleep 10 
              if ($count % 4 -eq 0){
    
                write-log -message "Image is still being uploaded. $($uploadstatus.percentagecompleted) % Status is $($uploadstatus.status)"
    
              }
            } else {
      
              write-log -message "Upload status is $($uploadstatus.status) $($uploadstatus.percentagecompleted) %"
      
              $images = REST-Query-Images -ClusterPC_IP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -silent 1
              $imageobj = $images.entities | where {$_.spec.name -eq $image }
      
              if ($imageobj){
      
                write-log -message "Image is present $($imageobj.status.name)"
                write-log -message "Image was granted UUID $($imageobj.metadata.uuid)"
              
              }
            }
          } until ($imageobj -or $count -ge $maxloops -or $uploadstatus.status -eq "failed")
    
          if ($uploadstatus.status -eq "failed"){
            $Failcount ++
            [array]$Failednames += $image 
            if ($mainloop -eq 1){
              write-log -message "Lets fail fast" -sev "WARN"
  
              $Backup = 1
  
            }
          }
    
        } elseif ($ISOurlData.$($image) -eq "NA-AHV"){

          write-log -message "Image $image is not required for AHV"
        
        } else {
    
          write-log -message "Image is present $($imageobj.status.name)"
          write-log -message "Image was granted UUID $($imageobj.metadata.uuid)"
    
        }
      } else {

        write-log -message "Starting ESXi Upload"
        write-log -message "Upload Target ESX Host is '$ESXHost'"

        $filename = $($ISOurlData.$($image)) -split "/" | select -last 1
        $Securepass = ConvertTo-SecureString $datavar.pepass -AsPlainText -Force;
        $credential = New-Object System.Management.Automation.PSCredential ("root", $Securepass);
        $session = New-SSHSession -ComputerName $ESXHost -Credential $credential -AcceptKey;
        $check = ((Invoke-SSHCommand -SSHSession $session -command "cd /vmfs/volumes/$($datagen.ImagesContainerName)/;ls -ltr" -timeout 999 -EnsureConnection -ea:0).output) | where {$_ -match $filename -or $_ -match "Temp_$($filename)" -and $_ -match "chk"} | select -first 1

        if ($filename -match "ova|ovf"){

          write-log -message "Nothing to do here."

        } elseif ($check){

          write-log -message "Image present and already passed the control check"

        } else {
          

          write-log -message "Uploading $filename towards /vmfs/volumes/$($datagen.ImagesContainerName)/$($filename)"
  
          $Securepass = ConvertTo-SecureString $datavar.pepass -AsPlainText -Force;
          $credential = New-Object System.Management.Automation.PSCredential ("root", $Securepass);
          $session = New-SSHSession -ComputerName $ESXHost -Credential $credential -AcceptKey;
          
          write-log -message "Connected to the host $ESXHost, starting the upload"
  
          $Clean = Invoke-SSHCommand -SSHSession $session -command "sudo rm /vmfs/volumes/$($datagen.ImagesContainerName)/$filename" 
          sleep 4
          $URL = $($ISOurlData.$($image))

          if ($URL -match "https"){

            write-log -message "https backup urls are not supported. Primary datasource failures?" -sev "WARN"

          } else {
            try {

              $Securepass = ConvertTo-SecureString $datavar.pepass -AsPlainText -Force;
              $credential = New-Object System.Management.Automation.PSCredential ("root", $Securepass);
              $session = New-SSHSession -ComputerName $ESXHost -Credential $credential -AcceptKey;
              $Upload = Invoke-SSHCommand -SSHSession $session -command "cd /vmfs/volumes/$($datagen.ImagesContainerName)/;wget $URL" -timeout 999 -EnsureConnection
            
            } catch {

              write-log -message "Retry" -sev "WARN"

              sleep 60
              $Securepass = ConvertTo-SecureString $datavar.pepass -AsPlainText -Force;
              $credential = New-Object System.Management.Automation.PSCredential ("root", $Securepass);
              $session = New-SSHSession -ComputerName $ESXHost -Credential $credential -AcceptKey;
              $Clean = Invoke-SSHCommand -SSHSession $session -command "sudo rm /vmfs/volumes/$($datagen.ImagesContainerName)/$filename"
              $Upload = Invoke-SSHCommand -SSHSession $session -command "cd /vmfs/volumes/$($datagen.ImagesContainerName)/;wget $URL" -timeout 999 -EnsureConnection
            } 
              sleep 10
            [array]$Imagestatus = (Invoke-SSHCommand -SSHSession $session -command "cd /vmfs/volumes/$($datagen.ImagesContainerName)/;ls" -timeout 999 -EnsureConnection).output
            if ($debug -ge 2){
  
              write-log -message "Below all images"
  
              $Imagestatus
            }
            if ($filename -notin $imagestatus){
              $count = 0
              do {
  
                write-log -message "Getting Image status some more."
  
                $count++
                sleep 10
                $session = New-SSHSession -ComputerName $ESXHost -Credential $credential -AcceptKey;
                [array]$Imagestatus = (Invoke-SSHCommand -SSHSession $session -command "cd /vmfs/volumes/$($datagen.ImagesContainerName)/;ls" -timeout 999 -EnsureConnection).output
                $hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
                $session | remove-sshsession
  
              } until ($filename -in $imagestatus -or $count -ge 6)
  
              if ($filename -notin $imagestatus){
  
                $Failcount ++
                [array]$Failednames += $image 
      
                write-log -message "Image not found after upload...." -sev "WARN"
  
              } 

            }

            if ($filename -in $imagestatus){
              $intcount = 0 
              do {
                $exclude = 0
                $intcount ++

                write-log -message "Image Located in the datastore"
                write-log -message "Executing Bite Check."

                CMD-Connect-VMware -datavar $datavar

                $datastoreitem = (get-item vmstores:\$($datavar.vcenterip)@443\Nutanix\$($datagen.imagescontainername)\$filename).length
                $URLControl = $URL + ".chk"
                try{
                  $controlsize = (invoke-webrequest -uri $URLControl).RawContent -split "\n"| select -last 1
                } catch {

                  write-log -message "Cannot execute bite size check for $URL"

                  $exclude = 1
                }
                if ($datastoreitem -ne $controlsize -and $exclude -ne 1){
        
                  write-log -message "Bitesize Check Failed expecting $controlsize bites, got only $datastoreitem" -SEV "WARN"
                  write-log -message "Cleaning $filename" -SEV "WARN"

                  $session = New-SSHSession -ComputerName $ESXHost -Credential $credential -AcceptKey;
                  $Clean = Invoke-SSHCommand -SSHSession $session -command "sudo rm /vmfs/volumes/$($datagen.ImagesContainerName)/$filename"

                  write-log -message "Uploading $filename using $URL" -SEV "WARN"
                  $Upload = Invoke-SSHCommand -SSHSession $session -command "cd /vmfs/volumes/$($datagen.ImagesContainerName)/;wget $URL" -timeout 999 -EnsureConnection
  
                } elseif ($exclude -eq 1){

                  write-log -message "Bitesize Check Impossible for public URLs"

                } else {

                  write-log -message "Writing done file"

                  $Clean = Invoke-SSHCommand -SSHSession $session -command "echo 'done' > /vmfs/volumes/$($datagen.ImagesContainerName)/$filename-$($datavar.queueuuid).chk"
                  
                  write-log -message "Bitesize Check Confirmed"


                }
              } until ($datastoreitem -eq $controlsize -or $Intcount -ge 5 -or $exclude -eq 1)

            }
    
            $hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
            $session | remove-sshsession
          }
        }
      }
    }

    ## Only if we havnt failed alot, we proceed with the non wait list.


    if ($mode -eq "Base" -and ($Failcount -le $maxFails -or $backupmode -eq 1 -and $ISOurlData.$($image) -ne "NA-AHV") -and $datavar.Hypervisor -match "Nutanix|AHV"){
      $exclude = $null
      [array]$Exclude += $Priowaitlist
      [array]$Exclude += $namelist | where {$_ -match "MSSQL|Oracle"}

      foreach ($image in $namelist){
        if ($image -notin $Exclude -and $image -notmatch "xx"){
          [array]$nonWaitlist += $image
        }
      }
    
      write-log -message "We have $($nonWaitlist.count) images remaining. AHV Only"
    
      foreach ($image in $nonWaitlist){
    
        write-log -message "Working on $image"
        write-log -message "URL is $($ISOurlData.$($image))"
         
        $maxloops = 4
        $imageobj = $null
        
        $images = REST-Query-Images -ClusterPC_IP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -silent 1
        $imageobj = $images.entities | where {$_.spec.name -eq $image }
      
        if (!$imageobj -and $ISOurlData.$($image) -ne "NA-AHV"){
          $task = REST-Upload-Image -datavar $datavar -datagen $datagen -imageContainerUUID $Imagecontainer.containerUuid -ImageName $image -ImageURL $ISOurlData.$($image)
      
          write-log -message "Uploaded started for $image, using taskID $($task.taskUuid)"
          write-log -message "This is the non wait list, so guess what, Were bailing after $maxloops loops"
      
          $count = 0
          do {
            $count ++
            if ($count % 4 -eq 0){  
      
              write-log -message "cycle $count out of $maxloops"
      
            }
            $tasks = REST-Get-AOS-LegacyTask -datagen $datagen -datavar $datavar
            $uploadstatus = $tasks.entities | where {$_.id -eq $task.taskUuid}
              
            if ($uploadstatus.percentagecompleted -ne 100){
              sleep 10 
              if ($count % 4 -eq 0){
                foreach ($image in $uploadstatus){
                  write-log -message "Image is still being uploaded. $($image.percentagecompleted) % Status is $($image.status)"
                }
              }
            } else {
        
              write-log -message "Upload status is $($uploadstatus.status) $($uploadstatus.percentagecompleted) %"
        
              $images = REST-Query-Images -ClusterPC_IP $datavar.PEClusterIP -clpassword $datavar.pepass -clusername $datagen.buildaccount -silent 1
              $imageobj = $images.entities | where {$_.spec.name -eq $image }
        
              if ($imageobj){
        
                write-log -message "Image is present $($imageobj.status.name)"
                write-log -message "Image was granted UUID $($imageobj.metadata.uuid)"
                
              }
            }
          } until ($imageobj -or $count -ge $maxloops -or $uploadstatus.status -eq "failed")
      
          if ($uploadstatus.status -eq "failed"){
            $Failcount ++
            [array]$Failednames += $image 
          }
      
        } elseif ($ISOurlData.$($image) -eq "NA-AHV"){

          write-log -message "Image $image is not required for AHV"

        } else {
      
          write-log -message "Image is present $($imageobj.status.name)"
          write-log -message "Image was granted UUID $($imageobj.metadata.uuid)"
      
        }

      }

    } else {

      write-log -message "No Action Needed in oracle mode"

    }
  } until ($Failcount -le 0 -or $mainloop -ge 3)

  if ($mode -eq "Oracle" -and $datavar.Hypervisor -notmatch "ESX"){

    $imageimport = REST-Image-Import-PC -clpassword $datavar.PEPass -clusername $datagen.buildaccount -PCClusterIP $datagen.PCClusterIP -failsilent 1

  } 
  if ($Failcount -ge 4){
    
    $status = "Failed"

    write-log -message "Number of images failed is $Failcount out of $($namelist.count)" -sev "ERROR"

  } elseif ($Failcount -ge 3) {

    $status = "Success"

    write-log -message "Number of images failed is $Failcount out of $($namelist.count)" -sev "WARN"

  } else {

    $status = "Success"

    write-log -message "Number of images failed is $Failcount out of $($namelist.count)"  

  }
  $resultobject =@{
    Result = $status
  };
  return $resultobject
}
 
