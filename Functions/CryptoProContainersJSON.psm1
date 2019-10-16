function Get-DateForLogs {
    param (
        [Parameter()]
        # DateTime format
        [string]
        $Format = 'yyyy-MM-dd HH:mm:ss:fff',

        [Parameter()]
        [Alias('fn')]
        # Function name
        [string]
        $FunctionName
    )
    $dt = Get-Date -Format $Format
    $outString = "[$dt]: [$FunctionName]:"
    $outString
}

function Get-SIDbyUserName {
    [CmdletBinding()]
    param (
        [Parameter()]
        # Username (sAMaccountName); default is "env:USERNAME"
        [string]
        $Username = $env:USERNAME
    )
    [string]$outString = (Get-WmiObject -Class Win32_UserAccount -Filter "Name = '$Username'").SID
    return $outString
}

function Get-CryptoProRegContainersPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,ParameterSetName='SID')]
        # SID of target user
        [string]
        $SID,

        [Parameter(Mandatory=$true,ParameterSetName='UserName')]
        # Username
        [string]
        $Username
    )
    $theFName = $MyInvocation.MyCommand.Name
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Starting function..."
    if ($Username) {
        Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Defined the username: `"$Username`". Resolving to SID..."
        $SID = Get-SIDbyUserName -Username $Username
    }
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Defined the SID: `"$SID`""
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Defining OS architecture by WMI"
    $archOS = (Get-WmiObject -Class Win32_OperatingSystem).OSArchitecture -replace '[^0-9]', ''
    if ($archOS -eq 64) {
        $regCryptPath = 'HKLM:\SOFTWARE\Wow6432Node'
    } elseif ($archOS -eq 32) {
        $regCryptPath = 'HKLM:\SOFTWARE'
    }
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) OS architecture is $archOS-bit and root hive for CryptoPro keys should be: `"$regCryptPath`"."
    $regUserSubPath = 'Crypto Pro\Settings\Users'
    $outPath = "$regCryptPath\$regUserSubPath\$SID\Keys"
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Path to CryptoPro registry containers: `"$outPath`""
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) End of function."
    return $outPath
}

function Export-RegKeyToObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        # Registry key
        [Microsoft.Win32.RegistryKey]
        $RegistryKey,

        [Parameter()]
        # Keyword for define registry key name
        [string]
        $KeyName = 'Name',

        [Parameter()]
        # Keyword for define name of array of registry key properties
        [string]
        $PropertyName = 'Property'
    )
    $theFName = $MyInvocation.MyCommand.Name
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Starting function..."
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Executing operation on reg key: `"$RegistryKey`""
    $outObject = New-Object -TypeName PSObject
    [string]$keyNameShort = $RegistryKey.PSChildName
    $outObject | Add-Member -MemberType NoteProperty -Name $KeyName -Value $keyNameShort
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Added property `"$KeyName`" to output object."
    $propObject = New-Object -TypeName PSObject
    [array]$keyPropertyNames = $RegistryKey.Property
    foreach ($propName in $keyPropertyNames) {
        $propNameEscaped = $propName
        $Value = $RegistryKey.GetValue($propName)
        $propObject | Add-Member -MemberType NoteProperty -Name $propNameEscaped -Value $Value
    }
    $outObject | Add-Member -MemberType NoteProperty -Name $PropertyName -Value $propObject
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) End of function."
    return $outObject
}

