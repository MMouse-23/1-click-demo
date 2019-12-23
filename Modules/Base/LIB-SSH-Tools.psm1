Function SSH-PC-InsertHotfix {
  Param (
    [object] $datavar,
    [object] $datagen,
    [string] $filename1
  )
  #dependencies LIB-write-log, Posh-SSH, PE_ncli

  $count = 0 
  write-log -message "Building Credential for SSH session";
  $hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
  $Securepass = ConvertTo-SecureString $datavar.pepass -AsPlainText -Force;
  $credential = New-Object System.Management.Automation.PSCredential ('nutanix', $Securepass);
  $session = New-SSHSession -ComputerName $datagen.PCClusterIP -Credential $credential -AcceptKey;
  
  write-log -message "Building session";

  do {;
    $count1++
    try {;
      $session = New-SSHSession -ComputerName $datagen.PCClusterIP -Credential $credential -AcceptKey -connectiontimeout 20

      write-log -message "Installing dos2unix"

      $Install = Invoke-SSHCommand -SSHSession $session -command "sudo yum install dos2unix -y" -EnsureConnection
      sleep 10
      
      write-log -message "Uploading the file $filename1"
      write-log -message "To Its destination /home/nutanix"

      $upload = Set-SCPFile -LocalFile $filename1 -RemotePath "/home/nutanix" -ComputerName $datagen.PCClusterIP -Credential $credential -AcceptKey $true -connectiontimeout 20

      write-log -message "Setting XBit";

      $chmod = Invoke-SSHCommand -SSHSession $session -command "chmod +x /home/nutanix/update-msp.sh" -EnsureConnection -timeout 20 -ea:0;

      sleep 10

      write-log -message "Converting";

      $chmod = Invoke-SSHCommand -SSHSession $session -command "dos2unix /home/nutanix/update-msp.sh" -EnsureConnection -timeout 20 -ea:0;

      sleep 10

      write-log -message "Executing";

      $Execute1 = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/update-msp.sh" -EnsureConnection -timeout 20 -ea:0;
   
      $completedp1 = 1
      $Execute1.ExitStatus
      $Execute1.Output
    } catch {

      write-log -message "Failure during upload or execute";

    }

  } until (($completedp1 -eq 1 -and $Execute1.ExitStatus -eq 0 ) -or $count1 -ge 6)

  if ($completedp1 -eq 1 -and $Execute1.ExitStatus -eq 0 ){

    write-log -message "One small step for man, one giant leap for mankind.";

    $status = "Success"
  } else {
    $status = "Failed"
  }
  $resultobject =@{
    Result = $status
    Output = $result.output
  }
  Try {
    write-log -message "Executing session cleanup"
    $clean = Remove-SSHSession -SSHSession $session
  } catch {}
  return $resultobject
};


Function SSH-Restart-KeepAlived {
  Param (
    [object] $datavar,
    [object] $datagen
  )
  #This module is tot repair an Objects 1.0 bug.
  $hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
  $Resetpasscount = 0 
  $passreset = $false
  $Securepass = ConvertTo-SecureString $datavar.PreDestroyPass -AsPlainText -Force; 
  
  write-log -message "Building Credential for SSH session";

  [Array]$ObjectsIPs = $datagen.ObjectsIntRange.split("|") | select -first 1
  

  write-log -message "Using $($Objectsips.count) Objects IPs";   

  $sshusername = "nutanix"
  $oldpass = "nutanix/4u"
  $oldSecurepass = ConvertTo-SecureString $oldpass -AsPlainText -Force; 

  write-log -message "Restarting KeepAlived Nutanix";
  foreach ($ip in $ObjectsIPs){
    try {
      $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $oldSecurepass);
      $session = New-SSHSession -ComputerName $ip -Credential $credential -AcceptKey -connectiontimeout 120 -operationtimeout 100 -ea:0
      $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
      $output0 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "sudo systemctl restart keepalived"
      if ($Output0 -match "password for"){
        write-log -message "Sending sudo pass"
        $output1 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command $oldpass
      }
      write-log -message "Hmm that went well on $ip."
    } catch {

      write-log -message "Not needed on this node $ip." -sev "WARN"

    }     
    $hide = Get-sshsession | Remove-SSHSession
  }
};

