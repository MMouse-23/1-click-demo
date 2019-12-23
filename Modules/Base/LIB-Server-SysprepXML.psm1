
Function LIB-Server-SysprepXML {
  param(
    $Password
  )
$Sysprepfile = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>0413:00020409</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguageFallback>en-US</UILanguageFallback>
            <UserLocale>nl-NL</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <AutoLogon>
                <Enabled>true</Enabled>
                <LogonCount>9999999</LogonCount>
                <Username>Administrator</Username>
                <Password>
                    <PlainText>true</PlainText>
                    <Value>$($Password)</Value>
                </Password>
            </AutoLogon>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Home</NetworkLocation>
                <ProtectYourPC>2</ProtectYourPC>
            </OOBE>
            <UserAccounts>
                <AdministratorPassword>
                    <PlainText>true</PlainText>
                    <Value>$($Password)</Value>
                </AdministratorPassword>
            </UserAccounts>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c winrm quickconfig -q</CommandLine>
                    <Description>Win RM quickconfig -q</Description>
                    <Order>20</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c winrm quickconfig -transport:http</CommandLine>
                    <Description>Win RM quickconfig -transport:http</Description>
                    <Order>21</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c winrm set winrm/config @{MaxTimeoutms="1800000"}</CommandLine>
                    <Description>Win RM MaxTimoutms</Description>
                    <Order>22</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c winrm set winrm/config/winrs @{MaxMemoryPerShellMB="300"}</CommandLine>
                    <Description>Win RM MaxMemoryPerShellMB</Description>
                    <Order>23</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c winrm set winrm/config/service @{AllowUnencrypted="true"}</CommandLine>
                    <Description>Win RM AllowUnencrypted</Description>
                    <Order>24</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c winrm set winrm/config/service/auth @{Basic="true"}</CommandLine>
                    <Description>Win RM auth Basic</Description>
                    <Order>25</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c winrm set winrm/config/client/auth @{Basic="true"}</CommandLine>
                    <Description>Win RM auth Basic</Description>
                    <Order>26</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c winrm set winrm/config/listener?Address=*+Transport=HTTP @{Port="5985"} </CommandLine>
                    <Description>Win RM listener Address/Port</Description>
                    <Order>27</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c netsh advfirewall firewall set rule group="remote administration" new enable=yes </CommandLine>
                    <Description>Win RM adv firewall enable</Description>
                    <Order>29</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c net stop winrm </CommandLine>
                    <Description>Stop Win RM Service </Description>
                    <Order>28</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c net start winrm </CommandLine>
                    <Description>Start Win RM Service</Description>
                    <Order>32</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>powershell -Command &quot;Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force&quot;</CommandLine>
                    <Description>Set PowerShell ExecutionPolicy</Description>
                    <Order>1</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                    <CommandLine>powershell -Command &quot;Enable-PSRemoting -Force&quot;</CommandLine>
                    <Description>Enable PowerShell Remoting</Description>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>61</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                    <CommandLine>powershell -Command &quot;Enable-NetFirewallRule -DisplayGroup "Remote Desktop"&quot;</CommandLine>
                    <Description>Rule RDP Filewall</Description>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>62</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                    <CommandLine>powershell -Command &quot;Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -Name "UserAuthentication" -Value 1&quot;</CommandLine>
                    <Description>Enable RDP2016</Description>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>63</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                    <CommandLine>powershell -Command &quot;Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name "fDenyTSConnections" -Value 0&quot;</CommandLine>
                    <Description>Enable RDP2016p2</Description>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>5</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                    <Description>RDP adv firewall enable</Description>
                    <CommandLine>cmd.exe /c netsh advfirewall firewall set rule group=&quot;Remote Desktop&quot; new enable=yes </CommandLine>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>31</Order>
                    <CommandLine>cmd.exe /c sc config winrm start= auto</CommandLine>
                    <RequiresUserInput>true</RequiresUserInput>
                    <Description>No-Delay Auto start WinRM on boot</Description>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>30</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                    <CommandLine>cmd.exe /c netsh advfirewall set allprofiles state off</CommandLine>
                    <Description>Disable Windows Firewall</Description>
                </SynchronousCommand>
            </FirstLogonCommands>
<ShowWindowsLive>false</ShowWindowsLive>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>net user administrator /active:Yes</Path>
                    <WillReboot>Never</WillReboot>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
        <component name="Microsoft-Windows-Security-SPP-UX" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SkipAutoActivation>true</SkipAutoActivation>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>*</ComputerName>
        </component>
    </settings>
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SetupUILanguage>
            <UILanguage>en-US </UILanguage>
            </SetupUILanguage>
            <InputLocale>en-US </InputLocale>
            <SystemLocale>en-US </SystemLocale>
            <UILanguage>en-US </UILanguage>
            <UILanguageFallback>en-US </UILanguageFallback>
            <UserLocale>en-US </UserLocale>
        </component>
    </settings>
</unattend>
"@
  

return $Sysprepfile
}

