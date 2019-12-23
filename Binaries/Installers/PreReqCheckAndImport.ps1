# Copyright (c) 2014 Nutanix Inc. All rights reserved.
#
# Author : isha.singhal@nutanix.com
#
# Description: Checks if the CLRVersion is compatible with the DLLs
# If the CLRVersion is not compatible it is changed.
# Also restarts powershell to retain the change in the property of CLRVersion
# After that importModule script is called.

function RestartPowershell($importModuleScript)
{
    <#
    .DESCRIPTION
    Opens a new powershell session and calls the importModule script.
    Also closes the current powershell session.

    .PARAMETER $importModuleScript
    The path of the script file to be called in the new powershell session.
    #>
    $importModuleScript += ".ps1"
    [string] $args1 = "
    -noexit -executionpolicy unrestricted -File ```"$importModuleScript```" "
    $exp = "start-process powershell.exe -verb runas -ArgumentList `"$args1`" "
    Invoke-Expression $exp
}

# Script to change the CLRverion of Powershell
# This script is run only if the CLRVersion is found incompatible
$config_text=@"
<?xml version="1.0"?>
<configuration>
    <startup useLegacyV2RuntimeActivationPolicy="true">
        <supportedRuntime version="v4.0.30319"/>
        <supportedRuntime version="v2.0.50727"/>
    </startup>
</configuration>
"@

# DLLs are built using .NET 4.0 so supported CLRVersion is 4.0
# If CLRVersion is 2.0 then built DLLs cannot be imported
# without changing the CLRVersion
# Powershell v3 (windows 8 has by default powershell v3) has by default
# CLRVersion 4.0. So there we do not have any problem and
# the script runs without changing the CLRVersion. Powershell v2 has
# CLRVersion 2.0. In that case it is changed.
if ($PSVersionTable.CLRVersion.Major -eq 2)
{
    Write-Host "CLRVersion of Powershell is not compatible with the built DLLs."
    Write-Host "Cannot import the DLLs in the current powershell session."
    Write-Host "Can only import DLLs after changing the CLRVersion."
    Write-Host "Your current CLRVersion is 2.0."
    Write-Host "Compatible CLRVersion with the built DLLs is 4.0"
    Write-Host "This CLRVersion can be changed. "
    Write-Host "This change is permanent and cannot be reverted."
    do
    {
        $permission = Read-Host "Would you like to change CLRVersion(y/n) "

        # If user gives the permission to change the CLRVersion
        # then the script for the same is  run
        if ($permission -eq "y")
        {
            $psFile = $pshome + "\powershell.exe.config"
            $psIseFile = $pshome + "\powershell_ise.exe.config"
            try
            {
                $fileTest = [IO.FILE]::OpenWrite($psFile)
                $fileTest.close()
                $fileIseTest = [IO.FILE]::OpenWrite($psIseFile)
                $fileIseTest.close()
            }

            catch
            {
                $errorMsg = "The current user does not have write permissions"
                $errorMsg += " on this system which is needed"
                $errorMsg += " to change the CLR version."
                $errorMsg += "Please enable write permissions and try again."
                Write-Host $errorMsg
            }

            Write-Host "Changing CLRversion..."

            $config_text | Out-File $pshome\powershell.exe.config
            $config_text | Out-File $pshome\powershell_ise.exe.config

            Write-Host "CLRVersion Changed..."
            Write-Host "Press any key to continue..."
            $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
        }

        # If user does not want to change the CLRVersion, then exit the script
        # with appropriate message
        elseif ($permission -eq "n")
        {
            Write-Host "Cannot proceed without changing the CLRVersion..."
            Write-Host "Exiting the script..."
            Write-Host "Press any key to exit..."
            $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
            Exit
        }

        else
        {
            Write-Host "Please enter a valid choice "
        }
    } while (!(($permission -eq "y") -or ($permission -eq "n")))
}

# If CLRVersion is 4.0, then directly go on to importing the modules
else
{
    Write-Host "CLRVersion found compatible with DLLs"
    Write-Host "Press any key to continue importing the modules..."
    
}

$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$importScript = $PSScriptRoot + "\ImportModules"

RestartPowershell $importScript
Exit
