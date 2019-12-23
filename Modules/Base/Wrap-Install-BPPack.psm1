function Wrap-Install-BPPack {
  param(
    $datavar,
    $datagen,
    $BlueprintsPath
  )

  write-log -message "Starting BluePrint Pack Installer" -sev "Chapter" -slacklevel 1
  write-log -message "Installing Calmers GTS 2019 BluePrintPack" -slacklevel 1
  write-log -message "https://github.com/pipoe2h/gtsx2019" -slacklevel 1

  $Jsonfiles = get-childitem "$($BlueprintsPath)\gtsx2019\*.json" -recurse
  foreach ($file in $Jsonfiles){
    $json = get-content $file.fullname
    $object = $json | convertfrom-json
    $object.psobject.members.remove("Status")
    $json = $object | convertto-json -depth 100
    write-log -message "Importing BluePrint $($object.metadata.name)"
    REST-Restore-BackupBlueprint -datagen $datagen -datavar $datavar -blueprint $json
  }

  write-log -message "Backup Engine Scheduler Finished." -sev "Chapter" -slacklevel 1
}