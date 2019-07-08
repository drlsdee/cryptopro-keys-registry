$StartLocation = Get-Location
$WrkDirName = "RegKeys"
$WorkingDir = Join-Path -Path $StartLocation -ChildPath $WrkDirName
$SrcDirName = "src"
$SourceDir = Join-Path -Path $WorkingDir -ChildPath $SrcDirName
$ODirNameX86 = "x86out"
$OutDirX86 = Join-Path -Path $WorkingDir -ChildPath $ODirNameX86
$ODirNameX64 = "x64out"
$OutDirX64 = Join-Path -Path $WorkingDir -ChildPath $ODirNameX64


$SourceFiles = Get-ChildItem -Path $SourceDir -File -Filter "*.reg"

$Regex = "(S\-){1}(\d\-){2}\d{2}\-\d{9}\-\d{10}\-\d{9}\-\d{3,}"

Set-Location -Path $WorkingDir

[array]$Usernames = Get-Content -Path ".\Usernames.txt"

function Get-UserSID {
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Username
    )
    Write-Verbose -Message "Given username is $Username"
    $UserSID = (Get-ADUser -Identity $Username).SID.Value
    return $UserSID
}

function Check-DestFolder {
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $DestFolder
    )
    [string]$Parent = $DestFolder | Split-Path -Parent
    [string]$Child = $DestFolder | Split-Path -Leaf
    if (Test-Path -Path $DestFolder -PathType Container) {
        Write-Verbose -Message "Destination folder exists"
    } elseif (Test-Path -Path $DestFolder -PathType Leaf) {
        Write-Warning -Message "File with name '$Child' already exists in path '$Parent'! Trying to remove..."
        try {
            Remove-Item -Path $DestFolder -Force -ErrorAction Stop -Verbose
            Write-Warning -Message "File '$Child' deleted successfully. Creating folder..."
            New-Item -Path $Parent -Name $Child -ItemType Directory -ErrorAction Stop -Verbose
        } catch {
            Write-Error -Message "Cannot remove file!"
        }
    } else {
        Write-Warning -Message "Destination folder does NOT exists!"
        try {
            Write-Verbose -Message "Creating destination folder..."
            New-Item -Path $Parent -Name $Child -ItemType Directory -ErrorAction Stop -Verbose
        } catch {
            Write-Error -Message "Cannot create folder!"
        }
    }
}

function Replace-SIDinString {
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $NewSID,

        [Parameter(Mandatory=$true)]
        [string]
        $SourceString,

        [Parameter()]
        [switch]
        $ExcludeWOW6432,

        [Parameter()]
        [regex]
        $SIDregex = "(S\-){1}(\d\-){2}\d{2}\-\d{9}\-\d{10}\-\d{9}\-\d{3,}"
    )
    Write-Verbose -Message "Given new SID is $NewSID"
    Write-Verbose -Message "Source string is $SourceString"
    Write-Verbose -Message "Regex to validate SID is $SIDregex"
    if ($ExcludeWOW6432) {
        Write-Warning -Message "WOW64 node will be EXCLUDED!"
    }
    Write-Verbose -Message "Splitting source string to array of substrings..."
    [array]$StringToArray = $SourceString -split "\\"
    $StringToArray.ForEach({Write-Verbose -Message $_})
    if ($ExcludeWOW6432) {
        Write-Warning -Message "Excluding 'Wow6432Node'..."
        if ($StringToArray -notcontains "Wow6432Node") {
            Write-Warning -Message "Registry node 'Wow6432Node' does not exists. Nothing to do!"
        } else {
            [array]$newArray = $StringToArray.Where({$_ -ne "Wow6432Node"})
            $newArray.ForEach({Write-Warning -Message $_})
            $StringToArray = $newArray
        }
    } else {
        Write-Verbose -Message "Check if node 'Wow6432Node' exists..."
        if ($StringToArray -contains "Wow6432Node") {
            Write-Verbose -Message "Registry node 'Wow6432Node' exists. Nothing to do!"
        } else {
            Write-Verbose -Message "Registry node 'Wow6432Node' will be added after nodes 'HKLM\SOFTWARE'..."
            $Wow6432NodeIndex = $StringToArray.IndexOf("SOFTWARE") + 1
            Write-Verbose -Message "... at index $Wow6432NodeIndex"
            [System.Collections.ArrayList]$StrToArrList = $StringToArray
            $StrToArrList.Insert($Wow6432NodeIndex,"Wow6432Node")
            $StringToArray = $StrToArrList
            Write-Verbose -Message "Node inserted:"
            $StringToArray.ForEach({Write-Verbose -Message $_})
        }
    }

    Write-Verbose -Message "Finding source SID..."
    [string]$SourceSID = $StringToArray.Where({$_ -match $SIDregex})
    Write-Verbose -Message "Source SID found: $SourceSID"
    Write-Verbose -Message "Finding position of SID in source string..."
    [int]$SIDindex = $StringToArray.IndexOf($SourceSID)
    Write-Verbose -Message "Index of SID is $SIDIndex"
    Write-Verbose -Message "Replacing source SID $SourceSID to new SID $NewSID"
    $StringToArray.SetValue($NewSID,$SIDindex)
    $StringToArray.ForEach({Write-Verbose -Message $_})
    Write-Verbose -Message "Join array back to string..."
    [string]$NewString = $StringToArray -join "\"
    Write-Verbose -Message "New string:"
    Write-Verbose -Message $NewString
    return $NewString
}