Function SSH-Manage-SoftwarePE {
  Param (
    [string] $ClusterPE_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $PCversion,
    [string] $FilesVersion, 
    [string] $Model,
    [string] $pcwait,
    [string] $AOSversion
  )
  #dependencies LIB-write-log, Posh-SSH, PE_ncli
  $hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
  $Filesdownloadcount = 0 
  $pcdownloadcount = 0 
  $pcstatuscheck = 0
  $AFSStatuscheck = 0 


  write-log -message "Building Credential for SSH session";
  write-log -message "Using PC Version $PCversion";
  write-log -message "Using Files Version $FilesVersion";
  write-log -message "Using AOS Version $AOSVersion";

  $Securepass = ConvertTo-SecureString $clpassword -AsPlainText -Force;
  $credential = New-Object System.Management.Automation.PSCredential ($clusername, $Securepass);
  if ($mode -ne "PC"){
    do {;
      $pcdownloadcount++
      $pcstatuscheck = 0
      try {;
        ## PC wait Disabled and code replicated in pc install wrapper
        $session = New-SSHSession -ComputerName $ClusterPE_IP -Credential $credential -AcceptKey;
        write-log -message "Downloading the latest PC, Telling AOS to do their own work.";
        $PossiblePCVersions = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=PRISM_CENTRAL_DEPLOY" -EnsureConnection
        $PCDownloadStatus = (Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=PRISM_CENTRAL_DEPLOY name='$($truePCversion)'" -EnsureConnection).output
        $object = ($PossiblePCVersions.Output | ConvertFrom-Csv -Delimiter : )
        if ($PCversion -ne "Latest"){
  
          write-log -message "Checking if requested version is possible."
  
          $MatchingVersion = $object.'Prism Central Deploy' | where {$_ -match "[0-9]" -and $_ -notmatch "bytes|in-progress"} | sort { [version]$_} | where {$_ -eq $PCversion} | select -last 1
          if ($matchingversion){
  
            write-log -message "Requested version found $truePCversion"
  
            $truePCversion = $MatchingVersion
          } else {;
    
            write-log -message "Version $PCversion not found as available within this AOS Version. Using latest."
  
            $PCversion = "Latest";
          };
        };
        if ($PCversion -eq "Latest"){
          $truePCversion = $object.'Prism Central Deploy' | where {$_ -match "[0-9]" -and $_ -notmatch "bytes|in-progress"} | sort { [version]$_} | select -last 1
  
          write-log -message "We are using $truePCversion"
  
        } 
        write-log -message "Starting the download of Prism Central $truePCversion"
  
        $PCDownload = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software download software-type='PRISM_CENTRAL_DEPLOY' name='$($truePCversion)'" -EnsureConnection
        if ($debug -ge 2){
          $PCDownload
        }
        if ($pcwait -eq 1){
          do {
            $pcstatuscheck++
            $PCDownloadStatus = (Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=PRISM_CENTRAL_DEPLOY name='$($truePCversion)'" -EnsureConnection).output
            sleep 90
            if ($debug -ge 2){
              $PCDownloadStatus
            }
            write-log -message "Still downloading Prism Central." 
          } until ($pcstatuscheck -ge 40 -or $PCDownloadStatus -match "completed")
        } else {
          $PCDownloadStatus = "Completed"
        }
        if ($pcstatuscheck -ge 40){
  
          write-log -message "AOS Could not download PC in time" -sev "ERROR"
  
        } 
        if ($PCDownloadStatus -match "Completed"){
          $PCDownloadCompleted = $true
        }
      } catch {;
        $PCDownloadCompleted = $false
  
        write-log -message "Error Downloading / Uploading PC, Retry" -sev "WARN";
  
        sleep 2
      };
    } until (($PCDownloadCompleted -eq $true) -or $pcdownloadcount -ge 5)
  
    write-log -message "Prism Central Downloads Completed";
    write-log -message "Downloading the latest Files, Auto Versioning";
  
    do {;
      $Filesdownloadcount++
      $AFSStatuscheck = 0
      try {;
        $session = New-SSHSession -ComputerName $ClusterPE_IP -Credential $credential -AcceptKey;
        $PossibleFilesVersions = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=FILE_SERVER" -EnsureConnection
        if ($PossibleFilesVersions -notmatch "\[None\]"){
          $object = ($PossibleFilesVersions.Output | ConvertFrom-Csv -Delimiter : )
          if ($FilesVersion -ne "Latest"){
    
            write-log -message "Requested version found $FilesVersion"
            write-log -message "Checking if requested version is possible."
    
            $MatchingVersion = $object.'Prism Central Deploy' | where {$_ -match "[0-9]" -and $_ -notmatch "bytes|in-progress"} | sort { [version]$_} | where {$_ -eq $FilesVersion}
            if ($matchingversion){
              $trueFilesVersion = $matchingversion
            } else {;
              $FilesVersion = "Latest";
    
              write-log -message "Version $FilesVersion not found as available within this AOS Version. Using latest." 
    
            };
          };
          if ($FilesVersion -eq "Latest"){
            $trueFilesVersion = $object.'Acropolis File Services' | where {$_ -match "[0-9]" -and $_ -notmatch "bytes|in-progress"} | sort { [version]$_} | select -last 1
            write-log -message "We are using Version $trueFilesVersion for Files"
          
          }
          write-log -message "Starting the download of Files $trueFilesVersion"
          $AFSDownload = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software download software-type='FILE_SERVER' name='$($trueFilesVersion)'" -EnsureConnection
          if ($debug -ge 2){
            $AFSDownload
          }
          if ($wait -eq 1){
            do {
              $AFSStatuscheck++
              $AFSDownloadStatus = (Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=FILE_SERVER name='$($trueFilesVersion)'" -EnsureConnection).output
              sleep 60
              if ($debug -ge 2){
                $AFSDownloadStatus
              }
    
              write-log -message "Still downloading Files."
    
            } until ($AFSStatuscheck -ge 30 -or $AFSDownloadStatus -match "completed")
          } else {
            $AFSDownloadStatus = "Completed"
          }
        } else {
  
          write-log -message "There are no Files downloads available"
  
          $NCCDownloadStatus = "Completed"        
        }
        if ($AFSDownloadCompleted -ge 30){
  
          write-log -message "AOS Could not download Files in time" -sev "ERROR"
  
        }
        if ($AFSDownloadStatus -match "Completed"){
          $AFSDownloadCompleted = $true
        }
      } catch {;
        $AFSDownloadCompleted = $false
  
        write-log -message "Error Downloading / Uploading Files, Retry" -sev "WARN";
        
        sleep 2
      };
    } until (($AFSDownloadCompleted -eq $true) -or $Filesdownloadcount -ge 5) 
  
    write-log -message "Files Downloads Completed";

    write-log -message "Downloading the latest Analytics, Auto Versioning";
  
    do {;
      $Analyticsdownloadcount++
      $AnalyticsStatuscheck = 0
      $AnalyticsDownloadStatus = $null
      try {;
        $session = New-SSHSession -ComputerName $ClusterPE_IP -Credential $credential -AcceptKey;
        $PossibleAnalyticsVersions = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=FILE_Analytics" -EnsureConnection
        if ($PossibleAnalyticsVersions -notmatch "\[None\]"){
          $object = ($PossibleAnalyticsVersions.Output | ConvertFrom-Csv -Delimiter : )
          if ($AnalyticsVersion -ne "Latest"){
    
            write-log -message "Requested version found $AnalyticsVersion"
            write-log -message "Checking if requested version is possible."
    
            $MatchingVersion = $object.'File Analytics' | where {$_ -match "[0-9]" -and $_ -notmatch "bytes|in-progress"} | sort { [version]$_} | where {$_ -eq $AnalyticsVersion}
            if ($matchingversion){
              $trueAnalyticsVersion = $matchingversion
            } else {;
              $AnalyticsVersion = "Latest";
    
              write-log -message "Version $AnalyticsVersion not found as available within this AOS Version. Using latest." 
    
            };
          };
          if ($AnalyticsVersion -eq "Latest"){
            $trueAnalyticsVersion = $object.'File Analytics' | where {$_ -match "[0-9]" -and $_ -notmatch "bytes|in-progress"} | sort { [version]$_} | select -last 1
            write-log -message "We are using Version $trueAnalyticsVersion for Analytics"
          
          }
          write-log -message "Starting the download of Analytics $trueAnalyticsVersion"
          $AFSDownload = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software download software-type='FILE_Analytics' name='$($trueAnalyticsVersion)'" -EnsureConnection
          if ($debug -ge 2){
            $AFSDownload
          }
          if ($wait -eq 1){
            do {
              $AnalyticsStatuscheck++
              $AnalyticsDownloadStatus = (Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=FILE_Analytics name='$($trueAnalyticsVersion)'" -EnsureConnection).output
              sleep 60
              if ($debug -ge 2){
                $AnalyticsDownloadStatus
              }
    
              write-log -message "Still downloading Analytics."
    
            } until ($AnalyticsStatuscheck -ge 30 -or $AnalyticsDownloadStatus -match "completed")
          } else {
            $AnalyticsDownloadStatus = "Completed"
          }
        } else {
  
          write-log -message "There are no Analytics downloads available"
  
          $AFSDownloadStatus = "Completed"        
        }
        if ($Analyticsdownloadcount -ge 30){
  
          write-log -message "AOS Could not download Analytics in time" -sev "ERROR"
  
        }
        if ($AnalyticsDownloadStatus -match "Completed"){
          $AnalyticsDownloadCompleted = $true
        }
      } catch {;
        $AnalyticsDownloadCompleted = $false
  
        write-log -message "Error Downloading / Uploading Analytics, Retry" -sev "WARN";
        
        sleep 2
      };
    } until (($AFSDownloadCompleted -eq $true) -or $Analyticsdownloadcount -ge 5) 
  
    write-log -message "Analytics Downloads Completed";

  }

  write-log -message "Downloading the latest NCC, Auto Versioning";
  do {;
    $NCCdownloadcount++
    $NCCStatusCheck = 0
    try {;
      $session = New-SSHSession -ComputerName $ClusterPE_IP -Credential $credential -AcceptKey;
      $PossibleNCCVersions = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=NCC" -EnsureConnection
      if ($PossibleNCCVersions.output -notmatch "\[None\]"){
        $object = ($PossibleNCCVersions.Output | ConvertFrom-Csv -Delimiter : )
        $trueNCCVersion = $object.'NCC' | where {$_ -match "[0-9]" -and $_ -notmatch "bytes|in-progress"} | sort { [version]$_} | select -last 1

        write-log -message "We found Version $trueNCCVersion available for download"
        write-log -message "Starting the download of NCC Version $trueNCCVersion"

        $NCCDownload = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software download software-type='NCC' name='$($trueNCCVersion)'" -EnsureConnection
        if ($debug -ge 2){
          $NCCDownload
        }

        write-log -message "Not waiting for NCC downloads."

        $NCCDownloadCompleted = $true
      } else {

        write-log -message "There are no NCC downloads available"

        $NCCDownloadCompleted = $true
      }


    } catch {;
      $NCCDownloadCompleted = $false

      write-log -message "Error Downloading / Uploading NCC, Retry"
      
      sleep 2
    };
  } until (($NCCDownloadCompleted -eq $true) -or $NCCdownloadcount -ge 5)  

  write-log -message "NCC Downloads Completed";
  
  write-log -message "Checking AOS Downloads";

  do {;
    $NOSdownloadcount++
    $NOSStatusCheck = 0
    try {;
      $session = New-SSHSession -ComputerName $ClusterPE_IP -Credential $credential -AcceptKey;
      $PossibleNOSVersions = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=NOS" -EnsureConnection
      if ($PossibleNOSVersions.output -notmatch "\[None\]"){
        $object = ($PossibleNOSVersions.Output | ConvertFrom-Csv -Delimiter : )
        $trueNOSVersion = $object.'Acropolis Base Software' | where {$_ -match "[0-9]" -and $_ -notmatch "bytes|in-progress"} | sort { [version]$_} | select -last 1

        write-log -message "We found Version $trueNOSVersion available for download"
        write-log -message "Starting the download of NOS Version $trueNOSVersion"

        $NOSDownload = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software download software-type='NOS' name='$($trueNOSVersion)'" -EnsureConnection
        if ($debug -ge 2){
          $NCCDownload
        }
        if ($wait -eq 1){
          do {
            $NOSStatusCheck++
            $NOSDownloadStatus = (Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=NOS name='$($trueNOSVersion)'" -EnsureConnection).output
            sleep 60
            if ($debug -ge 2){
              $NOSDownloadStatus
            }
  
             write-log -message "Still downloading AOS Updates." 
  
          } until ($NOSStatusCheck -ge 20 -or $NOSDownloadStatus -match "completed")
        } else {
          $NOSDownloadStatus = "completed"

        }
      } else {

        write-log -message "There are no NOS downloads available"

        $NOSDownloadStatus = "Completed"
      }
      if ($NOSStatusCheck -ge 20){

        write-log -message "NOS Could not be downloaded in time" 

      }
      if ($NOSDownloadStatus -match "Completed"){
        $NOSDownloadCompleted = $true
      }
    } catch {;
      $NOSDownloadCompleted = $false

      write-log -message "Error Downloading / Uploading NOS" 
      
      sleep 2
    };
  } until (($NOSDownloadCompleted -eq $true) -or $NOSdownloadcount -ge 5)
 
  write-log -message "AOS Downloads Completed";  
  write-log -message "Checking HyperVisor Downloads";

  do {;
    $HVdownloadcount++
    $HVStatusCheck = 0
    try {;
      $session = New-SSHSession -ComputerName $ClusterPE_IP -Credential $credential -AcceptKey;
      $PossibleHVVersions = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=HYPERVISOR" -EnsureConnection
      if ($PossibleHVVersions.output -notmatch "\[None\]"){
        $object = ($PossibleHVVersions.Output | ConvertFrom-Csv -Delimiter : )
        $trueHVVersion = $object.'HYPERVISOR' | where {$_ -match "^el.*"} |  select -last 1

        write-log -message "We found Version $trueHVVersion available for download"
        write-log -message "Starting the download of HyperVisor Version $trueHVVersion"

        $HVDownload = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software download software-type='HYPERVISOR' name='$($trueHVVersion)'" -EnsureConnection
        if ($debug -ge 2){
          $HVDownload
        }
        if ($wait -eq 1){
          do {
            $HVStatusCheck++
            $HVDownloadStatus = (Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=HYPERVISOR name='$($trueHVVersion)'" -EnsureConnection).output
            sleep 60
            if ($debug -ge 2){
              $HVDownloadStatus
            }
  
            write-log -message "Still downloading new HyperVisor updates."
  
          } until ($HVStatusCheck -ge 10 -or $HVDownloadStatus -match "completed")
        } else {
          $HVDownloadStatus = "completed"

        }
      } else {

        write-log -message "There are no HyperVisor downloads available"

        $HVDownloadStatus = "Completed"
      }
      if ($HVStatusCheck -ge 20){

        write-log -message "The HyperVisor update Could not be downloaded in time" 

      }
      if ($HVDownloadStatus -match "Completed"){
        $HVDownloadCompleted = $true
      }
    } catch {;
      $HVDownloadCompleted = $false

      write-log -message "Error Downloading / Uploading the hypervisor" -sev "WARN";
      
      sleep 2
    };
  } until (($HVDownloadCompleted -eq $true) -or $HVdownloadcount -ge 5)

  write-log -message "HyperVisor Downloads Completed";
  write-log -message "Checking Firware Downloads";

  do {;
    $FWdownloadcount++
    try {;
      $session = New-SSHSession -ComputerName $ClusterPE_IP -Credential $credential -AcceptKey;
      $PossibleFWVersions = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=FIRMWARE_DISK" -EnsureConnection
      if ($PossibleFWVersions.output -notmatch "\[None\]"){
        $object = ($PossibleFWVersions.Output | ConvertFrom-Csv -Delimiter : )
        $trueHVVersion = $object.'NOS' | where {$_ -match "[0-9]" -and $_ -notmatch "bytes|in-progress"} | sort { [version]$_} | select -last 1

        write-log -message "We found Version $trueFWVersion available for download"
        write-log -message "Starting the download of Diskfirmware Version $trueFWVersion"

        $FWDownload = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software download software-type='FIRMWARE_DISK' name='$($trueFWVersion)'" -EnsureConnection
        if ($debug -ge 2){
          $FWDownload
        }
        do {
          $FWStatusCheck++
          $FWDownloadStatus = (Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=FIRMWARE_DISK name='$($trueFWVersion)'" -EnsureConnection).output
          sleep 60
          if ($debug -ge 2){
            $FWownloadStatus
          }

          write-log -message "Still firmware updates."

        } until ($FWStatusCheck -ge 20 -or $FWDownloadStatus -match "completed")
      } else {

        write-log -message "There are no Firmware downloads available"

        $FWDownloadStatus = "Completed"
      }
      if ($FWStatusCheck -ge 20){

        write-log -message "The Firmware update Could not be downloaded in time" 

      }
      if ($FWDownloadStatus -match "Completed"){
        $FWDownloadCompleted = $true
      }
    } catch {;
      $FWDownloadCompleted = $false

      write-log -message "Error Downloading / Uploading the Firmware updates"  -sev "WARN";
      
      sleep 2
    };
  } until (($FWDownloadCompleted -eq $true) -or $FWdownloadcount -ge 5)

  write-log -message "Enabling Autodownload"

  try {;
    $session = New-SSHSession -ComputerName $ClusterPE_IP -Credential $credential -AcceptKey;
    $Autodownloadresult = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software automatic-download enable=1" -EnsureConnection

    write-log -message "Auto Download Enabled"

  } catch {
    $session = New-SSHSession -ComputerName $ClusterPE_IP -Credential $credential -AcceptKey;
    $Autodownloadresult = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software automatic-download enable=1" -EnsureConnection

    write-log -message "Auto Download Enabled"
    
  }
  if ($debug -ge 2){
    $Autodownloadresult
  }

  if ($AnalyticsDownloadCompleted -eq $true -and $AFSDownloadCompleted -eq $true -and $PCDownloadCompleted -eq $true -and $NCCDownloadCompleted -eq $true -and $NOSDownloadCompleted -eq $true -and $HVDownloadCompleted -eq $true -and $FWDownloadCompleted -eq $true){
    $status = "Success"

    write-log -message "All Downloads completed successfully"

  } else {
    $status = "Failed"
  }
  $resultobject =@{
    Result = $status
    PCVersion = $truePCversion
    FilesVersion = $trueFilesVersion
    NCCVersion = $trueNCCVersion
    AOSVersion = $trueNOSVersion
    AnalyticsVersion = $trueAnalyticsVersion
  }
  Try {

    write-log -message "Executing session cleanup"

    Remove-SSHSession -SSHSession $session
  } catch {}
  return $resultobject
};

Function SSH-Destroy-Pe {
  Param (
    [object] $datavar,
    [object] $datagen,
    [string] $Lockdir
  )
  #dependencies LIB-write-log, Posh-SSH, PE_ncli
  $hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
  $Resetpasscount = 0 
  $passreset = $false
  $Securepass = ConvertTo-SecureString $datavar.PreDestroyPass -AsPlainText -Force; 
  
  write-log -message "Building Credential for SSH session";
  write-log -message "Using CVMs $($datavar.cvmips)";
  try {
    $cvmips = ($datavar.cvmips -split ",")
    $cvmip = $cvmips[0]
  } catch {
    write-log -message "Splicing the CVM IP threw an error";

  }
  $sshusername = "nutanix"
  $oldSecurepass = ConvertTo-SecureString "nutanix/4u" -AsPlainText -Force; 

  do {;
    $Resetpasscount++
    try {;
      try {

        write-log -message "Logging in with Default Creds, username is $sshusername";
        
        $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $oldSecurepass);
        $session = New-SSHSession -ComputerName $cvmip -Credential $credential -AcceptKey -ea:0;
        $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
      } catch {
        try {

          $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $Securepass);
          $session = New-SSHSession -ComputerName $cvmip -Credential $credential -AcceptKey -ea:0;
          $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)         
         
          write-log -message "Using specified creds, username is $sshusername";

        } catch {

          write-log -message "Cannot login with any creds" -sev "WARN"

        }
               
      }
      sleep 15

      $shell = $stream.read()

      if ($shell -match "Expired"){

        write-log -message "Prompted to change the SSH pass, changing"

        try{

          write-log -message "Sending Current and new Pass"

          Invoke-SSHStreamExpectSecureAction -ShellStream $stream -ExpectString "New password:" -SecureAction $Securepass -command "Nutanix/4u"

          write-log -message "Sending New Again"

          Invoke-SSHStreamShellCommand -ShellStream $stream -Command $datavar.pepass
          $hide = Get-sshsession | Remove-SSHSession

          write-log -message "Sleeping 1 minute"

          sleep 60

        } catch {

          write-log -message "Error Changing SSH Pass" -sev "ERROR"

        }

      }
      try {

        write-log -message "Checking if SSH Password needs to be changed" 

        $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $Securepass);
        $session = New-SSHSession -ComputerName $cvmip -Credential $credential -AcceptKey -ea:0
        #line below causes a clean error, the line above does not
        $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
        $passreset = $true
        
      } catch {

        write-log -message "SSH Password needs to be changed" 

        $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $oldSecurepass);
        $session = New-SSHSession -ComputerName $cvmip -Credential $credential -AcceptKey -ea:0;  
        $Passresetresult = Invoke-SSHCommand -SSHSession $session -command "echo `"$($datavar.pepass)`" | sudo passwd --stdin $sshusername"
        $hide = Get-sshsession | Remove-SSHSession

        write-log -message "Sleeping 1 minute"
  
        sleep 60
        $Passresetresult 
        $passreset = $true

      }
    } catch {
      write-log -message "Cluster Prerequsites Failure, retry $Resetpasscount out of 3" -sev "WARN"
      $passreset = $false
    }


  } until (($passreset -eq $true) -or $Resetpasscount -ge 3)
  $retrycounter = 0 
  if ($passreset -eq $true){
    do {
      $retrycounter ++
      try{

        write-log -message "Destroying Cluster" 

        foreach ($ip in $cvmips){

          write-log -message "Using Forced Mode for node $ip"

          $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $Securepass);
          $session = New-SSHSession -ComputerName $ip -Credential $credential -AcceptKey -ea:0
          $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
          $output0 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "sudo rm /etc/security/opasswd"
          if ($Output0 -match "password for"){
            write-log -message "sending sudo pass"
            $output1 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command $clpassword
          }           
          Invoke-SSHStreamShellCommand -ShellStream $stream -Command "touch /home/nutanix/.node_unconfigure;/usr/local/nutanix/cluster/bin/genesis restart"

        }
        sleep 119

        write-log -message "Cluster Destroyed, waiting Genny to restart"

        sleep 110
        $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $Securepass);
        $session = New-SSHSession -ComputerName $cvmip -Credential $credential -AcceptKey -ea:0
        $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)

        write-log -message "Creating Cluster"

        sleep 119
        $session = New-SSHSession -ComputerName $cvmip -Credential $credential -AcceptKey -ea:0
        $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
        Invoke-SSHStreamShellCommand -ShellStream $stream -Command "cluster -s $($datavar.cvmips) create"
        
        sleep 90
        $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $Securepass);
        $session = New-SSHSession -ComputerName $cvmip -Credential $credential -AcceptKey -ea:0
        $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)

        write-log -message "Starting Cluster"

        Invoke-SSHStreamShellCommand -ShellStream $stream -Command "cluster start"

        sleep 20 
        $reading = $stream.Read()
        
        if ($reading -match "Cluster is currently unconfigured. Please create"){
          try {

            write-log -message "Creating Cluster"

            $session = New-SSHSession -ComputerName $cvmip -Credential $credential -AcceptKey -ea:0
            $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
            invoke-SSHStreamShellCommand -ShellStream $stream -Command "cluster -s $($datavar.cvmips) create"
            sleep 5 
            write-log -message "Output below, not always present"
           
            sleep 119
            $start = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "cluster start"
          } catch {
            $hide = Get-sshsession | Remove-SSHSession
            $session = New-SSHSession -ComputerName $cvmip -Credential $credential -AcceptKey -ea:0
            $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
            invoke-SSHStreamShellCommand -ShellStream $stream -Command "cluster -s $($datavar.cvmips) create"
            sleep 119
            $start = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "cluster start"
          }
        }
        write-log -message "About to complete"
        sleep 119
        $hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
        $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $Securepass);
        $session = New-SSHSession -ComputerName $cvmip -Credential $credential -AcceptKey -ea:0
        $count = 0
        do {
          $count ++
          $hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
          $hide = Get-SSHSession | Remove-SSHSession
          $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $Securepass);
          $session = New-SSHSession -ComputerName $cvmip -Credential $credential -AcceptKey -ea:0
          $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
          Invoke-SSHStreamShellCommand -ShellStream $stream -Command "cluster status"

          write-log -message "Waiting for the cluster to finish."
          write-log -message "Cycle $count out of 5"

          $output = $stream.Read()
          
          sleep 60        
        } until ($count -ge 5 -or $output -match "Success")
        
        $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $Securepass);
        $session = New-SSHSession -ComputerName $cvmip -Credential $credential -AcceptKey -ea:0

        write-log -message "Configuring Cluster"
        write-log -message "Setting name Cluster"
    
        (Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli cluster edit-params new-name='$($datavar.pocname)'" -timeout 999 -EnsureConnection).output
  
        write-log -message "Setting DNS Cluster"
    
        (Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli cluster add-to-name-servers servers='$($datavar.DNSServer)'" -timeout 999 -EnsureConnection).output
  
        write-log -message "Setting NTP Cluster"
    
        (Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli cluster add-to-ntp-servers servers='$($datagen.NTPServer1),$($datagen.NTPServer2),$($datagen.NTPServer3),$($datagen.NTPServer4)'" -timeout 999 -EnsureConnection).output
  
        write-log -message "Setting Cluster IP"
    
        $status = (Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli cluster set-external-ip-address external-ip-address='$($datavar.peclusterip)'" -timeout 999 -EnsureConnection).output

        write-log -message "Resetting admin";

        $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $Securepass);
        $session = New-SSHSession -ComputerName $cvmip -Credential $credential -AcceptKey -connectiontimeout 120 -operationtimeout 100
        $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
        $output0 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "sudo rm /etc/security/opasswd"
        if ($Output0 -match "password for"){
          write-log -message "sending sudo pass"
          $output1 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command $datavar.pepass
        }           
        write-log -message "Using specified creds, username is $sshusername";

        foreach ($ip in $cvmips){

          write-log -message "Clearing Password cache for node $ip"

          $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $Securepass);
          $session = New-SSHSession -ComputerName $ip -Credential $credential -AcceptKey -ea:0
          $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
          $output0 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "sudo rm /etc/security/opasswd"
          if ($Output0 -match "password for"){
            write-log -message "sending sudo pass"
            $output1 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command $datavar.pepass
          }           
        }

        $output0 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "sudo passwd admin"
        if ($Output0 -match "password for"){
          write-log -message "sending sudo pass"
          $output1 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command $datavar.pepass
        } 
        if ($output1 -match "new password"){
          write-log -message "Sending new pass"
          $output2 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command $datavar.pepass
          if ($output2 -match "retype"){
            write-log -message "Sending new pass again"
            $output3 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command $datavar.pepass
            if ($output3 -match "all authentication" -or $output3 -match "Password has been already used"){
              write-log -message "Were all good to go"
            }
          } else {
            write-log -message "This is not what i expect from the last password step"
          }
        } else {
          write-log -message "This is not what i expect from the first password step"     
        }
      } catch {
  
        write-log -message "Error Caught creating cluster" -sev "WARN"
  
      }
    } until ($status -match "$($datavar.peclusterip)" -or $retrycounter -ge 3)
  }

  if ($status -match "$($datavar.peclusterip)"){
    $status = "Success"
    write-log -message "Cluster Has Been recreated"
  } else {
    write-log -message "Cluster create failure" -sev "ERROR"
    $status = "Failed"
  }
  $resultobject =@{
    Result = $status
  }
  Try {
    write-log -message "Executing session cleanup"
    $hide = Get-sshsession | Remove-SSHSession
  } catch {}
  return $resultobject
};

Function SSH-Networking-Pe {
  Param (
    [string] $PEClusterIP,
    [string] $clpassword,
    [string] $clusername,
    [string] $domainname,
    [string] $nw1dhcpstart,
    [string] $nw1gateway,
    [string] $nw1Subnet,
    [string] $nw1vlan,
    [string] $nw1name,   
    [string] $nw2dhcpstart,
    [string] $DC1IP,
    [string] $DC2IP,
    [string] $nw2Subnet,
    [string] $nw2gateway,
    [string] $nw2name,
    [string] $nw2vlan,
    [object] $datavar
  )
  #dependencies LIB-write-log, Posh-SSH, PE_ncli

  $count = 0 
  write-log -message "Building Credential for SSH session";
  $hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
  $Securepass = ConvertTo-SecureString $clpassword -AsPlainText -Force;
  $credential = New-Object System.Management.Automation.PSCredential ($clusername, $Securepass);
  $session = New-SSHSession -ComputerName $PEClusterIP -Credential $credential -AcceptKey;
  $netbios = $domainname.split(".")[0]
  $Delete = Invoke-SSHCommand -SSHSession $session -command "/usr/local/nutanix/bin/acli -y net.delete $nw1name" -EnsureConnection
  $Delete = Invoke-SSHCommand -SSHSession $session -command "/usr/local/nutanix/bin/acli -y net.delete $nw2name" -EnsureConnection

  write-log -message "Setting up Network for Prism Element : $PEClusterIP";

  do {;
    $count++
    try {;
      $session = New-SSHSession -ComputerName $PEClusterIP -Credential $credential -AcceptKey;
      
      write-log -message "Setting clean state"

      $Delete = Invoke-SSHCommand -SSHSession $session -command "/usr/local/nutanix/bin/acli -y net.delete Rx-Automation-Network" -EnsureConnection
      $Delete = Invoke-SSHCommand -SSHSession $session -command "/usr/local/nutanix/bin/acli -y net.delete Primary" -EnsureConnection
      $Delete = Invoke-SSHCommand -SSHSession $session -command "/usr/local/nutanix/bin/acli -y net.delete Secondary" -EnsureConnection

      write-log -message "Checking Networks";

      sleep 2
      $Existing = Invoke-SSHCommand -SSHSession $session -command "/usr/local/nutanix/bin/acli net.list" -EnsureConnection

      if ($Existing.output -match "Rx-Automation-Network"){

        write-log -message "Old Network exists...." -sev "WARN";

      } 

      if ($Existing.output -match $nw1name){

        $nw1completed = $true

        write-log -message "Network 1 $nw1name exist.";

      } else {

        write-log -message "Network 1 Does not exist, creating.";
        write-log -message "Calculating data.";

        $prefix = Convert-IpAddressToMaskLength $nw1Subnet
        $ipconfig = "$($nw1gateway)/$($prefix)"
        $lastIP = Get-LastAddress -IPAddress $PEClusterIP -SubnetMask $nw1Subnet

        write-log -message "IPconfig value should be: $ipconfig"
        write-log -message "DHCP Start should be: $nw1dhcpstart"
        write-log -message "Network 1 VLAN will be $nw1vlan"
        write-log -message "Last IP will be $lastIP"
        write-log -message "Netbios Domain is $netbios"
        write-log -message "DNS 1 = $DC1ip"
        write-log -message "DNS 1 = $DC2ip"

        $result = Invoke-SSHCommand -SSHSession $session -command "/usr/local/nutanix/bin/acli net.create $nw1name vlan=$($nw1vlan) ip_config=$($ipconfig)" -EnsureConnection
        sleep 2
        $result = Invoke-SSHCommand -SSHSession $session -command "/usr/local/nutanix/bin/acli net.update_dhcp_dns $nw1name servers=$($datavar.dnsserver) domains=$($netbios)" -EnsureConnection
        sleep 2
        $result = Invoke-SSHCommand -SSHSession $session -command "/usr/local/nutanix/bin/acli net.add_dhcp_pool $nw1name start=$($nw1dhcpstart) end=$($lastIP)" -EnsureConnection

        write-log -message "Network 1 Created"

      }
    } catch {

      $nw1completed = $false

      write-log -message "Error Creating Primary network, Retry" -sev "WARN";

      sleep 2

    }
    try {;
      if ($Existing.output -match $nw2name -and $nw2vlan){

        write-log -message "Network 2 exists";

        $nw2completed = $true

      } elseif ($nw2vlan) {

        write-log -message "Network 2 $nw2name Does not exist, and needs creating.";
        write-log -message "Calculating data.";

        $prefix = Convert-IpAddressToMaskLength $nw2Subnet
        $ipconfig = "$($nw2gateway)/$($prefix)"
        $lastIP = Get-LastAddress -IPAddress $nw2dhcpstart -SubnetMask $nw2Subnet

        write-log -message "IPconfig value should be: $ipconfig"
        write-log -message "DHCP Start should be: $nw2dhcpstart"
        write-log -message "Network 0 VLAN will be $nw2vlan"
        write-log -message "Last IP will be $lastIP"
        write-log -message "Netbios Domain is $netbios"

        $result = Invoke-SSHCommand -SSHSession $session -command "/usr/local/nutanix/bin/acli net.create $nw2name vlan=$($nw2vlan) ip_config=$($ipconfig)" -EnsureConnection
        $result = Invoke-SSHCommand -SSHSession $session -command "/usr/local/nutanix/bin/acli net.update_dhcp_dns $nw2name servers=$($DC1IP),$($DC2ip) domains=$($netbios)" -EnsureConnection
        $result = Invoke-SSHCommand -SSHSession $session -command "/usr/local/nutanix/bin/acli net.add_dhcp_pool $nw2name start=$($nw2dhcpstart) end=$($lastIP)"

      } else {

        write-log -message "Network 2 is not specified to be deployed";

        $nw2completed = $true
      }
      
    } catch {;
      $nw2completed = $false

      write-log -message "Error Creating networks, Retry" -sev "WARN";

      sleep 2
    };
  } until (($nw1completed -eq $true -and $nw2completed -eq $true) -or $count -ge 6)

 
  if ($nw1completed -eq $true){
    $status = "Success"

  } else {
    $status = "Failed"
  }
  $resultobject =@{
    Result = $status
    Output = $result.output
  }
  Try {
    write-log -message "Executing session cleanup"
    $clean = Remove-SSHSession -SSHSession $session
  } catch {}
  return $resultobject
};

Function SSH-Oracle-InsertDemo {
  Param (
    [string] $OracleIP,
    [string] $clpassword,
    [string] $filename1,   
    [string] $filename2,
    [string] $filename3
  )
  #dependencies LIB-write-log, Posh-SSH, PE_ncli

  $count = 0 
  write-log -message "Building Credential for SSH session";
  $hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
  $Securepass = ConvertTo-SecureString $clpassword -AsPlainText -Force;
  $credential = New-Object System.Management.Automation.PSCredential ('oracle', $Securepass);
  $session = New-SSHSession -ComputerName $OracleIP -Credential $credential -AcceptKey;
  
  write-log -message "Building session";

  do {;
    $count1++
    try {;
      $session = New-SSHSession -ComputerName $OracleIP -Credential $credential -AcceptKey -connectiontimeout 20

      write-log -message "Installing dos2unix"

      $Install = Invoke-SSHCommand -SSHSession $session -command "sudo yum install dos2unix -y" -EnsureConnection
      sleep 10
      
      write-log -message "Uploading the file $filename1"
      write-log -message "To Its destination /home/oracle/Downloads/"

      $upload = Set-SCPFile -LocalFile $filename1 -RemotePath "/home/oracle/Downloads/" -ComputerName $OracleIP -Credential $credential -AcceptKey $true -connectiontimeout 20

      write-log -message "Setting XBit";

      $chmod = Invoke-SSHCommand -SSHSession $session -command "chmod +x /home/oracle/Downloads/adump.sh" -EnsureConnection -timeout 20 -ea:0;

      sleep 10

      write-log -message "Converting";

      $chmod = Invoke-SSHCommand -SSHSession $session -command "dos2unix /home/oracle/Downloads/adump.sh" -EnsureConnection -timeout 20 -ea:0;

      sleep 10

      write-log -message "Executing";

      $Execute1 = Invoke-SSHCommand -SSHSession $session -command "bash /home/oracle/Downloads/adump.sh > ~/adump.log 2>&1 &" -EnsureConnection -timeout 20 -ea:0;

      $completedp1 = 1
      $Execute1.ExitStatus
      $Execute1.Output
    } catch {

      write-log -message "Failure during upload or execute";

    }

  } until (($completedp1 -eq 1 -and $Execute1.ExitStatus -eq 0 ) -or $count1 -ge 6)

  do {;
    $count2++
    try {;
      $session = New-SSHSession -ComputerName $OracleIP -Credential $credential -AcceptKey -connectiontimeout 20 -ea:0;
      
      write-log -message "Uploading the file $filename2"
      write-log -message "To Its destination /home/oracle/Downloads/"

      $upload = Set-SCPFile -LocalFile $filename2 -RemotePath "/home/oracle/Downloads/" -ComputerName $OracleIP -Credential $credential -AcceptKey $true -connectiontimeout 20

      write-log -message "Setting XBit";

      $chmod = Invoke-SSHCommand -SSHSession $session -command "chmod +x /home/oracle/Downloads/ticker.sh" -EnsureConnection -timeout 20 -ea:0;


      sleep 10

      write-log -message "Converting";

      $chmod = Invoke-SSHCommand -SSHSession $session -command "dos2unix /home/oracle/Downloads/ticker.sh" -EnsureConnection -timeout 120 -ea:0;

      sleep 10

      write-log -message "Executing";

      $Execute2 = Invoke-SSHCommand -SSHSession $session -command "bash /home/oracle/Downloads/ticker.sh > ~/ticker.log 2>&1 &" -EnsureConnection -timeout 120 -ea:0;

      $completedp2 = 1
      $Execute2.ExitStatus
      $Execute2.Output
    } catch {

      write-log -message "Failure during upload or execute";

    }

  } until (($completedp2 -eq 1 -and $Execute2.ExitStatus -eq 0 ) -or $count -ge 6)

  do {;
    $count3++
    try {;
      $session = New-SSHSession -ComputerName $OracleIP -Credential $credential -AcceptKey -connectiontimeout 20
      
      write-log -message "Uploading the file $filename3"
      write-log -message "To Its destination /home/oracle/Downloads/"

      $upload = Set-SCPFile -LocalFile $filename3 -RemotePath "/home/oracle/Downloads/" -ComputerName $OracleIP -Credential $credential -AcceptKey $true -connectiontimeout 20

      write-log -message "Setting XBit";

      $chmod = Invoke-SSHCommand -SSHSession $session -command "chmod +x /home/oracle/Downloads/swingbench.sh" -EnsureConnection -timeout 20 -ea:0;

      sleep 10

      write-log -message "Converting";

      $chmod = Invoke-SSHCommand -SSHSession $session -command "dos2unix /home/oracle/Downloads/swingbench.sh" -EnsureConnection -timeout 20 -ea:0;

      sleep 10

      write-log -message "Executing";

      $Execute3 = Invoke-SSHCommand -SSHSession $session -command "bash ~/Downloads/swingbench.sh welcome1 /oradata/ORCL/soe.dbf > ~/swingbench.log 2>&1 &" -EnsureConnection -timeout 20 -ea:0;

      $completedp3 = 1
      $Execute3.ExitStatus
      $Execute3.Output
    } catch {

      write-log -message "Failure during upload or execute";

    }

  } until (($completedp3 -eq 1 -and $Execute3.ExitStatus -eq 0 ) -or $count -ge 6)
  if ($completedp1 -eq 1 -and $Execute1.ExitStatus -eq 0 -and $completedp2 -eq 1 -and $Execute2.ExitStatus -eq 0 -and $completedp3 -eq 1 -and $Execute3.ExitStatus -eq 0){

    write-log -message "One small step for man, one giant leap for mankind.";

    $status = "Success"
  } else {
    $status = "Failed"
  }
  $resultobject =@{
    Result = $status
    Output = $result.output
  }
  Try {
    write-log -message "Executing session cleanup"
    $clean = Remove-SSHSession -SSHSession $session
  } catch {}
  return $resultobject
};

Function SSH-ResetPass-Px {
  Param (
    [string] $PxClusterIP,
    [string] $clpassword,
    [string] $clusername,
    [string] $mode = "NORMAL"
  )
  #dependencies LIB-write-log, Posh-SSH, PE_ncli
  $hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
  $Resetpasscount = 0 
  $passreset = $false
  $Securepass = ConvertTo-SecureString $clpassword -AsPlainText -Force;
  
  write-log -message "Building Credential for SSH session";
  write-log -message "Mode is $mode using IP $PxClusterIP";

  if ($mode -eq "PE"){
    $sshusername = "nutanix" 
    $oldSecurepass = ConvertTo-SecureString "nutanix/4u" -AsPlainText -Force;
  } elseif ($mode -eq "ERA" ){
    $sshusername = "era" 
    $oldSecurepass = ConvertTo-SecureString "Nutanix.1" -AsPlainText -Force;
  } elseif ($mode -eq "move" ){
    $sshusername = "admin" 
    $oldSecurepass = ConvertTo-SecureString "nutanix/4u" -AsPlainText -Force;
  } elseif ($mode -eq "Oracle1" ){
    $sshusername = "oracle" 
    $oldSecurepass = ConvertTo-SecureString "welcome1" -AsPlainText -Force;
  } elseif ($mode -eq "Oracle2" ){
    $sshusername = "root" 
    $oldSecurepass = ConvertTo-SecureString "welcome1" -AsPlainText -Force;
  } elseif ($mode -eq "Oracle3" ){
    $sshusername = "grid" 
    $oldSecurepass = ConvertTo-SecureString "welcome1" -AsPlainText -Force;
  } elseif ($mode -eq "Oracle4" ){
    $sshusername = "kamal" 
    $oldSecurepass = ConvertTo-SecureString "welcome1" -AsPlainText -Force;
  } elseif ($mode -eq "Centos"){
    $sshusername = "centos" 
    $oldSecurepass = ConvertTo-SecureString "Maandag01!" -AsPlainText -Force;
  } else {
    $sshusername = "nutanix"
    $oldSecurepass = ConvertTo-SecureString "nutanix/4u" -AsPlainText -Force;
  }


  do {;
    $Resetpasscount++
    try {;
      try {

        write-log -message "Logging in with Default Creds, username is $sshusername connecting towards $PxClusterIP";
        
        $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $oldSecurepass);
        $session = New-SSHSession -ComputerName $PxClusterIP -Credential $credential -AcceptKey -connectiontimeout 120 -operationtimeout 100 -ea:0
        $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
      } catch {
        try {

          $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $Securepass);
          $session = New-SSHSession -ComputerName $PxClusterIP -Credential $credential -AcceptKey -connectiontimeout 120 -operationtimeout 100
          $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)         
         
          write-log -message "Using specified creds, username is $sshusername";

        } catch {

          write-log -message "Cannot login with any creds" -sev "WARN"
          $session

        }
               
      }
      sleep 15

      $shell = $stream.read()

      if ($shell -match "Expired"){

        write-log -message "Prompted to change the SSH pass, changing"

        try{

          write-log -message "Sending Current and new Pass"
          if ($mode -eq "move"){
            $clearpass = "nutanix/4u"
          } else {
            $clearpass = "Nutanix/4u"
          }
          Invoke-SSHStreamExpectSecureAction -ShellStream $stream -ExpectString "New password:" -SecureAction $Securepass -command $clearpass -TimeOut 10

          write-log -message "Sending New Again"

          Invoke-SSHStreamShellCommand -ShellStream $stream -Command $clpassword
          $hide = Get-sshsession | Remove-SSHSession

          write-log -message "Sleeping 1 minute"

          sleep 60

        } catch {

          write-log -message "Error Changing SSH Pass" -sev "ERROR"

        }

      }
      try {

        write-log -message "Checking if SSH Password needs to be changed" 

        $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $Securepass);
        $session = New-SSHSession -ComputerName $PxClusterIP -Credential $credential -AcceptKey -connectiontimeout 120 -ea:0;
        #line below causes a clean error, the line above does not
        $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
        $passreset = $true
        
      } catch {

        write-log -message "SSH Password needs to be changed" 

        $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $oldSecurepass);
        $session = New-SSHSession -ComputerName $PxClusterIP -Credential $credential -AcceptKey -connectiontimeout 120 -ea:0;
        $Passresetresult = Invoke-SSHCommand -SSHSession $session -command "echo `"$($clpassword)`" | sudo passwd --stdin $sshusername" -TimeOut 120
        $hide = Get-sshsession | Remove-SSHSession
        if ($mode -notmatch "Oracle"){

          write-log -message "Sleeping 1 minute"
  
          sleep 60
        }
        $Passresetresult 
        $passreset = $true
      }
      if ($mode -match "move"){

          write-log -message "Sending move answer to network config"

          $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $Securepass);
          $session = New-SSHSession -ComputerName $PxClusterIP -Credential $credential -AcceptKey  -connectiontimeout 120 -ea:0;
          $answerconfig = Invoke-SSHCommand -SSHSession $session -command "n" -TimeOut 120
      }
      if ($mode -notmatch "ERA|Oracle|xray|move"){
        $passreset = $false

        write-log -message "Resetting Prism Portal Password; username is $($clusername)";
  
        try{
          $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $Securepass);
          $session = New-SSHSession -ComputerName $PxClusterIP -Credential $credential -AcceptKey  -connectiontimeout 120 -ea:0;
          sleep 1
          $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
          $hide = Get-sshsession | Remove-SSHSession
          $session = New-SSHSession -ComputerName $PxClusterIP -Credential $credential -AcceptKey -connectiontimeout 120 -ea:0;
          sleep 1
          if ($debug -ge 2){

            write-log -message "Resetting Prism Portal Password; Password is $($clpassword)";
            write-log -message "Executing ls command";

            $test1 = Invoke-SSHCommand -SSHSession $session -command "ls" -EnsureConnection -TimeOut 120
            write-host $test1
            write-log -message "Executing NCLI List command";

            $test2 = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli user list" -EnsureConnection -TimeOut 120
            write-host $test2
            write-log -message "Debug Done, resetting portal password now.";
          }
          $Passresetresult = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli user reset-password user-name='$($clusername)' password='$($clpassword)'" -EnsureConnection -TimeOut 120
          if ($Passresetresult.exitstatus -eq "0"){
  
            write-log -message "Password reset successful."
  
            $passreset = $true
          } elseif  ($Passresetresult.exitstatus -eq "1" -and $Passresetresult.output -match "characters from previous password"){
  
             write-log -message "Password reset already executed."
  
            $passreset = $true       
          } else {
            
            write $Passresetresult.output

            write-log -message "Unknown exit in password change." -sev "WARN"
            write-host $Passresetresult
  
            $passreset = $false
  
          }
        } catch{ 
  
          write-log -message "Cannot connect to Px SSH (password conflict nutanix user?) " -sev "WARN"
  
        }

        #write-log -message "Resetting Nutanix";
#
        #$credential = New-Object System.Management.Automation.PSCredential ($sshusername, $Securepass);
        #$session = New-SSHSession -ComputerName $PxClusterIP -Credential $credential -AcceptKey -connectiontimeout 120 -operationtimeout 100
        #$stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
        #$output0 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "sudo rm /etc/security/opasswd"
        #if ($Output0 -match "password for"){
        #  write-log -message "sending sudo pass"
        #  $output1 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command $clpassword
        #}           
        #write-log -message "Using specified creds, username is $sshusername";
#
        #$output0 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "sudo passwd nutanix"
        #if ($Output0 -match "password for"){
        #  write-log -message "sending sudo pass"
        #  $output1 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command $clpassword
        #} 
        #if ($output1 -match "new password"){
        #  write-log -message "Sending new pass"
        #  $output2 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command $clpassword
        #  if ($output2 -match "retype"){
        #    write-log -message "Sending new pass again"
        #    $output3 = Invoke-SSHStreamShellCommand -ShellStream $stream -Command $clpassword
        #    if ($output3 -match "all authentication" -or $output3 -match "Password has been already used"){
        #      write-log -message "Were all good to go"
        #    }
        #  } else {
        #    write-log -message "This is not what i expect from the last password step"
        #  }
        #} else {
        #  write-log -message "This is not what i expect from the first password step"     
        #}

      } else {
        ## Do some SSH based portal password reset for ERA
      }
    } catch {
      write-log -message "Password reset failure, retry $Resetpasscount out of 3" -sev "WARN"
      $passreset = $false
    }
  } until (($passreset -eq $true) -or $Resetpasscount -ge 3)
  if ($passreset -eq $true){
    $status = "Success"
    write-log -message "Password has been reset"
  } else {
    write-log -message "Password reset failure." -sev "ERROR"
    $status = "Failed"
  }
  $resultobject =@{
    Result = $status
  }
  Try {
    write-log -message "Executing session cleanup"
    $hide = Get-sshsession | Remove-SSHSession
  } catch {}
  return $resultobject
};
Export-ModuleMember *