function Import-RegKeyFromObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        # PSObject containing registry key to import
        [PSObject]
        $InputObject,

        [Parameter(Mandatory=$true)]
        # Path to registry hive
        [string]
        $RegHive,

        [Parameter()]
        # Keyword for define registry key name
        [string]
        $KeyName = 'Name',

        [Parameter()]
        # Keyword for define name of array of registry key properties
        [string]
        $PropertyName = 'Property',

        [Parameter()]
        # Create key even if exists
        [switch]
        $Force
    )
    $theFName = $MyInvocation.MyCommand.Name
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Starting function..."
    if (-not (Test-Path -Path $RegHive)) {
        Write-Warning -Message "$(Get-DateForLogs -fn $theFName) Registry path `"$RegHive`" IS INVALID! Exiting..."
        return
    } else {
        Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Using registry path `"$RegHive`"..."
    }
    $regKeyName = $InputObject.$KeyName
    $regKeyPath = "$RegHive\$regKeyName"
    if ((Test-Path -Path $regKeyPath) -and (-not $Force)) {
        Write-Warning -Message "$(Get-DateForLogs -fn $theFName) The key `"$regKeyPath`" already exists! Exiting..."
        return
    } else {
        Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Creating key `"$regKeyPath`"..."
        [Microsoft.Win32.RegistryKey]$newRegKey = New-Item -Path $regKeyPath -Force
        Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Key `"$($newRegKey.Name)`" created."
        Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Reading properties of input object..."
        $propertyList = $InputObject.$PropertyName.PSObject.Properties.Name
        $propertyObject = $InputObject.$PropertyName
        foreach ($propName in $propertyList) {
            Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Property `"$propName`" found"
            [byte[]]$propValue = $propertyObject.$propName
            $newRegKey.SetValue($propName,$propValue)
        }
    }
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) End of function."
    return
}