function Replace-SIDinRegKey {
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $NewSID,

        [Parameter(Mandatory=$true)]
        [array]
        $SourceReg,

        [Parameter()]
        [switch]
        $ExcludeWOW6432,

        [Parameter()]
        [regex]
        $SIDregex = "(S\-){1}(\d\-){2}\d{2}\-\d{9}\-\d{10}\-\d{9}\-\d{3,}"
    )
    Write-Verbose -Message "Given new SID is $NewSID"
    Write-Verbose -Message "First 5 strings of source registry key:"
    $SourceReg[0..5].ForEach({Write-Verbose -Message $_})
    Write-Debug -Message "Full content is here:"
    $SourceReg.ForEach({Write-Debug -Message $_})
    Write-Verbose -Message "Regex to validate SID is $SIDregex"
    if ($ExcludeWOW6432) {
        Write-Warning -Message "WOW64 node will be EXCLUDED!"
    }
    Write-Verbose -Message "Selecting strings containing SIDs..."
    [array]$MatchingStrings = $SourceReg.Where({$_ -match $SIDregex})
    Write-Verbose -Message "Found $($MatchingStrings.Count) matches:"
    $MatchingStrings.ForEach({Write-Verbose -Message $_})
    Write-Verbose -Message "Replacing SIDs in strings..."
    $MatchingStrings.ForEach({
        Write-Verbose -Message "Source string is:"
        Write-Verbose -Message $_
        if ($ExcludeWOW6432) {
            Write-Warning -Message "Excluding Wow6432Node..."
            $NewString = Replace-SIDinString -NewSID $NewSID -SourceString $_ -SIDregex $SIDregex -ExcludeWOW6432
        } else {
            $NewString = Replace-SIDinString -NewSID $NewSID -SourceString $_ -SIDregex $SIDregex
        }
        Write-Verbose -Message "NEW STRING IS:"
        Write-Verbose -Message $NewString
        $IndexOfString = $SourceReg.IndexOf($_)
        Write-Verbose -Message "Index of current string is $IndexOfString"
        Write-Verbose -Message "Replacing string $_ to $NewString"
        $SourceReg.SetValue($NewString,$IndexOfString)
        Write-Verbose -Message "Old value was:"
        Write-Verbose -Message $_
        Write-Verbose -Message "NEW VALUE IS:"
        Write-Verbose -Message $SourceReg[$IndexOfString]
    })
    Write-Verbose -Message "Returning result..."
    return $SourceReg
}

