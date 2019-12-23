function Slack-Send-DirectMessage {
  param(
    $user,
    $token,
    $message
  )
  $headers = @{ Authorization = "Bearer $token" }  

  $body = @"
{
    "token": "$token",
    "user": "$user",
}
"@ 
  $directopen = Invoke-RestMethod -Uri https://slack.com/api/im.open -method "POST" -Body $body -ContentType 'application/json' -headers $headers;
  #

  $body = @"
{
    "text": "$message",
    "token": "$token",
    "channel": "$($directopen.channel.id)",
}
"@ 

  $directsend = Invoke-RestMethod -Uri https://slack.com/api/chat.postMessage -method "POST" -Body $body -ContentType 'application/json' -headers $headers;

}
