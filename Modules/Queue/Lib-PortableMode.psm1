Function Lib-PortableMode {
  param (
    [string] $basedir,
    [string] $iisdir = "c:\inetpub\wwwroot\data"
  )
  $ProgressPreference = 'SilentlyContinue'
  $checkfile = "c:\windows\temp\downloaded.txt"
  $item = get-item $checkfile -ea:0
  $Google = test-connection www.google.nl -Quiet
  if (!$item -and $google){

    write-log -message "Cloning Git Repo"
    write-log -message "Refreshing GIT"
    sleep 60
    rm "$($BaseDir)\System\Temp\Git" -force -confirm:0 -recurse -ea:0
    mkdir "$($BaseDir)\System\Temp\Git"
    #
    git clone "https://github.com/MMouse-23/1-click-demo/" "$($BaseDir)\System\Temp\Git"
    rm "$($BaseDir)\Modules\" -force -recurse -confirm:0 -ea:0
    rm "$($BaseDir)\Binaries\" -force -recurse -confirm:0 -ea:0
    rm "$($BaseDir)\Blueprints\" -force -recurse -confirm:0 -ea:0
    rm "$($BaseDir)\AutoDownloadURLs\" -force -recurse -confirm:0 -ea:0
    try {
      cp "$($BaseDir)\System\Temp\Git\BluePrints\" "$($BaseDir)" -recurse -confirm:0 -ea:0
      cp "$($BaseDir)\System\Temp\Git\Modules\" "$($BaseDir)" -recurse -confirm:0 -ea:0
      cp "$($BaseDir)\System\Temp\Git\Binaries\" "$($BaseDir)"  -recurse -confirm:0 -ea:0
      cp "$($BaseDir)\System\Temp\Git\AutoDownloadURLs\" "$($BaseDir)" -recurse -confirm:0 -ea:0
      cp "$($BaseDir)\System\Temp\Git\Backend-Processsor.ps1" "$($BaseDir)Backend-Processsor.ps1" -confirm:0 -ea:0
      cp "$($BaseDir)\System\Temp\Git\Base-Outgoing-Queue-Processor.ps1" "$($BaseDir)Base-Outgoing-Queue-Processor.ps1" -confirm:0 -ea:0
      cp "$($BaseDir)\System\Temp\Git\Maintenance.ps1" "$($BaseDir)Maintenance.ps1" -confirm:0 -ea:0
    } catch {
      mv "$($BaseDir)\System\Temp\Git\BluePrints\" "$($BaseDir)" -force
      mv "$($BaseDir)\System\Temp\Git\Modules\" "$($BaseDir)" -force
      mv "$($BaseDir)\System\Temp\Git\Binaries\" "$($BaseDir)" -force
      mv "$($BaseDir)\System\Temp\Git\AutoDownloadURLs\" "$($BaseDir)" -force 
      mv "$($BaseDir)\System\Temp\Git\Backend-Processsor.ps1" "$($BaseDir)Backend-Processsor.ps1" -force 
      mv "$($BaseDir)\System\Temp\Git\Base-Outgoing-Queue-Processor.ps1" "$($BaseDir)Base-Outgoing-Queue-Processor.ps1" -force 
      mv "$($BaseDir)\System\Temp\Git\Maintenance.ps1" "$($BaseDir)Maintenance.ps1" -force   
    }

    write-log -message "Generating Local ISO Payload."
    $computersys = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges;
    $computersys.AutomaticManagedPagefile = $False;
    $computersys.Put();
    $pagefile = Get-WmiObject -Query "Select * From Win32_PageFileSetting Where Name like '%pagefile.sys'";
    $pagefile.InitialSize = 15;
    $pagefile.MaximumSize = 24576;
    $pagefile.Put();

    Import-Module "$($basedir)\Modules\Base\LIB-Config-ISOurlData.psm1" -DisableNameChecking;
    $ISOurlData = LIB-Config-ISOurlData -region "Backup"
    $iisdirexists = get-item $iisdir -ea:0
    if (!$iisdirexists){
      mkdir $iisdir

    }
    do {
     
      $download = Read-Host 'Do you want to download images to this VM or use dropbox L/D?'  
    } until ($download -eq "L" -or $download -eq "D")
    if ($download -eq "L"){
      write-log -message "This can take a long time."
      $nametemp = ($ISOurlData | gm | where {$_.membertype -eq "noteproperty"}).name
      foreach ($Image in $nametemp){
        $url = $($ISOurlData.$($Image))
        
        do {
          try {
            write-log -message "Downloading $image"
            write-log -message "Using URL $url"
        
            $filename = $($ISOurlData.$($Image)) -split "/" | select -last 1
            $output = "$($iisdir)\$($filename)"
            $outexits = get-item $output -ea:0
            if ($outexits){
              rm $outexits -force -confirm:0 -ea:0
              
              write-log -message "Removing existing file $output"
      
            }
      
            write-log -message "Writing towards destination: $output"
      
            $wc = New-Object net.webclient
            $wc.Downloadfile($url, $output)
            $downloaded = 1
          } catch {
  
            write-log -message "Unstable Client, Retry"
            $downloaded = 0
          }
        } until ($downloaded -eq 1)
        #Invoke-WebRequest -Uri $url -OutFile $output
  
        write-log -message "Image Downloaded"
  
      }
    }
    write "Blaat" |out-file $checkfile


    write-log -message "Images download completed, starting processor"

    get-scheduledtask "BackendProcessor" | enable-scheduledtask
    get-scheduledtask "BackendProcessor" | start-scheduledtask

    write-log -message "We are done downloading please open the localhost website."
  } elseif (!$google){

    write-log -message "There is no internet connection, 1CD Cannot build its repo."
    write-log -message "Please establish an internet connection and wait for this next cycle."
    sleep 50

  } else {

    write-log -message "Images already downloaded, starting processor"

  }
};
Export-ModuleMember *
 