Function SSH-ServiceAccounts-Px {
  Param (
    [string] $PxClusterIP,
    [object] $datavar,
    [object] $datagen
  )
  #dependencies LIB-write-log, Posh-SSH, PE_ncli
  $hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
  $count = 0 
  write-log -message "Building Credential for SSH session";

  $Securepass = ConvertTo-SecureString $datavar.pepass -AsPlainText -Force;
  $credential = New-Object System.Management.Automation.PSCredential ('admin', $Securepass);
  $session = New-SSHSession -ComputerName $PxClusterIP -Credential $credential -AcceptKey;

  write-log -message "Creating Service Accounts";
  $count = 0
  do {;
    $count++
    try {;
      $session = New-SSHSession -ComputerName $PxClusterIP -Credential $credential -AcceptKey;

      write-log -message "Creating ERA";
      
      $ServiceAccount = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli user create user-name=$($datagen.ERAAPIAccount) user-password=$($datavar.PEPass) first-name=era last-name=serviceaccount email-id=$($datagen.Supportemail)" -EnsureConnection
      sleep 1
      write-log -message "Adding Role";
      sleep 1
      $addgroup = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli user grant-cluster-admin-role user-name=$($datagen.ERAAPIAccount)" -EnsureConnection -timeout 999
      $addgroup = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli user grant-user-admin-role user-name=$($datagen.ERAAPIAccount)" -EnsureConnection -timeout 999

      write-log -message "Testing the values";
      
      $ERAresult = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli user list user-name=$($datagen.ERAAPIAccount)" -EnsureConnection -timeout 999
      $ERAresult.output
    } catch {;
      $ERAServiceAccountCompleted = $false

      write-log -message "Error setting creating ERA Svc through NCLI Px, Retry" -sev "WARN";

      sleep 2
    };
  } until (($ERAresult.output -match "ROLE.*CLUSTER_ADMIN") -or $count -ge 5)
  $count = 0
  do {;
    $count++
    try {;
      $session = New-SSHSession -ComputerName $PxClusterIP -Credential $credential -AcceptKey;
      
      write-log -message "Creating Move";
      
      $ServiceAccount = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli user create user-name=$($datagen.MoveAPIAccount) user-password=$($datavar.PEPass) first-name=Move last-name=serviceaccount email-id=$($datagen.Supportemail)" -EnsureConnection
      sleep 1
      write-log -message "Adding Role";
      sleep 1
      $addgroup = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli user grant-cluster-admin-role user-name=$($datagen.MoveAPIAccount)" -EnsureConnection -timeout 999
      $addgroup = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli user grant-user-admin-role user-name=$($datagen.MoveAPIAccount)" -EnsureConnection -timeout 999

      write-log -message "Testing the values";
      
      $moveresult = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli user list user-name=$($datagen.MoveAPIAccount)" -EnsureConnection -timeout 999
      $moveresult.output
    } catch {;
      $MoveServiceAccountCompleted = $false

      write-log -message "Error setting creating Move Svc through NCLI Px, Retry" -sev "WARN";

      sleep 2
    };
  } until (($moveresult.output -match "ROLE.*CLUSTER_ADMIN") -or $count -ge 5)
  do {;
    $count++
    try {;
      $session = New-SSHSession -ComputerName $PxClusterIP -Credential $credential -AcceptKey;
      
      write-log -message "Creating Build Account";
      
      $ServiceAccount = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli user create user-name=$($datagen.BuildAccount) user-password=$($datavar.PEPass) first-name=Move last-name=serviceaccount email-id=$($datagen.Supportemail)" -EnsureConnection
      sleep 1
      write-log -message "Adding Role";
      sleep 1
      $addgroup = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli user grant-cluster-admin-role user-name=$($datagen.BuildAccount)" -EnsureConnection -timeout 999
      $addgroup = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli user grant-user-admin-role user-name=$($datagen.BuildAccount)" -EnsureConnection -timeout 999

      write-log -message "Testing the values";
      
      $Buildresult = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli user list user-name=$($datagen.BuildAccount)" -EnsureConnection -timeout 999
      $Buildresult.output
    } catch {;
      $ERAServiceAccountCompleted = $false

      write-log -message "Error setting creating Build Svc through NCLI Px, Retry" -sev "WARN";

      sleep 2
    };
  } until (($buildresult.output -match "ROLE.*CLUSTER_ADMIN") -or $count -ge 5)

 
  if ($moveresult.output -match "ROLE.*CLUSTER_ADMIN" -and $buildresult.output -match "ROLE.*CLUSTER_ADMIN" -and $ERAresult.output -match "ROLE.*CLUSTER_ADMIN"){
    $status = "Success"
  } else {
    $status = "Failed"
  }
  $resultobject =@{
    Result = $status
  }
  Try {
    write-log -message "Executing session cleanup"
    Remove-SSHSession -SSHSession $session
  } catch {}
  return $resultobject
};