function Export-CryptoProContainersToJSON {
    [CmdletBinding()]
    param (
        [Parameter()]
        # UserName (default is current user)
        [string]
        $Username = $env:USERNAME,

        [Parameter()]
        # Path to output folder (default is current user's profile folder). MUST BE WRITABLE!
        [string]
        $OutputFolder = $env:USERPROFILE,

        [Parameter()]
        # Name of target container (if not set, all containers will be exported)
        [string]
        $ContainerName,

        [Parameter()]
        # Keyword for define registry key name
        [string]
        $KeyName = 'Name',

        [Parameter()]
        # Keyword for define name of array of registry key properties
        [string]
        $PropertyName = 'Property',

        [Parameter()]
        # Tries to write output file even if the file already exists
        [switch]
        $Force
    )
    $theFName = $MyInvocation.MyCommand.Name
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Starting function..."
    $regHivePath = Get-CryptoProRegContainersPath -Username $Username
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Exporting containers for user `"$Username`" from hive `"$regHivePath`" to folder `"$OutputFolder`"..."
    if ((-not (Test-Path -Path $OutputFolder -PathType Container))) {
        Write-Warning -Message "$(Get-DateForLogs -fn $theFName) Folder `"$OutputFolder`" DOES NOT EXISTS! Trying to create..."
        try {
            New-Item -Path $OutputFolder -ItemType Directory -Force
            $OutputFolder = (Get-Item -Path $OutputFolder).FullName
            Write-Warning -Message "$(Get-DateForLogs -fn $theFName) Folder `"$OutputFolder`" created."
        } catch {}
    }
    if (-not (Test-Path -Path $regHivePath -PathType Container)) {
        Write-Warning -Message "$(Get-DateForLogs -fn $theFName) Registry hive `"$regHivePath`" DOES NOT EXISTS! Exiting..."
        return
    }
    $regContainersAll = Get-ChildItem -Path $regHivePath
    if ($ContainerName) {
        $regContainersExport = $regContainersAll | Where-Object {$_.PSChildName -match $ContainerName}
    } else {
        $regContainersExport = $regContainersAll
    }
    foreach ($regCont in $regContainersExport) {
        $expObject = Export-RegKeyToObject -RegistryKey $regCont -KeyName $KeyName -PropertyName $PropertyName
        $expString = $expObject | ConvertTo-Json -Compress
        $expFileName = "$($expObject.$KeyName).json"
        $expFilePath = "$OutputFolder\$expFileName"
        if ((Test-Path -Path $expFilePath -PathType Any) -and (-not $Force)) {
            Write-Warning -Message "$(Get-DateForLogs -fn $theFName) File `"$expFileName`" already exists in path `"$OutputFolder`". Skipping..."
        } else {
            Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Creating the file `"$expFileName`" in path `"$OutputFolder`"..."
            $expString | Out-File -FilePath $expFilePath -Force
        }
    }
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) End of function."
    return
}

function Import-CryptoProContainersFromJSON {
    [CmdletBinding()]
    param (
        [Parameter()]
        # UserName (default is current user)
        [string]
        $Username = $env:USERNAME,

        [Parameter()]
        # Path to output folder (default is current user's profile folder). MUST BE WRITABLE!
        [string]
        $InputFolder = $env:USERPROFILE,

        [Parameter()]
        # Name of target container (if not set, all containers will be exported) #NOT USED NOW
        [string]
        $ContainerName,

        [Parameter()]
        # Keyword for define registry key name
        [string]
        $KeyName = 'Name',

        [Parameter()]
        # Keyword for define name of array of registry key properties
        [string]
        $PropertyName = 'Property',

        [Parameter()]
        # Tries to write output file even if the file already exists
        [switch]
        $Force
    )
    $theFName = $MyInvocation.MyCommand.Name
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Starting function..."
    $regHivePath = Get-CryptoProRegContainersPath -Username $Username
    if (-not (Test-Path -Path $InputFolder -PathType Container)) {
        Write-Warning -Message "$(Get-DateForLogs -fn $theFName) Input folder `"$InputFolder`" DOES NOT EXISTS OR UNREACHABLE. Exiting..."
        return
    } else {
        $InputFolder = (Resolve-Path -Path $InputFolder).Path
        Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Path to input folder `"$InputFolder`" resolved, folder exists."
    }
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Importing containers for user `"$Username`" from folder `"$InputFolder`" to hive `"$regHivePath`"..."
    [array]$inputFiles = (Get-ChildItem -Path $InputFolder | Where-Object {$_.Extension -eq '.json'}).FullName
    if (-not $inputFiles) {
        Write-Warning -Message "$(Get-DateForLogs -fn $theFName) Source JSON files in the folder `"$InputFolder`" NOT FOUND. Exiting..."
        return
    } else {
        Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) In the folder `"$InputFolder`" found $($inputFiles.Count) JSON files."
        foreach ($srcFile in $inputFiles) {
            Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Executing file: `"$srcFile`""
            $srcObject = Get-Content -Path $srcFile | ConvertFrom-Json
            Import-RegKeyFromObject -InputObject $srcObject -RegHive $regHivePath -Force:$Force -KeyName $KeyName -PropertyName $PropertyName
        }
    }
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) End of function."
    return
}

function Import-CryptoProCertsFromContainers {
    [CmdletBinding()]
    param ()
    $theFName = $MyInvocation.MyCommand.Name
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Starting function..."
    [string]$cspBinPath = "$env:ProgramFiles\Crypto Pro\CSP"
    [string]$cspTestExe = 'csptest.exe'
    if (-not (Test-Path -Path "$cspBinPath\$cspTestExe" -PathType Leaf)) {
        Write-Warning -Message "$(Get-DateForLogs -fn $theFName) Program `"$cspTestExe`" not found! Exiting..."
        return
    } else {
        Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) Program `"$cspTestExe`" found! Continue..."
        # Codepage MUST be 1251!
        chcp 1251 | Out-Null
        Start-Process -FilePath "$cspBinPath\$cspTestExe" -ArgumentList '-absorb -certs' -NoNewWindow
        #$cspTestOut
    }
    Write-Verbose -Message "$(Get-DateForLogs -fn $theFName) End of function."
    return
}
Export-ModuleMember -Function 'Export-CryptoProContainersToJSON'
Export-ModuleMember -Function 'Import-CryptoProContainersFromJSON'
Export-ModuleMember -Function 'Import-CryptoProCertsFromContainers'