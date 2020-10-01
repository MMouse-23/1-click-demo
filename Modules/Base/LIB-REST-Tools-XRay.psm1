

Function REST-XRay-Login {
  Param (
    [object] $appdetail,
    [object] $action,
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "nutanix:nutanix/4u"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Replacing JSON String Variables"
$Json = @"
{
    "password":"$($datavar.PEPass)"
}
"@ 
  $URL = "https://$($datagen.XRayIP)/xray/v1/auth"

  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-XRay-Accept-EULA {
  Param (
    [object] $datagen,
    [object] $datavar,
    [object] $eula
  )

  $credPair = "$($datavar.peadmin):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Accepting XRay EULA"

  $Json = @"
{
  "content": "abc",
  "pulse_optional": true,
  "accepted": true,
  "pulse_content": "abc",
  "pulse_accepted": true
}
"@ 
  
  $object = $json | convertfrom-json
  $object.content = $eula.content
  $object.pulse_content = $eula.pulse_content

  $json = $object | convertto-json -depth 100

  $URL = "https://$($datagen.XRayIP)/xray/v1/eula"

  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "post" -body $Json -ContentType 'application/json' -headers $headers;
  }

  Return $task
} 

Function REST-XRay-GET-EULA {
  Param (
    [object] $datagen,
    [object] $datavar
  )

  $credPair = "$($datavar.peadmin):$($datavar.PEPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Getting XRay EULA"

  $URL = "https://$($datagen.XRayIP)/xray/v1/eula"

  write-log -message "Using URL $URL"

  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET"  -headers $headers;
  } catch {
    sleep 10

    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers;
  }

  Return $task
} 