Function SSH-Storage-Pe {
  Param (
    [string] $PEClusterIP,
    [string] $clpassword,
    [string] $clusername,
    [string] $StoragePoolName,
    [string] $ImagesContainerName,
    [string] $DisksContainerName,
    [string] $ERAContainerName,
    [string] $KarbonContainername,
    [bool] $vmware
  )
  #dependencies LIB-write-log, Posh-SSH, PE_ncli
  $hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
  $count = 0 
  write-log -message "Building Credential for SSH session";

  $Securepass = ConvertTo-SecureString $clpassword -AsPlainText -Force;
  $credential = New-Object System.Management.Automation.PSCredential ($clusername, $Securepass);
  $session = New-SSHSession -ComputerName $PEClusterIP -Credential $credential -AcceptKey;

  write-log -message "Setting up Storage for Prism Element $PEClusterIP";

  do {;
    $count++
    try {;
      $session = New-SSHSession -ComputerName $PEClusterIP -Credential $credential -AcceptKey;
      
      write-log -message "Checking Storage Pools";
      
      $Existing = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli storagepool ls" -EnsureConnection
      $Currentname = $(($Existing.Output[3] -split (": "))[1]) 
      if ($Currentname -eq $StoragePoolName){

        write-log -message "All Done here";

        $sprename = $true

      } else {

        write-log -message "Storage pool is not renamed yet doing the needful";
        write-log -message "Current name is $Currentname";
        write-log -message "New Name will be $StoragePoolName";
        write-log -message "Executing Name Change for the storage pool.";

        $Rename = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli storagepool edit name=$($Currentname) new-name=$($StoragePoolName)" -EnsureConnection

      }

      write-log -message "Checking Disk Container";
      
      $Existing = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli container ls" -EnsureConnection
      $object = $Existing.Output | ConvertFrom-Csv -Delimiter ":" -Header Name,Value,Something
      $default = ($object | where {$_.name -match "Name"}).value | where {$_ -match "default-container"} | select -first 1
      $Newexisting = ($object | where {$_.name -match "Name"}).value | where {$_ -eq $DisksContainerName} | select -first 1

      if ($Newexisting -eq $DisksContainerName){

        write-log -message "All Done here";

        $SCont1 = $true

      } elseif ($default){

        write-log -message "Disk container is not renamed yet doing the needful";
        write-log -message "Current name is $default";
        write-log -message "New Name will be $DisksContainerName";
        write-log -message "Executing Name Change";

        if ($count -ge 3){ 

          write-log -message "This is the 3rd time, lets try just to create a new one.";

          $Create = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli container create name=$($DisksContainerName) sp-name=$($StoragePoolName)"  -EnsureConnection
           
        } else {

          $Rename = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli container edit name=$($default) new-name=$($DisksContainerName)"  -EnsureConnection

        }
      } elseif (!$Newexisting){

        write-log -message "Container for Disks does not exist yet.";
        write-log -message "New Name will be $DisksContainerName";
        write-log -message "Creating the container";

        $Create = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli container create name=$($DisksContainerName) sp-name=$($StoragePoolName)"  -EnsureConnection
      } else {
        
        write-log -message "Why am i here" -sev "Error";

      }

      write-log -message "Checking Image Container";
      
      $Existing = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli container ls" -EnsureConnection
      $object = $Existing.Output | ConvertFrom-Csv -Delimiter ":" -Header Name,Value,Something
      $Currentname = ($object | where {$_.name -match "Name"}).value | where {$_ -eq $ImagesContainerName} | select -first 1

      if ($Currentname -eq $ImagesContainerName){

        write-log -message "All Done here";

        $SCont2 = $true

      } elseif (!$Currentname){

        write-log -message "Storage container for images does not exist yet.";
        write-log -message "New Name will be $ImagesContainerName";
        write-log -message "Creating the container";

        $Create = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli container create name=$($ImagesContainerName) sp-name=$($StoragePoolName)"  -EnsureConnection
   

      } else {

        write-log -message "We should not be here" -sev "error"

      }
    
      write-log -message "Checking ERA Container";
      
      $Existing = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli container ls" -EnsureConnection
      $object = $Existing.Output | ConvertFrom-Csv -Delimiter ":" -Header Name,Value,Something
      $Currentname = ($object | where {$_.name -match "Name"}).value | where {$_ -eq $ERAContainerName} | select -first 1

      if ($Currentname -eq $ERAContainerName){

        write-log -message "All Done here";

        $SCont3 = $true

      } elseif (!$Currentname){

        write-log -message "Storage container for ERA does not exist yet.";
        write-log -message "New Name will be $ERAContainerName";
        write-log -message "Creating the container";

        $Create = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli container create name=$($ERAContainerName) sp-name=$($StoragePoolName)"  -EnsureConnection
   

      } else {

        write-log -message "We should not be here" -sev "error"

      }

      write-log -message "Checking Karbon Container";
      
      $Existing = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli container ls" -EnsureConnection
      $object = $Existing.Output | ConvertFrom-Csv -Delimiter ":" -Header Name,Value,Something
      $Currentname = ($object | where {$_.name -match "Name"}).value | where {$_ -eq $KarbonContainername} | select -first 1

      if ($Currentname -eq $KarbonContainername){

        write-log -message "All Done here";

        $SCont4 = $true

      } elseif (!$Currentname){

        write-log -message "Storage container for Karbon does not exist yet.";
        write-log -message "New Name will be $KarbonContainername";
        write-log -message "Creating the container";

        $Create = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli container create name=$($KarbonContainername) sp-name=$($StoragePoolName)"  -EnsureConnection
   

      } else {

        write-log -message "We should not be here" -sev "error"

      }

    } catch {;
      $nw1completed = $false

      write-log -message "Error Creating networks, Retry" -sev "WARN";

      sleep 2
    }
  } until (($SCont1 -eq $true -and $SCont2 -and $sprename -eq $true -and $SCont3 -eq $true -and $SCont4 -eq $true) -or $count -ge 6)

 
  if ($nw1completed -eq $true){
    $status = "Success"

  } else {
    $status = "Failed"
  }
  $resultobject =@{
    Result = $status
  }
  Try {
    write-log -message "Executing session cleanup"
    $clean = Remove-SSHSession -SSHSession $session
  } catch {}
  return $resultobject
};


