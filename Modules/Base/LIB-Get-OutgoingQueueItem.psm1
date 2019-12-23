function Lib-Get-OutgoingQueueItem{
	param(
    [string] $queuepath,
    [string] $Outgoing,
    [string] $Archive,
    [string] $prodmode
	)
	$item = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLQueueTableName) WHERE QueueUUID='$QueueUUID';" 
  if ($item){
    $object = $item

    ## Some Global Roles for Compatibility

    if ($object.debug -lt 1){

      write-log -Message "Debug is set lower then 1, raising to minimal"

      $object.debug = 1
    }
     if ($object.SetupSSP -ne 1){

      write-log -Message "SSP is required, cannot be disabled"

      $object.SetupSSP = 1
    }   
    if ($object.InstallKarbon -eq 1){

      write-log -Message "Forcing PC Scale out to 1 node."

      $object.pcmode = 1
    }

    if ($object.DemoXenDeskT -eq 1 -and $object.InstallFiles -eq 0){

      write-log -Message "Files cannot be disabled with XenDesktop Enabled."

      $object.DemoXenDeskT -eq 0

    }

    if ($object.Destroy -eq 1){

      write-log -Message "Changing PE Password"
      $random = Get-Random -Maximum 999
      $PEPass = "D3str0yeD$($random)!"
      $oldPass = $object.pepass
        
    } else {

      $PEPass = $object.pepass
      $oldPass = "NA"

    }

    write-log -Message "Updating QueueTable"

    $Update = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "UPDATE [$($SQLDatabase)].[dbo].[$($SQLQueueTableName)] SET QueueStatus = 'Archived' WHERE QueueUUID='$($object.QueueUUID)';" 

    write-log -Message "Creating Processor Entry"

    $SQLQuery = "USE `"$SQLDatabase`"
                                                      INSERT INTO dbo.$SQLDataVarTableName (QueueUUID, DateCreated, DateStopped, PEClusterIP, SenderName, SenderEMail, PEAdmin, PEPass, debug, AOSVersion, PCVersion, Hypervisor, InfraSubnetmask, InfraGateway, DNSServer, POCname, PCmode, SystemModel, Nw1Vlan, Nw2DHCPStart, Nw2Vlan, Nw2subnet, Nw2gw, Location, VersionMethod, VPNUser, VPNPass, VPNURL, SetupSSP, DemoLab, EnableFlow, DemoXenDeskT, EnableBlueprintBackup, InstallEra, InstallFrame, InstallMove, InstallObjects, UpdateAOS, DemoExchange, InstallKarbon, InstallXRay, DemoIISXPlay, InstallFiles, InstallSplunk, InstallHashiVault, Install1CD, Slackbot, InstallBPPack, Portable, EnableEMail, Destroy, CVMIPs, Install3TierLAMP, RootPID, PreDestroyPass, VCenterUser, VCenterPass, VCenterIP, pcsidebin, pcsidemeta )
VALUES('$($object.queueUuid)','$($object.DateCreated)','','$($object.PEClusterIP)','$($object.SenderName)','$($object.SenderEMail)','$($object.PEAdmin)','$($PEPass)','$($object.debug)','$($object.AOSVersion)','$($object.PCVersion)','$($object.Hypervisor)','$($object.InfraSubnetmask)','$($object.InfraGateway)','$($object.DNSServer)','$($object.POCname)','$($object.PCmode)','$($object.SystemModel)','$($object.nw1vlan)','$($object.Nw2DHCPStart)','$($object.Nw2Vlan)','$($object.nw2subnet)','$($object.nw2gw)','$($object.Location)','$($object.VersionMethod)','$($object.VPNUser)','$($object.VPNPass)','$($object.VPNURL)','$($object.SetupSSP)','$($object.DemoLab)','$($object.EnableFlow)','$($object.DemoXenDeskT)','$($object.EnableBlueprintBackup)','$($object.InstallEra)','$($object.InstallFrame)','$($object.InstallMove)','$($object.InstallObjects)','$($object.UpdateAOS)','$($object.DemoExchange)','$($object.installKarbon)','$($object.InstallXRay)','$($object.DemoIISXPlay)','$($object.InstallFiles)','$($object.InstallSplunk)','$($object.InstallHashiVault)','$($object.Install1CD)','$($object.Slackbot)','$($object.InstallBPPack)','$($object.portable)','$($object.EnableEmail)','$($object.Destroy)','$($object.CVMIPs)','$($object.Install3TierLAMP)','$pid','$oldpass','$($object.VCenterUser)','$($object.VCenterPass)','$($object.VCenterIP)','$($object.pcsidebin)','$($object.pcsidemeta)'     )"
    $SQLQueryOutput = Invoke-Sqlcmd -query $SQLQuery -ServerInstance $SQLInstance 
    sleep 5
    $datavar = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query "SELECT TOP 1 * FROM [$($SQLDatabase)].[dbo].$($SQLDataVarTableName) WHERE QueueUUID='$($object.queueUuid)';"

  } else {

  }
  return $datavar
}