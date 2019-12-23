Function REST-Query-Portal-API {
  param(
    [string] $url,
    [string] $cookiestring
  )
  $CookieObj = New-Object System.Net.Cookie
  $CookieObj.Name = "authToken"
  $CookieObj.Value = $cookiestring
  [System.Uri]$uri = "https://portal.nutanix.com" 
  $CookieObj.Domain = $uri.DnsSafeHost
  $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $WebSession.Cookies.Add($CookieObj)
  
  try{
    $task = Invoke-RestMethod -Method Get -Uri $url -websession $websession
  } catch {
    sleep 10

    write-log -message "Error Caught on function" -sev "WARN"

    $task = Invoke-RestMethod -Method Get -Uri $url -websession $websession
  }

  Return $task
} 


Function REST-Portal-Query-ReleaseAPI-ERA {
  Param (
    [object] $datagen,
    [object] $datavar
  )
  $token1 = get-content "$basedir\ReleaseToken1.txt"
  $token2 = get-content "$basedir\ReleaseToken2.txt"
  $headers = @{ 'Authorization' = "Basic $token1"; "X-NTNX-Portal" = "$token2" }
  
  $URL = "https://stage-release-api.nutanix.com/api/v2/era/"

  write-log -message "Query ERA Builds"
  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }

  Return $task
} 

Function REST-Portal-Query-AssetOtions {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  $URL = "https://portal.nutanix.com/api/v1/assetoptions"

  write-log -message "Query Portal Builds"
  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }

  Return $task
} 


Export-ModuleMember *