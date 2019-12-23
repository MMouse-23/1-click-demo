Function Lib-Check-Thread {
  param (
  $Status,
  $stage,
  $lockfile,
  $SingleModelck,
  $SenderEMail,
  $Logfile
  )
  if ($Status.Result -eq "Failed|Finished"){
    stop-transcript
    LIB-Send-Confirmation -reciever $datavar.SenderEMail -datagen $data -datavar $datavar -mode "FailedStage" -stage $stage -logfile $logfile
    $exit = 1
    try {
      Remove-item $lockfile -force -confirm:0 -ea:0
      Remove-item $SingleModelck -force -confirm:0 -ea:0
      if ($debug -ge 2){
        
      } else {
        Connect-NutanixVPN -VPNUser $datavar.VPNUser -VPNPass $datavar.vpnpass -VPNURL $datavar.vpnurl -mode "stop"
      }
    }catch {}
  write-host $status
  break
  }
} 