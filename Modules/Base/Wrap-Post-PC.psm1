Function Wrap-Post-PC {
  param (
    [object] $datavar,
    [object] $datagen
  )     

  write-log -message "Making sure the forest install is done."

  wait-forest-task -datavar $datavar

  if ($datavar.HyperVisor -match "nutanix|AHV"){

    write-log -message "Importing Images into Prism Central" -slacklevel 1

    $imageimport = REST-Image-Import-PC -clpassword $datavar.PEPass -clusername $datagen.buildaccount -PCClusterIP $datagen.PCClusterIP

  }
  
  write-log -message "Joining PE"
  
  Wrap-Join-PxtoADDomain -datagen $datagen -datavar $datavar -mode "PE"

  write-log -message "Joining PC"

  Wrap-Join-PxtoADDomain -datagen $datagen -datavar $datavar -mode "PC"

  write-log -message "Disable Search Tutorial"

  REST-Diable-PCSearch-Tutorial -datagen $datagen -datavar $datavar

  write-log -message "Post PC Install Finished" -slacklevel 1

}