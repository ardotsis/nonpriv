function Get-SystemUuid {
    return Get-WmiObject Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID
}

function ConvertTo-Sha256 ([string] $String) {
    $stream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($String))
    return (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash
}


$ErrorActionPreference = "SilentlyContinue"

# Stop the instance of powershell that handles main script
Get-Process -Name "powershell" | ForEach-Object {
    if ($_.Id -ne $PID) {
        Stop-Process -Id $_.Id -Force
    }
}

# Delete the base folder in "Temp" directory
$sha256uuid = ConvertTo-Sha256 -String (Get-SystemUuid)
$baseDir = Join-Path -Path $Env:TEMP -ChildPath $sha256uuid
Write-Output "Remove base directory [$baseDir]"
Remove-Item -Path $baseDir -Recurse -Force

# Delete VBS script
$vbsFilePath = Join-Path -Path $Env:TEMP -ChildPath "0.vbs"
Write-Output "Remove vbs file [$vbsFilePath]"
Remove-Item -Path $vbsFilePath -Force

# Delete auto run registry key
$autoRunKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$autoRunValueName = "Windows Helper"
Write-Output "Remove auto run registy key [$autoRunKeyPath ($autoRunValueName)]"
Remove-ItemProperty -Path $autoRunKeyPath -Name $autoRunValueName -Force

Write-Output "`nDone"
Start-Sleep -Seconds 1