Function LIB-IP-Server-SysprepXML {
  param(
    $Password,
    $IFName,
    $ip,
    $mask,
    $gw
  )
$Sysprepfile = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>0413:00020409</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguageFallback>en-US</UILanguageFallback>
            <UserLocale>nl-NL</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <AutoLogon>
                <Enabled>true</Enabled>
                <LogonCount>9999999</LogonCount>
                <Username>Administrator</Username>
                <Password>
                    <PlainText>true</PlainText>
                    <Value>$($Password)</Value>
                </Password>
            </AutoLogon>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Home</NetworkLocation>
                <ProtectYourPC>2</ProtectYourPC>
            </OOBE>
            <UserAccounts>
                <AdministratorPassword>
                    <PlainText>true</PlainText>
                    <Value>$($Password)</Value>
                </AdministratorPassword>
            </UserAccounts>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>netsh interface ip set address name="$($IFName)" static $($IP) $($mask) $($GW)</CommandLine>
                    <Description>Win RM quickconfig -q</Description>
                    <Order>69</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c winrm quickconfig -q</CommandLine>
                    <Description>Win RM quickconfig -q</Description>
                    <Order>20</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c winrm quickconfig -transport:http</CommandLine>
                    <Description>Win RM quickconfig -transport:http</Description>
                    <Order>21</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c winrm set winrm/config @{MaxTimeoutms="1800000"}</CommandLine>
                    <Description>Win RM MaxTimoutms</Description>
                    <Order>22</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c winrm set winrm/config/winrs @{MaxMemoryPerShellMB="300"}</CommandLine>
                    <Description>Win RM MaxMemoryPerShellMB</Description>
                    <Order>23</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c winrm set winrm/config/service @{AllowUnencrypted="true"}</CommandLine>
                    <Description>Win RM AllowUnencrypted</Description>
                    <Order>24</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c winrm set winrm/config/service/auth @{Basic="true"}</CommandLine>
                    <Description>Win RM auth Basic</Description>
                    <Order>25</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c winrm set winrm/config/client/auth @{Basic="true"}</CommandLine>
                    <Description>Win RM auth Basic</Description>
                    <Order>26</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c winrm set winrm/config/listener?Address=*+Transport=HTTP @{Port="5985"} </CommandLine>
                    <Description>Win RM listener Address/Port</Description>
                    <Order>27</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c netsh advfirewall firewall set rule group="remote administration" new enable=yes </CommandLine>
                    <Description>Win RM adv firewall enable</Description>
                    <Order>29</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c net stop winrm </CommandLine>
                    <Description>Stop Win RM Service </Description>
                    <Order>28</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c net start winrm </CommandLine>
                    <Description>Start Win RM Service</Description>
                    <Order>32</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>powershell -Command &quot;Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force&quot;</CommandLine>
                    <Description>Set PowerShell ExecutionPolicy</Description>
                    <Order>1</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                    <CommandLine>powershell -Command &quot;Enable-PSRemoting -Force&quot;</CommandLine>
                    <Description>Enable PowerShell Remoting</Description>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>61</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                    <CommandLine>powershell -Command &quot;Enable-NetFirewallRule -DisplayGroup "Remote Desktop"&quot;</CommandLine>
                    <Description>Rule RDP Filewall</Description>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>62</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                    <CommandLine>powershell -Command &quot;Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -Name "UserAuthentication" -Value 1&quot;</CommandLine>
                    <Description>Enable RDP2016</Description>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>63</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                    <CommandLine>powershell -Command &quot;Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name "fDenyTSConnections" -Value 0&quot;</CommandLine>
                    <Description>Enable RDP2016p2</Description>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>5</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                    <Description>RDP adv firewall enable</Description>
                    <CommandLine>cmd.exe /c netsh advfirewall firewall set rule group=&quot;Remote Desktop&quot; new enable=yes </CommandLine>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>31</Order>
                    <CommandLine>cmd.exe /c sc config winrm start= auto</CommandLine>
                    <RequiresUserInput>true</RequiresUserInput>
                    <Description>No-Delay Auto start WinRM on boot</Description>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>30</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                    <CommandLine>cmd.exe /c netsh advfirewall set allprofiles state off</CommandLine>
                    <Description>Disable Windows Firewall</Description>
                </SynchronousCommand>
            </FirstLogonCommands>
<ShowWindowsLive>false</ShowWindowsLive>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>net user administrator /active:Yes</Path>
                    <WillReboot>Never</WillReboot>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
        <component name="Microsoft-Windows-Security-SPP-UX" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SkipAutoActivation>true</SkipAutoActivation>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>*</ComputerName>
        </component>
    </settings>
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SetupUILanguage>
            <UILanguage>en-US </UILanguage>
            </SetupUILanguage>
            <InputLocale>en-US </InputLocale>
            <SystemLocale>en-US </SystemLocale>
            <UILanguage>en-US </UILanguage>
            <UILanguageFallback>en-US </UILanguageFallback>
            <UserLocale>en-US </UserLocale>
        </component>
    </settings>
</unattend>
"@
  

return $Sysprepfile
}

