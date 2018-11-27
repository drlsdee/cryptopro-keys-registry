<#
Задачи.
Получить список пользователей домена, имеющих право использования контейнеров
Конвертировать их имена в SID-ы
Получить список ПК с установленной КриптоПро
Записать в ветку реестра "HKLM\...\SID\Keys" список контейнеров
Запустить "CSP\csptest.exe -absorb -certs"

Входные параметры:
Эталонный пользователь (если не задано, текущий)
Эталонный компьютер (если не задано, текущий)
Группа пользователей
Назначение сертификатов (наименование сервиса - СУФД, Контур итп; наименование или иной ИД владельца; возможно, стоит связать с названием групп)
Компьютеры (при распространении через SCCM - обойтись коллекциями?)
#>

# DomainName
$DomainName = Get-ADDomain | Select-Object DistinguishedName -ExpandProperty DistinguishedName

# Group Name
$GroupName = "Kontur-Users"

# Array with PC names
$PCnames = Get-ADComputer -LDAPFilter "(name=*)" -SearchBase $DomainName | Select-Object DNSHostName -ExpandProperty DNSHostName
# PC name
[string]$PCname = $env:COMPUTERNAME

# Array with SIDs
$UserSIDs = $null
$UserSIDs = Get-ADGroup -LDAPFilter "(Name=$GroupName)" | Get-ADGroupMember | Select-Object SID -ExpandProperty SID | Select-Object Value -ExpandProperty Value

# Single SID
[string]$SID = $null
[string]$SID = (Get-ADUser -Filter {SamAccountName -eq "Administrator"}).SID
[string]$CSPpath = "C:\Program Files\Crypto Pro\CSP\"

# Root reg path for key containers
[string]$RegRoot
IF ((Get-WmiObject Win32_OperatingSystem -ComputerName $PCname).OSArchitecture -like "64*") {
    # Path to regkeys on x64
    $RegRoot = "HKLM:SOFTWARE\Wow6432Node\Crypto Pro\Settings\Users\"
    } ELSE {
        # and x86
        $RegRoot = "HKLM:SOFTWARE\Crypto Pro\Settings\Users\"
        }

# End of path
$Keys = "\Keys"

# Full hive
$KeyHive = $RegRoot + $SID + $Keys