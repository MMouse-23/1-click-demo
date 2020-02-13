
function Wrap-Install-PC {
  param(
    [object] $datagen,
    [object] $datavar,
    $stage,
    $logfile
  )
  
  ## 2 Stage wrapper to keep the code together.
  ## Stage 2 is on top, stage one is on the bottom. 

  $counter =0
  if ( $stage -ne 1){
    write-log -message "Stage 2, checking prism Central Install status."
    write-log -message "AOS $($datavar.AOSVersion) PC $($datavar.PCVersion)"
    write-log -message "We have to wait for PC Installer now"
    do {
      try{
        $counter ++
        write-log -message "Cycle $counter out of 25(minutes)."
  
        $tasks = REST-PE-ProgressMonitor -datavar $datavar -datagen $datagen
        $installtask = $tasks.entities | where {$_.operation -eq "PrismCentralDeploymentRequest"}
        if (!$installtask){

          write-log -message "We should not ever be here."

        } else {

          write-log -message "PC Install Detected"

        }
        foreach ($item in $installtask){
          if ($item.percentageCompleted -eq 100 -and $item.status -ne "Running") {
            $Deploycheck = "Success"
  
            write-log -message "PC Deploy task $($item.ID) is completed."
            write-log -message "PC Deploy task has status $($item.status)"

          } elseif ($item.percentageCompleted -ne 100){
  
            write-log -message "PC Deploy is at $($item.percentageCompleted) % Status is $($item.status)"
  
            $Deploycheck = "Running"
          }
        }
        if ($Deploycheck -eq "Success"){

          write-log -message "PC should be installed."

        } else{
          sleep 60
        }
      }catch{
        write-log -message "Error caught in loop."
      }
    } until ($Deploycheck -eq "Success" -or $counter -ge 25)

    write-log -message "Reset PC Password $($datagen.PCClusterIP)" -slacklevel 1

    $status1 = SSH-ResetPass-Px -PxClusterIP $datagen.PCClusterIP -clusername $datavar.peadmin -clpassword $datavar.PEPass -mode "PC"
    sleep 30

    if ($status1.result -eq "Success"){

      write-log -message "Sleeping 2 minutes for pw reset"

      if ($datavar.pcmode -eq 3){
        
        write-log -message "Sleeping for PC Scaleout PC Sync"
  
        $count = 0
        do {
          $count++
  
          write-log -message "Sleeping 30 seconds for $count out of 3"
  
          sleep 30
        } until ($count -eq 3)
      }

      write-log -message "Creating Service Accounts" -slacklevel 1

      $status = SSH-ServiceAccounts-Px -PxClusterIP $datagen.PCClusterIP -datavar $datavar -datagen $datagen

      write-log -message "Prism Central Finalize Login" -slacklevel 1

      REST-Finalize-Px -clusername $datagen.buildaccount -clpassword $datavar.PEPass -ClusterPx_IP $datagen.PCClusterIP -sename $datagen.sename -serole $datagen.serole -SECompany $datagen.SECompany -EnablePulse $datagen.EnablePulse
 
      write-log -message "Add Prism Element cluster to Prism Central Cluster" -slacklevel 1

      $status2 = PSR-MulticlusterPE-PC -datavar $datavar -datagen $datagen
      #$status2 = CMD-Add-PEtoPC -PEClusterIP $datavar.PEClusterIP -PCClusterIP $datagen.PCClusterIP -PEAdmin $datagen.buildaccount -PEPass $datavar.PEPass 

      write $status2

      $fixed = $status2.result
      write $fixed
      write-log "Here^"
      sleep 5
    } else {

      write-log -message "SSH Reset failed, there is no point in proceding.."

    }

    write-log -message "Password reset status is $($status1.result)"
    write-log -message "Join PE status is $($status2.result)"
    sleep 60 

    if ($status1.result -ne "Success" -or $status2.result -ne "Success"){

      $MasterLoopCounter = 0
      do{
        $MasterLoopCounter++
        try {

          write-log -message "Prism Central needs help, cleaning" -slacklevel 1
          write-log -message "This causes a 30 minute delay" -slacklevel 2


            LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "PCFailed" -logfile $logfile
      
            $hide = LIB-Connect-PSNutanix -ClusterName $datavar.PEClusterIP -NutanixClusterUsername $datagen.buildaccount -NutanixClusterPassword $datavar.PEPass
            $hide = get-ntnxvm | where {$_.vmname -match "^PC"} | Set-NTNXVMPowerOff -ea:0
            if ($debug -ge 3){
              $hide = get-ntnxvm | where {$_.vmname -match "^PC"} | set-NTNXVirtualMachine -name "DeadPC0$($MasterLoopCounter)"
            } else {
              $hide = get-ntnxvm | where {$_.vmname -match "^PC"} | Remove-NTNXVirtualMachine -ea:0
            }
            
            sleep 40
            $status = REST-Install-PC -DisksContainerName $datagen.DisksContainerName -AOSVersion $datavar.AOSVersion -clusername $datagen.buildaccount -clpassword $datavar.PEPass -ClusterPE_IP $datavar.PEClusterIP -PCClusterIP $datagen.PCClusterIP -InfraSubnetmask $datavar.InfraSubnetmask -InfraGateway $datavar.InfraGateway -DNSServer $datavar.DNSServer -PC1_Name $datagen.PCNode1Name -PC2_Name $datagen.PCNode2Name -PC3_Name $datagen.PCNode3Name -PC1_IP $datagen.PCNode1IP -PC2_IP $datagen.PCNode2IP -PC3_IP $datagen.PCNode3IP -Networkname $datagen.Nw1Name -PCVersion $($datavar.PCVersion) -PCmode $datavar.PCmode 
            sleep 119
            write-log -message "Sleeping 30 minutes for install, 8 minutes fixed, the rest dynamic."
            sleep 119
            write-log -message "Prism Central deleted and is reinstalling." -slacklevel 2
            sleep 119
            write-log -message "We have to wait for PC Installer now"
            sleep 119
            write-log -message "Prism Central installer......" 
            sleep 119
            write-log -message "Waiting....." 
            sleep 119
            write-log -message "About to proceed....." -slacklevel 2
            sleep 119
            $counter = 0
            $count = 0
            do {
              try{
                $counter ++
                write-log -message "Cycle $counter out of 30(minutes)."   
                $tasks = REST-PE-ProgressMonitor -datavar $datavar -datagen $datagen
                $installtask = $tasks.entities | where {$_.operation -eq "PrismCentralDeploymentRequest"}
      
                $Deploycheck = "Success"
                foreach ($item in $installtask){
                  if ($item.percentageCompleted -eq 100 -and $item.status -ne "Running") {
          
                    write-log -message "Found 1 PC Deploy task $($item.ID) is completed."
                    write-log -message "That PC Deploy task has status $($item.status)."
        
                  } elseif ($item.percentageCompleted -ne 100 ){
          
                    write-log -message "Found 1 PC Deploy is at $($item.percentageCompleted) %"
                    write-log -message "That PC Deploy task has status $($item.status)."
                    
                    $Deploycheck = "Running"
                  }
                }
                if ($Deploycheck -eq "Success"){
        
                  write-log -message "PC is installed."
        
                } else{
                  sleep 60
                }
              }catch{
                write-log -message "Error caught in loop."
              }
            } until ($Deploycheck -eq "Success" -or $counter -ge 30)
         
          write-log -message "Running Post installer steps"  -sev "CHAPTER"  -slacklevel 2
    
          $status1 = SSH-ResetPass-Px -PxClusterIP $datagen.PCClusterIP -clusername $datavar.PEAdmin -clpassword $datavar.PEPass -mode "PC"
    
          if ($status1.result -eq "Success" ){
            if ($datavar.pcmode -eq 3){
              write-log -message "Sleeping for PC Scaleout PC Sync"
        
              $count = 0
              do {
                $count++
        
                write-log -message "Sleeping 40 seconds for $count out of 3"
        
                sleep 40
              } until ($count -eq 3)
    
    
            }

            REST-Finalize-Px -clusername $datavar.PEAdmin -clpassword $datavar.PEPass -ClusterPx_IP $datagen.PCClusterIP -sename $datagen.sename -serole $datagen.serole -SECompany $datagen.SECompany -EnablePulse $datagen.EnablePulse
            $Output = SSH-ServiceAccounts-Px -PxClusterIP $datagen.PCClusterIP -datavar $datavar -datagen $datagen
            $status2 = PSR-MulticlusterPE-PC -datavar $datavar -datagen $datagen
            $status2 = CMD-Add-PEtoPC -PEClusterIP $datavar.PEClusterIP -PCClusterIP $datagen.PCClusterIP -PEAdmin $datagen.buildaccount -PEPass $datavar.PEPass 
 
            write-log -message "Prism Central Installed, updating" -sev "CHAPTER"  -slacklevel 2
    
            LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "PCSuccess" -logfile $logfile
            if ($datavar.Installkarbon -eq 1){

              write-log -message "Enable Karbon" -sev "CHAPTER"  -slacklevel 2

              REST-Enable-Karbon-PC -datavar $datavar -datagen $datagen            
            }
            
            if ($status2.result -eq "Success"){
              $result = "success"
            }
          } else {
    
            $result = "Failed"
    
          }

        } catch {

          write-log -message "I should not be here."

        }
      } until ($result -eq "success" -or $MasterLoopCounter -ge 8)

    } else {

      $result = "Success"
      LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $datagen -datavar $datavar -mode "PCSuccess" -logfile $logfile
      write-log -message "Prism Central Post install completed."
      if ($datavar.Installkarbon -eq 1){
              
        write-log -message "Enable Karbon" -sev "CHAPTER"  -slacklevel 1

        REST-Enable-Karbon-PC -datavar $datavar -datagen $datagen
        sleep 119            
      }
      ##REST-LCM-Perform-Inventory -datavar $datavar -datagen $datagen -mode "PC"
      #sleep 119
      ## Just once !!!

    }

  } else {

    $startcounter =0
    write-log -message "Checking NCLI for PC download status" 
    $Securepass = ConvertTo-SecureString $datavar.pepass -AsPlainText -Force;
    $credential = New-Object System.Management.Automation.PSCredential ("admin", $Securepass);
    $session = New-SSHSession -ComputerName $datavar.peclusterip -Credential $credential -AcceptKey;
    do {
      $pcstatuscheck++
      $credential = New-Object System.Management.Automation.PSCredential ("admin", $Securepass);
      $session = New-SSHSession -ComputerName $datavar.peclusterip -Credential $credential -AcceptKey;
      $PCDownloadStatus = (Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=PRISM_CENTRAL_DEPLOY name='$($datavar.PCVersion)'" -EnsureConnection).output
      get-sshsession | remove-sshsession -ea:0
      sleep 30
      if ($debug -ge 2){
        $PCDownloadStatus
      }
      if ($PCDownloadStatus -match "failed"){

        write-log -message "PC Download failed, restarting download" 
        $credential = New-Object System.Management.Automation.PSCredential ("admin", $Securepass);
        $session = New-SSHSession -ComputerName $datavar.peclusterip -Credential $credential -AcceptKey;
        $PCDownload = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software download software-type='PRISM_CENTRAL_DEPLOY' name='$($truePCversion)'" -EnsureConnection

      } elseif ($PCDownloadStatus -notmatch "completed"){
      
        write-log -message "Still downloading Prism Central. $PCDownloadStatus" 
    
      } else {

        write-log -message "PCDownload Completed" 

      }
    } until ($pcstatuscheck -ge 20 -or $PCDownloadStatus -match "completed")

    write-log -message "Download Completed, Starting PC Installer" 

    $status = REST-Install-PC -DisksContainerName $datagen.DisksContainerName -AOSVersion $datavar.AOSVersion -clusername $datagen.buildaccount -clpassword $datavar.PEPass -ClusterPE_IP $datavar.PEClusterIP -PCClusterIP $datagen.PCClusterIP -InfraSubnetmask $datavar.InfraSubnetmask -InfraGateway $datavar.InfraGateway -DNSServer $datavar.DNSServer -PC1_Name $datagen.PCNode1Name -PC2_Name $datagen.PCNode2Name -PC3_Name $datagen.PCNode3Name -PC1_IP $datagen.PCNode1IP -PC2_IP $datagen.PCNode2IP -PC3_IP $datagen.PCNode3IP -Networkname $datagen.Nw1Name -PCVersion $($datavar.PCVersion) -PCmode $datavar.PCmode   

    write-log -message "Prism Central should be started, checking."
    ## The loop below is to detect running status.
    ## If running stage 1 is complete
    ## This is not required on the stage 2 fallbackloop above because the Loop is much shorter as the previous failure is always detected and the loop exits because of that.



    do {
      try{
        $counter ++

        write-log -message "Cycle $counter out of 25(minutes)."

        sleep 119
        $tasks = REST-PE-ProgressMonitor -datavar $datavar -datagen $datagen
        $installtask = $tasks.entities | where {$_.operation -eq "PrismCentralDeploymentRequest"}
        if (!$installtask){
          $startcounter++

          write-log -message "Did not detect PS Install."

          if ($startcounter -eq 3){

            write-log -message "Lets kick it again."

            $status = REST-Install-PC -DisksContainerName $datagen.DisksContainerName -AOSVersion $datavar.AOSVersion -clusername $datagen.buildaccount -clpassword $datavar.PEPass -ClusterPE_IP $datavar.PEClusterIP -PCClusterIP $datagen.PCClusterIP -InfraSubnetmask $datavar.InfraSubnetmask -InfraGateway $datavar.InfraGateway -DNSServer $datavar.DNSServer -PC1_Name $datagen.PCNode1Name -PC2_Name $datagen.PCNode2Name -PC3_Name $datagen.PCNode3Name -PC1_IP $datagen.PCNode1IP -PC2_IP $datagen.PCNode2IP -PC3_IP $datagen.PCNode3IP -Networkname $datagen.Nw1Name -PCVersion $($datavar.PCVersion) -PCmode $datavar.PCmode   
          }
          $tasks = REST-PE-ProgressMonitor -datavar $datavar -datagen $datagen
          $installtask = $tasks.entities | where {$_.operation -eq "PrismCentralDeploymentRequest"}

        } else {

          write-log -message "PC Install Detected"
          foreach ($item in $installtask){
            if ($item.percentageCompleted -eq 100 -and $item.status -ne "Running") {
              $Deploycheck = "Success"
    
              write-log -message "PC Deploy (download) task $($item.ID) is completed."
  
            } elseif ($item.percentageCompleted -ne 100 -or  $item.status -eq "Running"){
    
              write-log -message "PC Deploy is at $($item.percentageCompleted) % Status is $($item.status)"
    
              $Deploycheck = "Running"
              if ($item.percentageCompleted -eq 55 -and $item.status -eq "Running"){
                $exit55 = 1
              }
    
            }
          }
        }
      } catch {

        write-log -message "Error caught in loop."

      }
    } until ($exit55 -eq 1 -or $counter -ge 5)
    $result = "Partial"
  };

  if ($result -match "Success"){
    $status = "Success"

    #SSH-PC-InsertHotfix -filename1 "$basedir\Binaries\PC\update-msp.sh" -datagen $datagen -datavar $datavar

    write-log -message "PC Install Completed" -sev "CHAPTER"
    write-log -message "Loving it";

    $result

  } elseif ($result -eq "Partial") {
    
    $status = "Success"

    write-log -message "Ill be back.";

  } else {

    $status = "Failed"

    write-log -message "Danger Will Robbinson." -sev "ERROR";

  }
  $resultobject =@{
    Result = $status
  };
  return $resultobject
}
Export-ModuleMember *
