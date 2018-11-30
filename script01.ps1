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

# Group Name
[string]$GroupName = "*" + $ServiceName + "*"

# Path to csptest.exe
$CSPpath = "C:\Program Files\Crypto Pro\CSP"

# Check environment variable PATH and add path to "csptest.exe" if needed
IF ($env:Path -notlike "Crypto Pro") {
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
    $RegRoot = "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Crypto Pro\Settings\Users\"
    } ELSE {
        # and x86
        $RegRoot = "HKEY_LOCAL_MACHINE\SOFTWARE\Crypto Pro\Settings\Users\"
        }


# End of path
$Keys = "\Keys"

# Full hive
$KeyHive = $RegRoot + $SID + $Keys

$RegQuery = reg query $KeyHive

foreach ($R in $RegQuery) {
    IF ($R -like $GroupName) {
        $exportName = $R.Substring($KeyHive.Length+1)
        echo $exportName
        $exportPath = "C:\" + $exportName + ".reg"
        reg export $R $exportPath
        }
    }