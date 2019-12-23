function LIB-Connect-NutanixVPN {
  param(
      [string]$VPNUser,
      [string]$VPNPass,
      [string]$VPNurl,
      $peclusterIP,
      $mode,
      $binairypath = "C:\Program Files (x86)\Common Files\Pulse Secure\Integration"
  )
  cd $binairypath
  if ($mode -eq "start"){
    write-log -message "Starting Single User VPN."
    try {
      $connect = invoke-expression ".\pulselauncher.exe -url `"$($VPNurl)`" -u `"$($VPNUser)`" -p `"$($VPNPass)`" -r Users"
    } catch {
      write-log -message "Error Attempting VPN connection." -sev "Error"
    }
  } else {
    write-log -message "Disconnecting VPN session."
    try {
      $disconnect = invoke-expression ".\pulselauncher.exe -stop -url `"$($VPNurl)`" -u `"$($VPNUser)`" -p `"$($VPNPass)`" -r Users"
    } catch {
      write-log -message "No VPN session to disconnect."
    }
  }
};
Export-ModuleMember *