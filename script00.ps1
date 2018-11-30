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
# Set input parameters
param (
        # Название сервиса, для которого используются ключи. "СУФД", "ЕИС", "Контур" и т.п. Должно содержаться как в названии контейнера, так и в названии группы.
        $ServiceName,
        # Имя ПК-источника. Если не задано, должен использоваться локальный компьютер.
        $SourcePC,
        # Логин учетной записи-источника. Если не задано, текущий пользователь.
        $SourceUser
        )

# Read the service name
IF ($ServiceName -eq $null) {
    $ServiceName = Read-Host "Enter service name here"
    }

# Read the name of the source PC
IF ($SourcePC -eq $null) {
    $SourcePC = $env:COMPUTERNAME
    }

# Read the name of the source user
IF ($SourceUser -eq $null) {
    $SourceUser = $env:USERNAME
    }


# DomainName
$DomainName = Get-ADDomain | Select-Object DistinguishedName -ExpandProperty DistinguishedName

# Group Name
[string]$GroupName = "*" + $ServiceName + "*"

# Path to csptest.exe
$CSPpath = "C:\Program Files\Crypto Pro\CSP"

# Check environment variable PATH and add path to "csptest.exe" if needed
IF ($env:Path -notlike "*Crypto Pro*") {
    $env:PATH = $env:PATH + ";" + $CSPpath
    echo $env:PATH
    } ELSE {
        echo $env:PATH
        }

# Array with target PC names
$PCnames = $null
$PCnames = Get-ADGroup -LDAPFilter "(Name=$GroupName)" | Get-ADGroupMember | Where-Object -Property objectClass -eq computer | Select-Object name -ExpandProperty name

# Single PC
$PC = $SourcePC

# Array with SIDs
$UserSIDs = $null
$UserSIDs = Get-ADGroup -LDAPFilter "(Name=$GroupName)" | Get-ADGroupMember | Where-Object -Property objectClass -eq user | Select-Object SID -ExpandProperty SID | Select-Object Value -ExpandProperty Value

# Single SID
[string]$SID = $null
[string]$SID = (Get-ADUser -Filter {SamAccountName -eq $SourceUser}).SID

# Root reg path for key containers
[string]$RegRoot

IF ((Get-WmiObject Win32_OperatingSystem -ComputerName $PC).OSArchitecture -like "64*") {
    # Path to regkeys on x64
    $RegRoot = "HKLM:SOFTWARE\Wow6432Node\Crypto Pro\Settings\Users\"
    } ELSE {
        # and x86
        $RegRoot = "HKLM:SOFTWARE\Crypto Pro\Settings\Users\"
        }


# End of path
$endOfPath = "\Keys"

# Full hive
$KeyHive = $RegRoot + $SID + $endOfPath

# Select hives with keys
$Keys = Get-ChildItem $KeyHive |  Where-Object Name -Like $GroupName

$UserSIDs
$PCnames
$KeyHive

foreach ($K in $Keys) {
    $Kpath = $K.Name
    Get-ItemProperty -Path Registry::$Kpath
    }