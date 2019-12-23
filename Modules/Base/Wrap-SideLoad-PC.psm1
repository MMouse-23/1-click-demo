Function Wrap-SideLoad-PC {
  param (
    [object] $datavar,
    [object] $datagen,
    [string] $UrlBase,
    [string] $jsonbase,
    [string] $AOSVersion
  )
  $meta = Invoke-RestMethod -Uri $jsonbase -method "GET"
  if ($meta){ 
    write-log -message "Building Credential for SSH session";
    $hide = Get-SSHTrustedHost | Remove-SSHTrustedHost
    $Securepass = ConvertTo-SecureString $datavar.pepass -AsPlainText -Force;
    $credential = New-Object System.Management.Automation.PSCredential ("nutanix", $Securepass);
    $session = New-SSHSession -ComputerName $datavar.peclusterip -Credential $credential -AcceptKey;
    
    write-log -message "JSON PC $($meta.version_id) $jsonbase"
    write-log -message "URL PC $($meta.version_id) $UrlBase"
    write-log -message "Pushing PC $($meta.version_id), AOS is $($AOSVersion)"

    do {;
      $count1++
      try {;
          
        $binarybaseshort = $UrlBase -split "/" | select -last 1
        $jsonbaseshort = $jsonbase -split "\\" | select -last 1
        $localBinBase = "c:\temp\$($binarybaseshort)"
        $localJSONBase= "c:\temp\$($jsonbaseshort)"

        write-log -message "Downloading Payload"

        $wc = New-Object net.webclient
        $wc.Downloadfile($UrlBase, $localBinBase)
        $wc = New-Object net.webclient
        $wc.Downloadfile($jsonbase, $localJSONBase)

        write-log -message "Building SSH Session"

        $session = New-SSHSession -ComputerName $datavar.peclusterip -Credential $credential -AcceptKey

        write-log -message "Before we start Each loop, lets check if ive done this before."

        $check1 = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type='PRISM_CENTRAL_DEPLOY' name=$($meta.version_id)" -EnsureConnection

        if ($check1.output -match "completed"){

          write-log -message "Already Done"

        } else {

          write-log -message "$($check1.output) Current status"
          write-log -message "Uploading the PC Binaries $($jsonbaseshort) and $($binarybaseshort)"
          write-log -message "To Its destination /home/nutanix/tmp/$($jsonbaseshort)"
          write-log -message "and /home/nutanix/tmp/$($binarybaseshort)"
          
          $Clean2 = Invoke-SSHCommand -SSHSession $session -command "sudo rm /home/nutanix/tmp/$binarybaseshort"

          $upload1 = Set-SCPFile -LocalFile $localJSONBase -RemotePath "/home/nutanix/tmp" -ComputerName $datavar.peclusterip -Credential $credential -AcceptKey $true
          sleep 3
          $upload2 = Set-SCPFile -LocalFile $localBinBase -RemotePath "/home/nutanix/tmp" -ComputerName $datavar.peclusterip -Credential $credential -AcceptKey $true
  
          write-log -message "Uploading PC Software in NCLI";
          
          sleep 2
          $NCLI1 = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software upload software-type='PRISM_CENTRAL_DEPLOY' file-path=/home/nutanix/tmp/$binarybaseshort meta-file-path=/home/nutanix/tmp/$jsonbaseshort" -timeout 999 -EnsureConnection
          sleep 2
          write-log -message "Cleaning, NCLI Output was $($NCLI1.output)"
  
          $Clean2 = Invoke-SSHCommand -SSHSession $session -command "sudo rm /home/nutanix/tmp/$binarybaseshort"
          sleep 2
          $Clean3 = rm $localBinBase -force -confirm:0
          $Clean4 = rm $localJSONBase -force -confirm:0
          $check1 = Invoke-SSHCommand -SSHSession $session -command "/home/nutanix/prism/cli/ncli software list software-type='PRISM_CENTRAL_DEPLOY' name=$($meta.version_id)" -EnsureConnection 

        }    

      } catch {

        write-log -message "Failure during upload";

      }

  
    } until ($check1.output -match "completed" -match "completed" -or $count1 -ge 8)

    write-log -message "SSH $($binarybaseshort) Sideload Success"
  } else {
    write-log -message "cannot open meta file for side load" -sev "WARN";
  }
  get-sshsession -ea:0 | remove-sshsession -ea:0
}
Export-ModuleMember *



  
  
  