Function SSH-Unlock-XPlay {
  Param (
    [string] $PCClusterIP,
    [string] $clpassword,
    [string] $clusername,
    [string] $filename
  )
  #dependencies LIB-write-log, Posh-SSH, PE_ncli

  $count = 0 
  write-log -message "Building Credential for SSH session";
  $hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
  $Securepass = ConvertTo-SecureString $clpassword -AsPlainText -Force;
  $credential = New-Object System.Management.Automation.PSCredential ("$clusername", $Securepass);
  $session = New-SSHSession -ComputerName $PCClusterIP -Credential $credential -AcceptKey;
  
  write-log -message "Building session";

  do {;
    $count++
    try {;
      $session = New-SSHSession -ComputerName $PCClusterIP -Credential $credential -AcceptKey -ConnectionTimeout 999 -OperationTimeout 999
      
      write-log -message "Uploading the file $filename"
      write-log -message "To Its destination /home/nutanix/tmp/"

      $upload = Set-SCPFile -LocalFile $filename -RemotePath "/home/nutanix/tmp/" -ComputerName $PCClusterIP -Credential $credential -AcceptKey $true

      write-log -message "Executing Unlock";

      sleep 10

      $Unlock = Invoke-SSHCommand -SSHSession $session -command "/usr/bin/python2.7 /home/nutanix/tmp/unlockxplay_py.py" -EnsureConnection
      $completed = 1
      $Unlock.ExitStatus

    } catch {

      write-log -message "Failure during upload or unlock";

    }

  } until (($completed -eq 1 -and $Unlock.ExitStatus -eq 0 ) -or $count -ge 6)
 
  if ($completed -eq 1 -and $Unlock.ExitStatus -eq 0){

    write-log -message "One small step for man, one giant leap for mankind.";

    $status = "Success"
  } else {
    $status = "Failed"
  }
  $resultobject =@{
    Result = $status
    Output = $result.output
  }
  Try {
    write-log -message "Executing session cleanup"
    $clean = Remove-SSHSession -SSHSession $session
  } catch {}
  return $resultobject
};