function Replace-SIDinFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $SourceFile,

        [Parameter(Mandatory=$true)]
        [string]
        $Destination,

        [Parameter(Mandatory=$true)]
        [string]
        $Username,
        
        [Parameter()]
        [switch]
        $ExcludeWOW6432,

        [Parameter()]
        [regex]
        $SIDregex = "(S\-){1}(\d\-){2}\d{2}\-\d{9}\-\d{10}\-\d{9}\-\d{3,}"
    )
    begin {
        Write-Verbose -Message "Given source file is $SourceFile"
        Write-Verbose -Message "Destination folder is $Destination"
        Write-Verbose -Message "Given username is $Username"
        Write-Verbose -Message "Regex to validate SID is $SIDregex"
        if ($ExcludeWOW6432) {
            Write-Warning -Message "WOW64 node will be EXCLUDED!"
        }
        if (Test-Path -Path $SourceFile -PathType Leaf) {
            Write-Verbose -Message "Source file exists"
        } else {
            Write-Error -Message "Source file does NOT exists!"
            stop
        }
        Check-DestFolder -DestFolder $Destination
    }

    process {
        Write-Verbose -Message "Getting SID by username..."
        [string]$UserSID = Get-UserSID -Username $Username
        Write-Verbose -Message "User's SID is $UserSID"

        $Rand = New-Guid
        $FileName = $Rand,"reg" -join "."
        Write-Verbose -Message "Name of output file is $FileName"
        $UserFolder = Join-Path -Path $Destination -ChildPath $Username
        Write-Verbose -Message "Destination folder is the folder '$Username' in the destination path:"
        Write-Verbose -Message $UserFolder
        Write-Verbose -Message "Check if the folder exists..."
        Check-DestFolder -DestFolder $UserFolder
        [string]$FullPath = Join-Path -Path $UserFolder -ChildPath $FileName
        Write-Verbose -Message "Full destination path is $FullPath"

        Write-Verbose -Message "Getting content from source regfile..."
        [array]$KeyContent = Get-Content -Path $SourceFile
        Write-Verbose -Message "First 5 strings of registry key:"
        $KeyContent[0..5].ForEach({Write-Verbose -Message $_})
        Write-Debug -Message "Full content is here:"
        $KeyContent.ForEach({Write-Debug -Message $_})

        Write-Verbose -Message "Start working with registry key..."
        if ($ExcludeWOW6432) {
            Write-Warning -Message "Excluding Wow6432Node..."
            $NewRegKey = Replace-SIDinRegKey -NewSID $UserSID -SourceReg $KeyContent -SIDregex $SIDregex -ExcludeWOW6432
        } else {
            $NewRegKey = Replace-SIDinRegKey -NewSID $UserSID -SourceReg $KeyContent -SIDregex $SIDregex
        }
    }

    end {
        Out-File -FilePath $FullPath -InputObject $NewRegKey
    }
}

function Replace-SIDinRegFiles {
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $SourcePath,

        [Parameter(Mandatory=$true)]
        [string]
        $DestinationPath,

        [Parameter(Mandatory=$true)]
        [string]
        $Username,
        
        [Parameter()]
        [switch]
        $ExcludeWOW6432,

        [Parameter()]
        [regex]
        $SIDregex = "(S\-){1}(\d\-){2}\d{2}\-\d{9}\-\d{10}\-\d{9}\-\d{3,}"
    )
    Write-Verbose -Message "Source path is $SourcePath"
    Write-Verbose -Message "Destination path is $DestinationPath"
    Write-Verbose -Message "Selected username is $Username"
    Write-Verbose -Message "Regex to validate SID is $SIDregex"
    if ($ExcludeWOW6432) {
        Write-Warning -Message "WOW64 node will be EXCLUDED!"
    }
    Write-Verbose -Message "List of regfiles in source folder:"
    [array]$SourceRegFiles = (Get-ChildItem -Path $SourcePath -File -Filter "*.reg").FullName
    $SourceRegFiles.ForEach({Write-Verbose -Message $_})
    Write-Verbose -Message "Start working..."
    if ($ExcludeWOW6432) {
        $SourceRegFiles.ForEach({
            Replace-SIDinFile -SourceFile $_ -Destination $DestinationPath -Username $Username -SIDregex $Regex -ExcludeWOW6432
        })
    } else {
        $SourceRegFiles.ForEach({
            Replace-SIDinFile -SourceFile $_ -Destination $DestinationPath -Username $Username -SIDregex $Regex
        })
    }
}

$Usernames.ForEach({
    Replace-SIDinRegFiles -SourcePath $SourceDir -DestinationPath $OutDirX86 -Username $_ -ExcludeWOW6432
    Replace-SIDinRegFiles -SourcePath $SourceDir -DestinationPath $OutDirX64 -Username $_
})

Write-Host -Object "===================================="

Set-Location -Path $StartLocation
<#
TODO:
arrays to arraylists
resolve usernames to SIDs separately
Too much repeats!
#>