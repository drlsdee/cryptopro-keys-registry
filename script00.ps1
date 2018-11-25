<#
Задачи.
Получить список пользователей домена, имеющих право использования контейнеров
Конвертировать их имена в SID-ы
Получить список ПК с установленной КриптоПро
Записать в ветку реестра "HKLM\...\SID\Keys" список контейнеров
Запустить "CSP\csptest.exe -absorb -certs"
#>

#OU for PC
[string]$LDAPSearchBasePC = "OU=Buch-PC,OU=Buch,OU=UMU,DC=mmc,DC=local"
#OU for users
[string]$LDAPSearchBaseUsers = "OU=Buch-Users,OU=Buch,OU=UMU,DC=mmc,DC=local"
#PC name
[string]$PCname = $env:COMPUTERNAME
#Username
[string]$User = $null
#SID
[string]$SID = $null
[string]$CSPpath = "C:\Program Files\Crypto Pro\CSP\"
[string]$RegistryPath = $null

# Root reg path for key containers
[string]$RegRoot
IF ((Get-WmiObject Win32_OperatingSystem -ComputerName $PCname).OSArchitecture -like "64*") {
    [string]$RegRoot = "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Crypto Pro\Settings\Users\"
    } ELSE {
        [string]$RegRoot = "HKEY_LOCAL_MACHINE\SOFTWARE\Crypto Pro\Settings\Users\"
        }
# For x64
#HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Crypto Pro\Settings\Users\ + SID + \Keys
# For x86
#HKEY_LOCAL_MACHINE\SOFTWARE\Crypto Pro\Settings\Users\ + SID + \Keys
[string]$RegKey = $null