Function SSH-Startup-Oracle {
  Param (
    [string] $OracleIP,
    [string] $clpassword
  )
  #dependencies LIB-write-log, Posh-SSH, PE_ncli
  $hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
  $count = 0 
  write-log -message "Building Credential for SSH session";

  $Securepass = ConvertTo-SecureString $clpassword -AsPlainText -Force;
  $credential = New-Object System.Management.Automation.PSCredential ('oracle', $Securepass);
  $session = New-SSHSession -ComputerName $OracleIP -Credential $credential -AcceptKey -connectiontimeout 20

  write-log -message "Starting Oracle Databases";

  do {;
    $count++
    try {;
      $session = New-SSHSession -ComputerName $OracleIP -Credential $credential -AcceptKey -connectiontimeout 120 -ea:0;
      
      write-log -message "Executing.....";

      $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
      sleep 10
      $stream.Write("sqlplus / as sysdba`n")
      sleep 20
      $stream.Write("startup;`n")
      sleep 20
      $output = $stream.Read()
      write-log -message "Testing the database started status";
      
      $result = Invoke-SSHCommand -SSHSession $session -command "ps -ef | grep pmon" -EnsureConnection -timeout 120 -ea:0;

      if ($debug -ge 2){
        write-host $output
      }

    } catch {;
      $output = $false

      write-log -message "Error starting Oracle Databases" -sev "WARN";

      sleep 2
    };
  } until (($output -match 'ORACLE instance started') -or $count -ge 3)

 
  if ($result.output -match $netbios){
    $status = "Success"

  } else {
    $status = "Failed"
  }
  $resultobject =@{
    Result = $status
    Output = $result.output
  }
  Try {
    write-log -message "Executing session cleanup"
    Remove-SSHSession -SSHSession $session
  } catch {}
  return $resultobject
};

Function SSH-Scan-PCVersion {
  Param (
    [string] $ClusterPE_IP,
    [string] $clpassword,
    [string] $clusername,
    [string] $PCversion,
    [string] $FilesVersion, 
    [string] $Model,
    [string] $pcwait
  )
  #dependencies LIB-write-log, Posh-SSH, PE_ncli
  $hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
  $Filesdownloadcount = 0 
  $pcdownloadcount = 0 
  $pcstatuscheck = 0
  $AFSStatuscheck = 0 


  write-log -message "Building Credential for SSH session";

  $Securepass = ConvertTo-SecureString $clpassword -AsPlainText -Force;
  $credential = New-Object System.Management.Automation.PSCredential ($clusername, $Securepass);
  $session = New-SSHSession -ComputerName $ClusterPE_IP -Credential $credential -AcceptKey;
  write-log -message "Downloading the latest PC, Telling AOS to do their own work.";
  $PossiblePCVersions = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=PRISM_CENTRAL_DEPLOY" -EnsureConnection
  $PCDownloadStatus = (Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type=PRISM_CENTRAL_DEPLOY name='$($truePCversion)'" -EnsureConnection).output
  $object = ($PossiblePCVersions.Output | ConvertFrom-Csv -Delimiter : )
  $truePCversion = $object.'Prism Central Deploy' | where {$_ -match "[0-9]" -and $_ -notmatch "bytes|in-progress"} | sort { [version]$_} | select -last 1

  write-log -message "Returning PC Version $truePCversion"

  $resultobject =@{
    PCVersion = $truePCversion
  }
  Try {

    write-log -message "Executing session cleanup"

    Remove-SSHSession -SSHSession $session
  } catch {}
  return $resultobject
};


function SSH-Wait-ImageUpload {
  param (
    [object] $datavar,
    [object] $datagen,
    [object] $ISOurlData,
    [string] $image
  )

  write-log -message "The VMWare image $image upload status is beeing tracked."
  $hosts = REST-PE-Get-Hosts -datagen $datagen -datavar $datavar
  $ESXHost = $hosts.entities.hypervisorKey | select -first 1

  $count = 0
  do {
    if (!$previoussize){
      $previoussize = 0
    } else {
      sleep 90
    }
    get-SSHSession | Remove-SSHSession
    $count++
    $filename = $($ISOurlData.$($image)) -split "/" | select -last 1
    $Securepass = ConvertTo-SecureString $datavar.pepass -AsPlainText -Force;
    $credential = New-Object System.Management.Automation.PSCredential ("root", $Securepass);
    $session = New-SSHSession -ComputerName $ESXHost -Credential $credential -AcceptKey -ea:0;
    [array]$Imagestatus = (Invoke-SSHCommand -SSHSession $session -command "cd /vmfs/volumes/$($datagen.ImagesContainerName)/;ls" -timeout 999 -EnsureConnection -ea:0).output
    #Both Temp and normal images are passed through, first time its filename, following are Temp_$Filename
    if ($filename -notin $imagestatus -and "Temp_$($filename)" -notin $imagestatus){
      
      if ($count % 4 -eq 0){

        write-log -message "The image is not there yet."

      }
    } else {


      if ($count % 4 -eq 0){

        write-log -message "Image present, checking if its ready."

      }

      get-SSHSession | Remove-SSHSession
      $session = New-SSHSession -ComputerName $ESXHost -Credential $credential -AcceptKey -ea:0;
      $output = ((Invoke-SSHCommand -SSHSession $session -command "cd /vmfs/volumes/$($datagen.ImagesContainerName)/;ls -la | awk '{print `$1, `$2, `$3,`$4, `$5, `$9}'" -timeout 999 -EnsureConnection -ea:0).output) | where {$_ -match $filename -or $_ -match "Temp_$($filename)" -and $_ -notmatch "chk"} | select -first 1
      $check = ((Invoke-SSHCommand -SSHSession $session -command "cd /vmfs/volumes/$($datagen.ImagesContainerName)/;ls -ltr" -timeout 999 -EnsureConnection -ea:0).output) | where {$_ -match "$($filename)-$($datavar.queueuuid).chk" }
      $Flatfile = $filename.substring(0, $filename.length -5) + "-flat.vmdk"
      $check2 = ((Invoke-SSHCommand -SSHSession $session -command "cd /vmfs/volumes/$($datagen.ImagesContainerName)/;ls -ltr" -timeout 999 -EnsureConnection -ea:0).output) | where {$_ -match $Flatfile} | select -first 1
      

      if ($debug -ge 2){

        write-log -message "Checking flatfile presense $Flatfile"
        ((Invoke-SSHCommand -SSHSession $session -command "cd /vmfs/volumes/$($datagen.ImagesContainerName)/;ls -ltr" -timeout 999 -EnsureConnection -ea:0).output)
      }


      $array = $output -split " "
      $size = $array[4]
      if ($check2){

        write-log -message "Already done mate"
        $exit = 1

      } elseif ($previoussize -eq 0){

        write-log -message "Initializing"
      
      } elseif ($previoussize -ne $size -or !$check){

        if ($previoussize -eq $size){

          write-log -message "Bytesize match, but checkfile does not exist"
          $count = $count + 100
        }

        write-log -message "Upload in progress"

      } else {
        if ($size -ge 1111111111){
          $readablesize = $size/1GB
          $unit = "GB"
        } else {
          $readablesize = $size/1MB
          $unit = "MB"
        }
        
        $readablesize = [math]::Round($readablesize)

        write-log -message "Upload Done for $filename $readablesize $unit Downloaded"

        #sleep 10 this kills multi disk perfromance

        if ($filename -match "vmdk"){

          write-log -message "Converting Image, this can take several minutes"
          get-SSHSession | Remove-SSHSession
          $session = New-SSHSession -ComputerName $ESXHost -Credential $credential -AcceptKey -ea:0;
          $ImageConvert = Invoke-SSHCommand -SSHSession $session -command "cd /vmfs/volumes/$($datagen.ImagesContainerName)/;mv $filename Temp_$($filename)" -timeout 999 -EnsureConnection
          $ImageConvert = Invoke-SSHCommand -SSHSession $session -command "cd /vmfs/volumes/$($datagen.ImagesContainerName)/;vmkfstools -i Temp_$($filename) $filename" -timeout 999 -EnsureConnection
          if ($debug -ge 2){

            write-log -message "Showing resulting folderstructure in debug mode."
            CMD-Connect-VMware -datavar $datavar
            get-item vmstores:\$($datavar.vcenterip)@443\Nutanix\$($datagen.ImagesContainerName) -ea:0
            (Invoke-SSHCommand -SSHSession $session -command "cd /vmfs/volumes/$($datagen.ImagesContainerName)/;ls" -timeout 999 -EnsureConnection -ea:0).output

          }
          $file = $filename.substring(0, $filename.length -5)
          $outfile = "/$($datagen.ImagesContainerName)/$($file)-flat.vmdk"
          $outfilewin = $outfile -replace "/","\"
          ## Control 
          CMD-Connect-VMware -datavar $datavar
          $datastoreitem = (get-item vmstores:\$($datavar.vcenterip)@443\Nutanix\$outfilewin -ea:0)
          if ($datastoreitem){

            write-log -message "Controll Check PASS"

            $exit = 1
            $ImageConvert = Invoke-SSHCommand -SSHSession $session -command "cd /vmfs/volumes/$($datagen.ImagesContainerName)/;rm -f Temp_$($filename)" -timeout 999 -EnsureConnection

          } else {

            write-log -message "Controll Check FAIL, Retry" -SEV "WARN"
            $count = $count + 100
          }

        } elseif ($filename -match "ova"){

          write-log -message "No action required for OVA Files."
          $exit = 1

        }

      }
      $previoussize = $size
    }  
  } until ($exit -eq 1 -or $count -eq 50)
  return $outfile
}

Function SSH-Finalize-Linux-VM {
  param (
    [string]  $mode,
    [object]  $datavar,
    [object]  $datagen,
    [string]  $currentIP,
    [string]  $targetIP,
    [string]  $vmname
  )
  $oldIPtest = test-connection -computername $targetIP -ea:0;

  if (!$oldIPtest){
    if ($mode -eq "centos"){
      $sshusername = "centos" 
      $oldSecurepass = ConvertTo-SecureString "nutanix/4u" -AsPlainText -Force;
    } elseif ($mode -eq "ERA" ){
      $sshusername = "era" 
      $oldSecurepass = ConvertTo-SecureString "Nutanix.1" -AsPlainText -Force;
    } elseif ($mode -eq "Oracle1" ){
      $sshusername = "oracle" 
      $oldSecurepass = ConvertTo-SecureString "welcome1" -AsPlainText -Force;
    } elseif ($mode -eq "Oracle2" ){
      $sshusername = "root" 
      $oldSecurepass = ConvertTo-SecureString "welcome1" -AsPlainText -Force;
    } elseif ($mode -eq "Oracle3" ){
      $sshusername = "grid" 
      $oldSecurepass = ConvertTo-SecureString "welcome1" -AsPlainText -Force;
    } elseif ($mode -eq "Oracle4" ){
      $sshusername = "kamal" 
      $oldSecurepass = ConvertTo-SecureString "welcome1" -AsPlainText -Force;
    } elseif ($mode -eq "move" ){
      $sshusername = "admin" 
      $oldSecurepass = ConvertTo-SecureString $datavar.pepass -AsPlainText -Force;
    } else {
      $sshusername = "nutanix"
      $oldSecurepass = ConvertTo-SecureString "nutanix/4u" -AsPlainText -Force; 
    }
  
    write-log -message "Mode is $mode"
  
    $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $oldSecurepass);
    $count = 0
    do {

      write-log -message "Building Session against current IP, Attempt: $count"

      $count++
      sleep 20
      $session = New-SSHSession -ComputerName $currentIP -Credential $credential -AcceptKey;
    } until ($session -or $count -ge 5)

    if ($session){

      write-log -message "Session built, executing"

    } 
    $reip = 0
    do {
      sleep 10
      write-debug -message "Looping for SSH reip, this is a tricky thing. "
      $reip ++
      $REIPVM   = (Invoke-SSHCommand -SSHSession $session -command "configure_static_ip ip=$($targetIP) gateway=$($datavar.InfraGateway) netmask=$($datavar.InfraSubnetMask) nameserver=$($datagen.dc1ip), $($datagen.dc2ip)" -timeout 25 -EnsureConnection -ea:0).output 
      $newiptest = test-connection -computername $targetIP -ea:0 -count 1
    } until ($newiptest -or $reip -ge 5)
    if ($newiptest){
      
      write-log -message "IP Changed"

    } else {

      write-log -message "Danger Will" -sev "ERROR"
      $failed = 1

    }

    $session = New-SSHSession -ComputerName $targetIP -Credential $credential -AcceptKey;

    if ($session){

      write-log -message "Target Connected"
      $failed = 0
    }
    
  } else {

    write-log -message "TargetIP is alive!" -sev "WARN"

  }
  Return $failed 
}

Function SSH-ERA-ESX-StaticIP {
  param (
    [object]  $datavar,
    [object]  $datagen
  )
  write-log -message "Building connection and setting up ERA CLI." 

  $sshusername = "era" 
  $oldSecurepass = ConvertTo-SecureString "Nutanix.1" -AsPlainText -Force;
  $credential = New-Object System.Management.Automation.PSCredential ($sshusername, $oldSecurepass);
  $session = New-SSHSession -ComputerName $datagen.ERA1IP -Credential $credential -AcceptKey;
  $ChangeERA   = (Invoke-SSHCommand -SSHSession $session -command "echo y | era-server -c `"era_server set ip=$($datagen.ERA1IP) gateway=$($datavar.InfraGateway) netmask=$($datavar.InfraSubnetMask) nameserver=$($datagen.dc1ip), $($datagen.dc2ip)`"" -timeout 25 -EnsureConnection -ea:0).output 
 
  write-log -message "Changing ERA IPconfig" 

}


Export-ModuleMember *